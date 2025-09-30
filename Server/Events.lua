SPAWNED_VEHICLES = {}

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

    if vehicleProperties == nil or type(vehicleProperties) ~= "table" then
        warn("Attempt to update persistent vehicle " .. vehicleId .. " without proper properties.")
        return
    end

    Vehicles[vehicleId] = vehicleProperties
end)

RegisterNetEvent("CR.PV:UpdateMultiple", function(updateArray)
    for vehicleId, vehicleProperties in pairs(updateArray) do
        if vehicleProperties == nil or type(vehicleProperties) ~= "table" then
            warn("Attempt to update persistent vehicle " .. vehicleId .. " without proper properties.")
            return
        end

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

RegisterNetEvent("CR.PV:ForgetVehicleById", function(uid)
    Vehicles[uid] = nil
    print("Forgot vehicle " .. uid)
end)

local LastSyncTime = 0
RegisterNetEvent("CR.PV:GetVehicles", function()
    if GetGameTimer() > (LastSyncTime + 1000) then
        -- Fetch all players
        local Players = {}
        local PlayerVehicles = {}
        local SpawnedVehicles = {}

        for _, playerId in ipairs(GetPlayers()) do
            local playerPed = GetPlayerPed(playerId)

            if DoesEntityExist(playerPed) then
                Players[playerId] = GetEntityCoords(playerPed)
            end
        end

        for vehicleId, vehicleData in pairs(Vehicles) do
            local coordsJson = vehicleData.matrix.position
            local coords = vector3(coordsJson.x, coordsJson.y, coordsJson.z)
            local nearestPlayer = nil
            local nearestDist = 1000.0

            -- Get nearest player to the vehicle
            for playerId, playerCoords in pairs(Players) do
                local dist = #(playerCoords - coords)

                if dist < nearestDist then
                    nearestPlayer = playerId
                    nearestDist = dist
                end
            end

            -- Assign the vehicle to nearest player
            if nearestPlayer then
                PlayerVehicles[nearestPlayer] = PlayerVehicles[nearestPlayer] or {}
                PlayerVehicles[nearestPlayer][vehicleId] = vehicleData
            end

            -- Check if another player reported the vehicle as spawned
            if SPAWNED_VEHICLES[vehicleId] == true then
                SpawnedVehicles[vehicleId] = true
            end
        end

        -- Fetch all spawned persistent vehicles
        for _, vehicle in ipairs(GetAllVehicles()) do
            if Entity(vehicle).state.persistentId then
                SpawnedVehicles[Entity(vehicle).state.persistentId] = true
            end
        end

        for playerId, playerVehicles in pairs(PlayerVehicles) do
            TriggerClientEvent("CR.PV:ReturnVehicles", playerId, playerVehicles, Players, SpawnedVehicles)
        end

        LastSyncTime = GetGameTimer()
    end
end)

RegisterNetEvent("CR.PV:MyFiveMId", function()
    local fivemId = GetPlayerIdentifierByType(source, "fivem"):gsub("fivem:", "")
    TriggerClientEvent("CR.PV:SetFivemId", source, fivemId)
end)

RegisterNetEvent("CR.PV:ISpawned", function(vehicleData)
    for _, vehicleInfo in pairs(vehicleData) do
        SPAWNED_VEHICLES[vehicleInfo[1]] = vehicleInfo[2]
    end
end)

-- Server sends each client a special PersitentVehicles table tailored to which vehicles are closest to them only
-- Removes nearest player check on client from being needed
