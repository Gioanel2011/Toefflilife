-- RequestRouter.spec: Nachweis fuer Task 05. Laeuft mit `lune run`.
local RemoteProtocol = require("../src/shared/net/RemoteProtocol")
local RequestRouter = require("../src/server/net/RequestRouter")

local function check(condition: boolean, label: string)
	assert(condition, "FAIL: " .. label)
	print("PASS: " .. label)
end

-- 1. Protokollversion und versionierte Remote-Namen.
check(type(RemoteProtocol.PROTOCOL_VERSION) == "number", "protocol version is a number")
check(RemoteProtocol.PROTOCOL_VERSION == 1, "protocol version is 1")
check(type(RemoteProtocol.REMOTES.REQUEST) == "string", "request remote name is a string")
check(type(RemoteProtocol.REMOTES.RESPONSE) == "string", "response remote name is a string")
check(string.find(RemoteProtocol.REMOTES.REQUEST, "v1") ~= nil, "request name is versioned")
check(string.find(RemoteProtocol.REMOTES.RESPONSE, "v1") ~= nil, "response name is versioned")

-- 2. Bekannte und unbekannte Aktionen.
check(RemoteProtocol.isKnownAction("ping"), "ping is known")
check(RemoteProtocol.isKnownAction("echo"), "echo is known")
check(not RemoteProtocol.isKnownAction("does-not-exist"), "unknown action rejected")
check(not RemoteProtocol.isKnownAction(123), "non-string action rejected")

-- 3. Payload-Validierung.
local okPing = RemoteProtocol.validatePayload("ping", {})
check(okPing, "ping with empty payload valid")
local okEcho, _ = RemoteProtocol.validatePayload("echo", { message = "hi" })
check(okEcho, "echo with message valid")
local badEcho = RemoteProtocol.validatePayload("echo", {})
check(not badEcho, "echo without message rejected")
local badType = RemoteProtocol.validatePayload("echo", { message = 42 })
check(not badType, "echo with wrong type rejected")
local badPayload = RemoteProtocol.validatePayload("echo", "hi")
check(not badPayload, "non-table payload rejected")
local badAction, code = RemoteProtocol.validatePayload("nope", {})
check(not badAction and code == "unknown_action", "unknown action code returned")

-- 4. Router: Registrierung, Spielerzuordnung, Erfolgspfad.
local router = RequestRouter.new()
check(not router:hasHandler("echo"), "no handler before register")
router:register("echo", function(player: any, payload: any)
	return { userId = player.UserId, message = payload.message }
end)
check(router:hasHandler("echo"), "handler registered")

local player = { UserId = 7, Name = "Test" }
local res = router:handle(player, "echo", { message = "hello" })
check(res.ok and res.data.userId == 7, "handler receives bound player")
check(res.data.message == "hello", "handler receives payload")

-- 5. Unbekannte Aktion und ungueltige Payloads werden abgewiesen.
local unknown = router:handle(player, "missing", {})
check(not unknown.ok and unknown.code == "unknown_action", "unknown action rejected by router")
local invalid = router:handle(player, "echo", {})
check(not invalid.ok and invalid.code == "invalid_payload", "invalid payload rejected by router")
local wrongType = router:handle(player, "echo", { message = 1 })
check(not wrongType.ok and wrongType.code == "invalid_payload", "wrong payload type rejected")
local nonTable = router:handle(player, "echo", "x")
check(not nonTable.ok and nonTable.code == "invalid_payload", "non-table payload rejected by router")

-- 6. Ungueltige Spieler werden abgewiesen.
local noPlayer = router:handle(nil, "echo", { message = "hi" })
check(not noPlayer.ok and noPlayer.code == "invalid_player", "nil player rejected")
local badPlayer = router:handle({ UserId = 0 }, "echo", { message = "hi" })
check(not badPlayer.ok and badPlayer.code == "invalid_player", "zero userid rejected")
local simulatedPlayer = router:handle({ UserId = -1 }, "echo", { message = "hi" })
check(not simulatedPlayer.ok and simulatedPlayer.code == "invalid_player", "simulated userid rejected by router")

-- 7. Handler-Fehler ergeben sichere Fehlerantwort ohne Details.
router:register("ping", function(_player: any, _payload: any)
	error("secret db handle leaked?")
end)
local failed = router:handle(player, "ping", {})
check(not failed.ok and failed.code == "handler_error", "handler error mapped safely")
check(string.find(failed.message or "", "secret") == nil, "no internals leaked")

-- 8. Unregister.
check(router:unregister("ping"), "unregister works")
check(not router:hasHandler("ping"), "handler removed")
local gone = router:handle(player, "ping", {})
check(not gone.ok and gone.code == "unknown_action", "removed action rejected")

print("ALL RequestRouter SPEC TESTS PASSED")
