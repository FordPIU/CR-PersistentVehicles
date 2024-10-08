Citizen.CreateThread(function()
    local plateTracking = {}

    while true do
        Wait(1000)

        local propertiesSet = {}
        local propertiesUpdate = {}

        --print("\nStarting vehicle property check and update")

        for _, v in ipairs(GetGamePool("CVehicle")) do
            local vState = Entity(v).state

            if vState.isPersistent and NetworkGetEntityOwner(v) == PlayerId() then
                if plateTracking[v] ~= nil and GetVehicleUID(v) ~= plateTracking[v] then
                    TriggerServerEvent("CR.PV:ForgetVehicleById", plateTracking[v])
                    TriggerServerEvent("CR.PV:NewVehicle", VehToNet(v))
                end

                if vState.nProperties then
                    --print("Setting properties for vehicle with Vehicle UID: " .. vState.pId)
                    SetVehicleProperties(v, vState.pProperties, vState.pId)
                    FreezeEntityPosition(v, false)
                    propertiesSet[VehToNet(v)] = true
                else
                    --print("Updating properties for vehicle with Vehicle UID: " .. vState.pId)
                    propertiesUpdate[VehToNet(v)] = GetVehicleProperties(v)
                end

                plateTracking[v] = GetVehicleUID(v)
            end
        end

        --print("Triggering server event for properties set")
        TriggerServerEvent("CR.PV:PropertiesSet", propertiesSet)

        --print("Triggering server event for properties update")
        TriggerServerEvent("CR.PV:PropertiesUpdate", propertiesUpdate)
    end
end)
