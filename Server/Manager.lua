local Vehicles = {}
local Vehicles_Metatable = {
    __index = function(table, key)
        return rawget(table, key)
    end,

    __newindex = function(table, key, value)
        local oldValue = rawget(table, key)
        if oldValue ~= value then
            rawset(table, key, value) -- Actually set the new value
            SaveVehicleData()
        end
    end
}
local Deleting = false

setmetatable(Vehicles, Vehicles_Metatable)
--------------------------------------------------

local function deleteAllPersistentVehicles()
    Deleting = true
    local vehicles = GetAllVehicles()

    for _, vehicle in pairs(vehicles) do
        if IsVehiclePersistent(vehicle) then
            DeleteEntity(vehicle)
        end
    end
    Deleting = false
end

local function spawnVehicle(vehicleUID, vehicleProperties)
    vehicleProperties = vehicleProperties or Vehicles[vehicleUID]

    local position = vehicleProperties.matrix.position
    local vehicle = CreateVehicleServerSetter(vehicleProperties.model, vehicleProperties.type, position.x, position.y,
        position.z,
        vehicleProperties.matrix.heading)

    repeat
        Wait(0)
    until DoesEntityExist(vehicle)

    Entity(vehicle).state.IsPersistent = true
    Entity(vehicle).state.NeedsPropertiesSet = vehicleProperties

    print("Spawned " .. vehicleUID)
end

local function spawnAllPersistentVehicles()
    for vehicleUID, properties in pairs(Vehicles) do
        spawnVehicle(vehicleUID, properties)
        Wait(500)
    end
end

--------------------------------------------------

function RefreshAndSpawn()
    deleteAllPersistentVehicles()
    spawnAllPersistentVehicles()
end

function UpdateVehicleProperties(vehicle, properties)
    Vehicles[GetVehicleUID(vehicle)] = properties
    SaveVehicleProperties()
end

function IsVehiclePersistent(vehicle)
    if Vehicles[GetVehicleUID(vehicle)] then
        return true
    else
        return false
    end
end

function NewVehiclePersistent(vehicle)
    Vehicles[GetVehicleUID(vehicle)] = true
end

--------------------------------------------------

AddEventHandler("entityRemoved", function(entity)
    if not Deleting and Entity(entity).state.IsPersistent then
        spawnVehicle(GetVehicleUID(entity))
    end
end)

RegisterNetEvent("CR.PV:PropertiesSet", function(vehicleNetId)
    local vehicle = NetworkGetEntityFromNetworkId(vehicleNetId)

    Entity(vehicle).state.NeedsPropertiesSet = nil
    SaveVehicleProperties()
end)

RegisterNetEvent("CR.PV:Forget", function(vehicleNetId)
    local vehicle = NetworkGetEntityFromNetworkId(vehicleNetId)

    Vehicles[GetVehicleUID(vehicle)] = nil

    print("Vehicle " .. GetVehicleUID(vehicle) .. " has been forgotten")
    SaveVehicleProperties()
end)

--[[
    Debug override command
]]
RegisterCommand("rpvs", function(source)
    if source > 0 then return end -- Only server can run this command

    GlobalState.PersistentVehiclesSpawned = false

    print("Reset global state for Persistent Vehicles Spawned")
end, false)

--[[
    Data Load/Save
]]
function LoadVehicleData(resourceName)
    local vehiclesJson = LoadResourceFile(resourceName or GetCurrentResourceName(), "vehicles.json")
    local vehicles = {}

    if vehiclesJson ~= nil then
        vehicles = TrimVehiclesJson(vehiclesJson)
        print("Loaded vehicles.json")
    else
        warn("No file: vehicles.json")
    end

    return vehicles
end

function SaveVehicleData(resourceName)
    SaveResourceFile(resourceName or GetCurrentResourceName(), "vehicles.json", json.encode(Vehicles), -1)
end
