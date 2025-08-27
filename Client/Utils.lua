--- Gets the matrix data (position, rotation vectors, heading) for a vehicle entity.
--- @param vehicle number The entity handle of the vehicle.
--- @return table A table containing matrix vectors, position, and heading.
function GetEntityMatrixTable(vehicle)
    local forward, right, up, _ = GetEntityMatrix(vehicle)
    return {
        vectors = { forward = forward, right = right, up = up },
        position = GetEntityCoords(vehicle),
        heading = GetEntityHeading(vehicle)
    }
end

--- Helper function to get vehicle color properties.
--- @param vehicle number The entity handle of the vehicle.
--- @return table A table containing color-related properties.
local function GetVehicleColorProperties(vehicle)
    local props = {}
    local colorPrimary, colorSecondary = GetVehicleColours(vehicle)
    local pearlescentColor, wheelColor = GetVehicleExtraColours(vehicle)

    props.color1 = colorPrimary
    props.color2 = colorSecondary
    props.pearlescentColor = pearlescentColor
    props.wheelColor = wheelColor
    props.interiorColor = GetVehicleInteriorColour(vehicle)

    -- RGB Colors (only add if custom)
    local r1, g1, b1 = GetVehicleCustomPrimaryColour(vehicle)
    if r1 ~= 0 or g1 ~= 0 or b1 ~= 0 then props.rgbcolor1 = { r1, g1, b1 } end
    local r2, g2, b2 = GetVehicleCustomSecondaryColour(vehicle)
    if r2 ~= 0 or g2 ~= 0 or b2 ~= 0 then props.rgbcolor2 = { r2, g2, b2 } end

    -- Neon (only add if enabled)
    local neonEnabled = {}
    local anyNeonEnabled = false
    for i = 0, 3 do
        neonEnabled[i + 1] = IsVehicleNeonLightEnabled(vehicle, i)
        if neonEnabled[i + 1] then anyNeonEnabled = true end
    end
    if anyNeonEnabled then
        props.neonEnabled = neonEnabled
        props.neonColor = table.pack(GetVehicleNeonLightsColour(vehicle))
    end

    -- Tyre Smoke Color (only add if custom)
    local sr, sg, sb = GetVehicleTyreSmokeColor(vehicle)
    if sr ~= 255 or sg ~= 255 or sb ~= 255 then props.tyreSmokeColor = { sr, sg, sb } end

    props.windowTint = GetVehicleWindowTint(vehicle)        -- -1 if none
    props.xenonColor = GetVehicleXenonLightsColour(vehicle) -- 255 if none (often part of modXenon)

    return props
end

--- Helper function to get vehicle modification properties.
--- @param vehicle number The entity handle of the vehicle.
--- @return table A table containing modification-related properties.
local function GetVehicleModProperties(vehicle)
    local props = {}
    props.wheels = GetVehicleWheelType(vehicle)
    props.modLivery = GetVehicleLivery(vehicle) -- -1 if none

    -- Extras
    local extras = {}
    local hasExtras = false
    for id = 0, 12 do
        if DoesExtraExist(vehicle, id) then
            extras[tostring(id)] = IsVehicleExtraTurnedOn(vehicle, id) == 1
            hasExtras = true
        end
    end
    if hasExtras then props.extras = extras end

    -- Mods (Standard and Toggle)
    local function addMod(modType, modValue)
        if modValue ~= -1 and modValue ~= 255 then props['mod' .. modType] = modValue end
    end

    -- Standard Mods (0-16, 23-48 excluding toggles)
    for i = 0, 16 do addMod(i, GetVehicleMod(vehicle, i)) end
    for i = 23, 46 do addMod(i, GetVehicleMod(vehicle, i)) end
    addMod(48, GetVehicleMod(vehicle, 48)) -- Livery mod slot

    -- Toggle Mods (Store only if true)
    if IsToggleModOn(vehicle, 18) then props.modTurbo = true end
    if IsToggleModOn(vehicle, 20) then props.modSmokeEnabled = true end
    if IsToggleModOn(vehicle, 22) then props.modXenon = true end

    -- Cosmetic Renaming (Mapping from index to name)
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
        [48] = "Livery"
    }
    for modIndex, modName in pairs(modNameMapping) do
        local propKey = 'mod' .. modIndex
        if props[propKey] ~= nil then
            props['mod' .. modName] = props[propKey]
            props[propKey] = nil -- Remove the indexed version
        end
    end
    -- Handle livery specifically if GetVehicleLivery was used and resulted in -1
    if props.modLivery == -1 then props.modLivery = nil end

    return props
end

--- Helper function to get vehicle state and damage properties.
--- @param vehicle number The entity handle of the vehicle.
--- @return table A table containing state and damage-related properties.
local function GetVehicleStateProperties(vehicle)
    local props = {}
    local _, lightsOn, _ = GetVehicleLightsState(vehicle)

    props.engineOn = GetIsVehicleEngineRunning(vehicle)
    props.lightsOn = lightsOn == 1
    props.sirenOn = IsVehicleSirenOn(vehicle)
    props.sirenAudioOn = IsVehicleSirenAudioOn(vehicle)
    props.bodyHealth = GetVehicleBodyHealth(vehicle)
    props.engineHealth = GetVehicleEngineHealth(vehicle)
    props.fuelLevel = GetVehicleFuelLevel(vehicle)
    props.dirtLevel = GetVehicleDirtLevel(vehicle)

    -- Tire Burst Status
    local tireBurst = {}
    local anyTireBurst = false
    for i = 0, 8 do                 -- Check common tire indices + spares
        if IsVehicleTyreBurst(vehicle, i, false) then
            tireBurst[i + 1] = true -- Lua tables are 1-based
            anyTireBurst = true
        end
    end
    if anyTireBurst then props.tireBurst = tireBurst end

    -- Window Status
    local windowStatus = {}
    local anyWindowBroken = false
    for i = 0, 7 do                    -- Check common window indices
        if not IsVehicleWindowIntact(vehicle, i) then
            windowStatus[i + 1] = true -- Lua tables are 1-based
            anyWindowBroken = true
        end
    end
    if anyWindowBroken then props.windowStatus = windowStatus end

    return props
end


--- Fetches various properties of a vehicle, organized into categories.
--- @param vehicle number The entity handle of the vehicle.
--- @return table A table containing the vehicle's properties.
function GetVehicleProperties(vehicle)
    local props = {
        model = GetEntityModel(vehicle),
        type = GetVehicleType(vehicle),
        matrix = GetEntityMatrixTable(vehicle), -- Position, rotation, heading
        plate = GetVehicleNumberPlateText(vehicle),
        plateIndex = GetVehicleNumberPlateTextIndex(vehicle)
    }

    -- Merge properties from helper functions
    for k, v in pairs(GetVehicleColorProperties(vehicle)) do props[k] = v end
    for k, v in pairs(GetVehicleModProperties(vehicle)) do props[k] = v end
    for k, v in pairs(GetVehicleStateProperties(vehicle)) do props[k] = v end

    -- Note: Custom data (like odometer) is managed server-side via exports

    return props
end

--- Helper function to apply color properties to a vehicle.
--- @param vehicle number The entity handle of the vehicle.
--- @param properties table The properties table containing color info.
local function ApplyVehicleColorProperties(vehicle, properties)
    -- RGB Colors take precedence
    if properties.rgbcolor1 then
        SetVehicleCustomPrimaryColour(vehicle, properties.rgbcolor1[1], properties.rgbcolor1[2], properties.rgbcolor1[3])
    elseif properties.color1 then
        local _, currentSecondary = GetVehicleColours(vehicle)
        SetVehicleColours(vehicle, properties.color1, properties.color2 or currentSecondary)
    elseif properties.color2 then -- Only secondary set (standard)
        local currentPrimary, _ = GetVehicleColours(vehicle)
        SetVehicleColours(vehicle, currentPrimary, properties.color2)
    end

    if properties.rgbcolor2 then
        SetVehicleCustomSecondaryColour(vehicle, properties.rgbcolor2[1], properties.rgbcolor2[2],
            properties.rgbcolor2[3])
    elseif not properties.rgbcolor1 and not properties.color1 and properties.color2 then -- Only secondary set (standard, ensure primary wasn't set)
        local currentPrimary, _ = GetVehicleColours(vehicle)
        SetVehicleColours(vehicle, currentPrimary, properties.color2)
    end

    -- Extras colors
    if properties.pearlescentColor or properties.wheelColor then
        local currentPearlescent, currentWheel = GetVehicleExtraColours(vehicle)
        SetVehicleExtraColours(vehicle, properties.pearlescentColor or currentPearlescent,
            properties.wheelColor or currentWheel)
    end

    if properties.interiorColor then SetVehicleInteriorColour(vehicle, properties.interiorColor) end
    if properties.windowTint then SetVehicleWindowTint(vehicle, properties.windowTint) end        -- Handles -1 correctly
    if properties.xenonColor then SetVehicleXenonLightsColour(vehicle, properties.xenonColor) end -- Handles 255 correctly

    -- Neon Lights
    if properties.neonEnabled then
        for i = 0, 3 do
            SetVehicleNeonLightEnabled(vehicle, i, properties.neonEnabled[i + 1] or false)
        end
        if properties.neonColor then
            SetVehicleNeonLightsColour(vehicle, properties.neonColor[1], properties.neonColor[2], properties.neonColor
                [3])
        end
    else -- Explicitly disable if not in properties
        for i = 0, 3 do SetVehicleNeonLightEnabled(vehicle, i, false) end
    end

    -- Tyre Smoke Color
    if properties.tyreSmokeColor then
        SetVehicleTyreSmokeColor(vehicle, properties.tyreSmokeColor[1], properties.tyreSmokeColor[2],
            properties.tyreSmokeColor[3])
        -- Ensure smoke mod is toggled on if color is set and mod wasn't explicitly false
        if properties.modSmokeEnabled ~= false then
            ToggleVehicleMod(vehicle, 20, true)
        end
    end
end

--- Helper function to apply modification properties to a vehicle.
--- Requires SetVehicleModKit(vehicle, 0) to be called beforehand if any mods are present.
--- @param vehicle number The entity handle of the vehicle.
--- @param properties table The properties table containing mod info.
local function ApplyVehicleModProperties(vehicle, properties)
    if properties.wheels then SetVehicleWheelType(vehicle, properties.wheels) end

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

    -- Apply standard mods by name
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
    if properties.modLivery then
        SetVehicleLivery(vehicle, properties.modLivery)
        -- Also set mod slot 48 if it wasn't set via the loop above and modLivery property exists
        if not properties.modLivery then -- Check if modLivery (index 48 named property) wasn't explicitly set
            SetVehicleMod(vehicle, 48, properties.modLivery, false)
        end
    end

    -- Extras (Toggle auto-repair only if extras are present)
    if properties.extras then
        SetVehicleAutoRepairDisabled(vehicle, false) -- ensure this is off for extras to set right
        for id, enabled in pairs(properties.extras) do
            SetVehicleExtra(vehicle, tonumber(id), not enabled)
        end
    end
end


--- Helper function to apply state and damage properties to a vehicle.
--- @param vehicle number The entity handle of the vehicle.
--- @param properties table The properties table containing state/damage info.
local function ApplyVehicleStateProperties(vehicle, properties)
    -- Health, Fuel, Dirt (Ensure they are numbers)
    if properties.bodyHealth then SetVehicleBodyHealth(vehicle, tonumber(properties.bodyHealth) + 0.0) end
    if properties.engineHealth then SetVehicleEngineHealth(vehicle, tonumber(properties.engineHealth) + 0.0) end
    if properties.fuelLevel then SetVehicleFuelLevel(vehicle, tonumber(properties.fuelLevel) + 0.0) end
    if properties.dirtLevel then SetVehicleDirtLevel(vehicle, tonumber(properties.dirtLevel) + 0.0) end

    -- Toggles
    if properties.lightsOn == true then SetVehicleLights(vehicle, 3) else SetVehicleLights(vehicle, 4) end    -- Explicitly turn off if false
    -- Note: Engine state requires careful handling, especially with keys/realistic start mods
    if properties.engineOn ~= nil then SetVehicleEngineOn(vehicle, properties.engineOn, true, false) end      -- `true` to instantly set, `false` to disable auto-start
    if properties.sirenOn ~= nil then SetVehicleSiren(vehicle, properties.sirenOn) end
    if properties.sirenAudioOn ~= nil then SetVehicleHasMutedSirens(vehicle, not properties.sirenAudioOn) end -- Muted = NOT sirenAudioOn

    -- Tire Burst
    if properties.tireBurst then
        for i = 0, 8 do
            if properties.tireBurst[i + 1] then                -- Key is index + 1
                SetVehicleTyreBurst(vehicle, i, false, 1000.0) -- Burst the tire
                -- else SetVehicleTyreFixed(vehicle, i) -- Optional: Fix tires not listed as burst
            end
        end
    end

    -- Window Status
    if properties.windowStatus then
        for i = 0, 7 do
            if properties.windowStatus[i + 1] then -- Key is index + 1
                SmashVehicleWindow(vehicle, i)
                -- else FixVehicleWindow(vehicle, i) -- Optional: Fix windows not listed as broken
            end
        end
    end
end


--- Applies a table of properties to a vehicle.
--- Organizes application into categories.
--- @param vehicle number The entity handle of the vehicle.
--- @param properties table The properties table (structure matching GetVehicleProperties output).
function SetVehicleProperties(vehicle, properties)
    local vehicleId = Entity(vehicle).state.pId

    if not properties or type(properties) ~= "table" then
        warn(string.format(
            "[CR-PersistentVehicles] SetVehicleProperties called with invalid properties for vehicle %d",
            vehicle,
            vehicleId or "N/A"))
        return
    end

    -- 1. Set Plate Info (Only if vehicleId is provided)
    if properties.plate and properties.plateIndex then
        SetVehicleNumberPlateText(vehicle, properties.plate)
        SetVehicleNumberPlateTextIndex(vehicle, properties.plateIndex)
    end

    -- 2. Set Position/Rotation (Matrix)
    if properties.matrix and properties.matrix.position and properties.matrix.vectors and properties.matrix.heading then
        local m = properties.matrix
        local v = m.vectors
        local p = m.position
        -- Ensure all vector components exist before setting
        if v.forward and v.right and v.up and p then
            SetEntityMatrix(vehicle,
                v.forward.x, v.forward.y, v.forward.z,
                v.right.x, v.right.y, v.right.z,
                v.up.x, v.up.y, v.up.z,
                p.x, p.y, p.z)
            SetEntityCoords(vehicle, p.x, p.y, p.z, false, false, false, true)
            SetEntityHeading(vehicle, m.heading)
        end
    else
        warn(string.format("[CR-PersistentVehicles] Missing matrix data for vehicle %d (ID: %s)", vehicle,
            vehicleId or "N/A"))
    end

    -- 3. Check if mods need to be applied to set ModKit
    local hasMods = false
    for key, _ in pairs(properties) do
        if string.sub(key, 1, 3) == "mod" or key == "extras" or key == "wheels" then
            hasMods = true
            break
        end
    end
    if hasMods then
        SetVehicleModKit(vehicle, 0)
    end

    -- 4. Apply Properties using Helper Functions
    ApplyVehicleColorProperties(vehicle, properties)
    if hasMods then -- Only apply mods if ModKit was set
        ApplyVehicleModProperties(vehicle, properties)
    end
    ApplyVehicleStateProperties(vehicle, properties)

    -- 5. Wait for mods to load IF mods were applied
    if hasMods then
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

    -- 6. Unfreeze after properties are set
    FreezeEntityPosition(vehicle, false)

    -- 7. Set state flag indicating properties are applied (client-side confirmation)
    return true
end

--- Draws 3D text at specified world coordinates.
--- @param x number World X coordinate.
--- @param y number World Y coordinate.
--- @param z number World Z coordinate.
--- @param text string The text to display.
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
