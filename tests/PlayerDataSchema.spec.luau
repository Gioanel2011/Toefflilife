--!strict
-- Spec für das Spielerprofil-Schema.
-- Ausführbar mit: lune run tests/PlayerDataSchema.spec.luau

local GameConfig = require("../src/shared/GameConfig")
local Schema = require("../src/shared/data/PlayerDataSchema")

local function check(condition: boolean, message: string)
	assert(condition, message)
	print("OK: " .. message)
end

check(GameConfig.MAX_PLAYERS == 15, "max players is 15")
check(GameConfig.START_VEHICLE_ID == "bicycle", "start vehicle is bicycle")
check(GameConfig.STARTER_DISCOUNT_ONCE == true, "starter discount is one-time")
check(GameConfig.STARTER_DISCOUNT_PERCENT > 0, "starter discount percent is positive")
check(GameConfig.AUTOSAVE_INTERVAL_SECONDS > 0, "autosave interval is positive")
check(GameConfig.PROFILE_VERSION == Schema.VERSION, "config and schema versions match")
check(table.isfrozen(GameConfig), "game config is frozen")

local defaults: any = Schema.createDefault()
local okDefault: boolean, _errDefault: string? = Schema.validate(defaults)
check(okDefault, "default profile validates")
check(defaults.cash == 0, "default cash is zero")
check(defaults.vehicles.selected == "bicycle", "default vehicle is bicycle")
check(defaults.starterDiscountUsed == false, "discount unused by default")
check(Schema.isStarterDiscountAvailable(defaults), "discount available by default")

local badCash: any = Schema.createDefault()
badCash.cash = -5
local okBad: boolean = Schema.validate(badCash)
check(okBad == false, "negative cash is rejected")

local legacy: any = { version = 0, cash = 10 }
local migrated: any = Schema.migrate(legacy)
check(migrated.version == Schema.VERSION, "migration bumps version")
local okMigrated: boolean = Schema.validate(migrated)
check(okMigrated, "migrated legacy profile validates")

local used: any = Schema.createDefault()
used.starterDiscountUsed = true
check(Schema.isStarterDiscountAvailable(used) == false, "used discount is unavailable")

print("PlayerDataSchema.spec: all assertions passed")
