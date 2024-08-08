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

RegisterNetEvent("CR.PV:PropertiesSet", function(vehNets)
    for vehNet, _ in pairs(vehNets) do
        local vehicle = NetToVeh(vehNet)

        if not DoesEntityExist(vehicle) then
            warn("Attempt to mark properties as set on non-exsistent vehicle")
        end

        Entity(vehicle).state.nProperties = false
    end
end)

RegisterNetEvent("CR.PV:PropertiesUpdate", function(vehNets)
    for vehNet, properties in pairs(vehNets) do
        local vehicle = NetToVeh(vehNet)

        if not DoesEntityExist(vehicle) then
            warn("Attempt to update properties on non-exsistent vehicle")
        end

        UpdateVehicle(vehicle, properties)
    end
end)

RegisterNetEvent("CR.PV:ForgetVehicle", function(vehNet)
    local vehicle = NetToVeh(vehNet)

    if not DoesEntityExist(vehicle) then
        warn("Attempt to forget non-exsistent vehicle")
    end

    ForgetVehicle(vehicle)
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
                NewVehicle(entity)
            else
                DeleteEntity(entity)
            end
        end
    end
end)

AddEventHandler("entityRemoved", function(entity)
    if GetEntityType(entity) == 2 then
        local vehicleId = GetVehicleUID(entity)

        if Entity(entity).state.isPersistent then
            SpawnVehicle(vehicleId)
        end
    end
end)
