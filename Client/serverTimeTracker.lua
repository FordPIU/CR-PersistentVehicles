local ServerTime = -1

Citizen.CreateThread(function()
    repeat
        Wait(0)
    until DoesEntityExist(PlayerPedId())

    TriggerServerEvent("CR.PV:GetServerTime")

    repeat
        Wait(0)
    until ServerTime ~= -1

    while true do
        Wait(0)

        for _, v in pairs(GetGamePool("CVehicle")) do
            local vehicleServerTime = Entity(v).state.PersistentServerTime
            if vehicleServerTime ~= nil and vehicleServerTime ~= ServerTime then
                DeleteEntity(v)
            end
        end
    end
end)

RegisterNetEvent("CR.PV:SetServerTime", function(serverTime)
    ServerTime = serverTime
end)
