local Vehicles = {}

--[[
    Data Load/Save
]]
function LoadVehicleData(resourceName)
    local vehiclesJson = LoadResourceFile(resourceName or GetCurrentResourceName(), "vehicles.json")

    if vehiclesJson ~= nil then
        Vehicles = TrimVehiclesJson(vehiclesJson)
        setmetatable(Vehicles, Vehicles_Metatable) -- Just to make sure the new table ref doesnt fuck it
        Print("Loaded vehicles.json")
    else
        Warn("No file: vehicles.json")
    end
end

function SaveVehicleData(resourceName)
    Print("Saving data...")
    SaveResourceFile(resourceName or GetCurrentResourceName(), "vehicles.json", json.encode(Vehicles), -1)
    Print("Saved data successfully.")
end

function SaveAndRefreshClients()
    SaveVehicleData()
    TriggerClientEvent("CR.PV:Vehicles", -1, Vehicles)
end

--[[
    Vehicle State Management
]]
function UpdateVehicle(vehicle, properties)
    Vehicles[GetVehicleUID(vehicle)] = properties
    SaveAndRefreshClients()
end

function ForgetVehicle(vehicle)
    Vehicles[GetVehicleUID(vehicle)] = nil
    SaveAndRefreshClients()
end

function GetVehicles()
    return Vehicles
end

function IsVehiclePersistent(vehicle)
    if Vehicles[GetVehicleUID(vehicle)] ~= nil then return true else return false end
end
