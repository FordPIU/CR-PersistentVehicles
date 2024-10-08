--[[
    Resource start/stop
]]
AddEventHandler("onResourceStart", function(resourceName)
    if resourceName == GetCurrentResourceName() then
        --print("Starting resource: " .. resourceName)
        LoadVehicleData(resourceName)
    end
end)

AddEventHandler("onResourceStop", function(resourceName)
    if resourceName == GetCurrentResourceName() then
        --print("Stopping resource: " .. resourceName)
        SaveVehicleData(resourceName)
    end
end)

RegisterNetEvent("CR.PV:PropertiesSet", function(vehNets)
    for vehNet, _ in pairs(vehNets) do
        local vehicle = NetworkGetEntityFromNetworkId(vehNet)

        if not DoesEntityExist(vehicle) then
            warn("Attempt to mark properties as set on non-existent vehicle with Net ID: " .. vehNet)
        else
            --print("Setting properties for vehicle with Vehicle UID: " .. GetVehicleUID(vehicle))
            Entity(vehicle).state.nProperties = false
        end
    end
end)

RegisterNetEvent("CR.PV:PropertiesUpdate", function(vehNets)
    for vehNet, properties in pairs(vehNets) do
        local vehicle = NetworkGetEntityFromNetworkId(vehNet)

        if not DoesEntityExist(vehicle) then
            warn("Attempt to update properties on non-existent vehicle with Net ID: " .. vehNet)
        else
            --print("Updating properties for vehicle with Vehicle UID: " .. GetVehicleUID(vehicle))
            UpdateVehicle(vehicle, properties)
        end
    end
end)

RegisterNetEvent("CR.PV:NewVehicle", function(vehNet)
    local vehicle = NetworkGetEntityFromNetworkId(vehNet)

    if not DoesEntityExist(vehicle) then
        warn("Attempt to add new non-existent vehicle with Net ID: " .. vehNet)
    else
        --print("Adding new vehicle with Vehicle UID: " .. GetVehicleUID(vehicle))
        NewVehicle(vehicle)
    end
end)

RegisterNetEvent("CR.PV:ForgetVehicle", function(vehNet)
    local vehicle = NetworkGetEntityFromNetworkId(vehNet)

    if not DoesEntityExist(vehicle) then
        warn("Attempt to forget non-existent vehicle with Net ID: " .. vehNet)
    else
        --print("Forgetting vehicle with Vehicle UID: " .. GetVehicleUID(vehicle))
        ForgetVehicle(vehicle)
    end
end)

RegisterNetEvent("CR.PV:ForgetVehicleById", function(vehicleUID)
    --print("Forgetting vehicle BY Vehicle UID: " .. vehicleUID)
    ForgetVehicle(nil, vehicleUID)
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
                --print("New vehicle created with Vehicle UID: " .. GetVehicleUID(entity))
                NewVehicle(entity)
            else
                --print("Deleting persistent vehicle with Vehicle UID: " .. GetVehicleUID(entity))
                DeleteEntity(entity)
            end
        end
    end
end)

DO_NOT_RESPAWN = {}
AddEventHandler("entityRemoved", function(entity)
    if GetEntityType(entity) == 2 then
        if DO_NOT_RESPAWN[entity] then
            DO_NOT_RESPAWN[entity] = nil
            return
        end

        if Entity(entity).state.isPersistent then
            --print("Respawning persistent vehicle with Vehicle UID: " .. vehicleId)
            SpawnVehicle(Entity(entity).state.pId)
        else
            --print("Non-persistent vehicle removed with Entity ID: " .. entity)
        end
    end
end)
