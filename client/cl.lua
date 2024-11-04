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

local function handleUpgrade(warehouseId, upgradeType)
    local prices = {
        slots = Config.upgradeCosts.slotCost,  
        weight = Config.upgradeCosts.weightCost   
    }

    local input = lib.inputDialog('Upgrade Warehouse', {
        {label = 'How much to upgrade?', type = 'number', placeholder = 'Enter amount...'}
    })

    if input and tonumber(input[1]) then
        local upgradeAmount = tonumber(input[1])
        local upgradeCost

        if upgradeType == 'slots' then
            upgradeCost = upgradeAmount * prices.slots
        elseif upgradeType == 'weight' then
            upgradeCost = upgradeAmount * prices.weight
        end

        local confirm = lib.alertDialog({
            header = 'Confirm Upgrade',
            content = ('Upgrade %s by %d for $%d?'):format(upgradeType, upgradeAmount, upgradeCost),
            centered = true,
            cancel = true
        })

        if confirm == 'confirm' then
            TriggerServerEvent('warehouse:upgradeStash', warehouseId, upgradeType, upgradeAmount, upgradeCost)
        else
            lib.notify({type = 'inform', description = 'Upgrade canceled.'})
        end
    else
        lib.notify({type = 'error', description = 'Invalid input. Please enter a valid number.'})
    end
end

local function openOwnerManagementMenu(warehouseId)
    lib.registerContext({
        id = 'warehouse_owner_management',
        title = 'Warehouse Management',
        options = {
            {
                title = 'Upgrade Warehouse',
                description = 'Upgrade stash capacity or weight',
                icon = 'fa-solid fa-arrow-up',
                onSelect = function()
                    lib.registerContext({
                        id = 'warehouse_upgrade_menu',
                        title = 'Upgrade Options',
                        options = {
                            {
                                title = 'Upgrade Slots',
                                description = 'Increase stash slots',
                                icon = 'fa-solid fa-box-open',
                                onSelect = function()
                                    handleUpgrade(warehouseId, 'slots')
                                end
                            },
                            {
                                title = 'Upgrade Weight',
                                description = 'Increase stash weight',
                                icon = 'fa-solid fa-weight-hanging',
                                onSelect = function()
                                    handleUpgrade(warehouseId, 'weight')
                                end
                            }
                        }
                    })
                    lib.showContext('warehouse_upgrade_menu')
                end
            },
            {
                title = 'Change Pincode',
                description = 'Change warehouse access code',
                icon = 'fa-solid fa-key',
                onSelect = function()
                    local input = lib.inputDialog('Change Warehouse Pincode', {
                        {label = 'New Access Code', type = 'input', placeholder = 'Enter a new 4-digit code...', password = true}
                    })
                    if input then
                        local newCode = input[1]
                        TriggerServerEvent('warehouse:changePin', warehouseId, newCode)
                    end
                end
            },
            {
                title = 'Sell the warehouse',
                description = 'sell the warehouse',
                icon = 'fa-solid fa-key',
                onSelect = function()
                    local maara = Config.sellpros * 100
                    local confirm = lib.alertDialog({
                        header = 'Confirm sell',
                        content = ('sell the warehouse you lose %s from the orginal price'):format(maara),
                        centered = true,
                        cancel = true
                    })
                    if confirm == 'confirm' then
                        TriggerServerEvent('warehouse:sell')
                    else
                        lib.notify({type = 'inform', description = 'Sell canceled.'})
                    end
                end
            }
        }
    })
    lib.showContext('warehouse_owner_management')
end


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

    changePinTarget = exports.ox_target:addSphereZone({
        coords = vec3(1049.0280, -3100.6545, -39.0287), 
        radius = 1.5,
        debugPoly = false,
        options = {
            {
                name = 'manageWarehouse',
                label = "Manage Warehouse",
                icon = 'fa-solid fa-cogs',
                canInteract = function()
                    return isOwner  
                end,
                onSelect = function()
                    openOwnerManagementMenu(warehouseId)
                end
            }
        }
    })

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

