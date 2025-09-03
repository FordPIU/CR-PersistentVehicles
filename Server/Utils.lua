function TrimVehiclesJson(vehiclesJson)
    print("Trimming vehicle JSON data")
    local decodedVehicles = json.decode(vehiclesJson)

    for vehicleUID, vehicleProperties in pairs(decodedVehicles) do
        if vehicleProperties == true then
            print("Removing vehicle with UID: " .. vehicleUID .. " from the list")
            decodedVehicles[vehicleUID] = nil
        end
    end

    return decodedVehicles
end