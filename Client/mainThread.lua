local Vehicles = {}

local function updateTick(vehicle)
    if not IsVehiclePersistent(vehicle) then return false end
    if not NetworkHasControlOfEntity(vehicle) then return false end
    if IsVehicleSpawningPaused(GetVehicleUID(vehicle)) then return false end

    TriggerServerEvent("CR.PV:Update", NetworkGetNetworkIdFromEntity(vehicle), GetVehicleProperties(vehicle))

    return true
end

local function spawnTick(vehicleId, vehicleData, playerPos)
    if type(vehicleData) ~= "table" then
        Warn("Data for vehicle " .. vehicleId .. " is of unknown type: " .. type(vehicleData))
        return false
    end
    if IsVehicleSpawningPaused(vehicleId) then return false end

    local vehiclePosNV3 = vehicleData.matrix.position -- NV3 = Not Vector3
    local vehiclePos = vector3(vehiclePosNV3.x, vehiclePosNV3.y, vehiclePosNV3.z)
    local distance = #(playerPos - vehiclePos)

    if distance <= Config.SpawnDistance and GetPlayerClosestToCoord(vehiclePos) == GetPlayerServerId(PlayerId()) and not DoesPersistentVehicleExists(vehicleId) then
        RequestModel(vehicleData.model)
        repeat
            Wait(0)
        until HasModelLoaded(vehicleData.model)

        local newVehicle = CreateVehicle(vehicleData.model, vehiclePos.x, vehiclePos.y, vehiclePos.z,
            vehicleData.matrix
            .heading, true, false)
        SetVehicleProperties(newVehicle, vehicleData, vehicleId)
        --print("Spawning vehicle " .. vehicleId)

        return true
    end

    return false
end

local function despawnTick(vehicleId, playerPos)
    local vehicle = GetVehicleFromVehicleId(vehicleId)
    local currentOwner = NetworkGetEntityOwner(vehicle)
    local distance = #(GetEntityCoords(vehicle) - playerPos)

    if distance <= Config.DespawnDistance then
        return false
    else                                                             --print(distance, vehicle, GetEntityCoords(vehicle), playerPos) end
        if currentOwner ~= PlayerId() then return false end

        local closestPlayer = GetPlayerClosestToEntity(vehicle)

        if closestPlayer == GetPlayerServerId(PlayerId()) then
            updateTick(vehicle)
            DeleteEntity(vehicle)
            --print("Despawning vehicle " .. vehicleId .. " due to distance.")
        else
            TriggerServerEvent("CR.PV:Transfer", closestPlayer, vehicleId)
            --print("Requested transfer of vehicle " .. vehicleId .. " to " .. closestPlayer)
        end
    end
end

local function duplicateTick(vehicleId, vehicle)
    for _, v in ipairs(GetGamePool("CVehicle")) do
        if DoesEntityExist(v) and GetVehicleUID(v) == vehicleId and v ~= vehicle then
            DeleteEntity(v)
            DeleteEntity(vehicle)
        end
    end
end

Citizen.CreateThread(function()
    while true do
        Wait(1000) -- 1 TPS

        local playerPos = GetEntityCoords(PlayerPedId())

        if playerPos ~= nil then
            for _, vehicle in ipairs(GetGamePool("CVehicle")) do
                if DoesEntityExist(vehicle) and IsVehiclePersistent(vehicle) then
                    local vehicleId = GetVehicleUID(vehicle)

                    duplicateTick(vehicleId, vehicle)
                    updateTick(vehicle)
                end
            end
        end
    end
end)

Citizen.CreateThread(function()
    while true do
        Wait(5000) -- .25 TPS

        local playerPos = GetEntityCoords(PlayerPedId())

        if playerPos ~= nil then
            for vehicleId, vehicleData in pairs(Vehicles) do
                spawnTick(vehicleId, vehicleData, playerPos)
                despawnTick(vehicleId, playerPos)
            end
        end
    end
end)

TriggerServerEvent("CR.PV:NewPlayer")
RegisterNetEvent("CR.PV:Vehicles", function(vehicles)
    Vehicles = vehicles

    --print("Vehicles table updated from server.")
end)
RegisterNetEvent("CR.PV:TransferRequest", function(vehicleId)
    local vehicle = GetVehicleFromVehicleId(vehicleId) -- This might be more expensive than just storing this shit in the loop above
    local timeout = GetGameTimer() + 5000

    repeat
        Wait(5)
        NetworkRequestControlOfEntity(vehicle)

        if GetGameTimer() >= timeout then
            Warn("Timeout for transfer request of vehicle " .. vehicleId)
            return
        end
    until NetworkHasControlOfEntity(vehicle)

    --print("Transfer of vehicle " .. vehicleId .. " complete.")
end)

function IsVehiclePersistent(vehicle)
    if not DoesEntityExist(vehicle) then
        Warn("Attempt to get IsVehiclePersistent on vehicle that does not exist?")
        return false
    end

    if Vehicles[GetVehicleUID(vehicle)] ~= nil then return true else return false end
end

function GetVehicles()
    return Vehicles
end
