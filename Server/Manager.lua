local Vehicles = {}

function RefreshAndSpawn()

end

function UpdateVehicleProperties(properties)

end

function SaveVehicleProperties()

end

AddEventHandler("onResourceStart", function(resourceName)
    if resourceName == GetCurrentResourceName() then
        RefreshAndSpawn()
    end
end)

AddEventHandler("onResourceStop", function(resourceName)
    if resourceName == GetCurrentResourceName() then
        SaveVehicleProperties()
    end
end)
