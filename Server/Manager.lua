RESOURCE_NAME = GetCurrentResourceName()
Vehicles = {}
local IsLoaded = false

local function getVehicleData(vehicleUID)
    if not vehicleUID then return nil end
    local data = Vehicles[vehicleUID]
    if type(data) == "table" then
        return data
    end
    return nil
end

function GenerateUID()
    local uid = math.random(1000000, 9999999)
    repeat
        Wait(0)
        uid = math.random(1000000, 9999999)
    until Vehicles[uid] == nil
    return uid
end

function LoadVehicleData()
    local vehiclesJson = LoadResourceFile(RESOURCE_NAME, "vehicles.json")
    if vehiclesJson == nil then return end
    Vehicles = json.decode(vehiclesJson)

    IsLoaded = true
end

function SaveVehicleData()
    if not IsLoaded then
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

function NewVehicle(vehicleEntity, vehicleProperties)
    if not DoesEntityExist(vehicleEntity) or GetEntityType(vehicleEntity) ~= 2 then
        warn(string.format("[%s] Attempted to register an invalid or non-vehicle entity: %d", GetCurrentResourceName(),
            vehicleEntity))
        return
    end

    local vehicleUID = GenerateUID()
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

    Vehicles[vehicleUID] = vehicleProperties

    local state = Entity(vehicleEntity).state
    state.isPersistent = true
    state.pId = vehicleUID

    if vehicleProperties then
        state.pProperties = vehicleProperties
        state.nProperties = false
    else
        state.pProperties = nil
    end
end

function UpdateVehicle(vehicleEntity, properties)
    if not DoesEntityExist(vehicleEntity) or GetEntityType(vehicleEntity) ~= 2 then
        return
    end

    local vehicleUID = Entity(vehicleEntity).state.pId

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
        vehicleUID = Entity(vehicleEntity).state.pId
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
        local currentEntityUID = Entity(vehicleEntity).state.pId
        if currentEntityUID == vehicleUID then
            print(string.format("[%s] Deleting entity %d associated with forgotten vehicle UID %s.",
                GetCurrentResourceName(), vehicleEntity, vehicleUID))
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
    local vehicleUID = Entity(vehicleEntity)?.state?.pId

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