local Vehicles = {}

local function deleteAllPersistentVehicles()
    local vehicles = GetAllVehicles()

    for _, vehicle in pairs(vehicles) do
        if IsVehiclePersistent(vehicle) then
            DeleteEntity(vehicle)
        end
    end
end

local function spawnAllPersistentVehicles()
    for vehicleUID, properties in pairs(Vehicles) do
        print(vehicleUID, json.encode(properties))
    end
end

local function trimVehiclesJson(vehiclesJson)
    local decodedVehicles = json.decode(vehiclesJson)

    for vehicleUID, vehicleProperties in pairs(decodedVehicles) do
        if vehicleProperties == false then
            decodedVehicles[vehicleUID] = nil
        end
    end

    return decodedVehicles
end

function RefreshAndSpawn()
    deleteAllPersistentVehicles()
    spawnAllPersistentVehicles()
end

function UpdateVehicleProperties(vehicle, properties)
    Vehicles[GetVehicleUID(vehicle)] = properties
end

function SaveVehicleProperties(resourceName)
    SaveResourceFile(resourceName, "vehicles.json", json.encode(Vehicles), -1)
end

function IsVehiclePersistent(vehicle)
    local vehicleUID = GetVehicleUID(vehicle)

    if Vehicles[vehicleUID] then
        return true
    else
        return false
    end
end

function NewVehiclePersistent(vehicle)
    Vehicles[GetVehicleUID(vehicle)] = false
end

AddEventHandler("onResourceStart", function(resourceName)
    if resourceName == GetCurrentResourceName() then
        local vehiclesJson = LoadResourceFile(resourceName, "vehicles.json")

        if vehiclesJson ~= nil then
            Vehicles = trimVehiclesJson(vehiclesJson)
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
