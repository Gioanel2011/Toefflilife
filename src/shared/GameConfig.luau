--!strict
-- Töffli Tal: unveränderliche Spielkonstanten.
-- Server-autoritativ: 15 Spieler, Startfahrrad, einmaliger Mofa-Startrabatt, Speicherintervall.

local GameConfig = {
	MAX_PLAYERS = 15,
	START_VEHICLE_ID = "bicycle",
	STARTER_MOPED_IDS = { "puch_maxi_s", "piaggio_ciao" },
	STARTER_DISCOUNT_PERCENT = 30,
	STARTER_DISCOUNT_ONCE = true,
	START_CASH = 0,
	AUTOSAVE_INTERVAL_SECONDS = 120,
	PROFILE_VERSION = 1,
}

table.freeze(GameConfig.STARTER_MOPED_IDS)
return table.freeze(GameConfig)
