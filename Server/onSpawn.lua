AddEventHandler("entityCreated", function(entity)
    repeat
        Wait(0)
    until DoesEntityExist(entity)

    if GetEntityType(entity) == 2 then
        local driver = GetPedInVehicleSeat(entity, -1)

        if DoesEntityExist(driver) and IsPedAPlayer(driver) then
        end
    end
end)
