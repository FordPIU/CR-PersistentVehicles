RESOURCE_NAME = GetCurrentResourceName()
local Vehicles = {}
DO_NOT_RESPAWN = {}

local function getVehicleData(vehicleUID)
    if not vehicleUID then return nil end
    local data = Vehicles[vehicleUID]
    if type(data) == "table" then
        return data
    end
    return nil
end

function GetVehicleUID(vehicle)
    if not DoesEntityExist(vehicle) or GetEntityType(vehicle) ~= 2 then
        return nil
    end
    local vehicleModel = GetEntityModel(vehicle)
    local plateText = GetVehicleNumberPlateText(vehicle)
    local plateIndex = GetVehicleNumberPlateTextIndex(vehicle)
    return string.format("%s-%d-%s", vehicleModel, plateIndex, plateText)
end

exports("GetVehicleUID", GetVehicleUID)


function LoadVehicleData()
    local vehiclesJson = LoadResourceFile(RESOURCE_NAME, "vehicles.json")
    if vehiclesJson == nil then return end
    Vehicles = json.decode(vehiclesJson)

    SpawnAllPersistentVehicles()
end

function SaveVehicleData()
    if IsLoading then
        warn("Attempt to save data while still loading data")
        return
    end
    local vehiclesJson = json.encode(Vehicles)
    local success = SaveResourceFile(RESOURCE_NAME, "vehicles.json", vehiclesJson, -1)

    if success then
        print("Successfully saved vehicle data.")
    else
        warn("Failed to save vehicle data to vehicles.json!")
    end
end

-- Periodic Saver Thread
Citizen.CreateThread(function()
    while true do
        Wait(30000)
        SaveVehicleData()
    end
end)

function SpawnVehicle(vehicleUID, vehicleData)
    -- todo: Check that the vehicle isnt already spawned, deny the spawn
    -- double spawning is occuring?
    -- todo: Some vehicles still wont spawn until the player actually spawnts it themselves and loads the modeL????
    vehicleData = vehicleData or getVehicleData(vehicleUID)

    if type(vehicleData) ~= "table" then
        warn("Attempt to spawn vehicle " .. vehicleUID .. " with invalid data, removing from persistent.")
        ForgetVehicle(nil, vehicleUID)
        return
    end

    if not vehicleData.model or not vehicleData.type or not vehicleData.matrix or not vehicleData.matrix.position or not vehicleData.matrix.heading then
        warn("Attempt to spawn vehicle " .. vehicleUID .. " with malformed matrix, type, or model")
        ForgetVehicle(nil, vehicleUID)
        return
    end

    local position = vector3(vehicleData.matrix.position.x, vehicleData.matrix.position.y, vehicleData.matrix.position.z)
    local heading = vehicleData.matrix.heading
    local vehicleEntity = CreateVehicle(vehicleData.model, position.x, position.y, position.z, heading, true, false)
    local timeout = GetGameTimer() + 5000
    local requestedLoad = false
    local requestLoadAt = GetGameTimer() + 1000

    repeat
        Wait(0)
        if GetGameTimer() > requestLoadAt then
            if not requestedLoad then
                requestedLoad = true
                TriggerClientEvent("CRPV_LOADMODEL", -1, vehicleData.model)
            end
        end
    until DoesEntityExist(vehicleEntity) or GetGameTimer() > timeout

    if not DoesEntityExist(vehicleEntity) then
        warn("Failed to spawn vehicle " .. vehicleUID)
        Citizen.CreateThread(function()
            repeat
                Wait(1000)
            until DoesEntityExist(vehicleEntity)

            local state = Entity(vehicleEntity).state
            state.isPersistent = true
            state.pId = vehicleUID
            state.pProperties = vehicleData
            state.nProperties = true
            print("Vehicle " .. vehicleUID .. " delayed spawn successfully")
        end)
        return
    end

    FreezeEntityPosition(vehicleEntity, true)

    local state = Entity(vehicleEntity).state
    state.isPersistent = true
    state.pId = vehicleUID
    state.pProperties = vehicleData
    state.nProperties = true
end

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

    if Vehicles[vehicleUID] then
        print(string.format("[%s] Vehicle with UID %s already exists. Ignoring new registration for entity %d.",
            GetCurrentResourceName(), vehicleUID, vehicleEntity))
        DeleteEntity(vehicleEntity)
        return
    end


    print(string.format("[%s] Registering new persistent vehicle with UID: %s (Entity ID: %d)", GetCurrentResourceName(),
        vehicleUID, vehicleEntity))

    Vehicles[vehicleUID] = true

    local state = Entity(vehicleEntity).state
    state.isPersistent = true
    state.pId = vehicleUID
    state.pProperties = nil
end

function UpdateVehicle(vehicleEntity, properties)
    if not DoesEntityExist(vehicleEntity) or GetEntityType(vehicleEntity) ~= 2 then
        return
    end

    local vehicleUID = Entity(vehicleEntity).state.pId
    if not vehicleUID then
        vehicleUID = GetVehicleUID(vehicleEntity)
    end

    if not vehicleUID then
        warn(string.format("[%s] UpdateVehicle: Could not get UID for entity %d.", GetCurrentResourceName(),
            vehicleEntity))
        return
    end

    -- Ensure this vehicle is actually being tracked (could be 'true' or a table)
    if not Vehicles[vehicleUID] then
        warn(string.format(
            "[%s] UpdateVehicle: Attempted update for untracked vehicle UID: %s (Entity ID: %d), adding as persistent",
            GetCurrentResourceName(), vehicleUID, vehicleEntity))
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

    Vehicles[vehicleUID] = properties

    Entity(vehicleEntity).state.pProperties = properties
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
        local state = Entity(vehicleEntity).state
        state.isPersistent = true
        state.pId = vehicleUID
        state.pProperties = Vehicles[vehicleUID]
        state.nProperties = true
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
