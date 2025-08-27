IsLoading = true
local IsStopping = false

AddEventHandler("onResourceStart", function(resourceName)
    if resourceName == GetCurrentResourceName() then
        print("Resource starting...")

        repeat
            Wait(1000)
        until #GetPlayers() > 0

        print("Player is in server.. starting the loading of data..")

        LoadVehicleData()

        IsLoading = false
        TriggerClientEvent("CRPV_SETSERVERLOADING", -1, false)
    end
end)

AddEventHandler("onResourceStop", function(resourceName)
    if resourceName == GetCurrentResourceName() then
        --print("Resource stopping, saving data...")
        --SaveVehicleData()

        IsStopping = true

        for _, v in ipairs(GetAllVehicles()) do
            DO_NOT_RESPAWN[v] = true
            DeleteEntity(v)
        end
    end
end)

RegisterNetEvent("CR.PV:PropertiesSet", function(vehNets)
    for vehNet, _ in pairs(vehNets) do
        local vehicle = NetworkGetEntityFromNetworkId(vehNet)
        if DoesEntityExist(vehicle) then
            local state = Entity(vehicle).state
            if state.isPersistent then
                state.nProperties = false
            end
        end
    end
end)

RegisterNetEvent("CR.PV:PropertiesUpdate", function(vehNets, vehIdToForget)
    for vehNet, properties in pairs(vehNets) do
        local vehicle = NetworkGetEntityFromNetworkId(vehNet)
        if DoesEntityExist(vehicle) then
            if type(properties) == "table" then
                UpdateVehicle(vehicle, properties)
            else
                local uid = Entity(vehicle)?.state?.pId
                warn(string.format(
                    "[%s] CR.PV:PropertiesUpdate: Received invalid properties type (%s) for NetID %d (UID: %s)",
                    GetCurrentResourceName(), type(properties), vehNet, uid))
            end
        else
            warn(string.format("[%s] CR.PV:PropertiesUpdate: Received update for non-existent NetID %d",
                GetCurrentResourceName(), vehNet))
        end
    end

    if vehIdToForget ~= nil then
        ForgetVehicle(nil, vehIdToForget)
    end
end)

RegisterNetEvent("CR.PV:NewVehicle", function(vehNet, vehProps)
    local vehicle = NetworkGetEntityFromNetworkId(vehNet)
    if DoesEntityExist(vehicle) then
        -- print(string.format("[%s] Received request to register new vehicle NetID %d", GetCurrentResourceName(), vehNet))
        NewVehicle(vehicle, vehProps)
    else
        warn(string.format("[%s] CR.PV:NewVehicle: Received request for non-existent NetID %d", GetCurrentResourceName(),
            vehNet))
    end
end)

--- Handles request from the client to forget (remove persistence) for a vehicle.
--- @param vehNet number The network ID of the vehicle to forget.
RegisterNetEvent("CR.PV:ForgetVehicle", function(vehNet)
    local vehicle = NetworkGetEntityFromNetworkId(vehNet)
    if DoesEntityExist(vehicle) then
        local uid = Entity(vehicle)?.state?.pId
        print(string.format("[%s] Received request to forget vehicle NetID %d (UID: %s)", GetCurrentResourceName(),
            vehNet, uid))
        ForgetVehicle(vehicle) -- Pass entity to ensure deletion
    else
        warn(string.format("[%s] CR.PV:ForgetVehicle: Received request for non-existent NetID %d",
            GetCurrentResourceName(), vehNet))
    end
end)

--- Handles request from the client to forget a vehicle based on its UID, even if the entity doesn't exist locally.
--- @param vehicleUID string The persistent UID of the vehicle to forget.
RegisterNetEvent("CR.PV:ForgetVehicleById", function(vehicleUID)
    if vehicleUID and type(vehicleUID) == "string" then
        print(string.format("[%s] Received request to forget vehicle by UID: %s", GetCurrentResourceName(), vehicleUID))
        ForgetVehicle(nil, vehicleUID) -- Pass nil for entity, only use UID
    else
        warn(string.format("[%s] CR.PV:ForgetVehicleById: Received invalid UID type (%s)", GetCurrentResourceName(),
            type(vehicleUID)))
    end
end)

AddEventHandler("entityRemoved", function(entity)
    if IsStopping then return end
    if DO_NOT_RESPAWN[entity] then
        DO_NOT_RESPAWN[entity] = nil
        return
    end

    local state = Entity(entity).state

    if state and state.isPersistent == true and state.pId then
        local vehicleUID = state.pId
        print(string.format("[%s] Persistent vehicle removed unexpectedly (Entity: %d, UID: %s). Respawning...",
            GetCurrentResourceName(), entity, vehicleUID))

        SpawnVehicle(vehicleUID)
    end
end)

RegisterNetEvent("CRPV_GETSERVERLOADING", function()
    TriggerClientEvent("CRPV_SETSERVERLOADING", source, IsLoading)
end)

RegisterNetEvent("CR.PV:VehiclePlateChange", function(oldVehId, newNetId, properties)
    local newVeh = NetworkGetEntityFromNetworkId(newNetId)

    if not DoesEntityExist(newVeh) then
        warn("Attempt to change plate on non-exsistent vehicle??")
        return
    end

    NewVehicle(newVeh)
    UpdateVehicle(newVeh, properties)
    ForgetVehicle(nil, oldVehId)
end)
