Citizen.CreateThread(function()
    while true do
        Wait(500) -- 2 TPS

        for _, veh in pairs(GetGamePool("CVehicle")) do
            local entityState = Entity(veh).state

            if not DoesEntityExist(veh) or IsEntityDead(veh) then -- I dont even know why they would be in the pool if they meet these conditions, but fivem
                warn("FiveM is fucking stupid and attempted to tick on a entity that is dead or doesnt even exist. Coolio.")
                goto skip
            end

            -- Updated properties for vehicles that server says needs it
            -- I honestly hate this method but too far along and too tired.
            if entityState.NeedsPropertiesSet ~= nil then
                -- Safeguard to make sure no issues with fivems shit networking happens
                if not NetworkHasControlOfEntity(veh) then
                    repeat
                        Wait(0)
                        NetworkRequestControlOfEntity(veh)
                    until NetworkHasControlOfEntity(veh)
                end

<<<<<<< Updated upstream
                -- This is just kinda ugly, fuck networking
                SetVehicleProperties(veh, entityState.NeedsPropertiesSet)
                TriggerServerEvent("CR.PV:PropertiesSet", NetworkGetNetworkIdFromEntity(veh))
                print("Set properties for persistent vehicle" .. veh)
=======
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
                            --print("Awaiting for new vehicle to exist")
                        until DoesEntityExist(newVehicle)

                        SetVehicleProperties(newVehicle, vehicleData)

                        --print("Spawning vehicle " .. vehicleId)
                    end
                else
                    warn("Data for vehicle " .. vehicleId .. " is of unknown type: " .. type(vehicleData))
                end
>>>>>>> Stashed changes
            end

            -- Yay, merging code that already doesnt work so that more of it doesnt work
            -- I wonder why I keep burning out
            if entityState.IsPersistent and NetworkHasControlOfEntity(veh) then
                local vehicleNetId = NetworkGetNetworkIdFromEntity(veh)
                local vehicleProperties = GetVehicleProperties(veh)

                TriggerServerEvent("CR.PV:Update", vehicleNetId, vehicleProperties)
                print("Updated properties for persistent vehicle " .. veh)
            end

            ::skip::
        end
    end
end)
