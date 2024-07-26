function GetVehicleProperties(vehicle)
    local colorPrimary, colorSecondary = GetVehicleColours(vehicle)
    local pearlescentColor, wheelColor = GetVehicleExtraColours(vehicle)
    local interiorColor                = GetVehicleInteriorColour(vehicle)

    local extras = {}

    for id = 0, 12 do
        if DoesExtraExist(vehicle, id) then
            local state = IsVehicleExtraTurnedOn(vehicle, id) == 1
            extras[tostring(id)] = state
        end
    end

    local props = {
        model             = GetEntityModel(vehicle),

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
