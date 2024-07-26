RegisterNetEvent("CR.PV:Update", function(vehicleNetId, properties)
    local vehicle = NetworkGetEntityFromNetworkId(vehicleNetId)

    if DoesEntityExist(vehicle) then
        if IsVehiclePersistent(vehicle) then
            UpdateVehicleProperties(vehicle, properties)
        else
            warn("Attempt to update on non-persistent vehicle")
        end
    else
        warn("Attempt to update on non-exsistent vehicle")
    end
end)