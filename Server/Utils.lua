function GetVehicleUID(vehicle)
    local plateText = GetVehicleNumberPlateText(vehicle)
    local plateIndex = GetVehicleNumberPlateTextIndex(vehicle)

    return plateIndex .. "-" .. plateText
end

exports("GetVehicleUID", GetVehicleUID)

function TrimVehiclesJson(vehiclesJson)
    --print("Trimming vehicle JSON data")
    local decodedVehicles = json.decode(vehiclesJson)

    for vehicleUID, vehicleProperties in pairs(decodedVehicles) do
        if vehicleProperties == true then
            --print("Removing vehicle with UID: " .. vehicleUID .. " from the list")
            decodedVehicles[vehicleUID] = nil
        end
    end

    return decodedVehicles
end

RegisterCommand("dvall", function()
    --print("Deleting all vehicles")
    for _, v in ipairs(GetAllVehicles()) do
        DeleteEntity(v)
        --print("Deleted vehicle with entity ID: " .. v)
    end
end, false)

RegisterCommand("dvallnr", function()
    --print("Deleting all vehicles without respawning")
    for _, v in ipairs(GetAllVehicles()) do
        DO_NOT_RESPAWN[v] = true
        DeleteEntity(v)
        --print("Deleted vehicle with entity ID: " .. v)
    end
end, false)

function GetRandomPlayerId()
    local players = {}

    for _, playerId in pairs(GetPlayers()) do
        players[#players + 1] = playerId
    end

    if #players == 0 then return nil end

    return players[math.random(1, #players)]
end
