# 15-Spieler-Playtest und Performance-Abnahme — TöffliTal

> Target: `docs/PLAYTEST.md` | Task 24 | Modus: BUILDMODUS
> Geltungsbereich: Abnahme für 15 gleichzeitige Spieler auf einem Server.

## 1. Voraussetzungen

- Build aus `default.project.json` via `rojo build` in Studio/Client geladen.
- Server mit 15 Test-Clients (Studio Multi-Client oder echte Clients).
- Frische DataStores oder Test-Namespace, damit Rabatt-/Persistenz-Tests valide sind.
- Stoppuhr, FPS-/Memory-Anzeige (Studio MicroProfiler / `stats`), Server-Konsole offen.
- Diese Datei ist die Abnahmeliste: Jede Zeile braucht ein eindeutiges Erwartungsergebnis und einen Haken.

Legende Status: `[ ]` offen, `[x]` bestanden, `[!]` fehlgeschlagen (Bug-ID notieren).

## 2. Durchführung

1. Alle 15 Spieler joinen innerhalb von 5 Minuten.
2. Jeder Tester erhält eine Spieler-Nummer P01–P15 und eine Checklisten-Kopie.
3. Pro Abschnitt führt der Lead die Schritte parallel aus und trägt Ergebnisse in Abschnitt 9 ein.
4. Abnahme gilt nur bei 100 % bestandenen Pflicht-Checks (Abschnitte 3–8).

## 3. Private Garagen — getrennte Bereiche

- [ ] **G-01 Eigene Garage:** Jeder Spieler öffnet seine Garage → Erwartung: Genau 1 private Garage pro Spieler, fremde Spieler/Avatare nicht sichtbar, keine fremden Mofas.
- [ ] **G-02 Zugriffsschutz:** P02 versucht per Exploit/Teleport in Garage von P01 zu gelangen → Erwartung: Server lehnt ab (`GarageService`: Zugriffsrecht verweigert), kein Teleport, Fehler in Server-Log ohne Stacktrace-Leak.
- [ ] **G-03 Gleichzeitigkeit:** Alle 15 öffnen gleichzeitig Garage + Hebebühne → Erwartung: Keine Vertauschung (jeder sieht nur eigenes Fahrzeug), keine Serverfehler.

## 4. Kauf- und Rabattmissbrauch

- [ ] **K-01 Startzustand:** Jeder neue Spieler hat Startfahrrad, kein Mofa, `starterDiscountUsed == false` → Erwartung: Inventar/Profil laut `PlayerDataSchema` valide.
- [ ] **K-02 Einmaliger Mofa-Rabatt:** P01–P15 kaufen je genau 1 Mofa (wahlweise Puch Maxi S / Piaggio Ciao) mit Rabatt → Erwartung: Rabattpreis abgebucht, Flag atomar auf `true`, zweiter rabattierter Kauf wird abgelehnt.
- [ ] **K-03 Doppelkauf-Parallel:** P03 sendet 2 parallele Kauf-Requests für dasselbe Mofa (Doppelklick / parallele Remotes) → Erwartung: Genau 1 Abbuchung, 1 Besitz-Eintrag, zweite Anfrage mit sicherer Fehlerantwort (`RateLimiter`/`RequestRouter`: idempotent abgelehnt).
- [ ] **K-04 Rejoin-Rabatt:** P04 kauft mit Rabatt, rejoined, versucht erneut Rabattkauf → Erwartung: Rabatt bleibt verbraucht (persistiert via `ProfileService`), voller Preis oder Ablehnung.
- [ ] **K-05 Fremdkonto:** P05 versucht Guthaben von P06 zu lesen/ändern → Erwartung: Abgelehnt, nur eigenes Wallet (`EconomyService`) les-/schreibbar.

## 5. Missionen und Lieferungen

- [ ] **M-01 Startmission Fahrrad:** Alle fahren 500 m mit Fahrrad auf Nebenstrasse → Erwartung: Fortschritt zählt nur bei plausibler Fahrt im eigenen Fahrzeug, Auszahlung genau einmal pro Missionsschlüssel.
- [ ] **M-02 Startmission Mofa:** Nach Mofakauf kurze Mofa-Mission fahren → Erwartung: Fahrrad-Distanz zählt nicht für Mofa-Mission und umgekehrt.
- [ ] **M-03 Teleport-Cheat:** P07 teleportiert 5 km (Admin-Teleport) → Erwartung: Kein Missionsfortschritt (`MissionService`: Teleport-Anteil verworfen).
- [ ] **M-04 Distanzmission:** P08 fährt 5 km kurvige Strecke + Autobahnabschnitt → Erwartung: Fortschritt plausibel, keine doppelten Auszahlungen bei Rejoin.
- [ ] **L-01 Döner-Annahme:** P09 nimmt Lieferauftrag an, Abholung am Dönerladen → Erwartung: Auftrag genau einem Spieler zugeordnet, Statuswechsel `angenommen → abgeholt → geliefert`.
- [ ] **L-02 Auslieferung:** Lieferung an zufällige Wohnadresse im Dorf → Erwartung: Nur bei Distanz- und Zustandsprüfung (nah genug, Fahrzeug intakt) erfolgt genau eine Auszahlung.
- [ ] **L-03 Parallel-Lieferungen:** 5 Spieler liefern gleichzeitig → Erwartung: Keine Vertauschung von Aufträgen/Belohnungen, jede Lieferung genau einmal vergütet.

## 6. Werkstatt — Einbau nur auf der Hebebühne

- [ ] **W-01 Negativprobe fahrend:** P10 versucht Einbau während Fahrt (Motor an, Geschwindigkeit > 0) → Erwartung: Abgelehnt (`WorkshopService`: kein aktiver Werkstattzustand).
- [ ] **W-02 Negativprobe abseits:** P10 versucht Einbau neben der Garage (nicht auf Hebebühne/markiertem Platz) → Erwartung: Abgelehnt, Hinweis „Auf Hebebühne aufbocken“.
- [ ] **W-03 Negativprobe Laptop:** Einbau-/Lackier-Request via Laptop-Terminal senden → Erwartung: Abgelehnt (Laptop darf nur Shop-Aktionen auslösen).
- [ ] **W-04 Positivprobe:** Eigenes Mofa stillstehend, Motor aus, auf Hebebühne → Vergaser + Auspuff einbauen, Lack ändern → Erwartung: Atomare Aktualisierung von Teilen/Farben, Werte via `StatsCalculator` neu berechnet, im Inventar abgebucht.
- [ ] **W-05 Kompatibilität:** Puch-Teil an Piaggio Ciao verbauen → Erwartung: Abgelehnt (inkompatibel laut `PartsCatalog`), keine Abbuchung.

## 7. Rejoin-Persistenz

- [ ] **R-01 Voll-Rejoin:** Alle 15 verlassen und joinen erneut → Erwartung: Geld, Fahrzeuge, Teile, Lacke, Missionsstand, Rabattflag identisch (kein Rollback > letztes `ProfileService`-Speicherintervall).
- [ ] **R-02 Mid-Mission-Rejoin:** P11 rejoined während aktiver Lieferung → Erwartung: Definierter Zustand (Auftrag fortgesetzt oder sauber abgebrochen, keine doppelte Auszahlung).
- [ ] **R-03 Autosave:** Server 10 Min laufen lassen, Crash simulieren (Server stoppen ohne Kick) → Erwartung: Maximal 1 Speicherintervall Verlust, keine korrupten Profile (Validierung beim Laden schlägt nicht fehl).

## 8. Treibstoff und Prüfstand

- [ ] **F-01 Verbrauch:** P12 fährt 3 km Volllast mit getuntem Zylinder → Erwartung: Tank sinkt lastabhängig (`FuelService`), Fahrrad-Verbrauch bleibt 0.
- [ ] **F-02 Tanken:** An beiden Tankstellen je 1 Tankvorgang, 1x mit zu wenig Geld → Erwartung: Erfolgreicher Tankvorgang nur bei Deckung, Guthabenänderung ausschliesslich serverseitig.
- [ ] **F-03 Liegenbleiben:** Tank leer fahren → Erwartung: Faire Lösung greift (z. B. Schieben/Abschlepp-/Kanister-Option laut Implementierung), kein Softlock, kein Gratis-Volltanken per Exploit.
- [ ] **D-01 Prüfstand positiv:** Eigenes Mofa korrekt aufgebockt im Laden, Dyno-Lauf starten → Erwartung: Lauf erfolgreich, Werte identisch zu `StatsCalculator` (Fahrphysik == Prüfstand), letztes Ergebnis gespeichert.
- [ ] **D-02 Prüfstand negativ:** Dyno mit fremdem / fahrendem / falsch geparktem Mofa oder mit Client-gesendeten Werten → Erwartung: Abgelehnt, keine Speicherung manipulierter Werte.

## 9. Streaming- und Serverperformance (15 Spieler, Pflicht)

Messfenster: 10 Minuten Vollast (alle fahren, 5 liefern, 3 schrauben, 2 am Dyno). Erwartungsergebnisse sind Abnahmekriterien.

- [ ] **P-01 Server-FPS:** `stats` Server-Herzfrequenz ≥ 55 FPS im Mittel, keine Einbrüche < 30 FPS länger als 2 s → Erwartung: Bestanden. Gemessen: ___ FPS avg / ___ FPS min.
- [ ] **P-02 Speicher:** ServerMemory wächst nicht unbegrenzt (< 1,5 GB, kein Leak über Messfenster) → Erwartung: Bestanden. Gemessen: ___ MB Start / ___ MB Ende.
- [ ] **P-03 Ping:** Client-Ping p95 < 200 ms im LAN-nahen Test, kein Rubberbanding beim Fahren → Erwartung: Bestanden. Gemessen p95: ___ ms.
- [ ] **P-04 Streaming:** Tal bleibt begrenzt (keine unendliche Fläche), alle POIs (Dorf, Tankstellen ×2, Töffli-Laden, Prüfstand, Dönerladen, Garagenanker) erreichbar, keine unsichtbaren Wände/Löcher bei 15 Spielern → Erwartung: Bestanden.
- [ ] **P-05 Fehlerfreiheit:** Server- und Client-Konsolen ohne rote Fehler über das Messfenster (Ratelimit-Ablehnungen als Warnungen ok) → Erwartung: Bestanden.
- [ ] **P-06 Ratelimit-Belastung:** 1 Spieler spammt Shop-/Werkstatt-Remotes (10 req/s, 30 s) → Erwartung: Legitime Nutzung der anderen 14 ungestört, Spammer gedrosselt mit sicherer Fehlerantwort, keine doppelten Käufe/Umbauten.

## 10. Ergebnisprotokoll (bei Abnahme ausfüllen)

| Datum | Server-Build (Commit) | Tester (15) | Bestanden / Gesamt | Freigabe |
|---|---|---|---|---|
| ____-__-__ | `________` | P01–P15: ___ | __ / 31 | [ ] JA / [ ] NEIN |

Fehlgeschlagene Checks:

| Check-ID | Beobachtung | Bug-ID/Notiz |
|---|---|---|
|  |  |  |

Unterschrift QA-Lead: ____________________

## 11. Schnellstart für den Testleiter

```sh
rokit install
rojo build default.project.json -o build/ToeffliTal.rbxlx
selene src/server/bootstrap.server.luau src/client/bootstrap.client.luau
# Studio: 15 Clients starten, Abschnitt 2–9 der Reihe nach abhaken
```

## 12. Task 03 – PC-Auf-/Absteigen am Startfahrrad (Studio-Playtest)

- **Datum:** 2026-11-06
- **Umgebung:** Roblox Studio (Windows), Place `build/ToeffliTal.rbxlx` aus `rojo build default.project.json`, Play Solo, Client- und Server-DataModel über Roblox Studio MCP.
- **Testobjekt:** `StarterBicycle_8195446797` (Tag `ToeffliBicycle`, `OwnerUserId` gesetzt), Sitz `Seat`, Antrieb `Drive`.

| Check | Erwartung | Ergebnis |
|---|---|---|
| E-Aufsteigen bei 4,2 Studs Abstand | `mounted=true`, `Humanoid.Sit=true`, `Seat.Occupant` = Humanoid | bestanden |
| Fahren mit W | Geschwindigkeit steigt bis max. 18 Studs/s, **gesamtes Model** fährt | bestanden (18,0 Studs/s; Abstand `Seat`↔`Drive` konstant 0,85 Studs über die ganze Fahrt) |
| Fahrer fährt mit | `Seat` und `HumanoidRootPart` bewegen sich synchron mit `Drive` | bestanden (`Seat.Z` = `Drive.Z` − 0,60; `Root.Z` = `Seat.Z`) |
| Ausrollen ohne Eingabe | Abfall um 6 Studs/s² bis 0 | bestanden (17,6 → 0 in ca. 2,7 s) |
| Bremsen mit Space bei 12,6 Studs/s | Abfall um 22 Studs/s², Fahrer bleibt im Sitz | bestanden (12,6 → 2,5 in 0,64 s; 14,5 → 0 in ca. 1,0 s, `Sit=true`) |
| E-Absteigen | `mounted=false`, `Humanoid.Sit=false`, Sitz frei | bestanden |
| Doppel-Mount | zweites E bei belegtem Sitz ändert nichts | bestanden (Debounce 0,5 s + Mount-Guard) |
| Fremdes Fahrrad | nur `OwnerUserId == LocalPlayer.UserId`, Distanz ≤ 10 Studs | bestanden (Tag- und Attributfilter im Code, kein Fremdzugriff im Test) |
| Konsole | keine Fehler aus dem Bicycle-Controller | bestanden |

### Gefundene und behobene Defekte

1. `findSeat` prüfte `IsA("SeatPart")` – diese Klasse existiert in Roblox nicht. Der Sitz wurde nie gefunden; korrigiert auf `IsA("Seat")`.
2. Space (Bremse) löste den Standard-Sprung aus und warf den Fahrer aus dem Sitz, während `_mounted` true blieb. Jetzt wird `Humanoid.Jump` während der Fahrt unterdrückt und ein externes Absteigen synchronisiert den Controller-Zustand.
3. Charakter und Fahrrad spawnen beide bei `(0, 5, 0)`; Roblox setzt den Spieler automatisch auf den Sitz. Der Controller übernimmt diesen Auto-Sitz (`_adoptAutoSeat`), sonst hätte E nicht absteigen können.
4. Build-Mapping fehlte: `ServerScriptService.shared` (Quelle `src/shared`) ergänzt, weil Servermodule `require("../../shared/...")` verwenden.
5. **Nur eine Platte fuhr:** Der Controller setzte `Drive.CFrame`; anchored Parts folgen keinen Welds, Sitz/Räder/Fahrer blieben stehen. Bewegung läuft jetzt über `Model:PivotTo` auf dem gesamten Model. Nachweis: `Seat`↔`Drive` bleibt bei 0,85 Studs, `Seat` und `HumanoidRootPart` wandern synchron mit `Drive`.

### Einschränkungen und offene Blocker (nicht Task 03)

- Der Client-Bootstrap hängt bei `InvokeServer("VehicleSelect")` (keine Antwort binnen 4 s); für diesen Test wurde der Controller direkt im Client gestartet. Der Server-Bootstrap meldet „ready“.
- `cloud_117748261035197.Script:149: Expected 'in' when parsing for loop` stammt aus einer anderen geöffneten Place und nicht aus diesem Projekt.
- Die Bewegung läuft clientseitig auf anchored Parts: Andere Clients und der Server sehen sie nicht. Das ist ein Sync-Thema für die spätere Fahrzeug-/Garagen-Integration und kein Task-03-Punkt.
- Ein fehlerhafter Vorzustand (Sitz bereits relativ zum `Drive` verschoben, hängende Taste) verfälschte einen Zwischenlauf; die Endmessung erfolgte mit frisch gespawntem Rad.

## 13. Minimal spielbar (Task 06) — Vertical Slice

> Target: `docs/PLAYTEST.md` | Task 06 | Modus: BUILDMODUS
> Abnahme nur nach tatsächlicher Studio-Ausführung. Keine Abhakung ohne Durchführung.

### 13.1 Voraussetzungen / Umgebung

- **Datum:** 2026-11-06 (Lauf 2)
- **Tester:** Agent (Roblox Studio MCP, Play Solo, 1 Client)
- **Umgebung:** Roblox Studio (Windows), Place „Töffli-Leben“ (placeId `125171592308827`), Studio-Instanz `56f661eb-4aad-4538-9ed8-7511e5265740`
- **Build:** Das Repo wurde 1:1 gemäss `default.project.json` in das Edit-DataModel gemappt (34 Skripte: `ReplicatedStorage.Shared` 7, `ServerScriptService.Services` 15, `ServerScriptService.shared` 7, `StarterPlayerScripts` 5). Die alten Place-Inhalte (`SwissMap`, `Spawn Car`, `Lighting`) wurden für den Lauf nach `ServerStorage.ToeffliTalLegacy_Temp` verschoben und danach zurückverschoben; die alte SwissMap-Terrainfläche wurde nur im Play-Session (nicht gespeichert) geleert, damit die neue Greybox-Welt gemessen wird.
- **DataModel beim Play:** Client + Server verfügbar
- **Lauf 1 (2026-11-06):** abgebrochen wegen BLOCKER-B01 (veraltete Studio-Place). Siehe 13.5.

### 13.2 Minimal-Checks

Legende Status: `[ ]` offen, `[x]` bestanden, `[!]` fehlgeschlagen (Bug-ID notieren).

- [x] **MS-01 Place startet ohne roten Output** — Erwartung: Server- und Client-Konsolen ohne rote Fehler beim Start.
- [x] **MS-02 Spieler spawnt sicher** — Erwartung: Charakter erscheint an sicherer Position, kein Fall durch Terrain, Kamera folgt.
- [x] **MS-03 Genau ein Startfahrrad erscheint** — Erwartung: Pro Spieler genau ein `StarterBicycle_<UserId>` mit Tag `ToeffliBicycle`, Seat und Drive in `Workspace.ToeffliTalVehicles` (bzw. Workspace).
- [x] **MS-04 E-Aufsteigen funktioniert** — Erwartung: Taste E steigt bei ≤ 10 Studs Abstand auf das eigene Fahrrad auf (`mounted=true`, `Humanoid.Sit=true`).
- [x] **MS-05 Fahren funktioniert** — Erwartung: W beschleunigt bis max. 18 Studs/s, gesamtes Model bewegt sich.
- [x] **MS-06 Bremsen funktioniert** — Erwartung: Space bremst mit 22 Studs/s², Fahrer bleibt im Sitz.
- [x] **MS-07 E-Absteigen funktioniert** — Erwartung: Nochmal E steigt ab (`mounted=false`, `Humanoid.Sit=false`, Sitz frei), kein Doppel-Mount.
- [x] **MS-08 Auftrag kann angenommen werden** — Erwartung: `DeliveryOrder` Remote liefert gültigen `orderId`, Status `angenommen`, serverseitig zugeordnet.
- [x] **MS-09 Auftrag kann abgeholt werden** — Erwartung: `DeliveryPickup` mit gültigem `orderId` wechselt Status auf `abgeholt`, nur am Dönerladen.
- [x] **MS-10 Auftrag kann ausgeliefert werden** — Erwartung: `DeliveryDeliver` mit gültigem `orderId` wechselt Status auf `geliefert`, nur bei Distanz- und Zustandsprüfung.
- [x] **MS-11 Gutschrift erfolgt serverseitig genau einmal** — Erwartung: Genau eine Belohnungsgutschrift pro erfolgreichem Auftrag, keine Client-Entscheidung, keine doppelte Auszahlung bei Wiederholung.

### 13.3 Durchgeführte Studio-Ausführung (2026-11-06, Lauf 2)

1. Repo-Baum ins Edit-DataModel gemappt, Altinhalte nach `ServerStorage` ausgelagert, `start_stop_play(is_start=true)` → „Game Started“, Client + Server verfügbar.
2. Server-Log: `[ToeffliTal][Server] Bootstrap ready: systems integrated`.
3. Server-Workspace: `Workspace.ValleyWorld` (Greybox: Ground, Wände, Strassen, Dörfer, Dönerplatz, 15 Garagen, Lieferpunkte) und `Workspace.ToeffliTalVehicles` vorhanden.
4. Client-Log: **keine** Meldung `[ToeffliTal][Client] Bootstrap ready …`; `PlayerGui` enthält nur `Freecam`, kein `DeliveryPrompt`-GUI.
5. Sichtprüfung Server: genau ein `StarterBicycle_8195446797`, Attribute `OwnerUserId=8195446797`, `IsStarterBicycle=true`, Tag `ToeffliBicycle=true`, Kinder `Seat` (`Seat`), `Drive`, `WheelFront`, `WheelRear`, `Handlebar` + 4 `WeldConstraint`, alle anchored, Pivot `(0, 5, 0)`.
6. Sichtprüfung Client/Server: Charakter `HRP = (0.0, 7.9, 0.0)`, `HumanoidStateType.Running`, `FloorMaterial=Plastic`, `Health=100`; Kamera `CameraType.Custom`, Subjekt `Humanoid`, Distanz 12.9 Studs.
7. Taste **E** bei 2.4 Studs Abstand zum Sitz → keine Aufstieg (`Humanoid.Sit=false`, `Seat.Occupant=nil`).
8. Taste **W** → Charakter läuft (Eingaben kommen an) und setzt sich durch die Standard-Roblox-Physik auf den Sitz; kein Controller-Fahrverhalten.
9. Remote-Test vom Client: `VehicleSelect` → `TIMEOUT(3s)`, `EconomyGet` → `TIMEOUT(3s)`; `DeliveryOrder` antwortet sofort.
10. Server-Introspektion: `RequestRouter` exportiert `new, handle, register, unregister, hasHandler, setRateLimit, setRateLimiter, getRateLimiter` — **kein** `init`, **kein** `registerHandler`.
11. `DeliveryOrder {vehicleType="bicycle"}` → `{ok=true, data={ok=false, code="deliveryUnavailable"}}`.
12. `ValleyWorld.getDeliveryPoints()` → Array `1..7` aus `{Name, Position}` (6 `Delivery_House_A…F` + `Delivery_Doner_Pickup`), **ohne** `shopPosition`/`addresses`.

**Beobachtete Konsolenausgabe (Auszug, projekteigen):**

```
[ToeffliTal][Server] Bootstrap ready: systems integrated
```

**Projektexterne Ausgabe (6×, nicht aus diesem Repo):**

```
cloud_117748261035197.Script:149: Expected 'in' when parsing for loop, got 'do'
```

### 13.4 Ergebnisprotokoll (Lauf 2, 2026-11-06)

| Check-ID | Erwartung | Tatsächliches Ergebnis | Status |
|---|---|---|---|
| MS-01 | Keine roten Fehler beim Start | Projekteigene Skripte fehlerfrei (`[ToeffliTal][Server] Bootstrap ready`); 6× projektexterne Fehler `cloud_117748261035197.Script:149` aus der Studio-Umgebung. | [!] extern |
| MS-02 | Sicherer Spawn | Charakter `(0.0, 7.9, 0.0)`, `Running`, `Health=100`, kein Durchfallen; Kamera `Custom` am `Humanoid` (12.9 Studs). Erster Spawn lag auf der Alt-Terrainfläche `(0, 30, 0)`, ebenfalls stabil. | [x] |
| MS-03 | Genau ein Startfahrrad | Genau 1× `StarterBicycle_8195446797` in `Workspace.ToeffliTalVehicles`, Owner-Attribut, Tag `ToeffliBicycle`, `Seat` + `Drive`, 2 Räder, Lenker, anchored, Pivot `(0, 5, 0)`. | [x] |
| MS-04 | E-Aufsteigen | E bei 2.4 Studs Abstand ohne Wirkung (`Sit=false`, `Seat.Occupant=nil`); der Client-Controller startet nie (siehe BLOCKER-B02). | [!] |
| MS-05 | Fahren | W läuft nur zu Fuss; kein Controller-Fahrverhalten, kein Model-Antrieb (BLOCKER-B02). | [!] |
| MS-06 | Bremsen | Nicht erreichbar, da kein Mount/Controller (BLOCKER-B02). | [!] |
| MS-07 | E-Absteigen | Nicht erreichbar, da kein Mount/Controller (BLOCKER-B02). | [!] |
| MS-08 | Auftrag annehmen | `DeliveryOrder {vehicleType="bicycle"}` → `{ok=true, data={ok=false, code="deliveryUnavailable"}}` (BLOCKER-B03). | [!] |
| MS-09 | Auftrag abholen | Nicht erreichbar: ohne Auftrag kein `orderId`, Weltpunkte nicht auflösbar (BLOCKER-B03). | [!] |
| MS-10 | Auftrag ausliefern | Nicht erreichbar (BLOCKER-B03). | [!] |
| MS-11 | Genau einmal Gutschrift | Nicht verifizierbar, weil kein Auftrag erzeugt werden kann (BLOCKER-B03). Serverseitige Einmal-Auszahlung ist im Lune-Test abgedeckt, nicht in der Laufzeit. | [!] |

**Gesamtergebnis Lauf 2: 2 / 11 bestanden — Abnahme NICHT bestanden.**

### 13.5 Blocker

| Blocker | Beobachtung | Ursache / Beleg | Betroffene Checks |
|---|---|---|---|
| BLOCKER-B01 | Studio-Place enthielt beim ersten Lauf `SwissMap`/`Spawn Car` statt `ValleyWorld`/`ToeffliTalVehicles`. | Place veraltet; Repo-Baum war nicht geladen. In Lauf 2 durch 1:1-Mapping des Repo-Baums behoben. | MS-01…MS-11 (Lauf 1) |
| BLOCKER-B02 | Client-Bootstrap bleibt bei `VehicleSelect` hängen; kein `[ToeffliTal][Client] Bootstrap ready`, kein `DeliveryPrompt`-GUI, kein Fahrrad-Controller. | `bootstrap.server.luau` ruft `RequestRouter.init` und `RequestRouter.registerHandler` auf; `RequestRouter` exportiert nur `new/register/handle/…`. Beide `callOptional`-Aufrufe sind No-Ops, daher erhalten alle Aktions-Remotes ausser den drei Delivery-Remotes kein `OnServerInvoke`; `InvokeServer` im Client wartet ewig (`TIMEOUT(3s)` gemessen). | MS-04, MS-05, MS-06, MS-07 |
| BLOCKER-B03 | Alle Delivery-Aktionen antworten mit `deliveryUnavailable`. | `DeliveryService.resolveWorldPoints` erwartet `shopPosition` + `addresses`; `ValleyWorld.getDeliveryPoints()` liefert ein Array `{1..7} = {Name, Position}`. Damit bleiben Shop und Adressen `nil` und `buildRuntime()` gibt `nil` zurück. | MS-08, MS-09, MS-10, MS-11 |

### 13.6 Nächste Schritte

- B02 beheben: generische Aktionen über eine Router-Instanz registrieren (`RequestRouter.new()` + `router:register(action, handler)` + `OnServerInvoke = function(player, payload) return router:handle(player, action, payload) end`) oder `init`/`registerHandler` im Router ergänzen; danach muss der Client `Bootstrap ready` melden und E mounten.
- B03 beheben: `DeliveryService.resolveWorldPoints` an das Array-Format von `ValleyWorld.getDeliveryPoints()` anpassen (Pickup-Punkt als Shop, übrige als Adressen) oder `ValleyWorld.getDeliveryPoints()` um `shopPosition`/`addresses` erweitern.
- Nach beiden Fixes Lauf 3 mit MS-04…MS-11 wiederholen. Task 06 bleibt bis dahin offen; keine Abhakung ohne bestandene Checks.

### 13.7 Re-Check 2026-11-09 — kein gültiger Lauf möglich

- **Datum:** 2026-11-09
- **Tester:** Agent (Code-Prüfung + Roblox-Studio-Bridge)
- **Ergebnis:** Kein durchführbarer Lauf. Task 06 bleibt offen; keine Abhakung von MS-01…MS-11.

| Blocker | Prüfung 2026-11-09 | Beleg |
|---|---|---|
| B01 (Place) | Die geöffnete Place `Töffli-Leben` ist weiterhin nicht gemappt. `search_game_tree` auf `ServerScriptService` (Edit) liefert nur den Wurzelknoten, keine Skripte. | `ServerScriptService` leer; ein Play würde nicht den Repo-Build ausführen. |
| B02 (Router) | Weiterhin vorhanden. `bootstrap.server.luau` ruft `RequestRouter.init` (Zeile 143) und `RequestRouter.registerHandler` (Zeile 167) über `callOptional`; `RequestRouter.luau` exportiert nur `new/setRateLimiter/getRateLimiter/setRateLimit/register/unregister/hasHandler/handle`. Beide Aufrufe sind No-Ops, generische Remotes (`VehicleSelect`, `EconomyGet`, …) erhalten kein `OnServerInvoke`. | Client-`requestViaRouter("VehicleSelect")` hängt; `Bootstrap ready` entfällt; MS-04…MS-07 bleiben blockiert. |
| B03 (Lieferpunkte) | Weiterhin vorhanden. `DeliveryService.resolveWorldPoints` liest `points.shopPosition`/`points.addresses`; `ValleyWorld.getDeliveryPoints` liefert nur ein Array aus `{ Name, Position }`. Damit bleiben Shop `nil` und Adressen leer, `buildRuntime()` gibt `nil` zurück. | `deliveryUnavailable` für `DeliveryOrder`; MS-08…MS-11 bleiben blockiert. |

**Fazit:** Die Voraussetzungen für einen gültigen Studio-Lauf fehlen weiterhin (kein gemappter Build + zwei offene Code-Blocker). Es wird keine Abhakung vorgenommen. Erforderlich ist die Eskalation an MiMo-V2.6 Pro / Kimi K3.1 Pro bzw. ein eigener Fix-Task für B02/B03 vor der erneuten Abnahme.

### 13.8 Lauf 3 (2026-11-09) — Minimal spielbar bestanden

- **Datum:** 2026-11-09
- **Tester:** Agent (Roblox-Studio-Bridge, Play Solo, 1 Client)
- **Umgebung:** Roblox Studio (Windows); frische Place aus `rojo build default.project.json -o build/ToeffliTal.rbxlx`, neu geöffnet statt der veralteten `Töffli-Leben`.
- **Vorher behoben (Task 33):** B02 (echter generischer Router + `VehicleSelect`/`EconomyGet`), B03 (`resolveWorldPoints` akzeptiert das Array-Format; `Vector3` wird als `type == "vector"` erkannt), Weltaufbau-Abbruch (`ColorShift_Top`/`ColorShift_Bottom`).
- **DataModel:** Client + Server verfügbar; 429 Skripte im Play-Place.

| Check-ID | Erwartung | Tatsächliches Ergebnis | Status |
|---|---|---|---|
| MS-01 | Keine roten Fehler beim Start | `[ToeffliTal][Server] Bootstrap ready` und `[ToeffliTal][Client] Bootstrap ready`; keine projekteigenen Fehler. Die verbleibende `cloud_117748261035197.Script:149`-Meldung ist projektextern (0 Treffer bei 429 Skripten im Place). | [x] |
| MS-02 | Sicherer Spawn | Charakter `(0, 12.84, 0)`, `Health=100`, `HumanoidState=Running`, `FloorMaterial=SmoothPlastic`, kein Durchfallen. | [x] |
| MS-03 | Genau ein Startfahrrad | 1× `StarterBicycle_8195446797` in `Workspace.ToeffliTalVehicles`, Pivot `(0,5,0)`, `Seat` + `Drive`, 9 Teile, `OwnerUserId=8195446797`, `IsStarterBicycle=true`, Tag `ToeffliBicycle`. | [x] |
| MS-04 | E-Aufsteigen | E bei 3 Studs Abstand → `sit=true`, `Seat.Occupant=GioBlox_135`, `HumanoidState=Seated`. | [x] |
| MS-05 | Fahren | W: 0 → 18,0–18,1 Studs/s; gesamtes Model bewegt sich synchron. | [x] |
| MS-06 | Bremsen | Space bei 18 Studs/s: 18,0 → 12,8 → 6,4 → 1,6 → 0 in ca. 0,9 s (≈22 Studs/s²), Fahrer bleibt im Sitz. | [x] |
| MS-07 | E-Absteigen | E → `sit=false`, `Seat.Occupant=nil`, `HumanoidState=Running`; erneutes E mountet wieder. | [x] |
| MS-08 | Auftrag annehmen | `DeliveryOrder {vehicleType="bicycle"}` → `{ok=true, orderId="8195446797-1", addressId="Delivery_Village_Seeblick_Slot_09", state="accepted", payout=25, starter=true}`. | [x] |
| MS-09 | Auftrag abholen | Spieler bei `(0,5,18)`, `DeliveryPickup {orderId}` → `state="pickedUp"`. | [x] |
| MS-10 | Auftrag ausliefern | Spieler bei `(267.3,4.3,254.8)`, `DeliveryDeliver {orderId}` → `state="delivered"`, `payout=25`. | [x] |
| MS-11 | Genau einmal Gutschrift | `EconomyGet` vorher `cash=0`, nachher `cash=25`; zweites `DeliveryDeliver` → `alreadyDelivered`; final `cash=25`. | [x] |

**Gesamtergebnis Lauf 3: 11 / 11 bestanden — Minimal spielbar bestanden.**

Hinweis: Der Lieferloop wurde über die echten Remotes geprüft; der Spieler wurde für Abholung/Auslieferung serverseitig an die Weltpunkte gesetzt (Distanz 5,8 bzw. 4,3 Studs < 12). Der Start-Radius steht auf 700, damit die Dorfrouten mit dem Startfahrrad gelten.

## 14. Minimal- und Weltabnahme (Task 31)

> Target: `docs/PLAYTEST.md` | Task 31 | Modus: BUILD-MODUS
> Geltungsbereich: Dokumentation der Abnahmeliste für Minimal-Spawn, Fahrradfahrt, Dönerloop und die prozedurale Welt. Keine Testergebnisse werden vor Durchführung eingetragen; Abhakung nur nach tatsächlichem Studio-Lauf.

### 14.1 Voraussetzungen / Umgebung

- Build aus `default.project.json` via `rojo build` in Studio/Client geladen.
- `Workspace.ValleyWorld` nach Serverstart vorhanden; `build(parent)` idempotent (Task 30).
- Test mit 1 Client (Minimal/Welt) bzw. 15 Clients (Streaming/Serverlast, siehe Abschnitt 9).
- Stoppuhr, FPS-/Memory-Anzeige (Studio MicroProfiler / `stats`), Server-Konsole offen.
- Jede Zeile braucht ein eindeutiges Erwartungsergebnis und ein Feld für das tatsächliche Ergebnis.

Legende Status: `[ ]` offen, `[x]` bestanden, `[!]` fehlgeschlagen (Bug-ID notieren).

### 14.2 Checkliste — Minimal-Spawn

- [ ] **WA-MS-01 Minimal-Spawn (Place startet ohne roten Output)** — Erwartung: Server- und Client-Konsolen ohne rote Fehler beim Start; Bootstrap meldet ready. Tatsächliches Ergebnis: ___
- [ ] **WA-MS-02 Spieler spawnt sicher** — Erwartung: Charakter erscheint an sicherer Position, kein Fall durch Terrain, Kamera folgt. Tatsächliches Ergebnis: ___
- [ ] **WA-MS-03 Genau ein Startfahrrad erscheint** — Erwartung: Pro Spieler genau ein `StarterBicycle_<UserId>` mit Tag `ToeffliBicycle`, Seat und Drive in `Workspace.ToeffliTalVehicles`. Tatsächliches Ergebnis: ___
- [ ] **WA-MS-04 E-Aufsteigen funktioniert** — Erwartung: Taste E steigt bei ≤ 10 Studs Abstand auf das eigene Fahrrad auf (`mounted=true`, `Humanoid.Sit=true`). Tatsächliches Ergebnis: ___
- [ ] **WA-MS-05 Fahren funktioniert** — Erwartung: W beschleunigt bis max. 18 Studs/s, gesamtes Model bewegt sich. Tatsächliches Ergebnis: ___
- [ ] **WA-MS-06 Bremsen funktioniert** — Erwartung: Space bremst mit 22 Studs/s², Fahrer bleibt im Sitz. Tatsächliches Ergebnis: ___
- [ ] **WA-MS-07 E-Absteigen funktioniert** — Erwartung: Nochmal E steigt ab (`mounted=false`, `Humanoid.Sit=false`, Sitz frei), kein Doppel-Mount. Tatsächliches Ergebnis: ___

### 14.3 Checkliste — Fahrradfahrt und Dönerloop

- [ ] **WA-DL-01 Auftrag kann angenommen werden** — Erwartung: `DeliveryOrder` liefert gültigen `orderId`, Status `angenommen`, serverseitig zugeordnet. Tatsächliches Ergebnis: ___
- [ ] **WA-DL-02 Auftrag kann abgeholt werden** — Erwartung: `DeliveryPickup` mit gültigem `orderId` wechselt Status auf `abgeholt`, nur am Dönerladen. Tatsächliches Ergebnis: ___
- [ ] **WA-DL-03 Auftrag kann ausgeliefert werden** — Erwartung: `DeliveryDeliver` mit gültigem `orderId` wechselt Status auf `geliefert`, nur bei Distanz- und Zustandsprüfung. Tatsächliches Ergebnis: ___
- [ ] **WA-DL-04 Gutschrift erfolgt serverseitig genau einmal** — Erwartung: Genau eine Belohnungsgutschrift pro erfolgreichem Auftrag, keine Client-Entscheidung, keine doppelte Auszahlung bei Wiederholung. Tatsächliches Ergebnis: ___
- [ ] **WA-DL-05 Fahrradfahrt zählt für Fahrradmission** — Erwartung: 500 m mit Fahrrad auf Nebenstrasse zählt Fortschritt; Mofa-Distanz zählt nicht. Tatsächliches Ergebnis: ___

### 14.4 Checkliste — Welt: Dörfer, Kirche, Garagen

- [ ] **WA-WL-01 Zwei Dörfer mit einzigartigen Häusern** — Erwartung: Genau 2 Dörfer, je 10 Häuser, alle 20 Häuser unterscheidbar (Dekoration/Farbe), je eine frei erreichbare Eingangstür; keine Duplikate. Tatsächliches Ergebnis: ___
- [ ] **WA-WL-02 Eine Kirche** — Erwartung: Genau 1 Kirche an `WorldLayout.CHURCH`, erreichbar, keine Duplikate. Tatsächliches Ergebnis: ___
- [ ] **WA-WL-03 15 gleiche private Garagen** — Erwartung: Exakt 15 Garagen aus `GarageFactory`, identische Grösse/Farbe/Ausstattung, gleicher Abstand zum Dönerladen, Mindestabstand untereinander, eindeutige Anker-Namen. Tatsächliches Ergebnis: ___
- [ ] **WA-WL-04 Garagen privat getrennt** — Erwartung: Jeder Spieler erhält genau einen Anker; fremde Spieler/Avatare/Mofas in fremder Garage nicht sichtbar; Fremdzugriff serverseitig abgelehnt. Tatsächliches Ergebnis: ___

### 14.5 Checkliste — Strassen und Verkehr

- [ ] **WA-ST-01 Strassenmarkierungen lesbar** — Erwartung: Markierungen an Strassen vorhanden und bei Sonne/Wolken lesbar (AtmosphereBuilder). Tatsächliches Ergebnis: ___
- [ ] **WA-ST-02 Stopstrassen mit Haltelinien** — Erwartung: Vor jeder Stopstrasse genau ein Stoppschild und eine gut sichtbare Haltelinie; Kreuzung befahrbar. Tatsächliches Ergebnis: ___
- [ ] **WA-ST-03 Kreisel befahrbar** — Erwartung: Kreisel flach befahrbar, kein Mittelstreifen im Inneren, keine Kollision. Tatsächliches Ergebnis: ___
- [ ] **WA-ST-04 Brücken stufenlos befahrbar** — Erwartung: Jede Brücke verbindet Fahrbahn stufenlos, seitliche Begrenzungen sichtbar, vollständig über Wasser, mit Fahrrad/Mofa ohne Stoss/Absprung. Tatsächliches Ergebnis: ___
- [ ] **WA-ST-05 Schilder blockieren nicht** — Erwartung: Verkehrszeichen blockieren weder Fahrbahn noch Gehweg noch Garagenzufahrt. Tatsächliches Ergebnis: ___

### 14.6 Checkliste — Gewässer, Weiden, Vegetation

- [ ] **WA-NAT-01 See und drei Bäche** — Erwartung: Genau 1 See und 3 Bäche aus WorldZones/Terrain vorhanden; Wasserflächen konsistent; Brücken liegen über Wasser. Tatsächliches Ergebnis: ___
- [ ] **WA-NAT-02 Weiden umzäunt** — Erwartung: Alle Weiden vollständig umzäunt mit erkennbarem Tor, grüner Boden ohne braune Stellen, keine Tiere, keine Strassenblockade, keine Zäune in Wasser/Gebäuden/Garagenzufahrten. Tatsächliches Ergebnis: ___
- [ ] **WA-NAT-03 Vegetation in Ausschlusszonen frei** — Erwartung: Bäume/Wälder nur ausserhalb von Strassen, Wasser, Gebäuden, Garagen, Lieferpunkten und Weiden; keine Bäume auf Fahrbahnen/Eingängen/Hebebühne; freie Sichtachsen. Tatsächliches Ergebnis: ___
- [ ] **WA-NAT-04 Gras-Performance** — Erwartung: Grasbüschel (`ToeffliGrass`) nur ausserhalb von Strassen/Wasser/Gebäuden/Garagen/Lieferpunkten mit Sicherheitsabstand; GrassController animiert nur nahe Chunks (≤ 24, Heartbeat-Sammelupdate 0,15 s, NEAR 120/FAR 150, Amplitude 0,08) ohne Frame-Einbruch oder Konsolenfehler; keine Server-CFrame-/Physikänderung. Tatsächliches Ergebnis: ___

### 14.7 Checkliste — Streaming und Serverlast (Basis)

- [ ] **WA-PERF-01 Streaming begrenzt** — Erwartung: Tal bleibt begrenzt (keine unendliche Fläche); alle POIs (Dorf, Tankstellen ×2, Töffli-Laden, Prüfstand, Dönerladen, Garagenanker) erreichbar; keine unsichtbaren Wände/Löcher. Tatsächliches Ergebnis: ___
- [ ] **WA-PERF-02 Server-FPS (Einzelclient)** — Erwartung: `stats` Server-Herzfrequenz ≥ 55 FPS im Mittel, keine Einbrüche < 30 FPS länger als 2 s. Gemessen: ___ FPS avg / ___ FPS min.
- [ ] **WA-PERF-03 Speicher (Einzelclient)** — Erwartung: ServerMemory wächst nicht unbegrenzt (< 1,5 GB, kein Leak über Messfenster). Gemessen: ___ MB Start / ___ MB Ende.
- [ ] **WA-PERF-04 Konsolen fehlerfrei** — Erwartung: Server- und Client-Konsolen ohne rote Fehler über das Messfenster (Ratelimit-Ablehnungen als Warnungen ok). Tatsächliches Ergebnis: ___
- [ ] **WA-PERF-05 15-Spieler-Abnahme** — Erwartung: Siehe Abschnitt 9 (P-01…P-06) und Task 32; alle Pflicht-Checks mit 15 Spielern bestanden. Tatsächliches Ergebnis: ___

### 14.8 Ergebnisprotokoll (bei Abnahme ausfüllen)

| Datum | Server-Build (Commit) | Tester | Bestanden / Gesamt | Freigabe |
|---|---|---|---|---|
| ____-__-__ | `________` | ___ | __ / 30 | [ ] JA / [ ] NEIN |

Fehlgeschlagene Checks:

| Check-ID | Beobachtung | Bug-ID/Notiz |
|---|---|---|
|  |  |  |

Unterschrift QA-Lead: ____________________

### 14.9 Hinweise

- Keine erfundenen Testergebnisse; keine Abhakung ohne Durchführung.
- Nicht bestandene Punkte bleiben offen und erzeugen einen konkreten Korrekturhinweis (siehe Task 32).
- Die 15-Spieler-Performance-Abnahme erfolgt in Abschnitt 9 / Task 32; hier nur Basis-Streaming und Einzelclient-Serverlast.

## 15. Task 32 — 15-Spieler-Abnahme (Versuch 2026-11-09)

> Target: `docs/PLAYTEST.md` | Task 32 | Modus: BUILD-MODUS
> **Ergebnis: NICHT BESTANDEN / nicht vollständig durchführbar. Task 32 bleibt offen.**

### 15.1 Umgebung und Build

- **Datum:** 2026-11-09
- **Tester:** Agent (Roblox Studio MCP, Studio `0.746.0.7461269`, Windows 10, 32 GB RAM)
- **Build:** frischer `rojo build default.project.json -o build/ToeffliTal.rbxlx` (Rojo 7.7.1), geöffnet als `ToeffliTal.rbxlx`; zusätzlich `build/ToeffliTal.rbxl` für CLI-Versuche.
- **Testarten:**
  1. `StudioTestService:ExecuteMultiplayerTestAsync(8, "task32")` (Studio-Mehrclient, 8 simulierte Clients).
  2. Play Solo mit echtem Konto `GioBlox_135` (`UserId 8195446797`).
  3. Server-Report-Script im **Game-VM** (nicht Command-Bar-VM) für Garage- und Weltzustand.
- **Konsolen:** keine projekteigenen roten Fehler. Die einzige rote Meldung ist die projektexterne `cloud_117748261035197.Script:149: Expected 'in' when parsing for loop, got 'do'` (0 Treffer im 429-Skripte-Build).

### 15.2 Blocker

| ID | Beobachtung | Beleg |
|---|---|---|
| **B32-01** | Studio-Mehrclient ist auf **8 simulierte Clients** begrenzt. `ExecuteMultiplayerTestAsync(8)` startet 8 Clients; ein zusätzliches `AddPlayers(7)` meldet `ok`, die Gesamtzahl bleibt aber 8. | 8-Client-Lauf: `[QA32] result ok=true res=players=8`; `AddPlayers(7)` -> `before=8 after=8`. Roblox-Doku: „supports up to 8 simulated clients per test session“. |
| **B32-02** | Simulierte Studio-Clients haben **negative UserIds** (`-1`…`-8`). `RequestRouter.invalidPlayer` verwirft `UserId <= 0`; dadurch antworten **alle** Remotes mit `invalid_player`. | Simulierter Client: `EconomyGet`, `VehicleSelect`, `DeliveryOrder` -> `{ok=false, code="invalid_player"}`. Code: `src/server/net/RequestRouter.luau`, Zeilen 18–30. |
| **B32-03** | Die generischen Remotes für Kauf, Shop, Werkstatt, Garage, Dyno, Tank, Mission und Transfer sind **nicht registriert**. `bootstrap.server.luau` registriert nur `VehicleSelect` und `EconomyGet`; die drei Delivery-Aktionen haben einen eigenen Router. Alle anderen antworten mit `unknown_action`. | Echter Client (`UserId 8195446797`): `VehicleBuy`, `ShopCatalog`, `ShopBuy`, `WorkshopInstall`, `WorkshopPaint`, `GarageEnter`, `DynoRun`, `FuelRefill`, `MissionProgress`, `EconomyTransfer` -> `{ok=false, code="unknown_action"}`. |
| **B32-04** | `VehicleSelect` liefert `cash=0`, während `EconomyGet` nach der Lieferung `cash=25` liefert. Der Client sieht damit zwei widersprüchliche Guthabenstände. | `VehicleSelect` -> `{cash=0, owned={bicycle}, selected="bicycle"}`; `EconomyGet` -> `{cash=25}`. Ursache: `vehicleSelectHandler` nutzt `PlayerDataSchema.createDefault().cash` statt `EconomyService`. |
| **B32-05** | Der CLI-Weg für 15 echte Clients (`-task StartServer -localPlaceFile …`) scheitert in dieser Umgebung. `-task EditFile` mit derselben Datei funktioniert. | `DataModelLoadingFailure: Die Ortsdatei kann nicht zum Lesen geöffnet werden: iostream stream error` für `.rbxl` und `.rbxlx`, mit/ohne `-placeId/-universeId/-creatorType`. |

### 15.3 Tatsächlich beobachtete Ergebnisse

- **8-Client-Lauf:** Server bootete, 8 Clients verbanden sich; der Lauf endete vorzeitig, weil ein alter Probe-Script-Timer `EndTest` auslöste. Ergebnis trotzdem verwertbar: 8 gleichzeitige Clients sind möglich, 15 nicht. Die Fahrräder der 8 Clients wurden nicht separat gezählt.
- **3-Spieler-Mehrclient-Lauf:** 3 Spieler, 3 unterschiedliche Garagen (`Garage_01`, `Garage_02`, `Garage_03`), 3 Startfahrräder, keine Doppelzuweisung.
- **Play Solo (echtes Konto):** Server- und Client-Bootstrap melden „ready“; Spawn bei `(0, 12.84, 0)`, `Health=100`, kein Durchfallen.
- **Dönerloop:** `DeliveryOrder {vehicleType="bicycle"}` -> `orderId=8195446797-1`, `addressId=Delivery_Village_Alpenblick_Slot_04`, `state=accepted`, `payout=25`. `DeliveryPickup` bei `(0, 5, 18)` -> `state=pickedUp`. `DeliveryDeliver` bei `(-347.76, 5, -360.81)` -> `state=delivered`, `payout=25`. Zweites `DeliveryDeliver` -> `alreadyDelivered`; `EconomyGet` danach `cash=25` (genau eine Gutschrift).
- **Garagen:** echter Spieler -> `Garage_01`; 15 synthetische UserIds -> 15 eindeutige Anker; 16. Zuweisung -> `nil` (`no_free_garage`).
- **Welt:** 15 Garagen (`Garage_01`…`Garage_15`), 20 Häuser (10× `House_Alpenblick_*`, 10× `House_Seeblick_*`), 1 Kirche (`Church_Alpenblick`), `Bridge_01` mit zwei Seitenteilen, 21 Lieferpunkte in `ValleyWorld.getDeliveryPoints()` (1 Döner-Abholung + 20 Adressdaten). Nur der Abholpunkt existiert als Part; die Adressen sind reine Datenpunkte.
- **Performance-Basis (1 Client, Studio):** `frames=600 avgFps=60.1 minFps=54.6 memStart=2609.5MB memEnd=2604.9MB`. Wegen Studio-Editor-Overhead **kein** Abnahmewert für den 15-Spieler-Server.

### 15.4 Checklisten-Ergebnis

Legende: `[x]` in diesem Lauf beobachtet bestanden, `[!]` beobachtet fehlgeschlagen, `[ ]` nicht durchführbar/nicht geprüft.

| Check(s) | Status | Tatsächliches Ergebnis / Grund |
|---|---|---|
| G-01 | `[!]` | `GarageEnter` -> `unknown_action`; serverseitige Zuweisung ist eindeutig, aber es gibt keinen funktionierenden Öffnungs-Remote. |
| G-02 | `[ ]` | Fremdzugriff über Remotes nicht prüfbar; `GarageService:hasAccess` ist im Lune-Test abgedeckt, nicht im 15-Spieler-Lauf. |
| G-03 | `[ ]` | 15 gleichzeitige Garagen nicht herstellbar (B32-01). 3 gleichzeitige Spieler sahen je eine eigene Garage. |
| K-01 | `[x]` | `VehicleSelect` -> `owned={bicycle}`, `selected="bicycle"`; kein Mofa. `starterDiscountUsed` nicht separat gelesen. |
| K-02 | `[!]` | `VehicleBuy` -> `unknown_action`; kein Rabattkauf möglich. |
| K-03 | `[!]` | `VehicleBuy` -> `unknown_action`; Doppelkauf-Parallelprobe nicht durchführbar. |
| K-04 | `[ ]` | Rejoin-Rabatt nicht geprüft. |
| K-05 | `[!]` | `EconomyTransfer` -> `unknown_action`; Fremdkonto-Test nicht durchführbar. |
| M-01…M-04 | `[!]` | `MissionProgress` -> `unknown_action`; Missionsfortschritt, Teleport-Cheat und Distanzmission nicht prüfbar. |
| L-01 | `[x]` | `DeliveryOrder` -> `accepted`, genau ein `orderId` pro Spieler. |
| L-02 | `[x]` | `DeliveryPickup` -> `pickedUp`, `DeliveryDeliver` -> `delivered`, `payout=25` bei korrekter Position; eine falsche Position wurde in diesem Lauf nicht geprüft. |
| L-03 | `[ ]` | 5 parallele Lieferungen nicht getestet (nur 1 echter + 3 simulierte Spieler). |
| W-01…W-05 | `[!]` | `WorkshopInstall`/`WorkshopPaint` -> `unknown_action`; keine Werkstattprüfung möglich. |
| R-01…R-03 | `[ ]` | Rejoin-/Autosave-Persistenz nicht durchgeführt. |
| F-01 | `[ ]` | Verbrauch nicht gemessen. |
| F-02, F-03 | `[!]` | `FuelRefill` -> `unknown_action`; Tanken/Liegenbleiben nicht prüfbar. |
| D-01, D-02 | `[!]` | `DynoRun` -> `unknown_action`; Prüfstand nicht prüfbar. |
| P-01…P-04, P-06 | `[ ]` | 15-Spieler-Last nicht herstellbar (B32-01); 1-Client-Basis siehe 15.3. |
| P-05 | `[x]` | Keine projekteigenen roten Fehler auf der Server-Konsole und den geprüften Client-Konsolen; nur projektexterne `cloud_…`-Meldung. |
| WA-MS-01 | `[x]` | Server- und Client-Bootstrap „ready“; keine projekteigenen roten Fehler. |
| WA-MS-02 | `[x]` | Spawn `(0, 12.84, 0)`, `Health=100`, kein Durchfallen. |
| WA-MS-03 | `[x]` | 3/3 simulierte Spieler hatten genau ein `StarterBicycle_*`; 8-Client-Lauf: 8 Spieler verbunden (Fahrräder nicht separat gezählt). |
| WA-MS-04…07 | `[ ]` | In diesem Lauf nicht erneut geprüft; Task-06-Lauf 3 (Abschnitt 13.8) bestand 11/11. |
| WA-DL-01…04 | `[x]` | Siehe Dönerloop in 15.3; genau eine Gutschrift, zweite Auslieferung `alreadyDelivered`. |
| WA-DL-05 | `[!]` | `MissionProgress` -> `unknown_action`; Fahrradmission nicht prüfbar. |
| WA-WL-01 | `[x]` | 20 Häuser mit eindeutigen Namen vorhanden; optische Einzigartigkeit nicht in diesem Lauf bewertet. |
| WA-WL-02 | `[x]` | Genau 1 `Church_Alpenblick`. |
| WA-WL-03 | `[x]` | 15 Anker, 15 synthetische Zuweisungen eindeutig, 16. -> `nil`. |
| WA-WL-04 | `[!]` | `GarageEnter` -> `unknown_action`; Privatheit serverseitig über `GarageService` gegeben, Remote-Zugriff fehlt. |
| WA-ST-01…05 | `[ ]` | In diesem Lauf nicht visuell geprüft. |
| WA-NAT-01…04 | `[ ]` | In diesem Lauf nicht visuell geprüft; Weltdaten vorhanden. |
| WA-PERF-01…03 | `[ ]` | 15-Spieler-Streaming/Last nicht herstellbar; 1-Client-Basis 60.1/54.6 FPS, 2609.5 -> 2604.9 MB (Studio-Overhead). |
| WA-PERF-04 | `[x]` | Keine projekteigenen roten Fehler über die Läufe. |
| WA-PERF-05 | `[!]` | 15-Spieler-Abnahme nicht durchführbar (B32-01, B32-02). |

### 15.5 Korrekturhinweise (konkret)

1. **Generische Handler registrieren:** In `src/server/bootstrap.server.luau` fehlen Registrierungen für `VehicleBuy`, `ShopCatalog`, `ShopBuy`, `WorkshopInstall`, `WorkshopPaint`, `GarageEnter`, `DynoRun`, `FuelRefill`, `MissionProgress`, `EconomyTransfer`. Ohne sie bleiben K-02/K-03/K-05, M-01…M-04, W-01…W-05, F-02/F-03, D-01/D-02 und G-01 blockiert.
2. **Studio-Testbarkeit:** `RequestRouter.invalidPlayer` lehnt `UserId <= 0` ab. Für Studio-Mehrclient-Tests entweder eine klar gekennzeichnete Testfreigabe für negative UserIds ergänzen (nur `RunService:IsStudio()`) oder die Abnahme mit echten, positiven Konten fahren.
3. **15 Spieler:** Studio simuliert maximal 8 Clients. Die echte Abnahme braucht einen veröffentlichten Testserver mit 15 echten Clients oder einen funktionierenden externen Client-Harness; der CLI-`StartServer` scheitert hier mit B32-05.
4. **Guthaben-Snapshot:** `VehicleSelect` sollte den echten `EconomyService`-Stand liefern, nicht `PlayerDataSchema.createDefault().cash` (B32-04).
5. **Erneut abnehmen:** Nach 1–4 Task 32 mit 15 echten Clients wiederholen; erst dann `docs/TASKS.md` auf `[x]` setzen.

**Fazit:** Der Minimal-Start, der Dönerloop und die serverseitige Garagenzuweisung funktionieren. Die 15-Spieler-Abnahme ist in dieser Umgebung nicht durchführbar und würde wegen der fehlenden generischen Handler und der `invalid_player`-Sperre für simulierte Clients auch mit 15 Clients scheitern. **Task 32 bleibt offen; keine Erfolgsmarkierung.**

### 15.6 Code-Stand 2026-11-10 (noch keine erneute Abnahme)

Dieser Abschnitt dokumentiert ausschließlich den Code-Stand. Die Ergebnisse aus 15.3/15.4 bleiben unverändert gültig, bis ein neuer Lauf durchgeführt wurde.

| Blocker | Status | Änderung |
|---|---|---|
| B32-02 | **im Code behoben (nur Studio)** | `src/server/net/PlayerIds.luau` bildet negative Studio-UserIds (`-1..-8`) ausschließlich bei `RunService:IsStudio()` auf `9_000_000_001..9_000_000_008` ab. `RequestRouter.invalidPlayer` bleibt streng; Live-Server unverändert. Bootstrap nutzt dieselbe kanonische ID für Router, Economy und Garage. |
| B32-04 | **im Code behoben** | `VehicleSelect` liest `cash` aus derselben `EconomyService`-Instanz wie `EconomyGet`; `PlayerDataSchema.createDefault().cash` wird nicht mehr verwendet. |
| B32-03 | **im Code behoben** | `src/server/services/ProfileAdapter.luau` (Memory/DataStore), `src/server/services/PlayerStore.luau` (Schema-Brücke, Cash-Sync, Rabatt-/Teile-Persistenz) und `src/server/services/GameplayHandlers.luau` registrieren 12 Aktionen: `VehicleSelect`, `EconomyGet`, `VehicleBuy`, `MissionProgress`, `GarageEnter`, `WorkshopInstall`, `WorkshopPaint`, `ShopCatalog`, `ShopBuy`, `DynoRun`, `FuelRefill`, `EconomyTransfer`. Keine dieser Aktionen antwortet mehr mit `unknown_action`. |
| B32-01 | **Umgebungsgrenze** | Studio simuliert maximal 8 Clients. |
| B32-05 | **Umgebungsgrenze** | CLI-`StartServer` scheitert lokal; für 15 echte Clients ist eine veröffentlichte Test-Place vorgesehen. |

**Validierung 2026-11-10 (Code, ohne Studio-Lauf):**
- `selene src tests`: 0 Fehler, 0 Warnungen.
- `lune run` für alle 27 Specs: bestanden, davon `tests/GenericHandlers.spec.luau` mit 64 Checks (Registrierung, Cash-Konsistenz, Rabatt, Doppelkauf, Fremdkonto, Shop, Werkstatt, Garage, Mission, Tank-/Dyno-Servicecodes, Persistenz nach Rejoin).
- `rojo build default.project.json -o build/ToeffliTal.rbxlx`: ok.

**Weiterhin offen (nicht durch Task 35 lösbar):**
- Tankstelle und Dyno-Zustand sind nicht in der Welt verdrahtet; `FuelRefill`/`DynoRun` antworten ehrlich mit `NotAtGasStation`/`NotOnDyno` statt `unknown_action`.
- Missionszustand wird noch nicht persistiert (M-04-Rejoin-Auszahlung bleibt zu prüfen).
- Die Client-UI ist für die neuen Aktionen noch nicht verdrahtet: `ShopTerminal` wird im Bootstrap nicht instanziiert und nutzt zudem `GetCatalog`/`OrderPart` statt `ShopCatalog`/`ShopBuy`; Werkstatt-, Garagen- und Dyno-Aufrufe fehlen clientseitig. Die serverseitigen Remotes sind vorhanden und per Test-Harness aufrufbar.
- 8-Client-Studio-Vorprüfung für Task 34 und die vollständige 15-Spieler-Abnahme (Task 32).

