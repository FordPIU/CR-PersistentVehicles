local Vehicles = {}

local function fullUpdateTick(vehicle, vehicleId)
    if IsVehicleSpawningPaused(vehicleId) then return end

    TriggerServerEvent("CR.PV:Update", VehToNet(vehicle), GetVehicleProperties(vehicle))
end

local function locationUpdateTick(vehicle, vehicleId)
    if IsVehicleSpawningPaused(vehicleId) then return end
    local vehicleData = Vehicles[vehicleId]

    if type(vehicleData) ~= "table" then
        fullUpdateTick(vehicle, vehicleId)
        return
    end

    local matrix = GetEntityMatrixTable(vehicle)
    vehicleData.matrix = matrix

    TriggerServerEvent("CR.PV:Update", VehToNet(vehicle), vehicleData)
end

local function spawnTick(vehicleId, vehicleData, playerPos)
    if IsVehicleSpawningPaused(vehicleId) then return end

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
    end
end

local function despawnTick(vehicle, vehicleId, playerPos)
    local distance = #(GetEntityCoords(vehicle) - playerPos)

    if distance > Config.DespawnDistance then
        local closestPlayer = GetPlayerClosestToEntity(vehicle)

        if closestPlayer == GetPlayerServerId(PlayerId()) then
            fullUpdateTick(vehicle, vehicleId)
            DeleteEntity(vehicle)
            --print("Despawning vehicle " .. vehicleId .. " due to distance.")
        else
            TriggerServerEvent("CR.PV:Transfer", closestPlayer, vehicleId)
            --print("Requested transfer of vehicle " .. vehicleId .. " to " .. closestPlayer)
        end
    end
end

Citizen.CreateThread(function()
    local i = 0
    while true do
        Wait(1000)

        local playerPos = GetEntityCoords(PlayerPedId())

        if playerPos ~= nil then
            for vehicleId, vehicleData in pairs(Vehicles) do
                if type(vehicleData) == "table" then
                    local vehicle = GetVehicleFromVehicleId(vehicleId)

                    if vehicle ~= nil then
                        if NetworkHasControlOfEntity(vehicle) then
                            if i == 10 then
                                fullUpdateTick(vehicle, vehicleId)
                                i = 0
                            else
                                locationUpdateTick(vehicle, vehicleId)
                            end
                            despawnTick(vehicle, vehicleId, playerPos)
                        end
                    else
                        spawnTick(vehicleId, vehicleData, playerPos)
                    end
                elseif vehicleData == true then
                    local vehicle = GetVehicleFromVehicleId(vehicleId)

                    if NetworkHasControlOfEntity(vehicle) then
                        fullUpdateTick(vehicle, vehicleId)
                    end
                end
            end
        end

        i += 1
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
