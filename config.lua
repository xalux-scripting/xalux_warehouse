Config = {}

Config.Warehouses = {
    {
        coords = vector3(598.4041, -408.3136, 26.0418), -- coords for the warehouse
        price = 50000,  --warehouse price

    },
    {
        coords = vector3(615.6195, -410.1126, 26.0322), 
        price = 75000,

    },
    {
        coords = vector3(610.4863, -420.4500, 24.8400), 
        price = 75000,

    },

}
Config.Blips = {
    enabled = true,         -- Set to false to disable blips for warehouses
    blipId = 473,           -- Default blip icon ID for warehouses
    blipColor = 3,          -- Blip color (use numbers from GTA color chart)
    blipName = "Warehouse"  -- Display name for warehouse blips
}

Config.maxPurchases = 6 -- max amount warehouses players can buy in one location




Config.Props = {
    {
        model = "prop_boxpile_07d",    -- prop model 
        coords = vector3(1053.2159, -3102.4148, -40.00000), -- vec3 coords
        heading = 270.0              -- prop heading
    },
}
Config.stashes = {
    defaultSlots = 50,          -- Default slots for a new warehouse
    defaultWeight = 50000,      -- Default weight in grams for a new warehouse (50 kg)
    maxSlots = 200,             -- Maximum slots allowed for upgrade
    maxWeight = 200000,          -- Maximum weight allowed for upgrade (200 kg by default)
    slotCost = 1000,  -- Cost per slot
    weightCost = 500  -- Cost per 1kg (1000g) of weight
}



-- discord logs
Config.Webhook = ''
Config.BotToken = ''

Config.sellpros = 0.25 -- precentage the people lose when selling
