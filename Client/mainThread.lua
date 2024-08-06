local Vehicles = {}

local function updateTick(vehicle)
    TriggerServerEvent("CR.PV:Update", NetworkGetNetworkIdFromEntity(vehicle), GetVehicleProperties(vehicle))
end

local function duplicationDetection(vehicle)
    local vehicleId = GetVehicleUID(vehicle)
    local anyDuplicates = false

    for _, vehicle2 in ipairs(GetGamePool("CVehicle")) do
        local vehicle2Id = GetVehicleUID(vehicle2)

        if vehicleId == vehicle2Id and not vehicle == vehicle2 then
            DeleteEntity(vehicle)
            DeleteEntity(vehicle2)

            anyDuplicates = true

            print("Duplicated vehicleId located " .. vehicleId .. ", " .. vehicle2Id)
        end
    end

    return anyDuplicates
end

Citizen.CreateThread(function()
    while true do
        Wait(1000) -- 1 TPS

        local scopeVehicles = {}
        local playerPos = GetEntityCoords(PlayerPedId())

        for _, vehicle in ipairs(GetGamePool("CVehicle")) do
            if not DoesEntityExist(vehicle) or IsEntityDead(vehicle) then -- I dont even know why they would be in the pool if they meet these conditions, but fivem
                warn(
                    "FiveM is fucking stupid and attempted to tick on a entity that is dead or doesnt even exist. Coolio.")
            else
                if IsVehiclePersistent(vehicle) and NetworkHasControlOfEntity(vehicle) then
                    if not duplicationDetection(vehicle) then
                        updateTick(vehicle)

                        scopeVehicles[GetVehicleUID(vehicle)] = vehicle

                        --print("Updated vehicle " .. GetVehicleUID(vehicle) .. " and added to scope.")
                    end
                end
            end
        end

        for vehicleId, vehicleData in pairs(Vehicles) do
            local vehicle = scopeVehicles[vehicleId]

            if vehicle ~= nil then
                local currentOwner = NetworkGetEntityOwner(vehicle)
                local distance = #(GetEntityCoords(vehicle) - playerPos)

                if distance > Config.DespawnDistance and currentOwner == PlayerId() then
                    local closestPlayer = GetPlayerClosestToEntity(vehicle)

                    if closestPlayer == GetPlayerServerId(PlayerId()) then
                        if not duplicationDetection(vehicle) then
                            updateTick(vehicle)
                            DeleteEntity(vehicle)

                            print("Despawning vehicle " .. vehicleId .. " due to distance.")
                        end
                    else
                        TriggerServerEvent("CR.PV:Transfer", closestPlayer, vehicleId)
                        print("Requested transfer of vehicle " .. vehicleId .. " to " .. closestPlayer)
                    end
                end
            else
                if type(vehicleData) == "table" then
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

                        repeat
                            Wait(0)
                            print("Awaiting for new vehicle to exist")
                        until DoesEntityExist(newVehicle)

                        SetVehicleProperties(newVehicle, vehicleData)

                        print("Spawning vehicle " .. vehicleId)
                    end
                else
                    warn("Data for vehicle " .. vehicleId .. " is of unknown type: " .. type(vehicleData))
                end
            end
        end
    end
end)

TriggerServerEvent("CR.PV:NewPlayer")
RegisterNetEvent("CR.PV:Vehicles", function(vehicles)
    Vehicles = vehicles
end)
RegisterNetEvent("CR.PV:TransferRequest", function(vehicleId)
    local vehicle = GetVehicleFromVehicleId(vehicleId) -- This might be more expensive than just storing this shit in the loop above
    local timeout = GetGameTimer() + 5000

    repeat
        Wait(5)
        NetworkRequestControlOfEntity(vehicle)

        if GetGameTimer() >= timeout then
            warn("Timeout for transfer request of vehicle " .. vehicleId)
            return
        end
    until NetworkHasControlOfEntity(vehicle)

    print("Transfer of vehicle " .. vehicleId .. " complete.")
end)

function IsVehiclePersistent(vehicle)
    if Vehicles[GetVehicleUID(vehicle)] ~= nil then return true else return false end
end
