local Vehicles = {}

--[[
    Data Load/Save
]]
function LoadVehicleData(resourceName)
    local vehiclesJson = LoadResourceFile(resourceName or GetCurrentResourceName(), "vehicles.json")

    if vehiclesJson ~= nil then
        Vehicles = TrimVehiclesJson(vehiclesJson)
        --Print("Loaded vehicles.json")
    else
        Warn("No file: vehicles.json")
    end
end

function SaveVehicleData(resourceName)
    --Print("Saving data...")
    SaveResourceFile(resourceName or GetCurrentResourceName(), "vehicles.json", json.encode(Vehicles), -1)
    --Print("Saved data successfully.")
end

--[[
    Vehicle State Management
]]
function UpdateVehicle(vehicle, properties)
    Vehicles[GetVehicleUID(vehicle)] = properties
    SaveVehicleData()
end

function ForgetVehicle(vehicle)
    Vehicles[GetVehicleUID(vehicle)] = nil
    SaveVehicleData()
end

function GetVehicles()
    return Vehicles
end

function IsVehiclePersistent(vehicle)
    if Vehicles[GetVehicleUID(vehicle)] ~= nil then return true else return false end
end

Citizen.CreateThread(function()
    while true do
        Wait(1000)
        TriggerClientEvent("CR.PV:Vehicles", -1, Vehicles)
    end
end)
