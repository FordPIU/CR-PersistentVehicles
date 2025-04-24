Config = {}

-- Server-side configuration
Config.SaveInterval = 60000           -- Interval in milliseconds for periodic saving (e.g., 60000 = 60 seconds)
Config.UpdateYieldRate = 20           -- Number of vehicle updates to process in CR.PV:PropertiesUpdate before yielding (Wait(0))
Config.RespawnDelay = 1000            -- Delay in milliseconds before respawning a persistent vehicle after it's removed unexpectedly
Config.AttachmentCheckInterval = 5000 -- Interval in milliseconds for checking pending trailer/tow attachments

-- Client-side configuration (can add more later if needed)
Config.EnableDebugUI = false -- Set to true to enable the /pvdebug command by default

-- Entity Creation Handling (Server-side)
Config.AutoRegisterPlayerSpawnedVehicles = true -- Automatically register vehicles spawned by players (e.g., via menus) if they aren't already persistent?
-- Config.DeleteNonPersistentPlayerSpawnedVehicles = false -- If AutoRegister is false, should we delete vehicles players spawn? (Use with caution)

-- Add any other configurable options here
