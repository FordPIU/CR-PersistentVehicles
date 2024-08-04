local Vehicles = {}

local function updateTick(vehicle)
    TriggerServerEvent("CR.PV:Update", NetworkGetNetworkIdFromEntity(vehicle))
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
                goto skip
            end

            if IsVehiclePersistent(vehicle) and NetworkHasControlOfEntity(vehicle) then
                updateTick(vehicle)

                scopeVehicles[GetVehicleUID(vehicle)] = vehicle
            end

            ::skip::
        end

        for vehicleId, vehicleData in pairs(Vehicles) do
            local vehicle = scopeVehicles[vehicleId]

            if vehicle ~= nil then
                -- Handle transfers, despawning
                local currentOwner = NetworkGetEntityOwner(vehicle)
                local distance = #(GetEntityCoords(vehicle) - playerPos)

                if distance > Config.DespawnDistance and currentOwner == PlayerId() then
                    local closestPlayer = GetPlayerClosestToEntity(vehicle)

                    if closestPlayer == PlayerId() then
                        updateTick(vehicle)
                        DeleteEntity(vehicle)

                        print("Despawning vehicle " .. vehicleId .. " due to distance.")
                    else
                        TriggerServerEvent("CR.PV:Transfer", GetPlayerServerId(closestPlayer), vehicleId)
                        print("Requested transfer of vehicle " ..
                            vehicleId .. " to " .. closestPlayer .. "(" .. GetPlayerServerId(closestPlayer) .. ")")
                    end
                end
            else
                -- Handle spawning
                local vehiclePos = vehicleData.matrix.position

                if #(playerPos - vehiclePos) <= Config.SpawnDistance and GetPlayerClosestToCoord(vehiclePos) == PlayerId() then
                    local newVehicle = CreateVehicle(vehicleData.model, vehiclePos.x, vehiclePos.y, vehiclePos.z,
                        vehicleData.matrix
                        .heading, true, true)

                    repeat
                        Wait(0)
                    until DoesEntityExist(newVehicle)

                    SetVehicleProperties(newVehicle, vehicleData)

                    print("Spawning vehicle " .. vehicleId)
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

    repeat
        Wait(0)
        NetworkRequestControlOfEntity(vehicle)
    until NetworkHasControlOfEntity(vehicle)

    print("Transfer of vehicle " .. vehicleId .. " complete.")
end)

function IsVehiclePersistent(vehicle)
    if Vehicles[GetVehicleUID(vehicle)] ~= nil then return true else return false end
end
