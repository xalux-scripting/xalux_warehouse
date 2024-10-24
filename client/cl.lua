

local Config = Config or {}
local insideWarehouse = false
local leaveTarget = nil  
local changePinTarget = nil  
local stashTarget = nil  


local function addTargetZone(coords, radius, name, label, icon, onSelect)
    exports.ox_target:addSphereZone({
        coords = coords,
        radius = radius,
        debugPoly = false,
        options = {
            {
                name = name, 
                label = label, 
                icon = icon, 
                onSelect = function()
                    onSelect() 
                end
            }
        }
    })
end

Citizen.CreateThread(function()
    for index, warehouse in ipairs(Config.Warehouses) do
        addTargetZone(warehouse.coords, 1.5, 'buyWarehouse_' .. index, "Buy Warehouse - $" .. warehouse.price, 'fa-solid fa-dollar-sign', function()
            local input = lib.inputDialog('Buy Warehouse', {
                {label = 'Warehouse Name', type = 'input', placeholder = 'Enter a name for the warehouse...'},
                {label = 'Access Code', type = 'input', placeholder = 'Enter a 4-digit code for the warehouse...'}
            })

            if input then
                local name = input[1]
                local code = input[2]
                TriggerServerEvent('warehouse:buy', index, name, code)
            end
        end)

        addTargetZone(warehouse.coords, 1.5, 'enterWarehouse_' .. index, "Enter Warehouse", 'fa-solid fa-door-open', function()
            local playerCoords = GetEntityCoords(PlayerPedId())

            local input = lib.inputDialog('Enter Warehouse', {
                {label = 'Warehouse Name', type = 'input', placeholder = 'Enter warehouse name...'},
                {label = 'Access Code', type = 'input', password = true, placeholder = 'Enter access code...'}
            })
            
            if input then
                local name = input[1]
                local code = input[2]
                TriggerServerEvent('warehouse:enter', name, code, playerCoords)
            end
        end)
    end
end)

RegisterNetEvent('warehouse:teleportInside')
AddEventHandler('warehouse:teleportInside', function(warehouseId, isOwner)
    SetEntityCoords(PlayerPedId(), 1048.12, -3096.97, -39.0, false, false, false, true)
    insideWarehouse = true
    if leaveTarget then exports.ox_target:removeZone(leaveTarget) leaveTarget = nil end
    if changePinTarget then exports.ox_target:removeZone(changePinTarget) changePinTarget = nil end
    if stashTarget then exports.ox_target:removeZone(stashTarget) stashTarget = nil end

    leaveTarget = exports.ox_target:addSphereZone({
        coords = vec3(1048.12, -3096.97, -39.0),
        radius = 1.5,
        debugPoly = false,
        options = {
            {
                name = 'leaveWarehouse',
                label = "Leave Warehouse",
                icon = 'fa-solid fa-door-closed',
                onSelect = function()
                    TriggerServerEvent('warehouse:leave')
                end
            }
        }
    })

    if isOwner then
        changePinTarget = exports.ox_target:addSphereZone({
            coords = vec3(1049.0280, -3100.6545, -39.0287), 
            radius = 1.5,
            debugPoly = false,
            options = {
                {
                    name = 'changePin',
                    label = "Change Pincode",
                    icon = 'fa-solid fa-key',
                    onSelect = function()
                        local input = lib.inputDialog('Change Warehouse Pincode', {
                            {label = 'New Access Code', type = 'input', placeholder = 'Enter a new 4-digit code...'}
                        })
                        if input then
                            local newCode = input[1]
                            TriggerServerEvent('warehouse:changePin', warehouseId, newCode)
                        end
                    end
                }
            }
        })
    end

    stashTarget = exports.ox_target:addSphereZone({
        coords = vec3(1052.7151, -3100.8760, -39.0000), 
        radius = 1.5,
        debugPoly = false,
        options = {
            {
                name = 'openStash',
                label = "Open Warehouse Stash",
                icon = 'fa-solid fa-box',
                onSelect = function()
                    TriggerEvent('ox_inventory:openInventory', 'stash', {id = 'warehouse_' .. warehouseId, name = 'Warehouse Stash'})
                end
            }
        }
    })
end)

RegisterNetEvent('warehouse:teleportOutside')
AddEventHandler('warehouse:teleportOutside', function(originalPos)
    SetEntityCoords(PlayerPedId(), originalPos.x, originalPos.y, originalPos.z, false, false, false, true)
    insideWarehouse = false


    if leaveTarget then exports.ox_target:removeZone(leaveTarget) leaveTarget = nil end
    if changePinTarget then exports.ox_target:removeZone(changePinTarget) changePinTarget = nil end
    if stashTarget then exports.ox_target:removeZone(stashTarget) stashTarget = nil end
end)
