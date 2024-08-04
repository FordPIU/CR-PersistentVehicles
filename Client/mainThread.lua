Citizen.CreateThread(function()
    while true do
        Wait(1000) -- 1 TPS

        for _, veh in pairs(GetGamePool("CVehicle")) do
            local entityState = Entity(veh).state

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
            end

            -- Yay, merging code that already doesnt work so that more of it doesnt work
            -- I wonder why I keep burning out
            if entityState.IsPersistent and NetworkHasControlOfEntity(veh) then
                local vehicleNetId = NetworkGetNetworkIdFromEntity(veh)
                local vehicleProperties = GetVehicleProperties(veh)

                TriggerServerEvent("CR.PV:Update", vehicleNetId, vehicleProperties)
            end
        end
    end
end)
