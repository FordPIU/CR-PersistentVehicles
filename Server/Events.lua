--[[
    Handles server-side events related to resource lifecycle,
    network communication for properties, and entity creation/deletion.
]]

--[[--------------------------------------------------------------------------
    Resource Lifecycle Events
--------------------------------------------------------------------------]]

--- Handles the start of this resource. Loads vehicle data.
AddEventHandler("onResourceStart", function(resourceName)
    if resourceName == GetCurrentResourceName() then
        print(string.format("[%s] Resource starting, loading data...", resourceName))
        -- Ensure Manager.lua functions are loaded before calling LoadVehicleData
        -- This usually happens automatically based on fxmanifest load order
        LoadVehicleData(resourceName)
    end
end)

--- Handles the stop of this resource. Saves vehicle data.
AddEventHandler("onResourceStop", function(resourceName)
    if resourceName == GetCurrentResourceName() then
        print(string.format("[%s] Resource stopping, saving data...", resourceName))
        SaveVehicleData(resourceName) -- Attempt a final save
    end
end)


--[[--------------------------------------------------------------------------
    Network Events from Client
--------------------------------------------------------------------------]]

--- Handles confirmation from the client that properties have been applied to a vehicle.
--- Sets the 'nProperties' state bag flag to false.
--- @param vehNets table A table where keys are the network IDs of vehicles whose properties were set.
RegisterNetEvent("CR.PV:PropertiesSet", function(vehNets)
    -- This event confirms the client has finished applying the initial properties
    -- sent via the state bag during SpawnVehicle.
    for vehNet, _ in pairs(vehNets) do
        local vehicle = NetworkGetEntityFromNetworkId(vehNet)
        if DoesEntityExist(vehicle) then
            local state = Entity(vehicle).state
            if state.isPersistent then    -- Check if it's still considered persistent
                state.nProperties = false -- Mark properties as applied
                -- print(string.format("[%s] Confirmed properties set for vehicle NetID %d (UID: %s)", GetCurrentResourceName(), vehNet, state.pId or "N/A"))
            end
            -- else warn(string.format("[%s] CR.PV:PropertiesSet: Received confirmation for non-existent NetID %d", GetCurrentResourceName(), vehNet))
        end
    end
end)

--- Handles property updates sent from the client (e.g., after modifications, damage).
--- Calls UpdateVehicle for each and triggers a single SaveVehicleData after processing the batch.
--- Optimized to reduce save frequency and server load.
--- @param vehNets table A table where keys are vehicle network IDs and values are the property tables.
RegisterNetEvent("CR.PV:PropertiesUpdate", function(vehNets)
    local vehiclesToUpdate = {} -- Collect vehicles to update

    -- Quickly gather data from the network event
    for vehNet, properties in pairs(vehNets) do
        local vehicle = NetworkGetEntityFromNetworkId(vehNet)
        if DoesEntityExist(vehicle) then
            -- Store entity and properties for processing after the loop
            -- Ensure properties is actually a table before adding
            if type(properties) == "table" then
                table.insert(vehiclesToUpdate, { entity = vehicle, props = properties })
            else
                local uid = Entity(vehicle)?.state?.pId or GetVehicleUID(vehicle) or "N/A"
                warn(string.format(
                "[%s] CR.PV:PropertiesUpdate: Received invalid properties type (%s) for NetID %d (UID: %s)",
                    GetCurrentResourceName(), type(properties), vehNet, uid))
            end
            -- else warn(string.format("[%s] CR.PV:PropertiesUpdate: Received update for non-existent NetID %d", GetCurrentResourceName(), vehNet))
        end
    end

    if #vehiclesToUpdate == 0 then return end -- No valid updates received

    -- Process updates in a separate thread to avoid blocking network event handler
    -- and allow yielding during processing.
    Citizen.CreateThread(function()
        local updatedCount = 0
        print(string.format("[%s] Processing %d vehicle property updates...", GetCurrentResourceName(), #
        vehiclesToUpdate))
        for _, data in ipairs(vehiclesToUpdate) do
            -- Double check entity existence before updating
            if DoesEntityExist(data.entity) then
                UpdateVehicle(data.entity, data.props)  -- UpdateVehicle now only marks dataNeedsSaving = true
                updatedCount = updatedCount + 1
                -- Yield periodically if processing a large batch
                if updatedCount % (Config.UpdateYieldRate or 20) == 0 then  -- Yield every 20 updates by default
                    Wait(0)
                end
            end
        end

        -- Save *once* after processing all updates from this event batch IF any updates occurred
        if updatedCount > 0 then
            SaveVehicleData(GetCurrentResourceName()) -- SaveVehicleData checks dataNeedsSaving flag internally
            print(string.format("[%s] Finished processing %d updates.", GetCurrentResourceName(), updatedCount))
        end
    end)
end)


--- Handles request from the client to register a newly created/found vehicle as persistent.
--- @param vehNet number The network ID of the vehicle to register.
RegisterNetEvent("CR.PV:NewVehicle", function(vehNet)
    local vehicle = NetworkGetEntityFromNetworkId(vehNet)
    if DoesEntityExist(vehicle) then
        -- print(string.format("[%s] Received request to register new vehicle NetID %d", GetCurrentResourceName(), vehNet))
        NewVehicle(vehicle)
    else
        warn(string.format("[%s] CR.PV:NewVehicle: Received request for non-existent NetID %d", GetCurrentResourceName(),
            vehNet))
    end
end)

--- Handles request from the client to forget (remove persistence) for a vehicle.
--- @param vehNet number The network ID of the vehicle to forget.
RegisterNetEvent("CR.PV:ForgetVehicle", function(vehNet)
    local vehicle = NetworkGetEntityFromNetworkId(vehNet)
    if DoesEntityExist(vehicle) then
        local uid = Entity(vehicle)?.state?.pId or GetVehicleUID(vehicle) or "N/A"
        print(string.format("[%s] Received request to forget vehicle NetID %d (UID: %s)", GetCurrentResourceName(),
            vehNet, uid))
        ForgetVehicle(vehicle) -- Pass entity to ensure deletion
    else
        warn(string.format("[%s] CR.PV:ForgetVehicle: Received request for non-existent NetID %d",
            GetCurrentResourceName(), vehNet))
    end
end)

--- Handles request from the client to forget a vehicle based on its UID, even if the entity doesn't exist locally.
--- @param vehicleUID string The persistent UID of the vehicle to forget.
RegisterNetEvent("CR.PV:ForgetVehicleById", function(vehicleUID)
    if vehicleUID and type(vehicleUID) == "string" then
        print(string.format("[%s] Received request to forget vehicle by UID: %s", GetCurrentResourceName(), vehicleUID))
        ForgetVehicle(nil, vehicleUID) -- Pass nil for entity, only use UID
    else
        warn(string.format("[%s] CR.PV:ForgetVehicleById: Received invalid UID type (%s)", GetCurrentResourceName(),
            type(vehicleUID)))
    end
end)


--[[--------------------------------------------------------------------------
    Entity Lifecycle Events
--------------------------------------------------------------------------]]

--- Detects when entities are created. If it's a vehicle potentially spawned by a player
--- (e.g., via menus, cheats, or scripts not using the persistence system),
--- it can be registered automatically or handled based on configuration.
AddEventHandler("entityCreated", function(entity)
    -- Use a timer to delay the check slightly, allowing entity state/driver to settle
    SetTimeout(500, function()
        -- Re-check existence as entity might be deleted quickly
        if not DoesEntityExist(entity) then return end

        -- Check if it's a vehicle
        if GetEntityType(entity) == 2 then
            local driver = GetPedInVehicleSeat(entity, -1) -- Check driver seat

            -- Check if driver exists and is a player
            if DoesEntityExist(driver) and IsPedAPlayer(driver) then
                -- Check if this vehicle is *already* persistent (e.g., spawned by our system)
                if not IsVehiclePersistent(entity) then
                    -- Configurable: Decide whether to automatically register vehicles spawned by players
                    if Config.AutoRegisterPlayerSpawnedVehicles then
                        local uid = GetVehicleUID(entity)
                        print(string.format("[%s] Auto-registering player-spawned vehicle (Entity: %d, UID: %s)",
                            GetCurrentResourceName(), entity, uid or "N/A"))
                        NewVehicle(entity)
                    else
                        -- Optional: Delete non-persistent vehicles spawned by players if not auto-registering
                        -- if Config.DeleteNonPersistentPlayerSpawnedVehicles then
                        --    print(string.format("[%s] Deleting non-persistent player-spawned vehicle (Entity: %d)", GetCurrentResourceName(), entity))
                        --    DeleteEntity(entity)
                        -- end
                    end
                    -- else
                    -- Vehicle already persistent, likely spawned correctly by SpawnVehicle. Do nothing.
                    -- print(string.format("[%s] Player entered an existing persistent vehicle (Entity: %d)", GetCurrentResourceName(), entity))
                end
                -- else
                -- Vehicle created without a player driver (e.g., mission script, traffic)
                -- Usually ignore these unless specific handling is needed.
            end
        end
    end)
end)


--- Detects when entities are removed (deleted). If it's a persistent vehicle
--- that wasn't intentionally forgotten (via ForgetVehicle), it should be respawned.
AddEventHandler("entityRemoved", function(entity)
    -- Check if the entity was marked in DO_NOT_RESPAWN table
    if DO_NOT_RESPAWN[entity] then
        DO_NOT_RESPAWN[entity] = nil -- Clean up the entry
        -- print(string.format("[%s] Entity %d removed, marked DO_NOT_RESPAWN.", GetCurrentResourceName(), entity))
        return                       -- Do not respawn it
    end

    -- Check if the removed entity *was* a persistent vehicle by checking its state bag
    -- Note: State bags might become unreliable immediately upon deletion in some edge cases.
    -- Relying on the state bag content *before* deletion is safer if possible, but entityRemoved is post-deletion.
    -- We need to access the state *before* it's fully gone. This is tricky.
    -- A potential workaround is to store the state temporarily when a persistent vehicle is detected.
    -- However, let's try accessing the state directly first. It *might* still be available briefly.

    local state = Entity(entity)?.state -- Use safe navigation

    -- Check if it was a vehicle and marked as persistent
    -- GetEntityType might return 0 if already fully removed, so rely on state bag primarily
    if state and state.isPersistent == true and state.pId then
        local vehicleUID = state.pId
        print(string.format("[%s] Persistent vehicle removed unexpectedly (Entity: %d, UID: %s). Respawning...",
            GetCurrentResourceName(), entity, vehicleUID))

        -- Respawn the vehicle using its stored UID
        -- Add a small delay before respawning to prevent potential conflicts
        SetTimeout(Config.RespawnDelay or 1000, function()
            SpawnVehicle(vehicleUID)
        end)
        -- else
        -- Entity removed was not a persistent vehicle tracked by this resource, or state was lost.
        -- print(string.format("[%s] Non-persistent entity %d removed.", GetCurrentResourceName(), entity))
    end
end)
