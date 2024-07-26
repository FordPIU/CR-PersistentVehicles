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

local function spawnAllPersistentVehicles()
    for vehicleUID, properties in pairs(Vehicles) do
        print(vehicleUID, json.encode(properties))
    end
end

--------------------------------------------------

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
