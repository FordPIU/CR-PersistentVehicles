local Vehicles = {}

--[[
    Data Load/Save
]]
function LoadVehicleData(resourceName)
    local vehiclesJson = LoadResourceFile(resourceName or GetCurrentResourceName(), "vehicles.json")

    if vehiclesJson ~= nil then
        Vehicles = TrimVehiclesJson(vehiclesJson)
    else
        warn("No file: vehicles.json")
    end

    GlobalState.spVehicles = GlobalState.spVehicles or {}

    DeleteAllPersistentVehicles()
    SpawnAllPersistentVehicles()
end

function SaveVehicleData(resourceName)
    SaveResourceFile(resourceName or GetCurrentResourceName(), "vehicles.json", json.encode(Vehicles), -1)
end

--[[
    Vehicle State Management
]]
function SpawnVehicle(vehicleId)
    if GlobalState.spVehicles[vehicleId] == nil then
        local vehicleData = Vehicles[vehicleId]
        local position = vehicleData.matrix.position
        local vehicle = CreateVehicleServerSetter(vehicleData.model, vehicleData.type, position.x, position.y,
            position.z, vehicleData.matrix.heading)

        Entity(vehicle).state.isPersistent = true
        Entity(vehicle).state.pProperties = vehicleData
        Entity(vehicle).state.nProperties = true
        Entity(vehicle).state.pId = vehicleId

        GlobalState.spVehicles[vehicleId] = true
    end
end

function NewVehicle(vehicle)
    local vehicleId = GetVehicleUID(vehicle)

    Vehicles[vehicleId] = true

    Entity(vehicle).state.isPersistent = true
    Entity(vehicle).state.pId = vehicleId
    Entity(vehicle).state.pProperties = nil
end

function UpdateVehicle(vehicle, properties)
    Vehicles[GetVehicleUID(vehicle)] = properties

    Entity(vehicle).state.pProperties = properties
    SaveVehicleData()
end

function ForgetVehicle(vehicle)
    local vehicleId = GetVehicleUID(vehicle)

    Vehicles[vehicleId] = nil

    Entity(vehicle).state.isPersistent = false
    DeleteEntity(vehicle)
    SaveVehicleData()
end

function IsVehiclePersistent(vehicle)
    if Vehicles[GetVehicleUID(vehicle)] then return true else return false end
end

function DeleteAllPersistentVehicles()
    local vehicles = GetAllVehicles()

    ---@diagnostic disable-next-line: param-type-mismatch
    for _, vehicle in ipairs(vehicles) do
        if IsVehiclePersistent(vehicle) then
            local vehicleId = GetVehicleUID(vehicle)

            Entity(vehicle).state.isPersistent = false
            DeleteEntity(vehicle)

            GlobalState.spVehicles[vehicleId] = nil
        end
    end
end

function SpawnAllPersistentVehicles()
    for vehicleId, _ in pairs(Vehicles) do
        SpawnVehicle(vehicleId)
    end
end
