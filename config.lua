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
    slots = 100,       -- set the number of slots to the stashes
    maxWeight = 1000000  -- set max weight for the stashes if you set 1000 it 1kg because the last tree numbers are grams. Default it set to 1000kg
}


-- discord logs
Config.Webhook = 'change me'
