Config = Config or {} 


local DISCORD_WEBHOOK_URL = Config.Webhook 


local playerLocations = {}

local function generateUniqueWarehouseId()
    local warehouseId, isUnique = nil, false
    while not isUnique do
        warehouseId = math.random(500, 1000)
        local result = MySQL.query.await('SELECT `warehouse_id` FROM `warehouses` WHERE `warehouse_id` = ?', {warehouseId})
        if result[1] == nil then isUnique = true end 
    end
    return warehouseId
end


local function getPlayerIdentifiers(src)
    local discordIdentifier = nil
    for _, id in ipairs(GetPlayerIdentifiers(src)) do
        if string.match(id, "discord:") then
            discordIdentifier = id
        end
    end

    return discordIdentifier
end


local function sendToDiscord(title, message, color)
    PerformHttpRequest(DISCORD_WEBHOOK_URL, function(err, text, headers) end, 'POST', json.encode({
        embeds = { {
            title = title,
            description = message,
            color = color
        }}
    }), { ['Content-Type'] = 'application/json' })
end


RegisterNetEvent('warehouse:buy')
AddEventHandler('warehouse:buy', function(warehouseIndex, warehouseName, warehouseCode)
    local src = source
    local warehouse = Config.Warehouses[warehouseIndex]
    local discordId = getPlayerIdentifiers(src)
    local Owner = GetPlayerName(src) 


    if not warehouseName or warehouseName == "" then
        TriggerClientEvent('ox_lib:notify', src, {title = 'Error', description = 'Invalid warehouse name!', type = 'error'})
        return
    end

    if not warehouseCode or warehouseCode == "" or #warehouseCode ~= 4 then
        TriggerClientEvent('ox_lib:notify', src, {title = 'Error', description = 'Invalid access code! Must be 4 digits.', type = 'error'})
        return
    end

    local existingWarehouse = MySQL.query.await('SELECT `name` FROM `warehouses` WHERE `name` = ?', {warehouseName})
    if existingWarehouse[1] then
        TriggerClientEvent('ox_lib:notify', src, {title = 'Error', description = 'A warehouse with this name already exists!', type = 'error'})
        return
    end

    local money = exports.ox_inventory:GetItem(src, 'money')
    local warehousePrice = warehouse.price
    if not money or money.count < warehousePrice then
        TriggerClientEvent('ox_lib:notify', src, {title = 'Error', description = 'Insufficient money to buy this warehouse!', type = 'error'})
        return
    end


    exports.ox_inventory:RemoveItem(src, 'money', warehousePrice)

    local warehouseId = generateUniqueWarehouseId()

    MySQL.insert.await('INSERT INTO `warehouses` (owner, discord, name, code, location, warehouse_id, entry_coords) VALUES (?, ?, ?, ?, ?, ?, ?)', {
        playerName, discordId, warehouseName, warehouseCode, json.encode(warehouse.coords), warehouseId, json.encode(warehouse.coords)
    })


    exports.ox_inventory:RegisterStash('warehouse_' .. warehouseId, warehouseName, Config.stashes.slots, Config.stashes.maxWeight, playerName)

    TriggerClientEvent('ox_lib:notify', src, {title = 'Success', description = 'You bought the warehouse: ' .. warehouseName, type = 'success'})

    TriggerClientEvent('warehouse:setupStashTarget', src, warehouse.coords, warehouseId)

    sendToDiscord("Warehouse Purchased", ("**Player:** %s\n**Discord:** %s\n**Warehouse:** %s\n**Price:** $%d"):format(playerName, discordId, warehouseName, warehousePrice), 3066993)
end)

RegisterNetEvent('warehouse:changePin')
AddEventHandler('warehouse:changePin', function(warehouseId, newCode)
    local src = source
    local playerName = GetPlayerName(src)

    -- Validate the new code
    if not newCode or #newCode ~= 4 then
        TriggerClientEvent('ox_lib:notify', src, {title = 'Error', description = 'Invalid access code! Must be 4 digits.', type = 'error'})
        return
    end

    MySQL.update('UPDATE `warehouses` SET `code` = ? WHERE `warehouse_id` = ? AND `owner` = ?', {newCode, warehouseId, playerName}, function(affectedRows)
        if affectedRows > 0 then
            TriggerClientEvent('ox_lib:notify', src, {title = 'Success', description = 'Warehouse pincode changed successfully!', type = 'success'})
        else
            TriggerClientEvent('ox_lib:notify', src, {title = 'Error', description = 'You are not the owner of this warehouse!', type = 'error'})
        end
    end)
end)

RegisterNetEvent('warehouse:enter')
AddEventHandler('warehouse:enter', function(warehouseName, enteredCode, playerCoords)
    local src = source
    MySQL.query('SELECT `code`, `warehouse_id`, `owner`, `entry_coords` FROM `warehouses` WHERE `name` = ? AND `code` = ?', {warehouseName, enteredCode}, function(result)
        if result[1] then
            local entryCoords = json.decode(result[1].entry_coords)
            local distance = #(playerCoords - vec3(entryCoords.x, entryCoords.y, entryCoords.z))
            if distance <= 5.0 then
                local warehouseId = result[1].warehouse_id
                local isOwner = (result[1].owner == GetPlayerName(src))

                playerLocations[src] = playerCoords

                SetPlayerRoutingBucket(src, warehouseId)
                TriggerClientEvent('warehouse:teleportInside', src, warehouseId, isOwner)

                TriggerClientEvent('warehouse:setupStashTarget', src, entryCoords, warehouseId)
            else
                TriggerClientEvent('ox_lib:notify', src, {title = 'Error', description = 'You cannot enter this warehouse from here!', type = 'error'})
            end
        else
            TriggerClientEvent('ox_lib:notify', src, {title = 'Error', description = 'Invalid warehouse name or code!', type = 'error'})
        end
    end)
end)

RegisterNetEvent('warehouse:leave')
AddEventHandler('warehouse:leave', function()
    local src = source
    local originalPos = playerLocations[src]

    SetPlayerRoutingBucket(src, 0)
    if originalPos then
        TriggerClientEvent('warehouse:teleportOutside', src, originalPos)
        playerLocations[src] = nil
    end
end)

RegisterCommand("requestStashInfo", function(source, args, rawCommand)
    local src = source
    local playerName = GetPlayerName(src)

    if IsPlayerAceAllowed(src, "command.requestStashInfo") then
        if not args[1] then
            TriggerClientEvent('ox_lib:notify', src, {title = 'Error', description = 'Please provide a warehouse name!', type = 'error'})
            return
        end

        local warehouseName = args[1]

        MySQL.query('SELECT `warehouse_id`, `owner`, `discord` FROM `warehouses` WHERE `name` = ?', {warehouseName}, function(result)
            if result[1] then
                local warehouseId = result[1].warehouse_id
                local ownerSteamId = result[1].owner
                local ownerDiscord = result[1].discord
                local stashId = 'warehouse_' .. warehouseId
                local ownerSteamName = nil 

                for _, playerId in ipairs(GetPlayers()) do
                    if GetPlayerIdentifier(playerId, 0) == ownerSteamId then
                        ownerSteamName = GetPlayerName(playerId)
                        break
                    end
                end

                if not ownerSteamName then
                    ownerSteamName = "Owner is offline (Steam ID: " .. ownerSteamId .. ")"
                end

                local inventory = exports.ox_inventory:GetInventory(stashId)
                if inventory and inventory.items then
                    local stashItems = inventory.items
                    local itemList = ""
                    for _, item in pairs(stashItems) do
                        itemList = itemList .. ("**Item:** %s | **Count:** %d\n"):format(item.name, item.count)
                    end

                    if itemList == "" then
                        itemList = "The stash is empty."
                    end
                    sendToDiscord("Warehouse Stash Info", ("**Warehouse Name:** %s\n**Owner:** %s\n**Owner Discord:** %s\n**Requested by:** %s\n\n%s"):format(warehouseName, ownerSteamName, ownerDiscord, playerName, itemList), 3447003)

                    TriggerClientEvent('ox_lib:notify', src, {title = 'Success', description = 'Stash info sent to Discord!', type = 'success'})
                else
                    TriggerClientEvent('ox_lib:notify', src, {title = 'Error', description = 'No items found in the stash.', type = 'error'})
                end
            else
                TriggerClientEvent('ox_lib:notify', src, {title = 'Error', description = 'No warehouse found with that name!', type = 'error'})
            end
        end)
    else
        TriggerClientEvent('ox_lib:notify', src, {title = 'Error', description = 'You do not have permission to use this command!', type = 'error'})
    end
end)


AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then
        return
    end
    local warehouses = MySQL.query.await('SELECT `warehouse_id`, `name`, `owner` FROM `warehouses`')
    if warehouses then
        for _, warehouse in pairs(warehouses) do
            exports.ox_inventory:RegisterStash('warehouse_' .. warehouse.warehouse_id, warehouse.name, Config.stashes.slots, Config.stashes.maxWeight, warehouse.owner)
        end
    end
end)
