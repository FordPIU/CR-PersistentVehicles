Citizen.CreateThread(function()
    while true do
        Wait(500)

        local vehicle = GetVehiclePedIsIn(PlayerPedId(), true)

        if Entity(vehicle).state.IsPersistent then
            local vehicleNetId = NetworkGetNetworkIdFromEntity(vehicle)
            local vehicleProperties = GetVehicleProperties(vehicle)

            TriggerServerEvent("CR.PV:Update", vehicleNetId, vehicleProperties)
        end
    end
end)
