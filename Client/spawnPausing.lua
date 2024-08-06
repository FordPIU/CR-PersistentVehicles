local VehiclesPaused = {}

function IsVehicleSpawningPaused(vehicleUID)
    return VehiclesPaused[vehicleUID] or false
end

function SetVehicleSpawningPaused(vehicleUID, set)
    VehiclesPaused[vehicleUID] = set
end

exports("IsVehicleSpawningPaused", IsVehicleSpawningPaused)
exports("SetVehicleSpawningPaused", SetVehicleSpawningPaused)
