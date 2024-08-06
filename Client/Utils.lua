--[[
    I honestly never want to ever touch this file...
    What a ugly mess.
]]

local PlayerList = {}

function GetEntityMatrixTable(vehicle)
    local forward, right, up, pos = GetEntityMatrix(vehicle)

    return {
        vectors = {
            forward = forward,
            right = right,
            up = up,
        },
        position = pos,
        heading = GetEntityHeading(vehicle)
    }
end

function GetVehicleProperties(vehicle)
    local colorPrimary, colorSecondary = GetVehicleColours(vehicle)
    local pearlescentColor, wheelColor = GetVehicleExtraColours(vehicle)
    local interiorColor                = GetVehicleInteriorColour(vehicle)

    local extras                       = {}

    for id = 0, 12 do
        if DoesExtraExist(vehicle, id) then
            local state = IsVehicleExtraTurnedOn(vehicle, id) == 1
            extras[tostring(id)] = state
        end
    end

    local props = {
        model             = GetEntityModel(vehicle),
        type              = GetVehicleType(vehicle),
        matrix            = GetEntityMatrixTable(vehicle),

        sirenOn           = IsVehicleSirenOn(vehicle),
        sirenAudioOn      = IsVehicleSirenAudioOn(vehicle),

        plate             = GetVehicleNumberPlateText(vehicle),
        plateIndex        = GetVehicleNumberPlateTextIndex(vehicle),

        bodyHealth        = GetVehicleBodyHealth(vehicle),
        engineHealth      = GetVehicleEngineHealth(vehicle),

        fuelLevel         = GetVehicleFuelLevel(vehicle),
        dirtLevel         = GetVehicleDirtLevel(vehicle),
        color1            = colorPrimary,
        color2            = colorSecondary,

        rgbcolor1         = { GetVehicleCustomPrimaryColour(vehicle) },
        rgbcolor2         = { GetVehicleCustomSecondaryColour(vehicle) },

        interiorColor     = interiorColor,
        pearlescentColor  = pearlescentColor,
        wheelColor        = wheelColor,

        wheels            = GetVehicleWheelType(vehicle),
        windowTint        = GetVehicleWindowTint(vehicle),
        xenonColor        = GetVehicleXenonLightsColour(vehicle),

        neonEnabled       = {
            IsVehicleNeonLightEnabled(vehicle, 0),
            IsVehicleNeonLightEnabled(vehicle, 1),
            IsVehicleNeonLightEnabled(vehicle, 2),
            IsVehicleNeonLightEnabled(vehicle, 3)
        },

        neonColor         = table.pack(GetVehicleNeonLightsColour(vehicle)),
        extras            = extras,
        tyreSmokeColor    = table.pack(GetVehicleTyreSmokeColor(vehicle)),

        modSpoilers       = GetVehicleMod(vehicle, 0),
        modFrontBumper    = GetVehicleMod(vehicle, 1),
        modRearBumper     = GetVehicleMod(vehicle, 2),
        modSideSkirt      = GetVehicleMod(vehicle, 3),
        modExhaust        = GetVehicleMod(vehicle, 4),
        modFrame          = GetVehicleMod(vehicle, 5),
        modGrille         = GetVehicleMod(vehicle, 6),
        modHood           = GetVehicleMod(vehicle, 7),
        modFender         = GetVehicleMod(vehicle, 8),
        modRightFender    = GetVehicleMod(vehicle, 9),
        modRoof           = GetVehicleMod(vehicle, 10),

        modEngine         = GetVehicleMod(vehicle, 11),
        modBrakes         = GetVehicleMod(vehicle, 12),
        modTransmission   = GetVehicleMod(vehicle, 13),
        modHorns          = GetVehicleMod(vehicle, 14),
        modSuspension     = GetVehicleMod(vehicle, 15),
        modArmor          = GetVehicleMod(vehicle, 16),

        modTurbo          = IsToggleModOn(vehicle, 18),
        modSmokeEnabled   = IsToggleModOn(vehicle, 20),
        modXenon          = IsToggleModOn(vehicle, 22),

        modFrontWheels    = GetVehicleMod(vehicle, 23),
        modBackWheels     = GetVehicleMod(vehicle, 24),

        modPlateHolder    = GetVehicleMod(vehicle, 25),
        modVanityPlate    = GetVehicleMod(vehicle, 26),
        modTrimA          = GetVehicleMod(vehicle, 27),
        modOrnaments      = GetVehicleMod(vehicle, 28),
        modDashboard      = GetVehicleMod(vehicle, 29),
        modDial           = GetVehicleMod(vehicle, 30),
        modDoorSpeaker    = GetVehicleMod(vehicle, 31),
        modSeats          = GetVehicleMod(vehicle, 32),
        modSteeringWheel  = GetVehicleMod(vehicle, 33),
        modShifterLeavers = GetVehicleMod(vehicle, 34),
        modAPlate         = GetVehicleMod(vehicle, 35),
        modSpeakers       = GetVehicleMod(vehicle, 36),
        modTrunk          = GetVehicleMod(vehicle, 37),
        modHydrolic       = GetVehicleMod(vehicle, 38),
        modEngineBlock    = GetVehicleMod(vehicle, 39),
        modAirFilter      = GetVehicleMod(vehicle, 40),
        modStruts         = GetVehicleMod(vehicle, 41),
        modArchCover      = GetVehicleMod(vehicle, 42),
        modAerials        = GetVehicleMod(vehicle, 43),
        modTrimB          = GetVehicleMod(vehicle, 44),
        modTank           = GetVehicleMod(vehicle, 45),
        modWindows        = GetVehicleMod(vehicle, 46),
        modLivery         = GetVehicleLivery(vehicle)
    }

    for k, v in pairs(props) do
        if v == false or v == -1 then
            props[k] = nil
        end
    end

    return props
end

function SetVehicleProperties(vehicle, properties)
    local colorPrimary, colorSecondary = GetVehicleColours(vehicle)
    local pearlescentColor, wheelColor = GetVehicleExtraColours(vehicle)
    SetVehicleModKit(vehicle, 0)

    if properties.matrix then
        local vectors = properties.matrix.vectors
        local forward = vectors.forward
        local right = vectors.right
        local up = vectors.up
        local at = properties.matrix.position
        SetEntityMatrix(vehicle, forward.x, forward.y, forward.z, right.x, right.y, right.z, up.x, up.y, up.z, at.x, at
            .y, at.z)
        SetEntityHeading(vehicle, properties.matrix.heading)
    end
    if properties.sirenOn then SetVehicleSiren(vehicle, properties.sirenOn) end
    if properties.sirenAudioOn then SetVehicleHasMutedSirens(vehicle, not properties.sirenAudioOn) end
    if properties.plate then SetVehicleNumberPlateText(vehicle, properties.plate) end
    if properties.plateIndex then SetVehicleNumberPlateTextIndex(vehicle, properties.plateIndex) end
    if properties.bodyHealth then SetVehicleBodyHealth(vehicle, properties.bodyHealth + 0.0) end
    if properties.engineHealth then SetVehicleEngineHealth(vehicle, properties.engineHealth + 0.0) end
    if properties.fuelLevel then SetVehicleFuelLevel(vehicle, properties.fuelLevel + 0.0) end
    if properties.dirtLevel then SetVehicleDirtLevel(vehicle, properties.dirtLevel + 0.0) end
    if properties.color1 then SetVehicleColours(vehicle, properties.color1, colorSecondary) end
    if properties.color2 then SetVehicleColours(vehicle, properties.color1 or colorPrimary, properties.color2) end
    if properties.interiorColor then SetVehicleInteriorColour(vehicle, properties.interiorColor) end
    if properties.pearlescentColor then SetVehicleExtraColours(vehicle, properties.pearlescentColor, wheelColor) end
    if properties.wheelColor then
        SetVehicleExtraColours(vehicle, properties.pearlescentColor or pearlescentColor,
            properties.wheelColor)
    end
    if properties.wheels then SetVehicleWheelType(vehicle, properties.wheels) end
    if properties.windowTint then SetVehicleWindowTint(vehicle, properties.windowTint) end
    if properties.rgbcolor1 then
        SetVehicleCustomPrimaryColour(vehicle, properties.rgbcolor1[1], properties.rgbcolor1[2],
            properties.rgbcolor1[3])
    end
    if properties.rgbcolor2 then
        SetVehicleCustomSecondaryColour(vehicle, properties.rgbcolor2[1],
            properties.rgbcolor2[2], properties.rgbcolor2[3])
    end

    if properties.neonEnabled then
        SetVehicleNeonLightEnabled(vehicle, 0, properties.neonEnabled[1])
        SetVehicleNeonLightEnabled(vehicle, 1, properties.neonEnabled[2])
        SetVehicleNeonLightEnabled(vehicle, 2, properties.neonEnabled[3])
        SetVehicleNeonLightEnabled(vehicle, 3, properties.neonEnabled[4])
    end

    if properties.extras then
        SetVehicleAutoRepairDisabled(vehicle, false)

        for id, enabled in pairs(properties.extras) do
            if enabled then
                SetVehicleExtra(vehicle, tonumber(id), 0)
            else
                SetVehicleExtra(vehicle, tonumber(id), 1)
            end
        end

        SetVehicleAutoRepairDisabled(vehicle, true)
    end

    if properties.neonColor then
        SetVehicleNeonLightsColour(vehicle, properties.neonColor[1], properties.neonColor[2],
            properties.neonColor[3])
    end
    if properties.xenonColor then SetVehicleXenonLightsColour(vehicle, properties.xenonColor) end
    if properties.modSmokeEnabled then ToggleVehicleMod(vehicle, 20, true) end
    if properties.tyreSmokeColor then
        SetVehicleTyreSmokeColor(vehicle, properties.tyreSmokeColor[1],
            properties.tyreSmokeColor[2], properties.tyreSmokeColor[3])
    end
    if properties.modSpoilers then SetVehicleMod(vehicle, 0, properties.modSpoilers, false) end
    if properties.modFrontBumper then SetVehicleMod(vehicle, 1, properties.modFrontBumper, false) end
    if properties.modRearBumper then SetVehicleMod(vehicle, 2, properties.modRearBumper, false) end
    if properties.modSideSkirt then SetVehicleMod(vehicle, 3, properties.modSideSkirt, false) end
    if properties.modExhaust then SetVehicleMod(vehicle, 4, properties.modExhaust, false) end
    if properties.modFrame then SetVehicleMod(vehicle, 5, properties.modFrame, false) end
    if properties.modGrille then SetVehicleMod(vehicle, 6, properties.modGrille, false) end
    if properties.modHood then SetVehicleMod(vehicle, 7, properties.modHood, false) end
    if properties.modFender then SetVehicleMod(vehicle, 8, properties.modFender, false) end
    if properties.modRightFender then SetVehicleMod(vehicle, 9, properties.modRightFender, false) end
    if properties.modRoof then SetVehicleMod(vehicle, 10, properties.modRoof, false) end
    if properties.modEngine then SetVehicleMod(vehicle, 11, properties.modEngine, false) end
    if properties.modBrakes then SetVehicleMod(vehicle, 12, properties.modBrakes, false) end
    if properties.modTransmission then SetVehicleMod(vehicle, 13, properties.modTransmission, false) end
    if properties.modHorns then SetVehicleMod(vehicle, 14, properties.modHorns, false) end
    if properties.modSuspension then SetVehicleMod(vehicle, 15, properties.modSuspension, false) end
    if properties.modArmor then SetVehicleMod(vehicle, 16, properties.modArmor, false) end
    if properties.modTurbo then ToggleVehicleMod(vehicle, 18, properties.modTurbo) end
    if properties.modXenon then ToggleVehicleMod(vehicle, 22, properties.modXenon) end
    if properties.modFrontWheels then SetVehicleMod(vehicle, 23, properties.modFrontWheels, false) end
    if properties.modBackWheels then SetVehicleMod(vehicle, 24, properties.modBackWheels, false) end
    if properties.modPlateHolder then SetVehicleMod(vehicle, 25, properties.modPlateHolder, false) end
    if properties.modVanityPlate then SetVehicleMod(vehicle, 26, properties.modVanityPlate, false) end
    if properties.modTrimA then SetVehicleMod(vehicle, 27, properties.modTrimA, false) end
    if properties.modOrnaments then SetVehicleMod(vehicle, 28, properties.modOrnaments, false) end
    if properties.modDashboard then SetVehicleMod(vehicle, 29, properties.modDashboard, false) end
    if properties.modDial then SetVehicleMod(vehicle, 30, properties.modDial, false) end
    if properties.modDoorSpeaker then SetVehicleMod(vehicle, 31, properties.modDoorSpeaker, false) end
    if properties.modSeats then SetVehicleMod(vehicle, 32, properties.modSeats, false) end
    if properties.modSteeringWheel then SetVehicleMod(vehicle, 33, properties.modSteeringWheel, false) end
    if properties.modShifterLeavers then SetVehicleMod(vehicle, 34, properties.modShifterLeavers, false) end
    if properties.modAPlate then SetVehicleMod(vehicle, 35, properties.modAPlate, false) end
    if properties.modSpeakers then SetVehicleMod(vehicle, 36, properties.modSpeakers, false) end
    if properties.modTrunk then SetVehicleMod(vehicle, 37, properties.modTrunk, false) end
    if properties.modHydrolic then SetVehicleMod(vehicle, 38, properties.modHydrolic, false) end
    if properties.modEngineBlock then SetVehicleMod(vehicle, 39, properties.modEngineBlock, false) end
    if properties.modAirFilter then SetVehicleMod(vehicle, 40, properties.modAirFilter, false) end
    if properties.modStruts then SetVehicleMod(vehicle, 41, properties.modStruts, false) end
    if properties.modArchCover then SetVehicleMod(vehicle, 42, properties.modArchCover, false) end
    if properties.modAerials then SetVehicleMod(vehicle, 43, properties.modAerials, false) end
    if properties.modTrimB then SetVehicleMod(vehicle, 44, properties.modTrimB, false) end
    if properties.modTank then SetVehicleMod(vehicle, 45, properties.modTank, false) end
    if properties.modWindows then SetVehicleMod(vehicle, 46, properties.modWindows, false) end

    if properties.modLivery then
        SetVehicleMod(vehicle, 48, properties.modLivery, false)
        SetVehicleLivery(vehicle, properties.modLivery)
    end

    while not IsVehicleModLoadDone(vehicle) do
        Wait(0)
    end
end

function GetVehicleUID(vehicle)
    local plateText = GetVehicleNumberPlateText(vehicle)
    local plateIndex = GetVehicleNumberPlateTextIndex(vehicle)

    return plateIndex .. "-" .. plateText
end

function GetPlayerClosestToEntity(entity)
    local closestPlayer = nil
    local closestDistance = -1
    local entityCoords = GetEntityCoords(entity)

    for playerId, playerCoords in pairs(PlayerList) do
        local distance = #(entityCoords - playerCoords)

        if closestDistance == -1 or distance < closestDistance then
            closestPlayer = playerId
            closestDistance = distance
        end
    end

    return closestPlayer
end

function GetPlayerClosestToCoord(coord)
    local closestPlayer = nil
    local closestDistance = -1
    local entityCoords = coord

    for playerId, playerCoords in pairs(PlayerList) do
        local distance = #(entityCoords - playerCoords)

        if closestDistance == -1 or distance < closestDistance then
            closestPlayer = playerId
            closestDistance = distance
        end
    end

    return closestPlayer
end

function GetVehicleFromVehicleId(vehicleId)
    for _, v in ipairs(GetGamePool("CVehicle")) do
        if GetVehicleUID(v) == vehicleId then return v end
    end
end

function DoesPersistentVehicleExists(vehicleId)
    for _, v in ipairs(GetGamePool("CVehicle")) do
        if GetVehicleUID(v) == vehicleId then return true end
    end

    return false
end

function ForgetVehicle(vehicle)
    if GetPlayerClosestToEntity(vehicle) ~= PlayerId() then return false end

    local vehicleUID = GetVehicleUID(vehicle)

    repeat
        Wait(10)
        NetworkRequestControlOfEntity(vehicle)
    until NetworkHasControlOfEntity(vehicle)

    Print("Has control")

    SetVehicleSpawningPaused(vehicleUID, true)
    TriggerServerEvent("CR.PV:Forget", VehToNet(vehicle))
    Print("Vehicle marked for forget")

    repeat
        Wait(0)
        print(type(GetVehicles()[vehicleUID]))
    until type(GetVehicles()[vehicleUID]) ~= "table"

    Print("Vehicle data now of type " .. type(GetVehicles()[vehicleUID]) ~= "table")
    DeleteEntity(vehicle)
    SetVehicleSpawningPaused(vehicleUID, false)
    Print("Vehicle deleted")

    return true
end

RegisterNetEvent("CR.PV:Playerlist", function(playerList)
    PlayerList = playerList
end)

exports("GetVehicleUID", GetVehicleUID)
exports("ForgetVehicle", ForgetVehicle)
