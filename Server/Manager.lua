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

end

function RefreshAndSpawn()
    deleteAllPersistentVehicles()
    spawnAllPersistentVehicles()
end

function UpdateVehicleProperties(properties)

end

function SaveVehicleProperties()

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

end

AddEventHandler("onResourceStart", function(resourceName)
    if resourceName == GetCurrentResourceName() then
        RefreshAndSpawn()
    end
end)

AddEventHandler("onResourceStop", function(resourceName)
    if resourceName == GetCurrentResourceName() then
        SaveVehicleProperties()
    end
end)
