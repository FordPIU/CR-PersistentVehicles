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

--- Fetches various properties of a vehicle.
--- @param vehicle number The entity handle of the vehicle.
--- @return table A table containing the vehicle's properties.
function GetVehicleProperties(vehicle)
    -- Pre-fetch values used multiple times or needed for checks
    local colorPrimary, colorSecondary = GetVehicleColours(vehicle)
    local pearlescentColor, wheelColor = GetVehicleExtraColours(vehicle)
    local _, lightsOn, _ = GetVehicleLightsState(vehicle)


    -- Initialize the properties table
    local props = {
        model = GetEntityModel(vehicle),
        type = GetVehicleType(vehicle),
        matrix = GetEntityMatrixTable(vehicle), -- Gets position and heading
        engineOn = GetIsVehicleEngineRunning(vehicle),
        lightsOn = lightsOn == 1,
        sirenOn = IsVehicleSirenOn(vehicle),           -- Keep even if false
        sirenAudioOn = IsVehicleSirenAudioOn(vehicle), -- Keep even if false
        bodyHealth = GetVehicleBodyHealth(vehicle),
        engineHealth = GetVehicleEngineHealth(vehicle),
        fuelLevel = GetVehicleFuelLevel(vehicle),
        dirtLevel = GetVehicleDirtLevel(vehicle),
        color1 = colorPrimary,
        color2 = colorSecondary,
        interiorColor = GetVehicleInteriorColour(vehicle), -- Fetch directly
        pearlescentColor = pearlescentColor,
        wheelColor = wheelColor,
        wheels = GetVehicleWheelType(vehicle),
        windowTint = GetVehicleWindowTint(vehicle),        -- Returns -1 if none, handle in setter or keep -1
        xenonColor = GetVehicleXenonLightsColour(vehicle), -- Returns 255 if none, handle in setter or keep 255
        modLivery = GetVehicleLivery(vehicle)              -- Returns -1 if none
    }

    -- RGB Colors (only add if custom)
    local r1, g1, b1 = GetVehicleCustomPrimaryColour(vehicle)
    if r1 ~= 0 or g1 ~= 0 or b1 ~= 0 then -- Check if different from default black
        props.rgbcolor1 = { r1, g1, b1 }
    end
    local r2, g2, b2 = GetVehicleCustomSecondaryColour(vehicle)
    if r2 ~= 0 or g2 ~= 0 or b2 ~= 0 then -- Check if different from default black
        props.rgbcolor2 = { r2, g2, b2 }
    end

    -- Neon Enabled (Use a loop)
    local neonEnabled = {}
    local anyNeonEnabled = false
    for i = 0, 3 do
        neonEnabled[i + 1] = IsVehicleNeonLightEnabled(vehicle, i)
        if neonEnabled[i + 1] then anyNeonEnabled = true end
    end
    if anyNeonEnabled then -- Only store if at least one is enabled
        props.neonEnabled = neonEnabled
        -- Only get neon color if neon is enabled
        props.neonColor = table.pack(GetVehicleNeonLightsColour(vehicle))
    end

    -- Tire Burst Status (Use a loop)
    local tireBurst = {}
    local anyTireBurst = false
    for i = 0, 8 do -- Check common tire indices
        if IsVehicleTyreBurst(vehicle, i, false) then
            -- Store index + 1 as key for Lua table (1-based)
            -- Store true to indicate burst state
            tireBurst[i + 1] = true
            anyTireBurst = true
        end
    end
    if anyTireBurst then
        props.tireBurst = tireBurst -- Only store the table if any tire is burst
    end

    -- Window Status (Use a loop, store broken windows)
    local windowStatus = {}
    local anyWindowBroken = false
    for i = 0, 7 do -- Check common window indices
        if not IsVehicleWindowIntact(vehicle, i) then
            -- Store index + 1 as key for Lua table (1-based)
            -- Store true to indicate broken state (since we check !IsVehicleWindowIntact)
            windowStatus[i + 1] = true
            anyWindowBroken = true
        end
    end
    if anyWindowBroken then
        props.windowStatus = windowStatus -- Store only if any window is broken
    end

    -- Extras (Use a loop)
    local extras = {}
    local hasExtras = false
    for id = 0, 12 do
        if DoesExtraExist(vehicle, id) then
            -- Store extra state directly (true if on, false if off)
            extras[tostring(id)] = IsVehicleExtraTurnedOn(vehicle, id) == 1
            hasExtras = true
        end
    end
    if hasExtras then
        props.extras = extras
    end

    -- Tyre Smoke Color (only add if custom)
    local sr, sg, sb = GetVehicleTyreSmokeColor(vehicle)
    if sr ~= 255 or sg ~= 255 or sb ~= 255 then -- Check if different from default white
        props.tyreSmokeColor = { sr, sg, sb }
    end

    -- Mods (Use loops and check for -1)
    local function addMod(modType, modValue)
        if modValue ~= -1 and modValue ~= 255 then -- 255 often indicates 'stock' for toggles like Xenon
            props['mod' .. modType] = modValue
        end
    end

    -- Standard Mods (0-16, 23-48 excluding toggles)
    for i = 0, 16 do addMod(i, GetVehicleMod(vehicle, i)) end
    for i = 23, 46 do addMod(i, GetVehicleMod(vehicle, i)) end -- Corrected upper limit
    addMod(48, GetVehicleMod(vehicle, 48))                     -- Livery mod slot

    -- Toggle Mods (18, 20, 22) - Store only if 'true'
    if IsToggleModOn(vehicle, 18) then props.modTurbo = true end
    if IsToggleModOn(vehicle, 20) then props.modSmokeEnabled = true end
    if IsToggleModOn(vehicle, 22) then props.modXenon = true end -- Note: GetVehicleMod(veh, 22) also works

    -- Rename mods for clarity (matches your original names) - This is cosmetic mapping
    local modNameMapping = {
        [0] = "Spoilers",
        [1] = "FrontBumper",
        [2] = "RearBumper",
        [3] = "SideSkirt",
        [4] = "Exhaust",
        [5] = "Frame",
        [6] = "Grille",
        [7] = "Hood",
        [8] = "Fender",
        [9] = "RightFender",
        [10] = "Roof",
        [11] = "Engine",
        [12] = "Brakes",
        [13] = "Transmission",
        [14] = "Horns",
        [15] = "Suspension",
        [16] = "Armor",
        [23] = "FrontWheels",
        [24] = "BackWheels",
        [25] = "PlateHolder",
        [26] = "VanityPlate",
        [27] = "TrimA",
        [28] = "Ornaments",
        [29] = "Dashboard",
        [30] = "Dial",
        [31] = "DoorSpeaker",
        [32] = "Seats",
        [33] = "SteeringWheel",
        [34] = "ShifterLeavers",
        [35] = "APlate",
        [36] = "Speakers",
        [37] = "Trunk",
        [38] = "Hydrolic",
        [39] = "EngineBlock",
        [40] = "AirFilter",
        [41] = "Struts",
        [42] = "ArchCover",
        [43] = "Aerials",
        [44] = "TrimB",
        [45] = "Tank",
        [46] = "Windows",
        [48] =
        "Livery" -- Note: Livery is often GetVehicleLivery, but mod slot 48 exists
    }

    -- Apply the cosmetic names
    for modIndex, modName in pairs(modNameMapping) do
        local propKey = 'mod' .. modIndex
        if props[propKey] ~= nil then
            props['mod' .. modName] = props[propKey]
            props[propKey] = nil -- Remove the indexed version
        end
    end
    -- Handle livery specifically if GetVehicleLivery was used
    if props.modLivery == -1 then props.modLivery = nil end


    -- No need for the final loop to remove false/-1, as we avoided adding them.

    return props
end

--- Applies a table of properties to a vehicle.
--- @param vehicle number The entity handle of the vehicle.
--- @param properties table The properties table (structure matching GetVehicleProperties output).
--- @param vehicleId string|nil The persistent ID of the vehicle (used for plate info).
function SetVehicleProperties(vehicle, properties, vehicleId)
    -- Only set mod kit if mods are actually present in the properties
    local hasMods = false
    for key, _ in pairs(properties) do
        if string.sub(key, 1, 3) == "mod" then
            hasMods = true
            break
        end
    end
    if hasMods then
        SetVehicleModKit(vehicle, 0)
    end

    -- Set Plate Info (Only if vehicleId is provided)
    if vehicleId then
        local plateIndex, plateText = GetPlateInfoByVehicleId(vehicleId)
        -- Provide defaults if lookup failed
        plateIndex = plateIndex and tonumber(plateIndex) or 0
        plateText = plateText or ""
        SetVehicleNumberPlateTextIndex(vehicle, plateIndex)
        SetVehicleNumberPlateText(vehicle, plateText)
    end

    -- Basic Properties
    if properties.matrix then
        local vectors = properties.matrix -- Use directly
        local pos = vectors.position
        -- Check if all components exist before setting
        if vectors.forward and vectors.right and vectors.up and pos then
            SetEntityMatrix(vehicle,
                vectors.forward.x, vectors.forward.y, vectors.forward.z,
                vectors.right.x, vectors.right.y, vectors.right.z,
                vectors.up.x, vectors.up.y, vectors.up.z,
                pos.x, pos.y, pos.z,
                false, false, false, false) -- Added missing arguments for SetEntityMatrix
            SetEntityHeading(vehicle, vectors.heading)
        end
    end

    -- Use elseif where appropriate if only one native should handle a property group
    if properties.rgbcolor1 then
        SetVehicleCustomPrimaryColour(vehicle, properties.rgbcolor1[1], properties.rgbcolor1[2], properties.rgbcolor1[3])
        -- Only set standard color if RGB is not set
    elseif properties.color1 then
        local _, currentSecondary = GetVehicleColours(vehicle) -- Get current secondary if needed
        SetVehicleColours(vehicle, properties.color1, properties.color2 or currentSecondary)
        -- Only set secondary if primary wasn't set (standard or RGB)
    elseif properties.color2 then
        local currentPrimary, _ = GetVehicleColours(vehicle)
        SetVehicleColours(vehicle, currentPrimary, properties.color2)
    end

    if properties.rgbcolor2 then
        SetVehicleCustomSecondaryColour(vehicle, properties.rgbcolor2[1], properties.rgbcolor2[2],
            properties.rgbcolor2[3])
        -- Only set standard secondary if RGB secondary not set AND primary wasn't handled above
    elseif not properties.rgbcolor1 and not properties.color1 and properties.color2 then
        local currentPrimary, _ = GetVehicleColours(vehicle)
        SetVehicleColours(vehicle, currentPrimary, properties.color2)
    end

    -- Extras colors need current values if only one is being set
    if properties.pearlescentColor or properties.wheelColor then
        local currentPearlescent, currentWheel = GetVehicleExtraColours(vehicle)
        SetVehicleExtraColours(vehicle, properties.pearlescentColor or currentPearlescent,
            properties.wheelColor or currentWheel)
    end

    if properties.interiorColor then SetVehicleInteriorColour(vehicle, properties.interiorColor) end

    -- Health, Fuel, Dirt (Ensure they are numbers)
    if properties.bodyHealth then SetVehicleBodyHealth(vehicle, tonumber(properties.bodyHealth) + 0.0) end
    if properties.engineHealth then SetVehicleEngineHealth(vehicle, tonumber(properties.engineHealth) + 0.0) end
    if properties.fuelLevel then SetVehicleFuelLevel(vehicle, tonumber(properties.fuelLevel) + 0.0) end
    if properties.dirtLevel then SetVehicleDirtLevel(vehicle, tonumber(properties.dirtLevel) + 0.0) end

    -- Toggles & Simple Setters
    if properties.lightsOn then SetVehicleLights(vehicle, 2) end
    if properties.engineOn ~= nil then SetVehicleEngineOn(vehicle, properties.engineOn, true, false) end      -- `true` to instantly set, `false` to disable auto-start
    if properties.sirenOn ~= nil then SetVehicleSiren(vehicle, properties.sirenOn) end
    if properties.sirenAudioOn ~= nil then SetVehicleHasMutedSirens(vehicle, not properties.sirenAudioOn) end -- Corrected logic
    if properties.wheels then SetVehicleWheelType(vehicle, properties.wheels) end
    if properties.windowTint then SetVehicleWindowTint(vehicle, properties.windowTint) end                    -- Handles -1 correctly
    if properties.xenonColor then SetVehicleXenonLightsColour(vehicle, properties.xenonColor) end             -- Handles 255 correctly

    -- Neon Lights (Enable/Disable and Color)
    if properties.neonEnabled then
        for i = 0, 3 do
            -- Enable neon only if the corresponding index is true in the properties table
            SetVehicleNeonLightEnabled(vehicle, i, properties.neonEnabled[i + 1] or false)
        end
        -- Only set color if neon was potentially enabled and color exists
        if properties.neonColor then
            SetVehicleNeonLightsColour(vehicle, properties.neonColor[1], properties.neonColor[2], properties.neonColor
                [3])
        end
    else -- If neonEnabled is not in properties, explicitly disable all
        for i = 0, 3 do
            SetVehicleNeonLightEnabled(vehicle, i, false)
        end
    end


    -- Tire Burst (Use loop)
    if properties.tireBurst then
        for i = 0, 8 do
            -- Check if the key (index + 1) exists and is true
            if properties.tireBurst[i + 1] then
                SetVehicleTyreBurst(vehicle, i, false, 1000.0) -- Burst the tire
                -- Optional: Fix tires that are not listed as burst in properties?
                -- else
                --    SetVehicleTyreFixed(vehicle, i)
            end
        end
    end

    -- Window Status (Use loop)
    if properties.windowStatus then
        for i = 0, 7 do
            -- Check if the key (index + 1) exists and is true (meaning broken)
            if properties.windowStatus[i + 1] then
                SmashVehicleWindow(vehicle, i)
                -- Optional: Fix windows that are not listed as broken?
                -- else
                --     FixVehicleWindow(vehicle, i)
            end
        end
    end

    -- Extras (Toggle auto-repair only if extras are present)
    if properties.extras then
        SetVehicleAutoRepairDisabled(vehicle, false) -- Disable auto repair before setting extras
        for idStr, enabled in pairs(properties.extras) do
            local idNum = tonumber(idStr)
            if idNum then                                           -- Ensure conversion worked
                SetVehicleExtra(vehicle, idNum, enabled and 0 or 1) -- Set extra state (0 = on, 1 = off)
            end
        end
        SetVehicleAutoRepairDisabled(vehicle, true) -- Re-enable auto repair after setting extras
    end

    -- Tyre Smoke Color
    if properties.tyreSmokeColor then
        SetVehicleTyreSmokeColor(vehicle, properties.tyreSmokeColor[1], properties.tyreSmokeColor[2],
            properties.tyreSmokeColor[3])
        -- Ensure smoke is toggled on if color is set (common expectation)
        if not properties.modSmokeEnabled then -- Check if modSmokeEnabled wasn't explicitly set to false
            ToggleVehicleMod(vehicle, 20, true)
        end
    end

    -- Mods (Apply using the cosmetic names from GetVehicleProperties)
    -- Reverse mapping from cosmetic name back to index
    local modIndexMapping = {
        Spoilers = 0,
        FrontBumper = 1,
        RearBumper = 2,
        SideSkirt = 3,
        Exhaust = 4,
        Frame = 5,
        Grille = 6,
        Hood = 7,
        Fender = 8,
        RightFender = 9,
        Roof = 10,
        Engine = 11,
        Brakes = 12,
        Transmission = 13,
        Horns = 14,
        Suspension = 15,
        Armor = 16,
        FrontWheels = 23,
        BackWheels = 24,
        PlateHolder = 25,
        VanityPlate = 26,
        TrimA = 27,
        Ornaments = 28,
        Dashboard = 29,
        Dial = 30,
        DoorSpeaker = 31,
        Seats = 32,
        SteeringWheel = 33,
        ShifterLeavers = 34,
        APlate = 35,
        Speakers = 36,
        Trunk = 37,
        Hydrolic = 38,
        EngineBlock = 39,
        AirFilter = 40,
        Struts = 41,
        ArchCover = 42,
        Aerials = 43,
        TrimB = 44,
        Tank = 45,
        Windows = 46,
        Livery = 48 -- Mod Slot 48 for livery mod
    }

    -- Apply standard mods
    for modName, modIndex in pairs(modIndexMapping) do
        local propKey = 'mod' .. modName
        if properties[propKey] ~= nil then
            SetVehicleMod(vehicle, modIndex, properties[propKey], false)
        end
    end

    -- Apply toggle mods (ensure value is boolean true)
    if properties.modTurbo == true then ToggleVehicleMod(vehicle, 18, true) end
    if properties.modSmokeEnabled == true then ToggleVehicleMod(vehicle, 20, true) end
    if properties.modXenon == true then ToggleVehicleMod(vehicle, 22, true) end

    -- Apply Livery (using GetVehicleLivery value if modLivery was used)
    -- Note: Mod slot 48 also exists, applying both might be needed depending on vehicle/setup
    if properties.modLivery then
        SetVehicleLivery(vehicle, properties.modLivery)
        -- Also set mod slot 48 if it wasn't set via the loop above
        if not properties.modLivery then -- Check if modLivery (index 48) wasn't explicitly set
            SetVehicleMod(vehicle, 48, properties.modLivery, false)
        end
    end


    -- Wait for mods to load IF mods were applied
    if hasMods then
        -- Consider adding a timeout to prevent infinite loops if mods never load
        local timeout = GetGameTimer() + 5000 -- 5 second timeout
        while not IsVehicleModLoadDone(vehicle) do
            Wait(0)
            if GetGameTimer() > timeout then
                warn(string.format("[CR-PersistentVehicles] Timeout waiting for mods to load on vehicle %d (ID: %s)",
                    vehicle, vehicleId or "N/A"))
                break
            end
        end
    end
end

--[[
    Parses a vehicle UID string (expected format: model-plateIndex-plateText)
    to extract the plate index and plate text components.

    @param vehicleUID string: The unique identifier string for the vehicle.
                           Example: "adder-0-MYPLATE"
    @return string|nil: The plate index (as a string).
    @return string|nil: The plate text.
                       Returns nil, nil if the input string is invalid or
                       does not match the expected 3-part format.
]]
function GetPlateInfoByVehicleId(vehicleUID)
    -- 1. Input Validation: Ensure we have a non-empty string.
    if type(vehicleUID) ~= "string" or vehicleUID == "" then
        -- warn(string.format("GetPlateInfoByVehicleUID: Invalid input type or empty string: %s", type(vehicleUID)))
        return nil, nil
    end

    local parts = {}
    -- 2. Split the string: Use string.gmatch to split by the hyphen delimiter.
    --    The pattern "([^%-]+)" captures sequences of one or more characters that are NOT hyphens.
    for part in string.gmatch(vehicleUID, "([^%-]+)") do
        table.insert(parts, part)
    end

    -- 3. Validate the result: Check if we got exactly 3 parts.
    if #parts == 3 then
        -- The new format is model-plateIndex-plateText
        -- So, plateIndex is the 2nd part, and plateText is the 3rd part.
        local plateIndex = parts[2]
        local plateText = parts[3]
        return plateIndex, plateText
    else
        -- warn(string.format("GetPlateInfoByVehicleUID: Unexpected format for UID '%s'. Expected 3 parts, found %d.", vehicleUID, #parts))
        -- Return nil, nil if the format is incorrect.
        return nil, nil
    end
end

function GetVehicleUID(vehicle)
    local vehicleModel = GetEntityModel(vehicle)
    local plateText = GetVehicleNumberPlateText(vehicle)
    local plateIndex = GetVehicleNumberPlateTextIndex(vehicle)

    return vehicleModel .. "-" .. plateIndex .. "-" .. plateText
end

exports("GetVehicleUID", GetVehicleUID)

function DrawText3D(x, y, z, text)
    SetDrawOrigin(x, y, z, 0)
    SetTextScale(0.35, 0.35)
    SetTextFont(4)
    SetTextProportional(1)
    SetTextColour(255, 255, 255, 215)
    SetTextEntry("STRING")
    SetTextCentre(1)
    AddTextComponentString(text)
    DrawText(0.0, 0.0)
    ClearDrawOrigin()
end
