local Vehicles = {}

--[[
    Data Load/Save
]]
function LoadVehicleData(resourceName)
    local vehiclesJson = LoadResourceFile(resourceName or GetCurrentResourceName(), "vehicles.json")

    if vehiclesJson ~= nil then
        print("Loading vehicle data from vehicles.json")
        Vehicles = TrimVehiclesJson(vehiclesJson)
    else
        warn("No file: vehicles.json found while loading vehicle data")
    end

    GlobalState.spVehicles = GlobalState.spVehicles or {}

    print("Deleting all persistent vehicles")
    DeleteAllPersistentVehicles()

    print("Spawning all persistent vehicles")
    SpawnAllPersistentVehicles()
end

function SaveVehicleData(resourceName)
    print("Saving vehicle data to vehicles.json")
    SaveResourceFile(resourceName or GetCurrentResourceName(), "vehicles.json", json.encode(Vehicles), -1)
end

--[[
    Vehicle State Management
]]
function SpawnVehicle(vehicleId)
    if GlobalState.spVehicles[vehicleId] == nil then
        local vehicleData = Vehicles[vehicleId]
        local position = vehicleData.matrix.position
        local vehicle = CreateVehicleServerSetter(vehicleData.model, vehicleData.type, position.x, position.y, position
            .z, vehicleData.matrix.heading)
        FreezeEntityPosition(vehicle, true)

        print("Spawning vehicle with Vehicle ID: " .. vehicleId)

        Entity(vehicle).state.isPersistent = true
        Entity(vehicle).state.pProperties = vehicleData
        Entity(vehicle).state.nProperties = true
        Entity(vehicle).state.pId = vehicleId

        GlobalState.spVehicles[vehicleId] = true
    else
        warn("Vehicle with Vehicle ID: " .. vehicleId .. " is already persistent")
    end
end

function NewVehicle(vehicle)
    local vehicleId = GetVehicleUID(vehicle)

    print("Registering new vehicle with Vehicle ID: " .. vehicleId)

    Vehicles[vehicleId] = true

    Entity(vehicle).state.isPersistent = true
    Entity(vehicle).state.pId = vehicleId
    Entity(vehicle).state.pProperties = nil
end

function UpdateVehicle(vehicle, properties)
    local vehicleId = GetVehicleUID(vehicle)

    print("Updating vehicle with Vehicle ID: " .. vehicleId)

    Vehicles[vehicleId] = properties

    Entity(vehicle).state.pProperties = properties
    SaveVehicleData()
end

function ForgetVehicle(vehicle)
    local vehicleId = GetVehicleUID(vehicle)

    print("Forgetting vehicle with Vehicle ID: " .. vehicleId)

    Vehicles[vehicleId] = nil

    Entity(vehicle).state.isPersistent = false
    DeleteEntity(vehicle)
    SaveVehicleData()
end

function IsVehiclePersistent(vehicle)
    local vehicleId = GetVehicleUID(vehicle)
    local isPersistent = Vehicles[vehicleId] ~= nil

    if isPersistent then
        print("Vehicle with Vehicle ID: " .. vehicleId .. " is persistent")
    else
        print("Vehicle with Vehicle ID: " .. vehicleId .. " is not persistent")
    end

    return isPersistent
end

function DeleteAllPersistentVehicles()
    local vehicles = GetAllVehicles()

    print("Deleting all persistent vehicles")

    for _, vehicle in ipairs(vehicles) do
        if IsVehiclePersistent(vehicle) then
            local vehicleId = GetVehicleUID(vehicle)

            print("Deleting persistent vehicle with Vehicle ID: " .. vehicleId)

            Entity(vehicle).state.isPersistent = false
            DeleteEntity(vehicle)

            GlobalState.spVehicles[vehicleId] = nil
        end
    end
end

function SpawnAllPersistentVehicles()
    print("Spawning all persistent vehicles")

    for vehicleId, _ in pairs(Vehicles) do
        SpawnVehicle(vehicleId)
    end
end
