local isDebugUI = false

Citizen.CreateThread(function()
    while true do
        Wait(0)

        if isDebugUI then
            local plrCoords = GetEntityCoords(PlayerPedId())

            for _, vehicle in ipairs(GetGamePool("CVehicle")) do
                local vState = Entity(vehicle).state
                local vehicleId = vState.pId or GetVehicleUID(vehicle) or "N/A"
                local isPersistent = vState.isPersistent and "true" or "false"
                local coords = GetEntityCoords(vehicle)
                local text = "vehicleId: " .. vehicleId .. "\nisPersistent: " .. isPersistent

                if #(plrCoords - coords) < 100.0 then
                    DrawText3D(coords.x, coords.y, coords.z + 1.0, text)
                end
            end
        else
            Wait(500)
        end
    end
end)

RegisterCommand("pvdebug", function()
    isDebugUI = not isDebugUI
end, false)
