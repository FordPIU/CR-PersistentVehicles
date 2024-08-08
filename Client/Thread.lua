Citizen.CreateThread(function()
    while true do
        Wait(1000)

        local propertiesSet = {}
        local propertiesUpdate = {}

        print("Starting vehicle property check and update")

        for _, v in ipairs(GetGamePool("CVehicle")) do
            local vState = Entity(v).state

            if vState.isPersistent then
                if vState.nProperties then
                    print("Setting properties for vehicle with Net ID: " .. VehToNet(v))
                    SetVehicleProperties(v, vState.pProperties, vState.pId)
                    propertiesSet[VehToNet(v)] = true
                else
                    print("Updating properties for vehicle with Net ID: " .. VehToNet(v))
                    propertiesUpdate[VehToNet(v)] = GetVehicleProperties(v)
                end
            else
                warn("Vehicle with entity ID: " .. v .. " is not persistent, skipping property check")
            end
        end

        print("Triggering server event for properties set")
        TriggerServerEvent("CR.PV:PropertiesSet", propertiesSet)

        print("Triggering server event for properties update")
        TriggerServerEvent("CR.PV:PropertiesUpdate", propertiesUpdate)
    end
end)
