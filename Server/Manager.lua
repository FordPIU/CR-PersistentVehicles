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
            TriggerClientEvent("CR.PV:Vehicles", -1, Vehicles)
        end
    end
}

setmetatable(Vehicles, Vehicles_Metatable)

--[[
    Data Load/Save
]]
function LoadVehicleData(resourceName)
    local vehiclesJson = LoadResourceFile(resourceName or GetCurrentResourceName(), "vehicles.json")

    if vehiclesJson ~= nil then
        Vehicles = TrimVehiclesJson(vehiclesJson)
        setmetatable(Vehicles, Vehicles_Metatable) -- Just to make sure the new table ref doesnt fuck it
        print("Loaded vehicles.json")
    else
        warn("No file: vehicles.json")
    end
end

function SaveVehicleData(resourceName)
    print("Saving data...")
    SaveResourceFile(resourceName or GetCurrentResourceName(), "vehicles.json", json.encode(Vehicles), -1)
    print("Saved data successfully.")
end

--[[
    Vehicle State Management
]]
function UpdateVehicle(vehicle, properties)
    Vehicles[GetVehicleUID(vehicle)] = properties
end

function ForgetVehicle(vehicle)
    Vehicles[GetVehicleUID(vehicle)] = nil
end

function GetVehicles()
    return Vehicles
end

function IsVehiclePersistent(vehicle)
    if Vehicles[GetVehicleUID(vehicle)] ~= nil then return true else return false end
end
