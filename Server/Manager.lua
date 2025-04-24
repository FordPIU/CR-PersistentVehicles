--[[
    Manages the state, loading, saving, and spawning of persistent vehicles.
    Includes API for managing custom vehicle data.
]]

-- Stores the data for all persistent vehicles managed by this resource.
-- Key: Vehicle UID (string, format: "modelHash-plateIndex-plateText")
-- Value: Table containing vehicle properties, including an optional 'customData' sub-table.
--        OR `true` if the vehicle is newly registered but properties haven't been saved yet.
local Vehicles = {}
local dataNeedsSaving = false -- Flag to track if data has changed and needs saving

-- Table to prevent respawning vehicles that were intentionally deleted (e.g., via ForgetVehicle)
DO_NOT_RESPAWN = {} -- Make sure this is accessible by Events.lua

--[[--------------------------------------------------------------------------
    Utility Functions (Internal)
--------------------------------------------------------------------------]]

--- Gets the internal data table for a specific vehicle UID.
--- @param vehicleUID string The unique identifier of the vehicle.
--- @return table|nil The vehicle's data table, or nil if not found or data is not a table.
local function getVehicleData(vehicleUID)
    if not vehicleUID then return nil end
    local data = Vehicles[vehicleUID]
    -- Return data only if it's a table (meaning properties are saved)
    if type(data) == "table" then
        return data
    end
    return nil -- Return nil if data is 'true' or vehicle doesn't exist
end

--- Generates a unique identifier string for a vehicle based on its model, plate index, and plate text.
--- @param vehicle number The entity handle of the vehicle.
--- @return string The unique identifier string (e.g., "adder-0-MYPLATE"). Returns nil if vehicle is invalid.
function GetVehicleUID(vehicle)
    if not DoesEntityExist(vehicle) or GetEntityType(vehicle) ~= 2 then
        return nil
    end
    local vehicleModel = GetEntityModel(vehicle) -- This is typically the hash as a number
    local plateText = GetVehicleNumberPlateText(vehicle)
    local plateIndex = GetVehicleNumberPlateTextIndex(vehicle)

    -- Using string format ensures consistent key type
    return string.format("%s-%d-%s", vehicleModel, plateIndex, plateText)
end

-- Export for potential external use server-side
exports("GetVehicleUID", GetVehicleUID)


--[[--------------------------------------------------------------------------
    Data Loading and Saving (Optimized)
--------------------------------------------------------------------------]]

--- Loads vehicle data from 'vehicles.json' when the resource starts.
--- Cleans the loaded data, removes existing persistent vehicles managed by this resource,
--- and then spawns vehicles from the loaded data.
--- @param resourceName string The name of the current resource.
function LoadVehicleData(resourceName)
    resourceName = resourceName or GetCurrentResourceName()
    local vehiclesJson = LoadResourceFile(resourceName, "vehicles.json")
    local loadedCount = 0

    if vehiclesJson then
        local success, decodedVehicles = pcall(json.decode, vehiclesJson) -- Use pcall for safe decoding
        if success and type(decodedVehicles) == "table" then
            print(string.format("[%s] Successfully loaded and decoded vehicles.json", resourceName))
            Vehicles = {} -- Start fresh
            -- Iterate and validate loaded data, removing 'true' entries
            for uid, data in pairs(decodedVehicles) do
                if type(data) == "table" then
                    Vehicles[uid] = data
                    loadedCount = loadedCount + 1
                else
                    print(string.format("[%s] Discarding invalid entry for UID '%s' (value was not a table).",
                        resourceName, uid))
                end
            end
            print(string.format("[%s] Loaded data for %d vehicles.", resourceName, loadedCount))
        else
            warn(string.format(
                "[%s] Failed to decode vehicles.json or it's not a valid table. Starting fresh. Error: %s", resourceName,
                tostring(decodedVehicles)))
            Vehicles = {} -- Start with an empty table if loading/decoding fails
        end
    else
        print(string.format("[%s] No vehicles.json file found. Starting with an empty vehicle list.", resourceName))
        Vehicles = {} -- Start with an empty table if file doesn't exist
    end

    -- Clear out any previously spawned persistent vehicles from this resource before respawning.
    print(string.format("[%s] Clearing previously spawned persistent vehicles...", resourceName))
    local deletedCount = 0
    for _, vehicleEntityId in ipairs(GetAllVehicles()) do
        -- Check state bag using safe navigation (?.) if available, otherwise check existence first
        local state = Entity(vehicleEntityId)?.state
        if state and state.isPersistent then
            -- print(string.format("[%s] Deleting existing persistent vehicle (Entity ID: %d, UID: %s)", resourceName, vehicleEntityId, state.pId or "N/A"))
            DO_NOT_RESPAWN[vehicleEntityId] = true -- Mark so entityRemoved doesn't respawn it
            DeleteEntity(vehicleEntityId)
            deletedCount = deletedCount + 1
        end
    end
    print(string.format("[%s] Cleared %d previously spawned vehicles.", resourceName, deletedCount))


    -- Spawn all vehicles defined in the loaded data.
    print(string.format("[%s] Spawning all persistent vehicles from loaded data...", resourceName))
    SpawnAllPersistentVehicles()
    print(string.format("[%s] Finished loading vehicle data.", resourceName))
end

--- Saves the current state of the `Vehicles` table to 'vehicles.json' IF data has changed.
--- This is called periodically and after batch updates to reduce I/O.
--- @param resourceName string The name of the current resource.
function SaveVehicleData(resourceName)
    if not dataNeedsSaving then return end -- Only save if changes were made

    resourceName = resourceName or GetCurrentResourceName()
    print(string.format("[%s] Saving vehicle data...", resourceName))

    -- Create a clean copy for saving, excluding 'true' entries
    local vehiclesToSave = {}
    for uid, data in pairs(Vehicles) do
        if type(data) == "table" then
            vehiclesToSave[uid] = data
        end
    end

    local vehiclesJson = json.encode(vehiclesToSave, { indent = true, sort_keys = true })
    local success = SaveResourceFile(resourceName, "vehicles.json", vehiclesJson, -1)

    if success then
        dataNeedsSaving = false -- Reset flag only on successful save
        print(string.format("[%s] Successfully saved vehicle data.", resourceName))
    else
        warn(string.format("[%s] Failed to save vehicle data to vehicles.json!", resourceName))
        -- Keep dataNeedsSaving = true so it tries again later
    end
end

-- Periodic Saver Thread
Citizen.CreateThread(function()
    while true do
        Wait(Config.SaveInterval or 60000) -- Use configurable interval, default 60 seconds
        SaveVehicleData(GetCurrentResourceName())
    end
end)

--[[--------------------------------------------------------------------------
    Vehicle State Management
--------------------------------------------------------------------------]]

--- Spawns a single persistent vehicle onto the server based on its stored data.
--- Sets initial state flags for the client-side script to handle property application.
--- @param vehicleUID string The unique identifier of the vehicle to spawn.
--- @param vehicleData table|nil Optional: The vehicle's data. If nil, retrieved from `Vehicles` table.
function SpawnVehicle(vehicleUID, vehicleData)
    vehicleData = vehicleData or getVehicleData(vehicleUID) -- Use helper to ensure data is a table

    -- Ensure we have valid data (helper function already checks type)
    if not vehicleData then
        -- warn(string.format("[%s] Attempted to spawn vehicle with UID '%s', but no valid data found or data was 'true'.", GetCurrentResourceName(), vehicleUID))
        return
    end

    -- Validate essential data fields before attempting to create the vehicle.
    if not vehicleData.model or not vehicleData.type or not vehicleData.matrix or not vehicleData.matrix.position or not vehicleData.matrix.heading then
        warn(string.format("[%s] Vehicle data for UID '%s' is incomplete or corrupt. Cannot spawn. Data: %s",
            GetCurrentResourceName(), vehicleUID, json.encode(vehicleData)))
        -- Consider removing the corrupt entry
        -- ForgetVehicle(nil, vehicleUID)
        return
    end

    local position = vector3(vehicleData.matrix.position.x, vehicleData.matrix.position.y, vehicleData.matrix.position.z)
    local heading = vehicleData.matrix.heading

    -- Create the vehicle entity on the server.
    local vehicleEntity = CreateVehicle(vehicleData.model, position.x, position.y, position.z, heading, true, false) -- Networked, not mission entity initially
    local timeout = GetGameTimer() + 1000

    repeat
        Wait(0)
    until DoesEntityExist(vehicleEntity) or GetGameTimer() > timeout

    if not DoesEntityExist(vehicleEntity) then
        warn(string.format("[%s] Failed to create vehicle entity for UID '%s' (Model: %s).", GetCurrentResourceName(),
            vehicleUID, vehicleData.model))
        return
    end

    -- Wait briefly for entity to stabilize network-wise? Might not be needed.
    -- Wait(100)

    print(string.format("[%s] Spawning vehicle with UID: %s (Entity ID: %d)", GetCurrentResourceName(), vehicleUID,
        vehicleEntity))

    -- Freeze the vehicle initially to prevent physics issues until client applies properties.
    FreezeEntityPosition(vehicleEntity, true)

    -- Set state bags for synchronization and identification:
    local state = Entity(vehicleEntity).state
    state.isPersistent = true       -- Mark this entity as managed by this resource.
    state.pId = vehicleUID          -- Store the persistent UID.
    state.pProperties = vehicleData -- Store the target properties (used for respawn/client sync).
    state.nProperties = true        -- Flag indicating the client needs to apply these properties.
end

--- Registers a newly created vehicle entity as persistent.
--- Initially marks it with `true` in the `Vehicles` table until properties are received.
--- @param vehicleEntity number The entity ID of the vehicle to register.
function NewVehicle(vehicleEntity)
    if not DoesEntityExist(vehicleEntity) or GetEntityType(vehicleEntity) ~= 2 then
        warn(string.format("[%s] Attempted to register an invalid or non-vehicle entity: %d", GetCurrentResourceName(),
            vehicleEntity))
        return
    end

    local vehicleUID = GetVehicleUID(vehicleEntity)
    if not vehicleUID then
        warn(string.format("[%s] Could not generate UID for new vehicle entity: %d", GetCurrentResourceName(),
            vehicleEntity))
        return
    end

    -- Check if vehicle with this UID already exists (e.g., from a rapid spawn/delete)
    if Vehicles[vehicleUID] then
        print(string.format("[%s] Vehicle with UID %s already exists. Ignoring new registration for entity %d.",
            GetCurrentResourceName(), vehicleUID, vehicleEntity))
        -- Optionally delete the new duplicate entity
        -- DeleteEntity(vehicleEntity)
        return
    end


    print(string.format("[%s] Registering new persistent vehicle with UID: %s (Entity ID: %d)", GetCurrentResourceName(),
        vehicleUID, vehicleEntity))

    -- Add to the main table, marking as new (value = true)
    Vehicles[vehicleUID] = true
    dataNeedsSaving = true -- Mark data as dirty (even though it's just 'true', indicates a change)

    -- Set initial state bags for the entity
    local state = Entity(vehicleEntity).state
    state.isPersistent = true
    state.pId = vehicleUID
    state.pProperties = nil -- No properties saved *yet*
    -- nProperties is not set here; client should request/send properties.

    -- No SaveVehicleData() here; saving happens when properties are updated or periodically.
end

--- Updates the stored properties for a specific persistent vehicle.
--- Marks data as needing to be saved.
--- @param vehicleEntity number The entity ID of the vehicle whose properties are being updated.
--- @param properties table The new set of properties to store for the vehicle.
function UpdateVehicle(vehicleEntity, properties)
    if not DoesEntityExist(vehicleEntity) or GetEntityType(vehicleEntity) ~= 2 then
        -- This might happen if the vehicle is deleted between client sending and server processing
        -- warn(string.format("[%s] UpdateVehicle: Entity %d no longer exists.", GetCurrentResourceName(), vehicleEntity))
        return
    end

    local vehicleUID = Entity(vehicleEntity).state.pId -- Get UID from state bag first (more reliable)
    if not vehicleUID then
        vehicleUID = GetVehicleUID(vehicleEntity)      -- Fallback if state bag wasn't set yet
    end

    if not vehicleUID then
        warn(string.format("[%s] UpdateVehicle: Could not get UID for entity %d.", GetCurrentResourceName(),
            vehicleEntity))
        return
    end

    -- Ensure this vehicle is actually being tracked (could be 'true' or a table)
    if not Vehicles[vehicleUID] then
        warn(string.format("[%s] UpdateVehicle: Attempted update for untracked vehicle UID: %s (Entity ID: %d)",
            GetCurrentResourceName(), vehicleUID, vehicleEntity))
        return
    end

    -- Ensure the provided properties are a table.
    if type(properties) ~= "table" then
        warn(string.format(
            "[%s] UpdateVehicle: Invalid properties received for UID: %s (Entity ID: %d). Expected table, got %s.",
            GetCurrentResourceName(), vehicleUID, vehicleEntity, type(properties)))
        return
    end

    -- Preserve existing customData if the incoming properties don't have it
    local existingData = getVehicleData(vehicleUID) -- Get current table data if it exists
    if existingData and existingData.customData and not properties.customData then
        properties.customData = existingData.customData
    end

    -- print(string.format("[%s] Updating properties for vehicle UID: %s (Entity ID: %d)", GetCurrentResourceName(), vehicleUID, vehicleEntity))

    -- Store the new properties in the main table.
    Vehicles[vehicleUID] = properties

    -- Update the state bag as well, in case it's needed before a respawn/resync.
    Entity(vehicleEntity).state.pProperties = properties
    -- nProperties should be set to false by the client event handler ("CR.PV:PropertiesSet") after applying.

    dataNeedsSaving = true -- Mark data as dirty
    -- NO SaveVehicleData() here - saving is debounced/periodic
end

--- Removes a vehicle from the persistent tracking list and optionally deletes its current entity.
--- Marks data as needing to be saved.
--- @param vehicleEntity number|nil The entity ID of the vehicle to forget. If nil, only vehicleUID is used.
--- @param vehicleUID string|nil The UID of the vehicle to forget. If nil, it's derived from vehicleEntity's state bag or natives.
function ForgetVehicle(vehicleEntity, vehicleUID)
    -- Determine the Vehicle UID reliably
    if not vehicleUID and vehicleEntity and DoesEntityExist(vehicleEntity) then
        vehicleUID = Entity(vehicleEntity).state.pId or GetVehicleUID(vehicleEntity)
    end

    if not vehicleUID then
        warn(string.format("[%s] ForgetVehicle called with insufficient information (Entity: %s, UID: %s).",
            GetCurrentResourceName(), tostring(vehicleEntity), tostring(vehicleUID)))
        return
    end

    -- Check if the vehicle exists in our tracking table
    if not Vehicles[vehicleUID] then
        -- print(string.format("[%s] Attempted to forget vehicle UID '%s', but it was not tracked.", GetCurrentResourceName(), vehicleUID))
        return -- Not an error, just means it's already gone or was never tracked.
    end

    print(string.format("[%s] Forgetting vehicle with UID: %s", GetCurrentResourceName(), vehicleUID))

    -- Remove the vehicle from the tracking table.
    Vehicles[vehicleUID] = nil
    dataNeedsSaving = true -- Mark data as dirty

    -- If a valid entity was provided and still exists, mark it for no respawn and delete it.
    if vehicleEntity and DoesEntityExist(vehicleEntity) then
        -- Verify the entity actually matches the UID we are forgetting
        local currentEntityUID = Entity(vehicleEntity).state.pId or GetVehicleUID(vehicleEntity)
        if currentEntityUID == vehicleUID then
            print(string.format("[%s] Deleting entity %d associated with forgotten vehicle UID %s.",
                GetCurrentResourceName(), vehicleEntity, vehicleUID))
            DO_NOT_RESPAWN[vehicleEntity] = true -- Prevent respawn via entityRemoved event
            local state = Entity(vehicleEntity).state
            if state then
                state.isPersistent = nil -- Clear the persistent flag
                state.pId = nil
                state.pProperties = nil
                state.nProperties = nil
            end
            DeleteEntity(vehicleEntity)
        else
            -- This shouldn't happen often but indicates a mismatch
            warn(string.format(
                "[%s] ForgetVehicle: Entity %d provided, but its UID (%s) doesn't match the target UID (%s). Not deleting entity.",
                GetCurrentResourceName(), vehicleEntity, currentEntityUID, vehicleUID))
        end
    end

    -- NO SaveVehicleData() here - saving is debounced/periodic
end

--- Checks if a given vehicle entity is currently tracked as persistent by this resource.
--- Checks the state bag first, then the Vehicles table as a fallback.
--- @param vehicleEntity number The entity ID of the vehicle to check.
--- @return boolean True if the vehicle is marked as persistent or its UID is found, false otherwise.
function IsVehiclePersistent(vehicleEntity)
    if not vehicleEntity or not DoesEntityExist(vehicleEntity) or GetEntityType(vehicleEntity) ~= 2 then
        return false -- Not a valid vehicle entity
    end

    -- Primary check: State bag flag
    if Entity(vehicleEntity)?.state?.isPersistent == true then
        return true
    end

    -- Fallback check: If state bag isn't set yet, check if its UID is in the Vehicles table
    local vehicleUID = GetVehicleUID(vehicleEntity)
    if vehicleUID and Vehicles[vehicleUID] ~= nil then
        -- If found in table but state bag isn't set, maybe set the state bag now?
        -- Or just return true based on the table lookup.
        return true
    end

    return false
end

-- Export for external checks server-side
exports('IsVehiclePersistent', IsVehiclePersistent)


--- Iterates through the `Vehicles` table and spawns all vehicles that have valid data (i.e., not 'true').
function SpawnAllPersistentVehicles()
    print(string.format("[%s] Starting SpawnAllPersistentVehicles...", GetCurrentResourceName()))
    local spawnCount = 0
    local skippedCount = 0
    for vehicleUID, vehicleData in pairs(Vehicles) do
        -- Only spawn if the vehicleData is a table (meaning properties have been saved).
        if type(vehicleData) == "table" then
            SpawnVehicle(vehicleUID, vehicleData)
            spawnCount = spawnCount + 1
            -- Add a small wait periodically if spawning many vehicles to avoid hitches
            if spawnCount % 10 == 0 then Wait(50) end
        else
            -- Skipping 'true' entries (newly registered, props not yet saved)
            skippedCount = skippedCount + 1
            -- print(string.format("[%s] Skipping spawn for vehicle UID '%s' as its data is not a table (likely value is 'true').", GetCurrentResourceName(), vehicleUID))
        end
    end
    print(string.format(
        "[%s] SpawnAllPersistentVehicles finished. Spawned %d vehicles, skipped %d (pending properties).",
        GetCurrentResourceName(), spawnCount, skippedCount))
end

--[[--------------------------------------------------------------------------
    Custom Variable API Exports
--------------------------------------------------------------------------]]

--- Sets a custom variable for a persistent vehicle.
--- @param vehicleUID string The unique identifier of the vehicle.
--- @param key string The key for the custom variable.
--- @param value any The value to store (must be serializable to JSON).
--- @return boolean True if successful, false otherwise.
exports('SetCustomVehicleVariable', function(vehicleUID, key, value)
    local data = getVehicleData(vehicleUID)
    if not data then
        -- If vehicle exists but only has 'true' entry, initialize properly
        if Vehicles[vehicleUID] == true then
            Vehicles[vehicleUID] = { customData = {} }
            data = Vehicles[vehicleUID]
        else
            warn(string.format("[%s] SetCustomVehicleVariable: Vehicle UID '%s' not found or has no data table.",
                GetCurrentResourceName(), vehicleUID))
            return false -- Vehicle not found or no data table yet
        end
    end

    if not data.customData then
        data.customData = {} -- Initialize if it doesn't exist
    end

    -- Prevent overwriting core properties if key matches
    if data[key] and not data.customData[key] then
        warn(string.format(
            "[%s] SetCustomVehicleVariable: Attempted to overwrite core property '%s' on UID '%s'. Use customData sub-table.",
            GetCurrentResourceName(), key, vehicleUID))
        return false
    end


    data.customData[key] = value
    dataNeedsSaving = true -- Mark for saving
    -- Optional: Trigger immediate save? Generally rely on periodic/batch save.
    -- SaveVehicleData()
    return true
end)

--- Gets a specific custom variable for a persistent vehicle.
--- @param vehicleUID string The unique identifier of the vehicle.
--- @param key string The key of the variable to retrieve.
--- @return any The value of the variable, or nil if not found.
exports('GetCustomVehicleVariable', function(vehicleUID, key)
    local data = getVehicleData(vehicleUID)
    if not data or not data.customData then
        return nil
    end
    return data.customData[key] -- Returns nil if key doesn't exist in customData
end)

--- Gets all custom variables for a persistent vehicle.
--- @param vehicleUID string The unique identifier of the vehicle.
--- @return table|nil A table containing all custom variables, or nil if none found or vehicle data invalid.
exports('GetAllCustomVehicleVariables', function(vehicleUID)
    local data = getVehicleData(vehicleUID)
    if not data or not data.customData then
        return nil
    end
    -- Return a copy to prevent external modification of the internal table
    local copy = {}
    for k, v in pairs(data.customData) do
        copy[k] = v
    end
    return copy
end)

--- Adds or updates multiple custom variables for a persistent vehicle.
--- Merges the provided table with existing custom data.
--- @param vehicleUID string The unique identifier of the vehicle.
--- @param varsTable table A table containing key-value pairs to add/update.
--- @return boolean True if successful, false otherwise.
exports('AddCustomVehicleVariables', function(vehicleUID, varsTable)
    if type(varsTable) ~= 'table' then
        warn(string.format("[%s] AddCustomVehicleVariables: varsTable must be a table for UID '%s'.",
            GetCurrentResourceName(), vehicleUID))
        return false
    end

    local data = getVehicleData(vehicleUID)
    if not data then
        -- If vehicle exists but only has 'true' entry, initialize properly
        if Vehicles[vehicleUID] == true then
            Vehicles[vehicleUID] = { customData = {} }
            data = Vehicles[vehicleUID]
        else
            warn(string.format("[%s] AddCustomVehicleVariables: Vehicle UID '%s' not found or has no data table.",
                GetCurrentResourceName(), vehicleUID))
            return false -- Vehicle not found or no data table yet
        end
    end

    if not data.customData then
        data.customData = {} -- Initialize if it doesn't exist
    end

    local changed = false
    for key, value in pairs(varsTable) do
        -- Optional: Add check to prevent overwriting core props?
        if data[key] and not data.customData[key] then
            warn(string.format(
                "[%s] AddCustomVehicleVariables: Skipping key '%s' as it conflicts with a core property on UID '%s'.",
                GetCurrentResourceName(), key, vehicleUID))
        else
            if data.customData[key] ~= value then -- Check if value actually changed
                data.customData[key] = value      -- Update/add each variable
                changed = true
            end
        end
    end

    if changed then
        dataNeedsSaving = true -- Mark for saving only if something changed
    end
    return true
end)

--- Gets the entire persistent data table for a vehicle (including core props and customData).
--- Use with caution, modifying the returned table directly bypasses saving logic.
--- @param vehicleUID string The unique identifier of the vehicle.
--- @return table|nil The full data table, or nil if not found.
exports('GetRawVehicleData', function(vehicleUID)
    return getVehicleData(vehicleUID) -- Returns the internal table or nil
end)
