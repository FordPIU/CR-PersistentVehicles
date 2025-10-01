local FivemId
local Vehicles = {}
local UniqueIds = {}

local function getUId()
    local isUnique = false
    local uniqueId = nil

    repeat
        Wait(0)

        uniqueId = tonumber(FivemId) .. math.random(100000, 999999)
        isUnique = UniqueIds[uniqueId] == nil and Vehicles[uniqueId] == nil
    until isUnique

    UniqueIds[uniqueId] = true

    return uniqueId
end

Citizen.CreateThread(function()
    TriggerServerEvent("CR.PV:MyFiveMId")

    local timeout = GetGameTimer() + 30000

    repeat
        Wait(0)
        if GetGameTimer() > timeout then
            return error("NO VALID FIVEM ID?")
        end
    until FivemId ~= nil

    while true do
        Wait(1500)
        TriggerServerEvent("CR.PV:GetVehicles")

        local playerVehicle = GetVehiclePedIsIn(PlayerPedId(), false)

        if DoesEntityExist(playerVehicle) then
            if not Entity(playerVehicle).state.isPersistent then
                local UId = getUId()
                local NetId = NetworkGetNetworkIdFromEntity(playerVehicle)

                SetNetworkIdExistsOnAllMachines(NetId, true)
                SetNetworkIdCanMigrate(NetId, true)

                Entity(playerVehicle).state:set('isPersistent', true, true)
                Entity(playerVehicle).state:set('persistentId', UId, true)
                Entity(playerVehicle).state:set('persistentHash', GetEntityModel(playerVehicle), true)
                TriggerServerEvent("CR.PV:UpdateSingle", UId, GetVehicleProperties(playerVehicle))
                print("Registered players current vehicle")
            else
                local properties = GetVehicleProperties(playerVehicle)
                local persistentId = Entity(playerVehicle).state.persistentId

                if properties and persistentId then
                    TriggerServerEvent("CR.PV:UpdateSingle", persistentId, properties)
                    print("Updated players current vehicle")
                end
            end
        end

        print("CR.PV Tick")
    end
end)

RegisterNetEvent("CR.PV:SetFivemId", function(FiveMId)
    FivemId = FiveMId
end)

local Loading = false
RegisterNetEvent("CR.PV:ReturnVehicles", function(PlayerVehicles, Players, SpawnedVehicles)
    if Loading == false then
        Loading = true
    else
        return
    end

    local PropertiesUpdate = {}
    local playerCoords = GetEntityCoords(PlayerPedId())

    -- Despawn, Update and SpawnedVehicles part
    for _, vehicle in ipairs(GetGamePool("CVehicle")) do
        if Entity(vehicle).state.isPersistent and GetEntityModel(vehicle) == Entity(vehicle).state.persistentHash and Entity(vehicle).state.persistentId ~= nil then
            local persistentId = Entity(vehicle).state.persistentId

            if PlayerVehicles[persistentId] ~= nil then
                local vehicleCoords = GetEntityCoords(vehicle)
                local distance = #(playerCoords - vehicleCoords)
                if distance > 250.0 then
                    -- Vehicles too far, delete it
                    SetModelAsNoLongerNeeded(GetEntityModel(vehicle))
                    DeleteEntity(vehicle)
                    print("Removing vehicle " .. persistentId .. " due to distance")
                else
                    -- Vehicles within range, update it
                    local properties = GetVehicleProperties(vehicle)

                    if properties ~= nil and type(properties) == "table" then
                        PropertiesUpdate[persistentId] = properties
                        print("Updating vehicle properties for vehicle " .. persistentId)
                    end
                end
            end

            -- We set this anyoway so we dont try to respawn it
            if SpawnedVehicles[persistentId] ~= true then
                print("Vehicle " .. persistentId .. " is spawned but not really???")
                DeleteEntity(vehicle)
            end
        end
    end

    -- Spawn part
    for vehicleId, vehicleData in pairs(PlayerVehicles) do
        -- Vehicle isnt spawned
        if SpawnedVehicles[vehicleId] == nil and vehicleData ~= nil then
            local jsonCoords = vehicleData.matrix.position
            local vehicleCoords = vector3(jsonCoords.x, jsonCoords.y, jsonCoords.z)
            local distance = #(playerCoords - vehicleCoords)

            if distance < 250.0 then
                -- Spawn the vehicle, within distance
                print("Spawning vehicle " .. vehicleId)


                -- Request the model
                local timeout = GetGameTimer() + 500
                while not HasModelLoaded(vehicleData.model) do
                    RequestModel(vehicleData.model)
                    if GetGameTimer() > timeout then
                        print("Vehicle " .. vehicleId .. " failed to load model, skipping")
                        --TriggerServerEvent("CR.PV:ForgetVehicleById", vehicleId)
                        goto skip_this_vehicle
                    end
                    Wait(1)
                end

                -- Create the vehicle and set the properties
                local newvehicle = CreateVehicle(vehicleData.model, vehicleCoords[1], vehicleCoords[2], vehicleCoords
                    [3], vehicleData.matrix.heading, true, false)

                print("Created vehicle " .. vehicleId)

                SetEntityCoords(newvehicle, vehicleCoords[1], vehicleCoords[2], vehicleCoords[3], false, false, false,
                    false)
                SetEntityHeading(newvehicle, vehicleData.matrix.heading)
                SetVehicleProperties(newvehicle, vehicleData)
                SetNetworkIdCanMigrate(NetworkGetNetworkIdFromEntity(newvehicle), true)
                SetNetworkIdExistsOnAllMachines(NetworkGetNetworkIdFromEntity(newvehicle), true)
                Entity(newvehicle).state:set('isPersistent', true, true)
                Entity(newvehicle).state:set('persistentId', vehicleId, true)
                Entity(newvehicle).state:set('persistentHash', vehicleData.model, true)
            end
        end

        ::skip_this_vehicle::
    end

    -- Send updates
    TriggerServerEvent("CR.PV:UpdateMultiple", PropertiesUpdate)

    Loading = false

    print("Tracked Vehicles: " .. GetTableLength(PlayerVehicles))
end)
