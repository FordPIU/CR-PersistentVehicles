local Vehicles = {}

--------------------------------------------------

local function deleteAllPersistentVehicles()
    local vehicles = GetAllVehicles()

    for _, vehicle in pairs(vehicles) do
        if IsVehiclePersistent(vehicle) then
            DeleteEntity(vehicle)
        end
    end
end

local function isVehicleSpawned(vehicleUID)
    local vehicles = GetAllVehicles()

    for _, vehicle in pairs(vehicles) do
        if GetVehicleUID(vehicle) == vehicleUID then return true end
    end

    return false
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
        if not isVehicleSpawned(vehicleUID) then
            spawnVehicle(vehicleUID, properties)
            Wait(500)
        end
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

function SaveVehicleProperties(resourceName)
    SaveResourceFile(resourceName or GetCurrentResourceName(), "vehicles.json", json.encode(Vehicles), -1)
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

AddEventHandler("onResourceStart", function(resourceName)
    if resourceName == GetCurrentResourceName() then
        local vehiclesJson = LoadResourceFile(resourceName, "vehicles.json")

        if vehiclesJson ~= nil then
            Vehicles = TrimVehiclesJson(vehiclesJson)
            print("Loaded vehicles.json")
        else
            warn("No file: vehicles.json")
        end

        RefreshAndSpawn()
    end
end)

AddEventHandler("onResourceStop", function(resourceName)
    if resourceName == GetCurrentResourceName() then
        SaveVehicleProperties(resourceName)
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

--------------------------------------------------

Citizen.CreateThread(function()
    while true do
        Wait(1000)

        for vehicleUID, _ in pairs(Vehicles) do
            if not isVehicleSpawned(vehicleUID) then
                spawnVehicle(vehicleUID)
            end
        end
    end
end)
