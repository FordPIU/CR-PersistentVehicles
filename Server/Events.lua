--[[
    Resource start/stop
]]
AddEventHandler("onResourceStart", function(resourceName)
    if resourceName == GetCurrentResourceName() then
        Vehicles = LoadVehicleData(resourceName)

        if not GlobalState.PersistentVehiclesSpawned then
            RefreshAndSpawn()

            GlobalState.PersistentVehiclesSpawned = true
        end
    end
end)

AddEventHandler("onResourceStop", function(resourceName)
    if resourceName == GetCurrentResourceName() then
        SaveVehicleData(resourceName)
    end
end)
