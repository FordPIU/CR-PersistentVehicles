local Vehicles = {}

--[[
    Data Load/Save
]]
function LoadVehicleData(resourceName)
    local vehiclesJson = LoadResourceFile(resourceName or GetCurrentResourceName(), "vehicles.json")

    if vehiclesJson ~= nil then
        print("Loading vehicle data from vehicles.json")
        Vehicles = TrimVehiclesJson(vehiclesJson)
    else
        warn("No file: vehicles.json found while loading vehicle data")
    end

    print("Deleting all persistent vehicles")
    DeleteAllPersistentVehicles()

    print("Spawning all persistent vehicles")
    SpawnAllPersistentVehicles()
end

function SaveVehicleData(resourceName)
    print("Saving vehicle data to vehicles.json")
    SaveResourceFile(resourceName or GetCurrentResourceName(), "vehicles.json", json.encode(Vehicles), -1)
end

--[[
    Vehicle State Management
]]
function SpawnVehicle(vehicleId)
    local vehicleData = Vehicles[vehicleId]
    local position = vehicleData.matrix.position
    local vehicle = CreateVehicleServerSetter(vehicleData.model, vehicleData.type, position.x, position.y, position
        .z, vehicleData.matrix.heading)
    FreezeEntityPosition(vehicle, true)

    print("Spawning vehicle with Vehicle ID: " .. vehicleId)

    Entity(vehicle).state.isPersistent = true
    Entity(vehicle).state.pProperties = vehicleData
    Entity(vehicle).state.nProperties = true
    Entity(vehicle).state.pId = vehicleId
end

function NewVehicle(vehicle)
    local vehicleId = GetVehicleUID(vehicle)

    print("Registering new vehicle with Vehicle ID: " .. vehicleId)

    Vehicles[vehicleId] = true

    Entity(vehicle).state.isPersistent = true
    Entity(vehicle).state.pId = vehicleId
    Entity(vehicle).state.pProperties = nil
end

function UpdateVehicle(vehicle, properties)
    local vehicleId = GetVehicleUID(vehicle)

    print("Updating vehicle with Vehicle ID: " .. vehicleId)

    Vehicles[vehicleId] = properties

    Entity(vehicle).state.pProperties = properties
    SaveVehicleData()
end

function ForgetVehicle(vehicle)
    local vehicleId = GetVehicleUID(vehicle)

    print("Forgetting vehicle with Vehicle ID: " .. vehicleId)

    Vehicles[vehicleId] = nil
    DO_NOT_RESPAWN[vehicle] = true

    DeleteEntity(vehicle)
    SaveVehicleData()
end

function IsVehiclePersistent(vehicle)
    local vehicleId = GetVehicleUID(vehicle)
    local isPersistent = Vehicles[vehicleId] ~= nil

    if isPersistent then
        print("Vehicle with Vehicle ID: " .. vehicleId .. " is persistent")
    else
        print("Vehicle with Vehicle ID: " .. vehicleId .. " is not persistent")
    end

    return isPersistent
end

function DeleteAllPersistentVehicles()
    print("Deleting all persistent vehicles")

    local playerId = GetRandomPlayerId()
    local playerPed = GetPlayerPed(playerId)

    repeat
        Wait(500)
        playerId = GetRandomPlayerId()
        playerPed = GetPlayerPed(playerId)
        print("Waiting for valid player ...")
    until playerId ~= nil and DoesEntityExist(playerPed)

    if playerId == nil or not DoesEntityExist(playerPed) then
        error("Failed to find a valid player ped to use for deletion process")
        return
    end

    local originalPlayerCoords = GetEntityCoords(playerPed)
    print("Freezing player ped at coordinates: " .. tostring(originalPlayerCoords))
    FreezeEntityPosition(playerPed, true)

    for vehicleId, vehicleData in pairs(Vehicles) do
        local pos = vehicleData.matrix.position
        print("Setting player ped coordinates to vehicle position: " .. tostring(pos))

        SetEntityCoords(playerPed, pos.x, pos.y, pos.z, true, false, false, false)

        for _, v in ipairs(GetAllVehicles()) do
            if GetVehicleUID(v) == vehicleId then
                DO_NOT_RESPAWN[v] = true
                print("Deleting vehicle with UID: " .. vehicleId)
                DeleteEntity(v)
            else
                warn("Vehicle with UID: " .. vehicleId .. " not found in current vehicle pool")
            end
        end
    end

    print("Restoring player ped to original coordinates: " .. tostring(originalPlayerCoords))
    SetEntityCoords(playerPed, originalPlayerCoords[1], originalPlayerCoords[2], originalPlayerCoords[3], true, false,
        false, false)
    FreezeEntityPosition(playerPed, false)
end

function SpawnAllPersistentVehicles()
    print("Spawning all persistent vehicles")

    for vehicleId, _ in pairs(Vehicles) do
        SpawnVehicle(vehicleId)
    end
end
