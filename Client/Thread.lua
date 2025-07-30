local SERVER_LOADING = true

Citizen.CreateThread(function()
    TriggerServerEvent("CRPV_GETSERVERLOADING")

    repeat
        Wait(0)
    until SERVER_LOADING == false

    while true do
        Wait(2500)

        local playerCoords = GetEntityCoords(PlayerPedId())
        local propertiesSet = {}
        local propertiesUpdate = {}

        for _, v in ipairs(GetGamePool("CVehicle")) do
            if NetworkGetEntityOwner(v) == PlayerId() then
                local vState = Entity(v).state
                local playerIsDriver = GetPedInVehicleSeat(v, -1) == PlayerPedId()
                local vehicleNetId = NetworkGetNetworkIdFromEntity(v)

                SetNetworkIdExistsOnAllMachines(vehicleNetId, true)

                if vState.isPersistent then
                    local vehicleCoords = GetEntityCoords(v)
                    if (vState.nProperties == true or vState.nProperties == nil) and #(playerCoords - vehicleCoords) < 100.0 then
                        SetVehicleProperties(v, vState.pProperties, vState.pId)
                        FreezeEntityPosition(v, false)
                        propertiesSet[vehicleNetId] = true
                    else
                        if vState.pId ~= GetVehicleUID(v) then
                            if playerIsDriver then
                                TriggerServerEvent("CR.PV:VehiclePlateChange", vState.pId, vehicleNetId,
                                    GetVehicleProperties(v))
                            end

                            Wait(2500)

                            DeleteEntity(v)
                        else
                            local vehProps = GetVehicleProperties(v)

                            if vehProps ~= nil and type(vehProps) == "table" then
                                propertiesUpdate[vehicleNetId] = GetVehicleProperties(v)
                            else
                                warn("Unknown vehicle properties", vehProps)
                            end
                        end
                    end
                elseif playerIsDriver then
                    TriggerServerEvent("CR.PV:NewVehicle", vehicleNetId, GetVehicleProperties(v))
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
