Citizen.CreateThread(function()
    while true do
        Wait(1000)

        local propertiesSet = {}
        local propertiesUpdate = {}

        for _, v in ipairs(GetGamePool("CVehicle")) do
            local vState = Entity(v).state

            if vState.isPersistent then
                -- Needs Properties Set
                if vState.nProperties then
                    SetVehicleProperties(v, vState.pProperties, vState.pId)
                    propertiesSet[VehToNet(v)] = true
                else
                    propertiesUpdate[VehToNet(v)] = GetVehicleProperties(v)
                end
            end
        end

        TriggerServerEvent("CR.PV:PropertiesSet", propertiesSet)
        TriggerServerEvent("CR.PV:PropertiesUpdate", propertiesUpdate)
    end
end)
