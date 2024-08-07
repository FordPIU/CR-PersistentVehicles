--[[
    Resource start/stop
]]
AddEventHandler("onResourceStart", function(resourceName)
    if resourceName == GetCurrentResourceName() then
        LoadVehicleData(resourceName)
    end
end)

AddEventHandler("onResourceStop", function(resourceName)
    if resourceName == GetCurrentResourceName() then
        SaveVehicleData(resourceName)
    end
end)

--[[
    Player related
]]
RegisterNetEvent("CR.PV:NewPlayer", function()
    TriggerClientEvent("CR.PV:Vehicles", source, GetVehicles())
end)
RegisterNetEvent("CR.PV:Transfer", function(serverId, vehicleId)
    TriggerClientEvent("CR.PV:TransferRequest", serverId, vehicleId)
end)

--[[
    Exposed Events
]]
RegisterNetEvent("CR.PV:Update", function(vehicleNetId, properties)
    local vehicle = NetworkGetEntityFromNetworkId(vehicleNetId)

    if not DoesEntityExist(vehicle) then
        Warn("Event call to forget vehicle, but net id was invalid and the vehicle doesnt exist.")
        return
    end

    UpdateVehicle(vehicle, properties)

    --Print("Updated vehicle " .. GetVehicleUID(vehicle))
end)

RegisterNetEvent("CR.PV:NetworkedUpdate", function(networkedData)
    for vehicleNetId, properties in pairs(networkedData) do
        local vehicle = NetworkGetEntityFromNetworkId(vehicleNetId)

        if not DoesEntityExist(vehicle) then
            Warn("Event call to forget vehicle, but net id was invalid and the vehicle doesnt exist.")
            return
        end

        UpdateVehicle(vehicle, properties)
    end
end)

RegisterNetEvent("CR.PV:Forget", function(vehicleNetId)
    local vehicle = NetworkGetEntityFromNetworkId(vehicleNetId)

    if not DoesEntityExist(vehicle) then
        Warn("Event call to forget vehicle, but net id was invalid and the vehicle doesnt exist.")
        return
    end

    ForgetVehicle(vehicle)

    --Print("Forgot vehicle " .. GetVehicleUID(vehicle))
end)

--[[
    vMenu vehicle spawn detection
]]
AddEventHandler("entityCreated", function(entity)
    repeat
        Wait(0)
    until DoesEntityExist(entity)

    if GetEntityType(entity) == 2 then
        local driver = GetPedInVehicleSeat(entity, -1)

        if DoesEntityExist(driver) and IsPedAPlayer(driver) then
            if not IsVehiclePersistent(entity) then
                UpdateVehicle(entity, true)
            else
                DeleteEntity(entity)
            end
        end
    end
end)
