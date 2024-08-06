function GetVehicleUID(vehicle)
    local plateText = GetVehicleNumberPlateText(vehicle)
    local plateIndex = GetVehicleNumberPlateTextIndex(vehicle)

    return plateIndex .. "-" .. plateText
end

function TrimVehiclesJson(vehiclesJson)
    local decodedVehicles = json.decode(vehiclesJson)

    for vehicleUID, vehicleProperties in pairs(decodedVehicles) do
        if vehicleProperties == true then
            decodedVehicles[vehicleUID] = nil
        end
    end

    return decodedVehicles
end

Citizen.CreateThread(function()
    while true do
        Wait(100)
        local playerList = {}

        for _, playerId in ipairs(GetPlayers()) do
            playerId = tonumber(playerId)
            local ped = GetPlayerPed(playerId)
            local coord = GetEntityCoords(ped)

            if DoesEntityExist(ped) and coord ~= nil then
                playerList[playerId] = coord
            end
        end

        TriggerClientEvent("CR.PV:Playerlist", -1, playerList)
    end
end)

exports("GetVehicleUID", GetVehicleUID)
