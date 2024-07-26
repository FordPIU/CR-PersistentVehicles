Citizen.CreateThread(function()
    while true do
        Wait(1000)

        for _, veh in pairs(GetGamePool("CVehicle")) do
            if Entity(veh).state.NeedsPropertiesSet ~= nil then
                SetVehicleProperties(veh, Entity(veh).state.NeedsPropertiesSet)
                TriggerServerEvent("CR.PV:PropertiesSet", NetworkGetNetworkIdFromEntity(veh))
            end
        end
    end
end)
