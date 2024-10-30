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
    --you can add more if needed
   
}

Config.stashes = {
    defaultSlots = 50,      -- Default stash slots
    defaultWeight = 50000   -- Default stash max weight in grams
}

Config.upgradeCosts = {
    slotCost = 1000,  -- Cost per slot
    weightCost = 500  -- Cost per 1kg (1000g) of weight
}
Config.DailyRentCost = 500 -- Set the daily rental cost 


-- discord logs
Config.Webhook = ''
Config.BotToken = ''

Config.sellpros = 0.25 -- precentage the people lose when selling
