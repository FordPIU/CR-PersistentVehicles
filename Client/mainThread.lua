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

                -- This is just kinda ugly, fuck networking
                SetVehicleProperties(veh, entityState.NeedsPropertiesSet)
                TriggerServerEvent("CR.PV:PropertiesSet", NetworkGetNetworkIdFromEntity(veh))
                print("Set properties for persistent vehicle" .. veh)
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
