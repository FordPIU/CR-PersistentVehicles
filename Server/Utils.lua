function GetVehicleUID(vehicle)
    local plateText = GetVehicleNumberPlateText(vehicle)
    local plateIndex = GetVehicleNumberPlateTextIndex(vehicle)

    print("Getting UID for vehicle with plate: " .. plateText .. " and plate index: " .. plateIndex)

    return plateIndex .. "-" .. plateText
end

exports("GetVehicleUID", GetVehicleUID)

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

RegisterCommand("dvall", function()
    print("Deleting all vehicles")
    for _, v in ipairs(GetGamePool("CVehicle")) do
        DeleteEntity(v)
        print("Deleted vehicle with entity ID: " .. v)
    end
end, false)
