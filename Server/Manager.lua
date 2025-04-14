--[[
    Manages the state, loading, saving, and spawning of persistent vehicles.
]]

-- Stores the data for all persistent vehicles managed by this resource.
-- Key: Vehicle UID (string, format: "plateIndex-plateText")
-- Value:
--   - `true`: Vehicle is newly registered but full properties haven't been saved yet.
--   - `table`: Contains the vehicle's persistent properties (model, position, mods, etc.).
local Vehicles = {}

--[[--------------------------------------------------------------------------
    Data Loading and Saving
--------------------------------------------------------------------------]]

--[[
    Loads vehicle data from the 'vehicles.json' file when the resource starts.
    It cleans the loaded data, removes currently spawned vehicles managed by this resource,
    and then spawns all persistent vehicles from the loaded data.

    @param resourceName string: The name of the current resource. Ensures the correct
                                file is loaded/saved, especially during restarts.
]]
function LoadVehicleData(resourceName)
    resourceName = resourceName or GetCurrentResourceName()
    local vehiclesJson = LoadResourceFile(resourceName, "vehicles.json")

    if vehiclesJson then
        -- Attempt to decode the JSON data safely.
        local decodedVehicles = json.decode(vehiclesJson)

        if decodedVehicles then
            print("Successfully loaded and decoded vehicles.json")
            -- Remove entries marked as 'true' (incomplete saves) before assigning.
            Vehicles = TrimVehiclesJson(decodedVehicles)
        else
            warn(string.format("[%s] Failed to decode vehicles.json or it's not a valid table. Error: %s", resourceName,
                tostring(decodedVehicles)))
            Vehicles = {} -- Start with an empty table if loading/decoding fails
        end
    else
        warn(string.format("[%s] No vehicles.json file found. Starting with an empty vehicle list.", resourceName))
        Vehicles = {} -- Start with an empty table if file doesn't exist
    end

    -- Clear out any previously spawned persistent vehicles from this resource before respawning.
    -- This prevents duplicates if the resource restarts without a server restart.
    print(string.format("[%s] Clearing previously spawned persistent vehicles...", resourceName))
    for _, vehicleEntityId in ipairs(GetAllVehicles()) do
        -- Check if the vehicle entity has the 'isPersistent' state flag set by this resource.
        -- This avoids deleting vehicles managed by other scripts.
        if Entity(vehicleEntityId)?.state?.isPersistent then -- Use Lua 5.4 ?. safe navigation operator
            print(string.format("[%s] Deleting existing persistent vehicle (Entity ID: %d)", resourceName,
                vehicleEntityId))
            -- Mark the vehicle so the entityRemoved event doesn't try to respawn it.
            DO_NOT_RESPAWN[vehicleEntityId] = true
            DeleteEntity(vehicleEntityId)
        end
    end

    -- Spawn all vehicles defined in the loaded data.
    print(string.format("[%s] Spawning all persistent vehicles from loaded data...", resourceName))
    SpawnAllPersistentVehicles()
    print(string.format("[%s] Finished loading vehicle data and spawning vehicles.", resourceName))
end

--[[
    Saves the current state of the `Vehicles` table to the 'vehicles.json' file.
    This function should be called whenever persistent vehicle data changes (update, forget).

    @param resourceName string: The name of the current resource.
]]
function SaveVehicleData(resourceName)
    resourceName = resourceName or GetCurrentResourceName()
    -- Encode the Vehicles table into a JSON string with pretty printing for readability.
    local vehiclesJson = json.encode(Vehicles, { indent = true, sort_keys = true }) -- Use pretty print options

    -- Save the JSON string to the file. The -1 indicates the length should be calculated automatically.
    local success = SaveResourceFile(resourceName, "vehicles.json", vehiclesJson, -1)

    if not success then
        warn(string.format("[%s] Failed to save vehicle data to vehicles.json!", resourceName))
        --else
        print(string.format("[%s] Successfully saved vehicle data.", resourceName))
    end
    -- NOTE: Saving on every update/forget can be I/O intensive.
    -- Consider debouncing or saving periodically/on resource stop for optimization if needed.
end

--[[--------------------------------------------------------------------------
    Vehicle State Management
--------------------------------------------------------------------------]]

--[[
    Spawns a single persistent vehicle onto the server based on its stored data.
    Sets initial state flags for the client-side script to handle property application.

    @param vehicleUID string: The unique identifier (plateIndex-plateText) of the vehicle to spawn.
    @param vehicleData table (optional): The vehicle's data. If nil, it's retrieved from the `Vehicles` table.
]]
function SpawnVehicle(vehicleUID, vehicleData)
    vehicleData = vehicleData or Vehicles[vehicleUID]

    -- Ensure we have valid data to spawn the vehicle.
    if not vehicleData or type(vehicleData) ~= "table" then
        warn(string.format("[%s] Attempted to spawn vehicle with UID '%s', but no valid data found.",
            GetCurrentResourceName(), vehicleUID))
        return
    end

    -- Validate essential data fields before attempting to create the vehicle.
    if not vehicleData.model or not vehicleData.type or not vehicleData.matrix or not vehicleData.matrix.position or not vehicleData.matrix.heading then
        warn(string.format("[%s] Vehicle data for UID '%s' is incomplete. Cannot spawn. Data: %s",
            GetCurrentResourceName(), vehicleUID, json.encode(vehicleData)))
        return
    end

    local position = vehicleData.matrix.position
    local heading = vehicleData.matrix.heading

    -- Create the vehicle entity on the server.
    -- Using CreateVehicleServerSetter ensures the server has authority initially.
    local vehicleEntity = CreateVehicleServerSetter(vehicleData.model, vehicleData.type, position.x, position.y,
        position.z, heading)

    if vehicleEntity == 0 then
        warn(string.format("[%s] Failed to create vehicle entity for UID '%s' (Model: %s).", GetCurrentResourceName(),
            vehicleUID, vehicleData.model))
        return
    end

    print(string.format("[%s] Spawning vehicle with UID: %s (Entity ID: %d)", GetCurrentResourceName(), vehicleUID,
        vehicleEntity))

    -- Freeze the vehicle initially to prevent physics issues until the client takes over or properties are set.
    FreezeEntityPosition(vehicleEntity, true)

    -- Set state bags for synchronization and identification:
    local state = Entity(vehicleEntity).state
    state.isPersistent = true       -- Mark this entity as managed by this resource.
    state.pId = vehicleUID          -- Store the persistent UID.
    state.pProperties = vehicleData -- Store the target properties (used for respawn/client sync).
    state.nProperties = true        -- Flag indicating the client needs to apply these properties.
end

--[[
    Registers a newly created vehicle entity as persistent.
    Initially marks it with `true` in the `Vehicles` table until properties are received and saved.

    @param vehicleEntity number: The entity ID of the vehicle to register.
]]
function NewVehicle(vehicleEntity)
    if not DoesEntityExist(vehicleEntity) or GetEntityType(vehicleEntity) ~= 2 then
        warn(string.format("[%s] Attempted to register an invalid or non-vehicle entity: %s", GetCurrentResourceName(),
            vehicleEntity))
        return
    end

    local vehicleUID = GetVehicleUID(vehicleEntity)

    if vehicleUID == nil then return end

    print(string.format("[%s] Registering new persistent vehicle with UID: %s (Entity ID: %d)", GetCurrentResourceName(),
        vehicleUID, vehicleEntity))

    -- Add to the main table, marking as new (value = true)
    Vehicles[vehicleUID] = true

    -- Set initial state bags for the entity
    local state = Entity(vehicleEntity).state
    state.isPersistent = true
    state.pId = vehicleUID
    state.pProperties = nil -- No properties saved *yet*
    -- nProperties is not set here; it's set by SpawnVehicle or expected to be handled by client logic after creation.

    -- Note: We don't save data here. Saving happens when properties are updated via UpdateVehicle.
end

--[[
    Updates the stored properties for a specific persistent vehicle and saves the data.

    @param vehicleEntity number: The entity ID of the vehicle whose properties are being updated.
    @param properties table: The new set of properties to store for the vehicle.
]]
function UpdateVehicle(vehicleEntity, properties)
    if not DoesEntityExist(vehicleEntity) or GetEntityType(vehicleEntity) ~= 2 then
        warn(string.format("[%s] Attempted to update properties on an invalid or non-vehicle entity: %s",
            GetCurrentResourceName(), vehicleEntity))
        return
    end

    local vehicleUID = GetVehicleUID(vehicleEntity)

    -- Ensure this vehicle is actually being tracked by the resource.
    if not Vehicles[vehicleUID] then
        warn(string.format("[%s] Attempted to update properties for an untracked vehicle with UID: %s (Entity ID: %d)",
            GetCurrentResourceName(), vehicleUID, vehicleEntity))
        return
    end

    -- Ensure the provided properties are a table.
    if type(properties) ~= "table" then
        warn(string.format(
            "[%s] Invalid properties received for vehicle UID: %s (Entity ID: %d). Expected table, got %s.",
            GetCurrentResourceName(), vehicleUID, vehicleEntity, type(properties)))
        return
    end

    print(string.format("[%s] Updating properties for vehicle with UID: %s (Entity ID: %d)", GetCurrentResourceName(),
        vehicleUID, vehicleEntity))

    -- Store the new properties in the main table.
    Vehicles[vehicleUID] = properties

    -- Update the state bag as well, in case it's needed before a respawn/resync.
    Entity(vehicleEntity).state.pProperties = properties
    -- nProperties should be set to false by the client event handler ("CR.PV:PropertiesSet") after applying.

    -- Save the updated vehicle data to the file.
    SaveVehicleData()
end

--[[
    Removes a vehicle from the persistent tracking list and optionally deletes its current entity.

    @param vehicleEntity number (optional): The entity ID of the vehicle to forget. If nil, only vehicleUID is used.
    @param vehicleUID string (optional): The UID of the vehicle to forget. If nil, it's derived from vehicleEntity.
]]
function ForgetVehicle(vehicleEntity, vehicleUID)
    -- Determine the Vehicle UID
    if not vehicleUID and vehicleEntity then
        if DoesEntityExist(vehicleEntity) and GetEntityType(vehicleEntity) == 2 then
            vehicleUID = GetVehicleUID(vehicleEntity)
        else
            warn(string.format("[%s] ForgetVehicle called with invalid entity %s and no UID.", GetCurrentResourceName(),
                vehicleEntity))
            return
        end
    elseif not vehicleUID and not vehicleEntity then
        warn(string.format("[%s] ForgetVehicle called with no entity or UID.", GetCurrentResourceName()))
        return
    end

    -- Check if the vehicle exists in our tracking table
    if not Vehicles[vehicleUID] then
        print(string.format("[%s] Attempted to forget vehicle with UID '%s', but it was not tracked.",
            GetCurrentResourceName(), vehicleUID))
        return -- Not an error, just means it's already gone or was never tracked.
    end

    print(string.format("[%s] Forgetting vehicle with UID: %s", GetCurrentResourceName(), vehicleUID))

    -- Remove the vehicle from the tracking table.
    Vehicles[vehicleUID] = nil

    -- If a valid entity was provided, mark it for no respawn and delete it.
    if vehicleEntity and DoesEntityExist(vehicleEntity) then
        print(string.format("[%s] Deleting entity %d associated with forgotten vehicle UID %s.", GetCurrentResourceName(),
            vehicleEntity, vehicleUID))
        DO_NOT_RESPAWN[vehicleEntity] = true           -- Prevent respawn via entityRemoved event
        Entity(vehicleEntity).state.isPersistent = nil -- Clear the persistent flag
        DeleteEntity(vehicleEntity)
    end

    -- Save the changes to the file.
    SaveVehicleData()
end

--[[
    Checks if a given vehicle entity is currently tracked as persistent by this resource.

    @param vehicleEntity number: The entity ID of the vehicle to check.
    @return boolean: True if the vehicle's UID is found in the `Vehicles` table, false otherwise.
]]
function IsVehiclePersistent(vehicleEntity)
    if not vehicleEntity or not DoesEntityExist(vehicleEntity) or GetEntityType(vehicleEntity) ~= 2 then
        return false -- Not a valid vehicle entity
    end

    local vehicleUID = GetVehicleUID(vehicleEntity)
    return Vehicles[vehicleUID] ~= nil
end

--[[
    Iterates through the `Vehicles` table and spawns all vehicles that have valid data.
    Skips entries that are marked as `true` (incomplete).
]]
function SpawnAllPersistentVehicles()
    print(string.format("[%s] Starting SpawnAllPersistentVehicles...", GetCurrentResourceName()))
    local spawnCount = 0
    for vehicleUID, vehicleData in pairs(Vehicles) do
        -- Only spawn if the vehicleData is a table (meaning properties have been saved).
        -- Entries with `true` are skipped as they represent newly created vehicles
        -- whose properties haven't been received/saved yet.
        if type(vehicleData) == "table" then
            SpawnVehicle(vehicleUID, vehicleData)
            spawnCount = spawnCount + 1
            --else
            print(string.format(
                "[%s] Skipping spawn for vehicle UID '%s' as its data is not a table (likely value is 'true').",
                GetCurrentResourceName(), vehicleUID))
        end
    end
    print(string.format("[%s] SpawnAllPersistentVehicles finished. Spawned %d vehicles.", GetCurrentResourceName(),
        spawnCount))
end

--[[
    Data Load/Save
]]
function LoadVehicleData(resourceName)
    local vehiclesJson = LoadResourceFile(resourceName or GetCurrentResourceName(), "vehicles.json")

    if vehiclesJson ~= nil then
        --print("Loading vehicle data from vehicles.json")
        Vehicles = TrimVehiclesJson(vehiclesJson)
    else
        warn("No file: vehicles.json found while loading vehicle data")
    end

    --print("Deleting all spawned vehicles")
    for _, v in ipairs(GetAllVehicles()) do
        DO_NOT_RESPAWN[v] = true
        DeleteEntity(v)
        --print("Deleted vehicle with entity ID: " .. v)
    end

    --print("Spawning all persistent vehicles")
    SpawnAllPersistentVehicles()
end

function SaveVehicleData(resourceName)
    --print("Saving vehicle data to vehicles.json")
    SaveResourceFile(resourceName or GetCurrentResourceName(), "vehicles.json", json.encode(Vehicles), -1)
end

--[[
    Vehicle State Management
]]
function SpawnVehicle(vehicleId)
    local vehicleData = Vehicles[vehicleId]
    local position = vehicleData.matrix.position
    local vehicle = CreateVehicleServerSetter(vehicleData.model, vehicleData.type, position.x, position.y, position
        .z, vehicleData.matrix.heading)
    FreezeEntityPosition(vehicle, true)

    --print("Spawning vehicle with Vehicle ID: " .. vehicleId)

    Entity(vehicle).state.isPersistent = true
    Entity(vehicle).state.pProperties = vehicleData
    Entity(vehicle).state.nProperties = true
    Entity(vehicle).state.pId = vehicleId
end

function NewVehicle(vehicle)
    local vehicleId = GetVehicleUID(vehicle)

    --print("Registering new vehicle with Vehicle ID: " .. vehicleId)

    Vehicles[vehicleId] = true

    Entity(vehicle).state.isPersistent = true
    Entity(vehicle).state.pId = vehicleId
    Entity(vehicle).state.pProperties = nil
end

function UpdateVehicle(vehicle, properties)
    local vehicleId = GetVehicleUID(vehicle)

    if not Vehicles[vehicleId] then return end

    --print("Updating vehicle with Vehicle ID: " .. vehicleId)

    Vehicles[vehicleId] = properties

    Entity(vehicle).state.pProperties = properties
    SaveVehicleData()
end

function ForgetVehicle(vehicle, vehicleId)
    if vehicleId == nil then vehicleId = GetVehicleUID(vehicle) end

    --print("Forgetting vehicle with Vehicle ID: " .. vehicleId)

    Vehicles[vehicleId] = nil

    if vehicle ~= nil then
        DO_NOT_RESPAWN[vehicle] = true
        DeleteEntity(vehicle)
    end

    SaveVehicleData()
end

function IsVehiclePersistent(vehicle)
    local vehicleId = GetVehicleUID(vehicle)
    local isPersistent = Vehicles[vehicleId] ~= nil

    if isPersistent then
        --print("Vehicle with Vehicle ID: " .. vehicleId .. " is persistent")
    else
        --print("Vehicle with Vehicle ID: " .. vehicleId .. " is not persistent")
    end

    return isPersistent
end

function SpawnAllPersistentVehicles()
    --print("Spawning all persistent vehicles")

    for vehicleId, _ in pairs(Vehicles) do
        SpawnVehicle(vehicleId)
    end
end

--[[
    Data Load/Save
]]
function LoadVehicleData(resourceName)
    local vehiclesJson = LoadResourceFile(resourceName or GetCurrentResourceName(), "vehicles.json")

    if vehiclesJson ~= nil then
        --print("Loading vehicle data from vehicles.json")
        Vehicles = TrimVehiclesJson(vehiclesJson)
    else
        warn("No file: vehicles.json found while loading vehicle data")
    end

    --print("Deleting all spawned vehicles")
    for _, v in ipairs(GetAllVehicles()) do
        DO_NOT_RESPAWN[v] = true
        DeleteEntity(v)
        --print("Deleted vehicle with entity ID: " .. v)
    end

    --print("Spawning all persistent vehicles")
    SpawnAllPersistentVehicles()
end

function SaveVehicleData(resourceName)
    --print("Saving vehicle data to vehicles.json")
    SaveResourceFile(resourceName or GetCurrentResourceName(), "vehicles.json", json.encode(Vehicles), -1)
end

--[[
    Vehicle State Management
]]
function SpawnVehicle(vehicleId)
    local vehicleData = Vehicles[vehicleId]
    local position = vehicleData.matrix.position
    local vehicle = CreateVehicleServerSetter(vehicleData.model, vehicleData.type, position.x, position.y, position
        .z, vehicleData.matrix.heading)
    FreezeEntityPosition(vehicle, true)

    --print("Spawning vehicle with Vehicle ID: " .. vehicleId)

    Entity(vehicle).state.isPersistent = true
    Entity(vehicle).state.pProperties = vehicleData
    Entity(vehicle).state.nProperties = true
    Entity(vehicle).state.pId = vehicleId
end

function NewVehicle(vehicle)
    local vehicleId = GetVehicleUID(vehicle)

    --print("Registering new vehicle with Vehicle ID: " .. vehicleId)

    Vehicles[vehicleId] = true

    Entity(vehicle).state.isPersistent = true
    Entity(vehicle).state.pId = vehicleId
    Entity(vehicle).state.pProperties = nil
end

function UpdateVehicle(vehicle, properties)
    local vehicleId = GetVehicleUID(vehicle)

    if not Vehicles[vehicleId] then return end

    --print("Updating vehicle with Vehicle ID: " .. vehicleId)

    Vehicles[vehicleId] = properties

    Entity(vehicle).state.pProperties = properties
    SaveVehicleData()
end

function ForgetVehicle(vehicle, vehicleId)
    if vehicleId == nil then vehicleId = GetVehicleUID(vehicle) end

    --print("Forgetting vehicle with Vehicle ID: " .. vehicleId)

    Vehicles[vehicleId] = nil

    if vehicle ~= nil then
        DO_NOT_RESPAWN[vehicle] = true
        DeleteEntity(vehicle)
    end

    SaveVehicleData()
end

function IsVehiclePersistent(vehicle)
    local vehicleId = GetVehicleUID(vehicle)
    local isPersistent = Vehicles[vehicleId] ~= nil

    if isPersistent then
        --print("Vehicle with Vehicle ID: " .. vehicleId .. " is persistent")
    else
        --print("Vehicle with Vehicle ID: " .. vehicleId .. " is not persistent")
    end

    return isPersistent
end

function SpawnAllPersistentVehicles()
    --print("Spawning all persistent vehicles")

    for vehicleId, _ in pairs(Vehicles) do
        SpawnVehicle(vehicleId)
    end
end
