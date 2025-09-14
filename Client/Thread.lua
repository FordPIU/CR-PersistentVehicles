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
                Entity(playerVehicle).state:set('isPersistent', true, true)
                Entity(playerVehicle).state:set('persistentId', UId, true)
                TriggerServerEvent("CR.PV:UpdateSingle", UId, GetVehicleProperties(playerVehicle))
            end
        end
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
        if Entity(vehicle).state.isPersistent then
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
                SpawnedVehicles[persistentId] = true
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
                while not HasModelLoaded(vehicleData.model) do
                    RequestModel(vehicleData.model)
                    Wait(1)
                end

                -- Create the vehicle and set the properties
                local vehicle = CreateVehicle(vehicleData.model, vehicleCoords[1], vehicleCoords[2], vehicleCoords
                    [3], vehicleData.matrix.heading, true, true)

                SetVehicleProperties(vehicle, vehicleData)
                Entity(vehicle).state:set('isPersistent', true, true)
                Entity(vehicle).state:set('persistentId', vehicleId, true)
            end
        end
    end

    -- Send updates
    TriggerServerEvent("CR.PV:UpdateMultiple", PropertiesUpdate)

    Loading = false

    print("Tracked Vehicles: " .. GetTableLength(PlayerVehicles))
end)
