---@diagnostic disable: param-type-mismatch
AddEventHandler("onResourceStart", function(resourceName)
    if resourceName == GetCurrentResourceName() then
        print("Resource starting, loading vehicle data")
        LoadVehicleData()
    end
end)

AddEventHandler("onResourceStop", function(resourceName)
    if resourceName == GetCurrentResourceName() then
        print("Resource stopping, saving data...")
        SaveVehicleData()

        for _, v in ipairs(GetAllVehicles()) do
            DeleteEntity(v)
        end
    end
end)

RegisterNetEvent("CR.PV:UpdateSingle", function(vehicleId, vehicleProperties, needsUID)
    if vehicleId == nil and needsUID == true then
        vehicleId = GenerateUID()
    end

    Vehicles[vehicleId] = vehicleProperties
end)

RegisterNetEvent("CR.PV:UpdateMultiple", function(updateArray)
    for vehicleId, vehicleProperties in pairs(updateArray) do
        Vehicles[vehicleId] = vehicleProperties
    end
end)

RegisterNetEvent("CR.PV:ForgetVehicle", function(vehNet)
    local vehicle = NetworkGetEntityFromNetworkId(vehNet)
    if DoesEntityExist(vehicle) then
        if Entity(vehicle).state.persistentId then
            Vehicles[Entity(vehicle).state.persistentId] = nil
        end
        DeleteEntity(vehicle)
    else
        warn(string.format("[%s] CR.PV:ForgetVehicle: Received request for non-existent NetID %d",
            GetCurrentResourceName(), vehNet))
    end
end)

local LastSyncTime = 0
RegisterNetEvent("CR.PV:GetVehicles", function()
    if GetGameTimer() > (LastSyncTime + 1000) then
        -- Fetch all players
        local Players = {}

        for _, playerId in ipairs(GetPlayers()) do
            local playerPed = GetPlayerPed(playerId)

            if DoesEntityExist(playerPed) then
                Players[playerId] = GetEntityCoords(playerPed)
            end
        end

        -- Fetch all spawned persistent vehicles
        local SpawnedVehicles = {}

        for _, vehicle in ipairs(GetAllVehicles()) do
            if Entity(vehicle).state.persistentId then
                SpawnedVehicles[Entity(vehicle).state.persistentId] = true
            end
        end

        TriggerClientEvent("CR.PV:ReturnVehicles", -1, Vehicles, Players, SpawnedVehicles)
        LastSyncTime = GetGameTimer()
    end
end)

RegisterNetEvent("CR.PV:MyFiveMId", function()
    local fivemId = GetPlayerIdentifierByType(source, "fivem"):gsub("fivem:", "")
    TriggerClientEvent("CR.PV:SetFivemId", source, fivemId)
end)

-- Server sends each client a special PersitentVehicles table tailored to which vehicles are closest to them only
-- Removes nearest player check on client from being needed