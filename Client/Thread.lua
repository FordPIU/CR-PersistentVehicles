local SERVER_LOADING = true

Citizen.CreateThread(function()
    TriggerServerEvent("CRPV_GETSERVERLOADING")

    repeat
        Wait(0)
    until SERVER_LOADING == false

    while true do
        Wait(2500)

        local propertiesSet = {}
        local propertiesUpdate = {}

        for _, v in ipairs(GetGamePool("CVehicle")) do
            if NetworkGetEntityOwner(v) == PlayerId() then
                local vState = Entity(v).state
                local playerIsDriver = GetPedInVehicleSeat(v, -1) == PlayerPedId()

                if vState.isPersistent then
                    if vState.nProperties == true or vState.nProperties == nil then
                        SetVehicleProperties(v, vState.pProperties, vState.pId)
                        FreezeEntityPosition(v, false)
                        propertiesSet[VehToNet(v)] = true
                    else
                        if vState.pId ~= GetVehicleUID(v) then
                            if playerIsDriver then
                                TriggerServerEvent("CR.PV:ForgetVehicleById", vState.pId)
                                TriggerServerEvent("CR.PV:NewVehicle", VehToNet(v))

                                local newVehicleProperties = {}
                                newVehicleProperties[VehToNet(v)] = GetVehicleProperties(v)

                                TriggerServerEvent("CR.PV:PropertiesUpdate", newVehicleProperties)
                            end

                            DeleteEntity(v)
                        else
                            propertiesUpdate[VehToNet(v)] = GetVehicleProperties(v)
                        end
                    end
                elseif playerIsDriver then
                    TriggerServerEvent("CR.PV:NewVehicle", VehToNet(v))
                end
            end
        end

        --print("Triggering server event for properties set")
        TriggerServerEvent("CR.PV:PropertiesSet", propertiesSet)

        --print("Triggering server event for properties update")
        TriggerServerEvent("CR.PV:PropertiesUpdate", propertiesUpdate)
    end
end)

RegisterNetEvent("CRPV_SETSERVERLOADING", function(setTo)
    SERVER_LOADING = setTo
end)

RegisterNetEvent("CRPV_LOADMODEL", function(vehicleHash)
    RequestModel(vehicleHash)
end)
