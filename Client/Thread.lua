local function duplicateCheck(vehicle, vehicleId)
    for _, v in ipairs(GetGamePool("CVehicle")) do
        local vId = GetVehicleUID(v)

        if vId == vehicleId and v ~= vehicle then
            DeleteEntity(v)
        end
    end
end

Citizen.CreateThread(function()
    while true do
        Wait(1000)

        local propertiesSet = {}
        local propertiesUpdate = {}

        print("\nStarting vehicle property check and update")

        for _, v in ipairs(GetGamePool("CVehicle")) do
            local vState = Entity(v).state

            if vState.isPersistent then
                if vState.nProperties then
                    print("Checking for duplicates of vehicle with Vehicle UID: " .. vState.pId)
                    duplicateCheck(v, vState.pId)

                    print("Setting properties for vehicle with Vehicle UID: " .. vState.pId)
                    SetVehicleProperties(v, vState.pProperties, vState.pId)
                    FreezeEntityPosition(v, false)
                    propertiesSet[VehToNet(v)] = true
                else
                    print("Updating properties for vehicle with Vehicle UID: " .. vState.pId)
                    propertiesUpdate[VehToNet(v)] = GetVehicleProperties(v)
                end
            end
        end

        print("Triggering server event for properties set")
        TriggerServerEvent("CR.PV:PropertiesSet", propertiesSet)

        print("Triggering server event for properties update")
        TriggerServerEvent("CR.PV:PropertiesUpdate", propertiesUpdate)
    end
end)
