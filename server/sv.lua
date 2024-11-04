Config = Config or {}

local webhook = Config.Webhook
local botToken = Config.BotToken 
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


local function getSteamIdentifier(src)
    for _, id in ipairs(GetPlayerIdentifiers(src)) do
        if string.match(id, "steam:") then
            return id
        end
    end
    return nil
end


local function getDiscordIdentifierAndTag(src, callback)
    local discordId
    for _, id in ipairs(GetPlayerIdentifiers(src)) do
        if string.match(id, "discord:") then
            discordId = string.sub(id, 9)
            break
        end
    end
    if discordId then
        PerformHttpRequest("https://discord.com/api/v10/users/" .. discordId, function(err, response, headers)
            if err == 200 then
                local data = json.decode(response)
                callback(discordId, data.username .. "#" .. data.discriminator)
            else
                callback(discordId, nil)
            end
        end, "GET", "", {["Authorization"] = "Bot " .. botToken})
    else
        callback(nil, nil)
    end
end


local function sendToDiscord(title, message, color)
    PerformHttpRequest(webhook, function(err, text, headers) end, 'POST', json.encode({
        embeds = {{
            title = title,
            description = message,
            color = color
        }}
    }), {['Content-Type'] = 'application/json'})
end

local function getDiscordIdentifierAndTag(src, callback)
    local discordId
    for _, id in ipairs(GetPlayerIdentifiers(src)) do
        if string.match(id, "discord:") then
            discordId = string.sub(id, 9)
            break
        end
    end
    if discordId then
        PerformHttpRequest("https://discord.com/api/v10/users/" .. discordId, function(err, response, headers)
            if err == 200 then
                local data = json.decode(response)
                callback(discordId, data.username .. "#" .. data.discriminator)
            else
                callback(discordId, nil)
            end
        end, "GET", "", {["Authorization"] = "Bot " .. botToken})
    else
        callback(nil, nil)
    end
end

local function sendToDiscord(title, message, color)
    PerformHttpRequest(webhook, function(err, text, headers) end, 'POST', json.encode({
        embeds = {{
            title = title,
            description = message,
            color = color
        }}
    }), {['Content-Type'] = 'application/json'})
end

RegisterNetEvent('warehouse:buy')
AddEventHandler('warehouse:buy', function(warehouseIndex, warehouseName, warehouseCode)
    local src = source
    local playerName = GetPlayerName(src)
    local steamId = getSteamIdentifier(src)
    local warehouse = Config.Warehouses[warehouseIndex]

    getDiscordIdentifierAndTag(src, function(discordId, discordTag)
        if not warehouseName or warehouseName == "" then
            TriggerClientEvent('ox_lib:notify', src, {title = 'Error', description = 'Invalid warehouse name!', type = 'error'})
            return
        end
        if not warehouseCode or #warehouseCode ~= 4 then
            TriggerClientEvent('ox_lib:notify', src, {title = 'Error', description = 'Invalid access code! Must be 4 digits.', type = 'error'})
            return
        end

        local existingWarehouse = MySQL.query.await('SELECT `name` FROM `warehouses` WHERE `name` = ?', {warehouseName})
        if existingWarehouse[1] then
            TriggerClientEvent('ox_lib:notify', src, {title = 'Error', description = 'Warehouse name already taken!', type = 'error'})
            return
        end

        local money = exports.ox_inventory:GetItem(src, 'money')
        local warehousePrice = warehouse.price
        if not money or money.count < warehousePrice then
            TriggerClientEvent('ox_lib:notify', src, {title = 'Error', description = 'Insufficient funds to buy the warehouse!', type = 'error'})
            return
        end

        exports.ox_inventory:RemoveItem(src, 'money', warehousePrice)
        local warehouseId = generateUniqueWarehouseId()

        MySQL.insert.await('INSERT INTO `warehouses` (owner, steam_id, name, code, location, warehouse_id, max_slots, max_weight, discord, original_price) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)', {
            playerName, steamId, warehouseName, warehouseCode, json.encode(warehouse.coords), warehouseId, Config.stashes.defaultSlots, Config.stashes.defaultWeight, discordId, warehousePrice
        })

        exports.ox_inventory:RegisterStash('warehouse_' .. warehouseId, warehouseName, Config.stashes.defaultSlots, Config.stashes.defaultWeight, playerName)
        TriggerClientEvent('ox_lib:notify', src, {title = 'Success', description = 'You bought the warehouse: ' .. warehouseName, type = 'success'})
        TriggerClientEvent('warehouse:setupStashTarget', src, warehouse.coords, warehouseId)

        local discordDisplay = discordTag or "Unknown"
        local mention = discordId and ("<@" .. discordId .. ">") or "Unknown"
        sendToDiscord("Warehouse Purchase", ("**Player:** %s\n**Discord:** %s\n**Warehouse Name:** %s\n**Price:** $%d"):format(playerName, mention, warehouseName, warehousePrice), 3447003)
    end)
end)


RegisterNetEvent('warehouse:changePin')
AddEventHandler('warehouse:changePin', function(warehouseId, newCode)
    local src = source
    local steamId = getSteamIdentifier(src)


    if not newCode or #newCode ~= 4 then
        TriggerClientEvent('ox_lib:notify', src, {title = 'Error', description = 'Invalid access code! Must be 4 digits.', type = 'error'})
        return
    end

    MySQL.update('UPDATE `warehouses` SET `code` = ? WHERE `warehouse_id` = ? AND `steam_id` = ?', {newCode, warehouseId, steamId}, function(affectedRows)
        if affectedRows > 0 then
            TriggerClientEvent('ox_lib:notify', src, {title = 'Success', description = 'Warehouse pincode changed successfully!', type = 'success'})
        else
            TriggerClientEvent('ox_lib:notify', src, {title = 'Error', description = 'You are not the owner of this warehouse!', type = 'error'})
        end
    end)
end)


RegisterNetEvent('warehouse:upgradeStash')
AddEventHandler('warehouse:upgradeStash', function(warehouseId, upgradeType, upgradeAmount, upgradeCost)
    local src = source
    local playerName = GetPlayerName(src)

    getDiscordIdentifierAndTag(src, function(discordId, discordTag)
        local mention = discordId and ("<@" .. discordId .. ">") or "Unknown"

        local money = exports.ox_inventory:GetItem(src, 'money')
        if not money or money.count < upgradeCost then
            TriggerClientEvent('ox_lib:notify', src, {title = 'Error', description = 'Insufficient funds for this upgrade!', type = 'error'})
            return
        end

        exports.ox_inventory:RemoveItem(src, 'money', upgradeCost)

        if upgradeType == "slots" then
            MySQL.update.await('UPDATE `warehouses` SET `max_slots` = `max_slots` + ? WHERE `warehouse_id` = ?', {upgradeAmount, warehouseId})
        elseif upgradeType == "weight" then
            MySQL.update.await('UPDATE `warehouses` SET `max_weight` = `max_weight` + ? WHERE `warehouse_id` = ?', {upgradeAmount * 1000, warehouseId}) 
        end

        local warehouse = MySQL.query.await('SELECT `name`, `max_slots`, `max_weight` FROM `warehouses` WHERE `warehouse_id` = ?', {warehouseId})
        exports.ox_inventory:RegisterStash('warehouse_' .. warehouseId, warehouse[1].name, warehouse[1].max_slots, warehouse[1].max_weight, playerName)

        TriggerClientEvent('ox_lib:notify', src, {title = 'Success', description = 'Warehouse upgraded successfully!', type = 'success'})

        sendToDiscord("Warehouse Upgrade", ("**Player:** %s\n**Warehouse ID:** %d\n**Discord:** %s\n**Upgrade Type:** %s\n**Upgrade Amount:** %d\n**Cost:** $%d"):format(playerName, warehouseId, mention, upgradeType, upgradeAmount, upgradeCost), 3066993)
    end)
end)


RegisterNetEvent('warehouse:enter')
AddEventHandler('warehouse:enter', function(warehouseName, enteredCode, playerCoords)
    local src = source
    local steamId = getSteamIdentifier(src)
    MySQL.query('SELECT `code`, `warehouse_id`, `steam_id`, `location` FROM `warehouses` WHERE `name` = ? AND `code` = ?', {warehouseName, enteredCode}, function(result)
        if result[1] then
            local entryCoords = json.decode(result[1].location)
            local distance = #(playerCoords - vec3(entryCoords.x, entryCoords.y, entryCoords.z))
            if distance <= 5.0 then
                local warehouseId = result[1].warehouse_id
                local isOwner = (result[1].steam_id == steamId)
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
AddEventHandler('warehouse:leave', function(src)
    local src = source
    local originalPos = playerLocations[src]  

    SetPlayerRoutingBucket(src, 0)
    if originalPos then
        TriggerClientEvent('warehouse:teleportOutside', src, originalPos)
        playerLocations[src] = nil  
    else
        TriggerClientEvent('ox_lib:notify', src, {title = 'Notice', description = 'No saved exit location found!', type = 'error'})
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

        MySQL.query('SELECT `warehouse_id`, `owner`, `discord`, `max_slots`, `max_weight` FROM `warehouses` WHERE `name` = ?', {warehouseName}, function(result)
            if result[1] then
                local warehouseId = result[1].warehouse_id
                local ownerName = result[1].owner
                local ownerDiscord = result[1].discord and ("<@" .. result[1].discord .. ">") or "Unknown"
                local stashId = 'warehouse_' .. warehouseId
                local inventory = exports.ox_inventory:GetInventory(stashId)
                if inventory and inventory.items then
                    local itemList = ""
                    for _, item in pairs(inventory.items) do
                        itemList = itemList .. ("**Item:** %s | **Count:** %d\n"):format(item.name, item.count)
                    end

                    if itemList == "" then
                        itemList = "The stash is empty."
                    end

                    sendToDiscord("Warehouse Stash Info", ("**Warehouse Name:** %s\n**Owner:** %s\n**Owner Discord:** %s\n**Requested by:** %s\n\n%s"):format(warehouseName, ownerName, ownerDiscord, playerName, itemList), 3447003)
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
    if GetCurrentResourceName() ~= resourceName then return end
    local warehouses = MySQL.query.await('SELECT `warehouse_id`, `name`, `owner`, `max_slots`, `max_weight` FROM `warehouses`')
    if warehouses then
        for _, warehouse in pairs(warehouses) do
            exports.ox_inventory:RegisterStash('warehouse_' .. warehouse.warehouse_id, warehouse.name, warehouse.max_slots, warehouse.max_weight, warehouse.owner)
        end
    end
end)


RegisterNetEvent('warehouse:sell')
AddEventHandler('warehouse:sell', function()
    local src = source
    local steamId = getSteamIdentifier(src)
    local playerName = GetPlayerName(src)
    local warehouseId = GetPlayerRoutingBucket(src) 
    local saleCutPercentage = Config.sellpros

    getDiscordIdentifierAndTag(src, function(discordId, discordTag)
        local mention = discordId and ("<@" .. discordId .. ">") or "Unknown"

        local warehouse = MySQL.query.await('SELECT `name`, `original_price`, `steam_id` FROM `warehouses` WHERE `warehouse_id` = ?', {warehouseId})
        if not warehouse[1] or tostring(warehouse[1].steam_id) ~= tostring(steamId) then
            TriggerClientEvent('ox_lib:notify', src, {title = 'Error', description = 'You are not the owner of this warehouse!', type = 'error'})
            return
        end

        local warehousePrice = warehouse[1].original_price or 0
        local payoutAmount = math.floor(warehousePrice * (1 - saleCutPercentage))

        if payoutAmount > 0 then
            exports.ox_inventory:AddItem(src, 'money', payoutAmount)
        else
            TriggerClientEvent('ox_lib:notify', src, {title = 'Error', description = 'Calculated payout is invalid!', type = 'error'})
            return
        end

        exports.ox_inventory:ClearInventory('warehouse_' .. warehouseId)
        MySQL.query.await('DELETE FROM `warehouses` WHERE `warehouse_id` = ?', {warehouseId})

        TriggerClientEvent('ox_lib:notify', src, {title = 'Success', description = ('You sold the warehouse for $%d after a %.0f%% cut.'):format(payoutAmount, saleCutPercentage * 100), type = 'success'})

        sendToDiscord("Warehouse Sold", ("**Player:** %s\n**Discord:** %s\n**Warehouse Name:** %s\n**Original Price:** $%d\n**Payout Amount:** $%d\n")
            :format(playerName, mention, warehouse[1].name, warehousePrice, payoutAmount), 16056320)

        TriggerEvent('warehouse:leave', src)
    end)
end)
