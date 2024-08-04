Citizen.CreateThread(function()
    while true do
        -- 1 TPS
        Wait(1000)

        for _, veh in pairs(GetGamePool("CVehicle")) do
            -- Updated properties for vehicles that server says needs it
            -- I honestly hate this method but too far along and too tired.
            if Entity(veh).state.NeedsPropertiesSet ~= nil then
                -- Safeguard to make sure no issues with fivems shit networking happens
                if not NetworkHasControlOfEntity(veh) then
                    repeat
                        Wait(0)
                        NetworkRequestControlOfEntity(veh)
                    until NetworkHasControlOfEntity(veh)
                end

                -- This is just kinda ugly, fuck networking
                SetVehicleProperties(veh, Entity(veh).state.NeedsPropertiesSet)
                TriggerServerEvent("CR.PV:PropertiesSet", NetworkGetNetworkIdFromEntity(veh))
            end
        end
    end
end)
