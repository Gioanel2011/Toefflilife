# Task-Warteschlange

> Ein Task pro Durchlauf. Nur Target- und Context-Dateien laden; kein Repository-Scanning.
> Reihenfolge = Priorität. Abgeschlossene Tasks werden nach der Dokumentation aus der aktiven Liste entfernt.
> Modellzuordnung: DeepSeek V4.1 Flash für Logik/Planung, Muse Spark 1.3 für 3D-/Code-/Mathematikpräzision, Beam 1.0 für UI/Configs/Routine.
> Kimi K3.1 Pro und MiMo-V2.6 Pro sind ausschliesslich Eskalationen nach zwei Fehlversuchen.

### [x] Task 01: Welt-Parent-Fehler im Server-Bootstrap beheben
- **Empfohlenes Modell:** DeepSeek V4.1 Flash | **Eskalation:** MiMo-V2.6 Pro / Kimi K3.1 Pro
- **Modus:** BUILD-MODUS
- **Target-Dateien:** src/server/bootstrap.server.luau
- **Context-Dateien:** src/server/world/ValleyWorld.luau
- **Agent-Persona:** Präziser Roblox-Laufzeitdiagnostiker für serverseitige Weltgenerierung.
- **Ausführungs-Prompt:**
  """
  Ersetze den Aufruf `callOptional(ValleyWorld, "build")` durch einen direkten Aufruf von `ValleyWorld.build(workspace)`.
  `callOptional` übergibt das Modul als Self und ist für diesen Builder falsch. Ändere `callOptional` selbst nicht und verändere keine anderen Services.
  Die Welt muss nach Serverstart genau einmal unter `Workspace.ValleyWorld` liegen. Keine globalen Variablen und keine zusätzlichen Dateien.
  """
- **Validierung:** `selene src/server/bootstrap.server.luau src/server/world/ValleyWorld.luau` und `rojo build default.project.json -o build/ToeffliTal.rbxlx` laufen fehlerfrei; nach Play existiert `Workspace.ValleyWorld` ohne roten Fehler im Output.
- **Commit-Empfehlung:** fix(world): pass workspace to world builder

### [x] Task 02: Serverseitiges kostenloses Startfahrrad erzeugen
- **Empfohlenes Modell:** Muse Spark 1.3 | **Eskalation:** MiMo-V2.6 Pro / Kimi K3.1 Pro
- **Modus:** BUILD-MODUS
- **Target-Dateien:** src/server/vehicle/BicycleSpawner.luau, src/server/bootstrap.server.luau
- **Context-Dateien:** src/client/controllers/BicycleController.luau, src/shared/data/VehicleCatalog.luau
- **Agent-Persona:** Roblox-3D- und Vehicle-Integrator für ein simples, stabiles Arcade-Fahrrad.
- **Ausführungs-Prompt:**
  """
  Lege `BicycleSpawner` als Modul ohne globale Variablen an. Öffentliche API:
  `BicycleSpawner.createForPlayer(player: Player, spawnCFrame: CFrame): Model` und `BicycleSpawner.releaseForPlayer(player: Player): ()`.
  Das Model heisst `StarterBicycle_<UserId>`, liegt in `Workspace.ToeffliTalVehicles`, hat PrimaryPart `Drive`, einen `SeatPart` namens `Seat`, zwei sichtbare Räder, Lenker und die Attribute `OwnerUserId`, `IsStarterBicycle=true`.
  Alle Teile sind anchored und über WeldConstraints verbunden. Setze das Model auf eine sichere Position über dem Boden, standardmässig `CFrame.new(0, 5, 0)`.
  Verdrahte den Spawn im Bootstrap nach erfolgreichem Spieler-Spawn. Kein Motor, kein Treibstoff, kein Tuning, keine Preise und keine weitere Gameplay-Logik.
  """
- **Validierung:** `selene src/server/vehicle/BicycleSpawner.luau src/server/bootstrap.server.luau` läuft fehlerfrei; nach Play existiert pro Spieler genau ein `StarterBicycle_<UserId>` mit Seat und Drive im Workspace.
- **Commit-Empfehlung:** feat(vehicle): spawn free starter bicycle

### [x] Task 03: PC-Auf- und Absteigen am Startfahrrad verdrahten
- **Empfohlenes Modell:** DeepSeek V4.1 Flash | **Eskalation:** MiMo-V2.6 Pro / Kimi K3.1 Pro
- **Modus:** BUILD-MODUS
- **Target-Dateien:** src/client/controllers/BicycleController.luau, src/client/bootstrap.client.luau
- **Context-Dateien:** src/server/vehicle/BicycleSpawner.luau
- **Agent-Persona:** Roblox-Gameplay-Programmierer für zugängliche PC-Fahrzeuginteraktion.
- **Ausführungs-Prompt:**
  """
  Ergänze im Controller eine Suche nach dem nächsten Fahrrad mit Tag `ToeffliBicycle`, Attribut `OwnerUserId == LocalPlayer.UserId` und maximal 10 Studs Abstand.
  Taste `E` steigt auf, wenn nicht gefahren wird; nochmal `E` steigt ab. Nutze vorhandene `Mount`/`Dismount`, halte Debounce und Distanzprüfung ein und verhindere Doppel-Mounts.
  Der Client darf nur das eigene Fahrrad auswählen, keine Serverwerte erfinden und keine fremden Fahrzeuge bewegen. Tagge das Model im BicycleSpawner bei Bedarf zusätzlich über CollectionService.
  """
- **Validierung:** `selene src/client/controllers/BicycleController.luau src/client/bootstrap.client.luau src/server/vehicle/BicycleSpawner.luau` läuft fehlerfrei; Studio bestätigt E-Aufsteigen, Fahren, Bremsen und E-Absteigen ohne Konsolenfehler.
- **Commit-Empfehlung:** feat(vehicle): add bicycle mount controls

### [x] Task 04: Döner-Lieferaufträge serverseitig verdrahten
- **Empfohlenes Modell:** DeepSeek V4.1 Flash | **Eskalation:** MiMo-V2.6 Pro / Kimi K3.1 Pro
- **Modus:** BUILD-MODUS
- **Target-Dateien:** src/shared/net/RemoteProtocol.luau, src/server/bootstrap.server.luau, src/server/services/DeliveryService.luau
- **Context-Dateien:** src/server/net/RequestRouter.luau, tests/DeliveryService.spec.luau
- **Agent-Persona:** Security-orientierter Roblox-Backend-Integrator für Lieferzustände.
- **Ausführungs-Prompt:**
  """
  Ermittle aus den Context-Dateien die tatsächlich vorhandenen DeliveryService-Funktionen und verdrahte sie über den RequestRouter.
  Definiere versionierte Payloads für `DeliveryOrder`, `DeliveryPickup` und `DeliveryDeliver` mit optionaler `orderId`. Belohnung, Distanz, Spielerzuordnung und Zustandswechsel bleiben vollständig serverseitig.
  Erfinde keine parallele Zustandsmaschine und übernimm keine Clientpreise, Distanzen oder Guthaben. Unbekannte Aktionen, falsche Typen und fremde Aufträge müssen sicher abgewiesen werden.
  """
- **Validierung:** `selene src/shared/net/RemoteProtocol.luau src/server/bootstrap.server.luau src/server/services/DeliveryService.luau` und `lune run tests/DeliveryService.spec.luau` bestehen.
- **Commit-Empfehlung:** feat(jobs): route doner delivery requests

### [x] Task 05: Minimales Döner-Lieferprompt bauen
- **Empfohlenes Modell:** Beam 1.0 | **Eskalation:** MiMo-V2.6 Pro / Kimi K3.1 Pro
- **Modus:** BUILD-MODUS
- **Target-Dateien:** src/client/ui/DeliveryPrompt.luau, src/client/bootstrap.client.luau
- **Context-Dateien:** src/shared/net/RemoteProtocol.luau, src/server/services/DeliveryService.luau
- **Agent-Persona:** Roblox-UI-Entwickler für eine schlanke und verständliche Lieferoberfläche.
- **Ausführungs-Prompt:**
  """
  Implementiere `DeliveryPrompt` mit `buildGui`, `open`, `close` und Statusanzeige. Zeige je nach Zustand genau eine passende Aktion: Auftrag annehmen, beim Laden abholen oder an der Zieladresse ausliefern.
  Sende ausschliesslich die in Task 04 definierten Remote-Anfragen; keine Preise, Distanzen, Belohnungen oder Erfolge clientseitig entscheiden.
  Die UI muss PC-tauglich, kontrastreich und klein sein und darf das Fahrrad-Mounten mit E nicht blockieren. Keine Shop-, Werkstatt- oder Tuningfunktionen.
  """
- **Validierung:** `selene src/client/ui/DeliveryPrompt.luau src/client/bootstrap.client.luau` läuft fehlerfrei; Studio bestätigt Öffnen, Zustandswechsel und Schliessen ohne Konsolenfehler.
- **Commit-Empfehlung:** feat(ui): add doner delivery prompt

### [x] Task 33: Minimalen Spiel- und Verdienstloop technisch verkabeln (Vorbedingung für Task 06)
- **Empfohlenes Modell:** DeepSeek V4.1 Flash | **Eskalation:** MiMo-V2.6 Pro / Kimi K3.1 Pro
- **Modus:** BUILD-MODUS
- **Target-Dateien:** src/server/bootstrap.server.luau, src/server/services/DeliveryService.luau, src/server/world/AtmosphereBuilder.luau
- **Context-Dateien:** src/shared/net/RemoteProtocol.luau, src/server/net/RequestRouter.luau, src/shared/net/RateLimiter.luau, src/shared/data/PlayerDataSchema.luau, src/server/world/ValleyWorld.luau, src/server/services/EconomyService.luau
- **Agent-Persona:** Server-Integrator für den ersten spielbaren Vertical Slice.
- **Ausführungs-Prompt:**
  """
  Behebe BLOCKER-B02: `bootstrap.server.luau` ruft `RequestRouter.init`/`registerHandler` auf, die es nicht gibt. Baue einen echten generischen Router (`RequestRouter.new()`), registriere mindestens `VehicleSelect` und `EconomyGet` mit serverseitigen Standardwerten und binde alle generischen Remotes per `OnServerInvoke` an den Router; nicht registrierte Aktionen antworten sofort mit `unknown_action` statt zu hängen.
  Behebe BLOCKER-B03: `DeliveryService.resolveWorldPoints` muss das Array-Format von `ValleyWorld.getDeliveryPoints()` (`{ Name, Position }`) verstehen (Pickup-Punkt als Shop, übrige als Adressen) und Lieferungen über eine echte `EconomyService`-Instanz genau einmal gutschreiben. Der Starter-Radius wird so gesetzt, dass der Startfahrrad-Loop die aktuellen Dorfrouten abdeckt.
  Behebe den in Lauf 3 gefundenen Weltaufbau-Abbruch: `AtmosphereBuilder` setzt die nicht existierenden Properties `ColorShiftTop`/`ColorShiftBottom`; korrekt sind `ColorShift_Top`/`ColorShift_Bottom`.
  Keine Cliententscheidungen, keine neuen globalen Variablen und keine parallele Zustandsmaschine.
  """
- **Validierung:** `selene src/server/bootstrap.server.luau src/server/services/DeliveryService.luau src/server/world/AtmosphereBuilder.luau` läuft fehlerfrei; `lune run tests/DeliveryService.spec.luau` besteht.
- **Commit-Empfehlung:** fix(server): wire minimal gameplay loop

### [x] Task 06: Minimalen Spiel- und Verdienstloop abnehmen
- **Empfohlenes Modell:** DeepSeek V4.1 Flash | **Eskalation:** MiMo-V2.6 Pro / Kimi K3.1 Pro
- **Modus:** BUILD-MODUS
- **Target-Dateien:** docs/PLAYTEST.md
- **Context-Dateien:** docs/TASKS.md
- **Agent-Persona:** QA-Engineer für den ersten spielbaren Roblox-Vertical-Slice.
- **Ausführungs-Prompt:**
  """
  Ergänze eine kurze Abnahmesektion `Minimal spielbar`: Place startet ohne roten Output, Spieler spawnt sicher, genau ein Startfahrrad erscheint, E/Fahren/Bremsen/Absteigen funktionieren, Auftrag kann angenommen, abgeholt und ausgeliefert werden.
  Die Gutschrift muss serverseitig genau einmal erfolgen. Dokumentiere Datum, Tester, Ergebnis und konkrete Fehlermeldungen. Ein Abschnitt darf nur nach tatsächlicher Studio-Ausführung abgehakt werden.
  """
- **Validierung:** Studio-Playtest besteht alle dokumentierten Minimal-Checks; `docs/PLAYTEST.md` enthält Testergebnis und keine unausgefüllten Pflichtfelder.
- **Commit-Empfehlung:** docs(qa): record minimal playable slice

### [x] Task 07: Layout für Dörfer, Garage und Dönerplatz definieren
- **Empfohlenes Modell:** DeepSeek V4.1 Flash | **Eskalation:** MiMo-V2.6 Pro / Kimi K3.1 Pro
- **Modus:** BUILD-MODUS
- **Target-Dateien:** src/server/world/WorldLayout.luau, tests/WorldLayout.spec.luau
- **Context-Dateien:** src/server/world/ValleyWorld.luau
- **Agent-Persona:** Räumlicher Systemarchitekt für faire und kollisionsfreie Spielwelten.
- **Ausführungs-Prompt:**
  """
  Definiere reine, deterministische Layoutdaten mit festem Seed: Grenzen, zwei Dörfer mit je 10 Haus-Slots, genau eine Kirche, zentralen Dönerplatz, 15 Garagen mit gleichem Abstand zum Dönerplatz und Mindestabstand zueinander.
  Öffentliche API: `SEED`, `BOUNDS`, `DONER`, `CHURCH`, `VILLAGES`, `GARAGES`, `getDeliveryPoints()`, `getGarageAnchors()`, `getPointsOfInterest()`, `isInsideBounds(position)`.
  Keine Roblox-Instanzen erzeugen und keine Preise oder Gameplaylogik. Kopien der Rückgabelisten liefern, damit Aufrufer die Konstanten nicht mutieren.
  """
- **Validierung:** `selene src/server/world/WorldLayout.luau tests/WorldLayout.spec.luau` und `lune run tests/WorldLayout.spec.luau` bestehen; geprüft werden 2 Dörfer, 20 Slots, 1 Kirche, 15 Garagen, gleiche Dönerdistanz und Mindestabstände.
- **Commit-Empfehlung:** feat(world): define deterministic world layout

### [x] Task 08: Strassen-, Wasser-, Weiden- und Waldzonen validieren
- **Empfohlenes Modell:** DeepSeek V4.1 Flash | **Eskalation:** MiMo-V2.6 Pro / Kimi K3.1 Pro
- **Modus:** BUILD-MODUS
- **Target-Dateien:** src/server/world/WorldZones.luau, tests/WorldZones.spec.luau
- **Context-Dateien:** src/server/world/WorldLayout.luau
- **Agent-Persona:** Vektor- und Kollisionslogiker für prozedurale Weltzonen.
- **Ausführungs-Prompt:**
  """
  Definiere reine Zonendaten für zweispurige Hauptstrassen, Stopstrassen, Kreisel, genau einen See, drei Bergbäche mit Quell- und Mündungspunkt, alle Brückenkreuzungen, Weiden und Wälder.
  Öffentliche API: `ROAD_SEGMENTS`, `STOP_ROADS`, `ROUNDABOUTS`, `WATER_COURSES`, `BRIDGE_CROSSINGS`, `PASTURES`, `FORESTS`, `containsWater(position)`, `isRoad(position, margin)`, `isReserved(position, margin)`.
  Prüfe Mindestabstände zu Garagen, Gebäuden und Dörfern. Keine Instanzen und keine Terrain-Erzeugung.
  """
- **Validierung:** `selene src/server/world/WorldZones.luau tests/WorldZones.spec.luau` und `lune run tests/WorldZones.spec.luau` bestehen; 3 Wasserläufe, keine Zonenüberschneidung an Pflichtflächen und alle Brücken liegen auf Strassen-Wasser-Kreuzungen.
- **Commit-Empfehlung:** feat(world): add validated world zones

### [x] Task 09: Sanftes Terrain-Höhenmodell implementieren
- **Empfohlenes Modell:** Muse Spark 1.3 | **Eskalation:** MiMo-V2.6 Pro / Kimi K3.1 Pro
- **Modus:** BUILD-MODUS
- **Target-Dateien:** src/server/world/TerrainHeight.luau, tests/TerrainHeight.spec.luau
- **Context-Dateien:** src/server/world/WorldLayout.luau, src/server/world/WorldZones.luau
- **Agent-Persona:** Präziser Vektor-Mathematiker für befahrbare prozedurale Landschaften.
- **Ausführungs-Prompt:**
  """
  Implementiere ohne Roblox-Instanzen: `heightAt(x: number, z: number): number`, `slopeAt(x: number, z: number): number` und `isBuildPad(position: Vector3): boolean`.
  Berge an den Rändern sind Wasserquellen; Tal, Seeufer und Brückenauffahrten bleiben flach. Strassen-, Dorf-, Döner- und Garagenflächen werden auf eine gemeinsame lokale Höhe abgeflacht.
  Ergebnisse müssen deterministisch und endlich sein. Keine braunen Bodenmaterialien, kein Sand und keine globale Mutation der Layoutdaten.
  """
- **Validierung:** `selene src/server/world/TerrainHeight.luau tests/TerrainHeight.spec.luau` und `lune run tests/TerrainHeight.spec.luau` bestehen; geprüft werden Determinismus, endliche Werte, flache Bauzonen, maximale Strassensteigung und flache Seeufer.
- **Commit-Empfehlung:** feat(world): add terrain height model

### [x] Task 10: Katalog mit 20 einzigartigen Häusern anlegen
- **Empfohlenes Modell:** Beam 1.0 | **Eskalation:** MiMo-V2.6 Pro / Kimi K3.1 Pro
- **Modus:** BUILD-MODUS
- **Target-Dateien:** src/server/world/data/BuildingCatalog.luau, tests/BuildingCatalog.spec.luau
- **Context-Dateien:** src/server/world/WorldLayout.luau
- **Agent-Persona:** Datenarchitekt für vielfältige Low-Poly-Gebäude.
- **Ausführungs-Prompt:**
  """
  Definiere exakt 20 Häuser, je 10 für die beiden Dörfer. Jedes Haus enthält stabile `Id`, `VillageId`, Grundriss, Höhe, Dachform, Fassadenfarben, Fensterstil, Türseite und Dekorationssignatur.
  Alle Kombinationen aus Grundriss, Dach, Farbe, Fenstern, Tür und Dekoration müssen eindeutig sein; keine sichtbaren Duplikate. Die Kirche ist nicht Teil des Hauskatalogs.
  Exportiere `HOUSES`, `getById(id)` und `validate()`. Keine Roblox-Instanzen und keine globalen Variablen.
  """
- **Validierung:** `selene src/server/world/data/BuildingCatalog.luau tests/BuildingCatalog.spec.luau` und `lune run tests/BuildingCatalog.spec.luau` bestehen; 20 IDs, 10 je Dorf und 20 eindeutige Gestaltungssignaturen.
- **Commit-Empfehlung:** feat(world): add unique house catalog

### [x] Task 11: Schweizer Verkehrszeichen-Assets bauen
- **Empfohlenes Modell:** Beam 1.0 | **Eskalation:** MiMo-V2.6 Pro / Kimi K3.1 Pro
- **Modus:** BUILD-MODUS
- **Target-Dateien:** src/server/world/TrafficSignBuilder.luau
- **Context-Dateien:** src/server/world/WorldLayout.luau
- **Agent-Persona:** Routine-3D-Artist für eindeutige Schweizer Verkehrsschilder.
- **Ausführungs-Prompt:**
  """
  Implementiere `createSpeedLimit(limit: number): Model` und `createStopSign(): Model`.
  Tempolimits sind runde weisse Schilder mit rotem Rand und schwarzer Zahl; Stoppschilder sind rot mit weisser Schrift und weissem Rand im oktogonalen Querschnitt. Jedes Model besitzt einen klaren Befestigungspunkt und eine lesbare Vorderseite.
  Platziere in diesem Task keine Schilder. Erzeuge keine anderen Verkehrszeichen und keine externen Assets.
  """
- **Validierung:** `selene src/server/world/TrafficSignBuilder.luau` läuft fehlerfrei; eine Studio-Prüfung beider Modelle bestätigt Lesbarkeit, Ausrichtung und Befestigungspunkt.
- **Commit-Empfehlung:** feat(world): add swiss traffic sign assets

### [x] Task 12: Spitzige Low-Poly-Tannen erzeugen
- **Empfohlenes Modell:** Muse Spark 1.3 | **Eskalation:** MiMo-V2.6 Pro / Kimi K3.1 Pro
- **Modus:** BUILD-MODUS
- **Target-Dateien:** src/server/world/ConiferFactory.luau
- **Context-Dateien:** keines
- **Agent-Persona:** Präziser Low-Poly-3D-Artist für facettierte Nadelbäume.
- **Ausführungs-Prompt:**
  """
  Implementiere `create(seed: number, scale: number?): Model`. Die Tanne hat einen schlanken braunen Stamm und mehrere gestaffelte, spitz zulaufende Kronen mit sichtbaren geometrischen Facetten. Höhe und Grünvariation werden deterministisch aus dem Seed abgeleitet.
  Alle Teile sind anchored, das Model heisst `Conifer` und besitzt keine Skripte oder externen Mesh-IDs. Erzeuge keine runden Laubbaumkronen.
  """
- **Validierung:** `selene src/server/world/ConiferFactory.luau` läuft fehlerfrei; Studio prüft mindestens drei Seeds auf spitzige Silhouette, Facetten und realistische Staffelung.
- **Commit-Empfehlung:** feat(world): add low poly conifer factory

### [x] Task 13: Hochwertige gemeinsame Garagenreferenz bauen
- **Empfohlenes Modell:** Muse Spark 1.3 | **Eskalation:** MiMo-V2.6 Pro / Kimi K3.1 Pro
- **Modus:** BUILD-MODUS
- **Target-Dateien:** src/server/world/GarageFactory.luau
- **Context-Dateien:** src/server/world/WorldLayout.luau
- **Agent-Persona:** Roblox-3D-Artist für eine hochwertige, strikt identische Spielergarage.
- **Ausführungs-Prompt:**
  """
  Implementiere `create(anchorName: string): Model` als einzige Garagenvorlage. Enthält grosses Fahrzeugtor, separaten Personeneingang, Fenster, Beleuchtung, Dachkante, identische Dekoration, Hebebühne und markierten Werkstattanker.
  Jede Instanz muss dieselben Abmessungen, Materialien, Farben und dieselbe Teilezahl besitzen. Nur Name und Anker-Attribut dürfen variieren. Keine Besitzerfarbe, keine Tuninglogik und keine individuellen Grössen.
  """
- **Validierung:** `selene src/server/world/GarageFactory.luau` läuft fehlerfrei; Studio erzeugt zwei Referenzen und bestätigt identische Abmessungen, Teilezahl, Türen, Beleuchtung und Hebebühne.
- **Commit-Empfehlung:** feat(garage): add shared garage factory

### [x] Task 14: Gras-Terrain und Bergbegrenzung erzeugen
- **Empfohlenes Modell:** Muse Spark 1.3 | **Eskalation:** MiMo-V2.6 Pro / Kimi K3.1 Pro
- **Modus:** BUILD-MODUS
- **Target-Dateien:** src/server/world/TerrainBuilder.luau, src/server/world/ValleyWorld.luau
- **Context-Dateien:** src/server/world/WorldLayout.luau, src/server/world/WorldZones.luau, src/server/world/TerrainHeight.luau
- **Agent-Persona:** Roblox-Terrain-Entwickler für saubere Low-Poly-Landschaften.
- **Ausführungs-Prompt:**
  """
  Implementiere `TerrainBuilder.build(parent: Instance): Folder` und rufe es aus `ValleyWorld` auf. Erzeuge begrenztes Gras-Terrain entlang `TerrainHeight`, mit sanften Randbergen, See- und Bachbetten.
  Entferne die alte Bodenplatte aus `ValleyWorld`, aber keine anderen Spielsysteme. Keine braunen Bodenmaterialien, kein Sand und keine offenen unendlichen Flächen.
  Das Ergebnis liegt unter einem benannten Ordner und ist frei von globalen Variablen.
  """
- **Validierung:** `selene src/server/world/TerrainBuilder.luau src/server/world/ValleyWorld.luau` läuft fehlerfrei; Studio zeigt grünes Terrain, Berge, ebene Bauzonen und keine braunen Flecken.
- **Commit-Empfehlung:** feat(world): build grass terrain

### [x] Task 15: See und drei Bergbäche erzeugen
- **Empfohlenes Modell:** Muse Spark 1.3 | **Eskalation:** MiMo-V2.6 Pro / Kimi K3.1 Pro
- **Modus:** BUILD-MODUS
- **Target-Dateien:** src/server/world/WaterBuilder.luau, src/server/world/ValleyWorld.luau
- **Context-Dateien:** src/server/world/WorldLayout.luau, src/server/world/WorldZones.luau, src/server/world/TerrainHeight.luau
- **Agent-Persona:** Roblox-Environment-Entwickler für zusammenhängende Gewässer.
- **Ausführungs-Prompt:**
  """
  Implementiere `WaterBuilder.build(parent: Instance): Folder` und integriere es nach dem Terrain. Erzeuge genau einen See und drei durchgehende Bäche von den Bergquellen bis zur Mündung in den See.
  Wasser darf nicht auf Strassen-, Garagen-, Dorf- oder Gebäudeflächen liegen. Ufer und Seezugang bleiben flach; Sand ist nicht erforderlich.
  Keine Strassen oder Brücken in diesem Task.
  """
- **Validierung:** `selene src/server/world/WaterBuilder.luau src/server/world/ValleyWorld.luau` läuft fehlerfrei; Studio bestätigt drei Verbindungen vom Berg zum See, flache Ufer und kein Wasser in reservierten Zonen.
- **Commit-Empfehlung:** feat(world): add lake and mountain streams

### [x] Task 16: Zweispurige Hauptstrassen mit Mittelstreifen bauen
- **Empfohlenes Modell:** Muse Spark 1.3 | **Eskalation:** MiMo-V2.6 Pro / Kimi K3.1 Pro
- **Modus:** BUILD-MODUS
- **Target-Dateien:** src/server/world/RoadBuilder.luau, src/server/world/ValleyWorld.luau
- **Context-Dateien:** src/server/world/WorldLayout.luau, src/server/world/WorldZones.luau, src/server/world/TerrainHeight.luau
- **Agent-Persona:** Roblox-Strassenbauer für gut befahrbare Arcade-Strecken.
- **Ausführungs-Prompt:**
  """
  Implementiere `RoadBuilder.build(parent: Instance): Folder` für alle Hauptstrassen aus `WorldZones`. Jede Hauptstrasse ist zweispurig, folgt dem Terrain, besitzt durchgehende weisse Mittelstreifen und ebene Anschlüsse an Dörfer, Dönerplatz und Garagen.
  Ersetze die bisherigen alten Strassenaufrufe in `ValleyWorld`, nicht die Terrain- oder Wassererzeugung. Keine Stopstrassen, Kreisel, Brücken oder Schilder.
  Markierungen dürfen die Fahrbahn nicht überhöhen oder blockieren.
  """
- **Validierung:** `selene src/server/world/RoadBuilder.luau src/server/world/ValleyWorld.luau` läuft fehlerfrei; Studio-Testfahrt bestätigt zwei Spuren, mittige Striche und keine Überlappung mit Wasser oder Gras.
- **Commit-Empfehlung:** feat(world): add marked two lane roads

### [x] Task 17: Zentralen Döner Laden bauen
- **Empfohlenes Modell:** Muse Spark 1.3 | **Eskalation:** MiMo-V2.6 Pro / Kimi K3.1 Pro
- **Modus:** BUILD-MODUS
- **Target-Dateien:** src/server/world/DonerShopBuilder.luau, src/server/world/ValleyWorld.luau
- **Context-Dateien:** src/server/world/WorldLayout.luau, src/server/world/TerrainHeight.luau
- **Agent-Persona:** Roblox-3D-Artist für einen markanten zentralen Gameplay-Ort.
- **Ausführungs-Prompt:**
  """
  Implementiere `DonerShopBuilder.build(parent: Instance): Model` am zentralen Dönerplatz. Das Gebäude besitzt klare Eingangstür, Schaufenster, Beleuchtung und ein grosses lesbares Schild mit exakt `Döner Laden`.
  Ersetze den alten Döner-Greyboxmarker in `ValleyWorld`, ohne andere POIs zu entfernen. Erzeuge einen kompatiblen Abholpunkt für Lieferungen, aber keine Preise oder Belohnungslogik.
  """
- **Validierung:** `selene src/server/world/DonerShopBuilder.luau src/server/world/ValleyWorld.luau` läuft fehlerfrei; Studio bestätigt exakten Schildtext, erreichbaren Eingang und funktionierende Lieferabholung.
- **Commit-Empfehlung:** feat(world): build central doner shop

### [x] Task 18: Genau eine dekorierte Dorfkirche bauen
- **Empfohlenes Modell:** Muse Spark 1.3 | **Eskalation:** MiMo-V2.6 Pro / Kimi K3.1 Pro
- **Modus:** BUILD-MODUS
- **Target-Dateien:** src/server/world/ChurchBuilder.luau, src/server/world/ValleyWorld.luau
- **Context-Dateien:** src/server/world/WorldLayout.luau, src/server/world/TerrainHeight.luau
- **Agent-Persona:** Low-Poly-Architekt für ein einzelnes markantes Dorfgebäude.
- **Ausführungs-Prompt:**
  """
  Implementiere `ChurchBuilder.build(parent: Instance): Model` an der einzigen vorgesehenen Position. Die Kirche besitzt eigenständiges Dach, Turm, klar erkennbares Portal, erreichbare Eingangstür und zurückhaltende Fassadendekoration.
  Integriere genau einen Aufruf in `ValleyWorld`. Sie darf kein dupliziertes Wohnhaus, keine zweite Kirche und keine Strassenblockade erzeugen.
  """
- **Validierung:** `selene src/server/world/ChurchBuilder.luau src/server/world/ValleyWorld.luau` läuft fehlerfrei; Studio zählt genau eine Kirche und bestätigt ein frei erreichbares Portal.
- **Commit-Empfehlung:** feat(world): add village church

### [x] Task 19: Alle Häuser mit Eingängen und Dekoration bauen
- **Empfohlenes Modell:** Muse Spark 1.3 | **Eskalation:** MiMo-V2.6 Pro / Kimi K3.1 Pro
- **Modus:** BUILD-MODUS
- **Target-Dateien:** src/server/world/BuildingFactory.luau, src/server/world/VillageBuilder.luau, src/server/world/ValleyWorld.luau
- **Context-Dateien:** src/server/world/data/BuildingCatalog.luau, src/server/world/WorldLayout.luau, src/server/world/TerrainHeight.luau
- **Agent-Persona:** Roblox-Environment-Artist für zwei detailreiche Low-Poly-Dörfer.
- **Ausführungs-Prompt:**
  """
  Implementiere `BuildingFactory.create(definition): Model` und `VillageBuilder.build(parent: Instance): Folder`. Erzeuge alle 20 Häuser aus dem Katalog, je 10 pro Dorf, an den Layout-Slots.
  Jedes Haus braucht eine sichtbare, frei erreichbare Eingangstür, Fenster und seine eindeutige Dekoration. Ersetze die alte Haus-Greybox in `ValleyWorld` vollständig, damit keine doppelten Häuser entstehen.
  Keine Kirche, keine Garagen und keine Türen in Wänden oder Böden.
  """
- **Validierung:** `selene src/server/world/BuildingFactory.luau src/server/world/VillageBuilder.luau src/server/world/ValleyWorld.luau` läuft fehlerfrei; Studio bestätigt zwei Dörfer, 20 unterschiedliche Häuser und 20 erreichbare Eingänge.
- **Commit-Empfehlung:** feat(world): build unique decorated villages

### [x] Task 20: Umzäunte Kuhweiden ohne Kühe bauen
- **Empfohlenes Modell:** Beam 1.0 | **Eskalation:** MiMo-V2.6 Pro / Kimi K3.1 Pro
- **Modus:** BUILD-MODUS
- **Target-Dateien:** src/server/world/PastureBuilder.luau, src/server/world/ValleyWorld.luau
- **Context-Dateien:** src/server/world/WorldZones.luau, src/server/world/TerrainHeight.luau
- **Agent-Persona:** Routine-Environment-Designer für ländliche Schweizer Flächen.
- **Ausführungs-Prompt:**
  """
  Implementiere `PastureBuilder.build(parent: Instance): Folder` für alle Weiden aus `WorldZones`. Jede Weide ist vollständig umzäunt, besitzt ein erkennbares Tor und grünen Boden ohne braune Stellen.
  Keine Kühe, keine Strassenblockade und keine Zäune in Wasser, Gebäuden oder Garagenzufahrten. Integriere den Builder einmalig in `ValleyWorld`.
  """
- **Validierung:** `selene src/server/world/PastureBuilder.luau src/server/world/ValleyWorld.luau` läuft fehlerfrei; Studio bestätigt geschlossene Zäune, Tore, keine Tiere und freie Fahrwege.
- **Commit-Empfehlung:** feat(world): add fenced cow pastures

### [x] Task 21: Wälder mit Ausschlusszonen platzieren
- **Empfohlenes Modell:** DeepSeek V4.1 Flash | **Eskalation:** MiMo-V2.6 Pro / Kimi K3.1 Pro
- **Modus:** BUILD-MODUS
- **Target-Dateien:** src/server/world/VegetationBuilder.luau, src/server/world/ValleyWorld.luau, tests/VegetationLayout.spec.luau
- **Context-Dateien:** src/server/world/ConiferFactory.luau, src/server/world/WorldZones.luau, src/server/world/TerrainHeight.luau
- **Agent-Persona:** Environment-Programmierer für performante Low-Poly-Wälder.
- **Ausführungs-Prompt:**
  """
  Trenne eine reine Funktion `calculatePlacements(): { { position: Vector3, scale: number, seed: number } }` von der Instanzerzeugung. Platziere begrenzte, deterministische Baumgruppen und Wälder nur ausserhalb von Strassen, Wasser, Gebäuden, Garagen, Lieferpunkten und Weiden.
  Variiere Höhe und Dichte, aber vermeide grosse identische Baumreihen. Integriere den Builder in `ValleyWorld`.
  Keine Bäume auf Fahrbahnen, in Eingängen oder auf der Hebebühne.
  """
- **Validierung:** `selene src/server/world/VegetationBuilder.luau tests/VegetationLayout.spec.luau` und `lune run tests/VegetationLayout.spec.luau` bestehen; Studio bestätigt freie Sichtachsen und keine Bäume in Ausschlusszonen.
- **Commit-Empfehlung:** feat(world): place conifer forests

### [x] Task 22: Sonne, Wolken und Atmosphäre konfigurieren
- **Empfohlenes Modell:** Beam 1.0 | **Eskalation:** MiMo-V2.6 Pro / Kimi K3.1 Pro
- **Modus:** BUILD-MODUS
- **Target-Dateien:** src/server/world/AtmosphereBuilder.luau, src/server/world/ValleyWorld.luau
- **Context-Dateien:** keines
- **Agent-Persona:** Roblox-Lighting- und Config-Spezialist für eine freundliche Spielwelt.
- **Ausführungs-Prompt:**
  """
  Implementiere `AtmosphereBuilder.apply(): ()`. Setze angenehme Lighting-Werte, sichtbare Wolken über `Workspace.Terrain` und eine passende Atmosphäre.
  Strassenmarkierungen, Schilder und Eingänge müssen gut lesbar bleiben. Kein Tag/Nacht-Kreislauf, keine übermässige Blendung und keine Gameplayänderungen. Integriere den Aufruf einmalig in `ValleyWorld`.
  """
- **Validierung:** `selene src/server/world/AtmosphereBuilder.luau src/server/world/ValleyWorld.luau` läuft fehlerfrei; Studio zeigt Sonne, Wolken und lesbare Strassen- und Gebäudedetails.
- **Commit-Empfehlung:** feat(world): configure sun and clouds

### [x] Task 23: Stopstrassen und Kreisel bauen
- **Empfohlenes Modell:** Muse Spark 1.3 | **Eskalation:** MiMo-V2.6 Pro / Kimi K3.1 Pro
- **Modus:** BUILD-MODUS
- **Target-Dateien:** src/server/world/IntersectionBuilder.luau, src/server/world/ValleyWorld.luau
- **Context-Dateien:** src/server/world/WorldZones.luau, src/server/world/TerrainHeight.luau, src/server/world/RoadBuilder.luau
- **Agent-Persona:** Verkehrsplaner und Roblox-Geometrieentwickler.
- **Ausführungs-Prompt:**
  """
  Implementiere `IntersectionBuilder.build(parent: Instance): Folder` für alle Stopstrassen und Kreisel aus `WorldZones`. Stopstrassen besitzen eine gut sichtbare Haltelinie; Kreisel sind flach, befahrbar und haben im Inneren keinen Mittelstreifen.
  Integriere den Builder nach den Hauptstrassen in `ValleyWorld`. Keine Brücken und keine Verkehrszeichen in diesem Task.
  """
- **Validierung:** `selene src/server/world/IntersectionBuilder.luau src/server/world/ValleyWorld.luau` läuft fehlerfrei; Studio bestätigt befahrbare Kreisel, Stopstrassen und korrekt platzierte Haltelinien.
- **Commit-Empfehlung:** feat(world): add stop roads and roundabouts

### [x] Task 24: Flache Brücken an Wasserquerungen bauen
- **Empfohlenes Modell:** Muse Spark 1.3 | **Eskalation:** MiMo-V2.6 Pro / Kimi K3.1 Pro
- **Modus:** BUILD-MODUS
- **Target-Dateien:** src/server/world/BridgeBuilder.luau, src/server/world/ValleyWorld.luau
- **Context-Dateien:** src/server/world/WorldZones.luau, src/server/world/TerrainHeight.luau, src/server/world/RoadBuilder.luau
- **Agent-Persona:** Roblox-Geometriker für stufenlose Fahrzeugbrücken.
- **Ausführungs-Prompt:**
  """
  Implementiere `BridgeBuilder.build(parent: Instance): Folder` für jede `BRIDGE_CROSSINGS`-Stelle. Jede Brücke verbindet die Fahrbahn stufenlos, besitzt sichtbare seitliche Begrenzungen und liegt vollständig über dem Wasser.
  Auffahrten müssen mit Fahrrad und Mofa flach befahrbar sein. Integriere den Builder nach Strassen und Wasser in `ValleyWorld`. Keine Schilder und keine Kollision mit Bachufern.
  """
- **Validierung:** `selene src/server/world/BridgeBuilder.luau src/server/world/ValleyWorld.luau` läuft fehlerfrei; Studio befährt jede Brücke ohne Stoss oder Absprung und bestätigt keine trockene Lücke.
- **Commit-Empfehlung:** feat(world): add water crossing bridges

### [x] Task 25: Verkehrszeichen im Strassennetz platzieren
- **Empfohlenes Modell:** DeepSeek V4.1 Flash | **Eskalation:** MiMo-V2.6 Pro / Kimi K3.1 Pro
- **Modus:** BUILD-MODUS
- **Target-Dateien:** src/server/world/TrafficSignPlacer.luau, src/server/world/ValleyWorld.luau, tests/TrafficSignPlacement.spec.luau
- **Context-Dateien:** src/server/world/TrafficSignBuilder.luau, src/server/world/WorldZones.luau
- **Agent-Persona:** Logikentwickler für richtungsbezogene Schweizer Verkehrsbeschilderung.
- **Ausführungs-Prompt:**
  """
  Berechne reine Platzierungen `{ signType, position, rotation, roadId }` und erzeuge daraus Instanzen mit `TrafficSignBuilder`. Vor jeder Stopstrasse steht genau ein Stoppschild; zulässige Tempolimits stehen fahrtrichtungsbezogen am passenden Strassenrand.
  Schilder dürfen weder Fahrbahn noch Gehweg oder Garagenzufahrt blockieren. Keine anderen Schildtypen. Integriere den Placer in `ValleyWorld`.
  """
- **Validierung:** `selene src/server/world/TrafficSignPlacer.luau tests/TrafficSignPlacement.spec.luau` und `lune run tests/TrafficSignPlacement.spec.luau` bestehen; Studio bestätigt ein korrekt ausgerichtetes Stoppschild je Stopstrasse und lesbare Tempolimits.
- **Commit-Empfehlung:** feat(world): place swiss traffic signs

### [x] Task 26: Fünfzehn identische Garagen platzieren
- **Empfohlenes Modell:** DeepSeek V4.1 Flash | **Eskalation:** MiMo-V2.6 Pro / Kimi K3.1 Pro
- **Modus:** BUILD-MODUS
- **Target-Dateien:** src/server/world/GarageWorldBuilder.luau, src/server/world/ValleyWorld.luau, tests/GaragePlacement.spec.luau
- **Context-Dateien:** src/server/world/GarageFactory.luau, src/server/world/WorldLayout.luau, src/server/world/WorldZones.luau
- **Agent-Persona:** Räumlicher Integrator für faire private Garagen.
- **Ausführungs-Prompt:**
  """
  Implementiere `GarageWorldBuilder.build(parent: Instance): Folder`. Erzeuge exakt 15 Instanzen aus `GarageFactory.create`, positioniert an `WorldLayout.GARAGES` mit identischer Distanz zum Dönerladen und ohne Überschneidung mit Strassen, Wasser oder Gebäuden.
  Jede Garage erhält einen eindeutigen Anker-Namen. Keine unterschiedlichen Grössen, Farben oder Zusatzvorteile. Integriere den Builder in `ValleyWorld`.
  """
- **Validierung:** `selene src/server/world/GarageWorldBuilder.luau tests/GaragePlacement.spec.luau` und `lune run tests/GaragePlacement.spec.luau` bestehen; Studio zählt 15 gleiche Garagen mit gleichem Dönerabstand und Mindestabstand.
- **Commit-Empfehlung:** feat(garage): place fifteen equal garages

### [x] Task 27: Garagen privat mit dem GarageService verdrahten
- **Empfohlenes Modell:** DeepSeek V4.1 Flash | **Eskalation:** MiMo-V2.6 Pro / Kimi K3.1 Pro
- **Modus:** BUILD-MODUS
- **Target-Dateien:** src/server/services/GarageService.luau, src/server/bootstrap.server.luau, tests/GarageService.spec.luau
- **Context-Dateien:** src/server/world/GarageWorldBuilder.luau, src/server/world/WorldLayout.luau
- **Agent-Persona:** Backend-Integrator für private Mehrspielerbereiche.
- **Ausführungs-Prompt:**
  """
  Verknüpfe die 15 Weltanker mit `GarageService.assignGarage` und `releaseGarage`. Jeder Spieler erhält genau eine Anker-ID; fremde Spieler dürfen weder Hebebühne noch Werkstattzustand nutzen.
  Ergänze Tests für vollständige Vergabe, Freigabe und Fremdzugriff-Abweisung. Keine Besitzerfarben und keine clientseitige Berechtigungsprüfung.
  """
- **Validierung:** `selene src/server/services/GarageService.luau src/server/bootstrap.server.luau tests/GarageService.spec.luau` und `lune run tests/GarageService.spec.luau` bestehen; Zwei-Client-Studio-Test bestätigt getrennte Garagen.
- **Commit-Empfehlung:** feat(garage): integrate private garage anchors

### [x] Task 28: Serverseitige Grasfelder mit Ausschlusszonen erzeugen
- **Empfohlenes Modell:** DeepSeek V4.1 Flash | **Eskalation:** MiMo-V2.6 Pro / Kimi K3.1 Pro
- **Modus:** BUILD-MODUS
- **Target-Dateien:** src/server/world/GrassFieldBuilder.luau, src/server/world/ValleyWorld.luau, tests/GrassLayout.spec.luau
- **Context-Dateien:** src/server/world/WorldZones.luau, src/server/world/TerrainHeight.luau
- **Agent-Persona:** Performanceorientierter Programmierer für Grasplatzierung.
- **Ausführungs-Prompt:**
  """
  Trenne `calculateGrassClumps()` von der Instanzerzeugung. Erzeuge kurze Grasbüschel nur ausserhalb von Strassen, Wasser, Gebäuden, Garagen und Lieferpunkten mit Sicherheitsabstand.
  Die Büschel sind anchored, tragen den CollectionService-Tag `ToeffliGrass` und eine Chunk-ID. Begrenze die Gesamtzahl für 15 Spieler und integriere den Builder in `ValleyWorld`.
  Keine Grasanimation in diesem Task und kein Gras auf Fahrbahnen.
  """
- **Validierung:** `selene src/server/world/GrassFieldBuilder.luau tests/GrassLayout.spec.luau` und `lune run tests/GrassLayout.spec.luau` bestehen; Studio bestätigt kurze Grasflächen und keine Büschel auf Strassen.
- **Commit-Empfehlung:** feat(world): add grass field generator

### [x] Task 29: Performante clientseitige Grasbewegung implementieren
- **Empfohlenes Modell:** Muse Spark 1.3 | **Eskalation:** MiMo-V2.6 Pro / Kimi K3.1 Pro
- **Modus:** BUILD-MODUS
- **Target-Dateien:** src/client/controllers/GrassController.luau, src/client/bootstrap.client.luau, tests/GrassMotion.spec.luau
- **Context-Dateien:** src/server/world/GrassFieldBuilder.luau
- **Agent-Persona:** Performance-Programmierer für clientseitige Roblox-Vegetation.
- **Ausführungs-Prompt:**
  """
  Implementiere eine reine, testbare Sway-Funktion und einen Client-Controller, der nur nahe `ToeffliGrass`-Chunks gebündelt animiert.
  Nutze eine feste maximale Update-Rate, begrenze die Zahl aktiver Chunks und verändere weder Server-CFrame noch Physik. Entferne oder pausiere weit entfernte Chunks.
  Kein Render-Callback pro Grashalm, keine globale Variable und keine Auswirkung auf Fahreigenschaften.
  """
- **Validierung:** `selene src/client/controllers/GrassController.luau tests/GrassMotion.spec.luau` und `lune run tests/GrassMotion.spec.luau` bestehen; Studio zeigt kurze Bewegung ohne Frame-Einbruch oder Konsolenfehler.
- **Commit-Empfehlung:** feat(world): animate nearby grass

### [x] Task 30: ValleyWorld bereinigen und idempotent machen
- **Empfohlenes Modell:** DeepSeek V4.1 Flash | **Eskalation:** MiMo-V2.6 Pro / Kimi K3.1 Pro
- **Modus:** BUILD-MODUS
- **Target-Dateien:** src/server/world/ValleyWorld.luau
- **Context-Dateien:** src/server/world/WorldLayout.luau, src/server/world/WorldZones.luau
- **Agent-Persona:** Systemintegrator für reproduzierbare Weltgenerierung.
- **Ausführungs-Prompt:**
  """
  Entferne alle verbliebenen alten Greybox-Konstanten und Greybox-Erzeugungen. Führe Terrain, Wasser, Strassen, Kreuzungen, Brücken, Gebäude, Garagen, Vegetation, Weiden, Schilder und Atmosphäre in fester Reihenfolge aus.
  Bei erneutem `build(parent)` wird ausschliesslich die bisher generierte Welt entfernt und neu erzeugt. Öffentliche APIs `getDeliveryPoints`, `getGarageAnchors`, `getPointsOfInterest`, `isInsideBounds` und `cleanup` bleiben erhalten.
  Keine doppelten Häuser, Garagen, Kirchen oder Gewässer.
  """
- **Validierung:** `selene src/server/world/ValleyWorld.luau` läuft fehlerfrei; Studio baut die Welt zweimal und bestätigt gleiche Objektanzahlen, 2 Dörfer, 1 Kirche und 15 Garagen ohne Duplikate.
- **Commit-Empfehlung:** perf(world): make world generation idempotent

### [x] Task 31: Minimal- und Weltabnahme dokumentieren
- **Empfohlenes Modell:** Beam 1.0 | **Eskalation:** MiMo-V2.6 Pro / Kimi K3.1 Pro
- **Modus:** BUILD-MODUS
- **Target-Dateien:** docs/PLAYTEST.md
- **Context-Dateien:** docs/MEMORY.md, docs/TASKS.md
- **Agent-Persona:** QA-Dokumentationsentwickler für die Roblox-Minimalversion.
- **Ausführungs-Prompt:**
  """
  Erweitere die Abnahmeliste um Minimal-Spawn, Fahrradfahrt, Dönerloop, zwei Dörfer mit einzigartigen Häusern, eine Kirche, 15 gleiche private Garagen, Strassenmarkierungen, Stopstrassen, Kreisel, Brücken, See und drei Bäche, Weiden, Vegetation, Gras-Performance sowie Streaming und Serverlast.
  Jeder kritische Pfad erhält ein eindeutiges Erwartungsergebnis und ein Feld für tatsächliches Ergebnis. Keine erfundenen Testergebnisse und keine Abhakung ohne Durchführung.
  """
- **Validierung:** Markdown-Prüfung bestätigt für jeden kritischen Pfad ein eindeutiges Erwartungsergebnis und ein Ergebnisprotokoll; keine Pflichtzeile fehlt.
- **Commit-Empfehlung:** docs(qa): extend playable world checklist

### [ ] Task 32: 15-Spieler-Abnahme durchführen und dokumentieren
- **Empfohlenes Modell:** DeepSeek V4.1 Flash | **Eskalation:** MiMo-V2.6 Pro / Kimi K3.1 Pro
- **Modus:** BUILD-MODUS
- **Target-Dateien:** docs/PLAYTEST.md
- **Context-Dateien:** docs/MEMORY.md
- **Agent-Persona:** QA- und Performance-Engineer für den finalen Multiplayer-Test.
- **Ausführungs-Prompt:**
  """
  Führe die Checkliste aus Task 31 mit tatsächlich 15 Spielern auf demselben Server aus. Prüfe getrennte private Garagen, gleiche Garagenbausubstanz, Spawn, Fahrrad, Dönerloop, Strassen, Schilder, Brücken, Gewässer, Persistenz, Streaming und Serverleistung.
  Trage ausschliesslich beobachtete Ergebnisse mit Datum, Testumgebung und Fehlermeldungen ein. Nicht bestandene Punkte bleiben offen und erzeugen einen konkreten Korrekturhinweis.
  """
- **Validierung:** Alle Pflichtfelder der Checkliste sind mit tatsächlichen Ergebnissen ausgefüllt; Start, Fahrt, Lieferung und 15 getrennte Garagen funktionieren ohne roten Output.
- **Commit-Empfehlung:** docs(qa): record fifteen player acceptance

### [x] Task 34: Studio-Mehrclient und konsistenten Guthaben-Snapshot herstellen (B32-02, B32-04)
- **Empfohlenes Modell:** DeepSeek V4.1 Flash | **Eskalation:** MiMo-V2.6 Pro / Kimi K3.1 Pro
- **Modus:** BUILD-MODUS
- **Target-Dateien:** src/server/net/PlayerIds.luau, src/server/bootstrap.server.luau, tests/PlayerIds.spec.luau, tests/RequestRouter.spec.luau, docs/PLAYTEST.md
- **Context-Dateien:** src/server/net/RequestRouter.luau, src/server/services/EconomyService.luau, src/shared/data/PlayerDataSchema.luau
- **Agent-Persona:** Sicherheitsorientierter Roblox-Netzwerkintegrator fuer Studio-Mehrclient und Guthabenkonsistenz.
- **Ausfuehrungs-Prompt:**
  """
  Bilde negative Studio-UserIds ausschliesslich bei `RunService:IsStudio()` auf einen reservierten positiven Bereich ab; Live-Server bleiben unveraendert streng. Alle Services und der Router erhalten dieselbe kanonische ID. `VehicleSelect` liefert den echten `EconomyService`-Stand statt `PlayerDataSchema.createDefault().cash`. Router-Validierung nicht aufweichen; keine Clientwerte, keine globalen Variablen.
  """
- **Validierung:** `selene` auf den Targets, `lune run` fuer `PlayerIds.spec` und `RequestRouter.spec`, `rojo build` fehlerfrei; Studio-8-Client-Lauf mit `EconomyGet`/`VehicleSelect`/`DeliveryOrder` ohne `invalid_player` und identischem `cash`.
- **Commit-Empfehlung:** fix(net): canonicalize studio player ids and cash snapshot
- **Ergebnis 2026-11-10:** `PlayerIds.canonical` (Offset 9_000_000_000, nur Studio) + Bootstrap-Anbindung + `VehicleSelect`-Guthaben umgesetzt. `PlayerIds.spec` 18/18, `RequestRouter.spec` gruen (inkl. neuer Negativprobe `UserId=-1`), Selene 0 Fehler, Rojo-Build ok. Studio-8-Client-Lauf offen.

### [x] Task 35: Generische Gameplay-Handler mit Profil-Store verdrahten (B32-03)
- **Empfohlenes Modell:** DeepSeek V4.1 Flash | **Eskalation:** MiMo-V2.6 Pro / Kimi K3.1 Pro
- **Modus:** BUILD-MODUS
- **Target-Dateien:** src/server/services/ProfileAdapter.luau, src/server/services/PlayerStore.luau, src/server/services/GameplayHandlers.luau, src/server/bootstrap.server.luau, src/shared/net/RemoteProtocol.luau, tests/GenericHandlers.spec.luau
- **Context-Dateien:** src/server/services/ProfileService.luau, src/server/services/VehicleService.luau, src/server/services/ShopService.luau, src/server/services/WorkshopService.luau, src/server/services/GarageService.luau, src/server/services/DynoService.luau, src/server/services/FuelService.luau, src/server/services/MissionService.luau, src/server/services/EconomyService.luau, src/shared/data/PlayerDataSchema.luau
- **Agent-Persona:** Server-Integrator fuer persistente, clientunabhaengige Gameplay-Handler.
- **Ausfuehrungs-Prompt:**
  """
  Instanziiere ProfileService mit einem DataStore-Adapter (Produktion) und einem In-Memory-Adapter (Studio/Test). Baue `PlayerStore` als Bruecke zwischen `PlayerDataSchema` (Persistenz) und der Service-Sicht (`money`, `vehicles`-Map, `selectedVehicle`); synchronisiere `cash` beim Laden und Speichern mit `EconomyService`. Registriere `VehicleBuy`, `ShopCatalog`, `ShopBuy`, `WorkshopInstall`, `WorkshopPaint`, `GarageEnter`, `DynoRun`, `FuelRefill`, `MissionProgress`, `EconomyTransfer` serverseitig mit Rate-Limit und Payload-Schemas. Preise, Distanzen, Besitz, Werkstattstatus und Rabatte bleiben ausschliesslich serverseitig.
  """
- **Validierung:** `selene` auf den Targets, alle `lune`-Specs inkl. `GenericHandlers.spec`, `rojo build` fehlerfrei; Play Solo mit echtem Konto: keines der zehn Remotes liefert `unknown_action`, `VehicleSelect.cash == EconomyGet.cash`.
- **Commit-Empfehlung:** feat(server): register generic gameplay handlers and unify cash
- **Ergebnis 2026-11-10:** `ProfileAdapter` (Memory/DataStore), `PlayerStore` (Schema-Sicht, Cash-Sync, Rabatt- und Teile-Persistenz) und `GameplayHandlers` (12 Aktionen inkl. `VehicleSelect`/`EconomyGet`) umgesetzt; Bootstrap initialisiert echte Service-Instanzen, DataStore nur ausserhalb Studio. Validierung: Selene 0 Fehler, 27/27 Lune-Specs (davon `GenericHandlers.spec` 64 Checks), Rojo-Build ok. Abgedeckt: kein `unknown_action`, Cash-Konsistenz, Rabatt/Doppelkauf/Fremdkonto, Shop, Werkstatt, Garage, Mission, Tank-/Dyno-Servicecodes, Persistenz nach Rejoin. Play-Solo-/15-Client-Lauf offen; Tankstelle und Dyno-Zustand fehlen weiterhin als Weltintegration.

### [ ] Task 36: Gekauftes Mofa als echtes, fahrbares Fahrzeug spawnen (Vorbedingung für M-02/F-01/D-01)
- **Empfohlenes Modell:** DeepSeek V4.1 Flash | **Eskalation:** MiMo-V2.6 Pro / Kimi K3.1 Pro
- **Modus:** BUILD-MODUS
- **Target-Dateien:** src/server/vehicle/MopedLayout.luau, src/server/vehicle/MopedSpawner.luau, src/server/bootstrap.server.luau, src/client/controllers/MopedMountController.luau, src/client/controllers/MopedController.luau, src/client/controllers/BicycleController.luau, src/client/bootstrap.client.luau, tests/MopedLayout.spec.luau
- **Context-Dateien:** src/server/vehicle/BicycleSpawner.luau, src/shared/data/VehicleCatalog.luau, src/server/services/PlayerStore.luau, src/server/services/GameplayHandlers.luau
- **Agent-Persona:** Roblox-Vehicle-Integrator für ein serverautoritatives, verankertes Arcade-Mofa.
- **Ausführungs-Prompt:**
  """
  Erzeuge für jedes serverseitig besessene Mofa (`puch_maxi_s`, `piaggio_ciao`) genau ein verankertes Model `Moped_<VehicleId>_<UserId>` in `Workspace.ToeffliTalVehicles`. Das Model besitzt `VehicleSeat` `Seat`, `Drive` als PrimaryPart, zwei Räder, Tank, Lenker, Licht und Auspuff, alle über WeldConstraints verbunden. Setze `OwnerUserId` (kanonisch), `OwnerPlayerUserId`, `VehicleId` sowie die Fahrwerte aus `VehicleCatalog` als Attribute und tagge es mit `ToeffliMoped`.
  Spawne gekaufte Mofas beim Kauf neben dem Käufer und beim Beitritt nach dem Charakter-Spawn; entferne sie beim Verlassen. Der Client darf nur eigene Modelle mounten, E steuert Auf-/Absteigen, und die Fahrt erfolgt wie beim Fahrrad über clientseitiges `PivotTo` mit den serverseitig gelieferten Attributwerten. Kein Wheel-Drive, keine Clientpreise, keine Client-Besitzentscheidung und keine globalen Variablen.
  """
- **Validierung:** `selene` auf den Target-Dateien, `lune run tests/MopedLayout.spec.luau`, alle übrigen Lune-Specs und `rojo build default.project.json -o build/ToeffliTal.rbxlx` bestehen; Studio bestätigt nach Kauf genau ein Mofa-Model, E-Aufsteigen, Fahren mit W/A/S/D, F-Motor und E-Absteigen ohne roten Output.
- **Commit-Empfehlung:** feat(vehicle): spawn and mount purchased mopeds
- **Ergebnis 2026-11-10:** `MopedLayout` (reine, deterministische Bauteile + Parkplätze), `MopedSpawner` (verankertes `VehicleSeat`-Model, Attribute, Tag, Boden-Raycast, Kauf-/Join-Spawn, Cleanup), `MopedMountController` (E-Mount, Auto-Sitz, nur eigene Modelle) und `PivotTo`-Fahrt im `MopedController` umgesetzt. Selene 0 Fehler, 28/28 Lune-Specs (`MopedLayout.spec` 125 Checks), Rojo-Build ok. Studio-Prüfung offen (Kauf → genau ein Model, E, W/A/S/D, F, E); Task bleibt bis dahin `[ ]`.

### [ ] Task 36a: Testguthaben und Testkauf fuer die Studio-Abnahme (Vorbedingung für Task 36)
- **Empfohlenes Modell:** DeepSeek V4.1 Flash | **Eskalation:** MiMo-V2.6 Pro / Kimi K3.1 Pro
- **Modus:** BUILD-MODUS
- **Target-Dateien:** src/server/services/PlayerStore.luau, src/server/bootstrap.server.luau, tests/PlayerStoreGrant.spec.luau
- **Context-Dateien:** src/server/services/GameplayHandlers.luau, src/server/net/RequestRouter.luau, src/shared/data/PlayerDataSchema.luau, src/shared/data/VehicleCatalog.luau
- **Agent-Persona:** Sicherheitsbewusster Test-Harness-Integrator, der Live-Verhalten unangetastet laesst.
- **Ausführungs-Prompt:**
  """
  Ermoegliche ausschliesslich in Studio (`RunService:IsStudio()`) oder in einer ausdruecklich markierten Abnahme-Welt (`ReplicatedStorage`-Attribut `AcceptanceMode == true`) ein Session-Testguthaben und einen Testkauf. `PlayerStore` erhaelt die Option `sessionGrantCash` als nicht persistiertes Session-Minimum; ungueltige Werte werden verworfen. Der Bootstrap uebergibt 5000 CHF nur im Abnahme-Modus und verbindet pro Spieler einen `/buy <vehicleId>`-Chatbefehl, der den bestehenden serverseitigen `VehicleBuy`-Handler ueber den `RequestRouter` aufruft. Keine Clientpreise, keine Client-Besitzentscheidung, keine globalen Variablen, kein Live-Einfluss.
  """
- **Validierung:** `selene` auf den Target-Dateien, `lune run tests/PlayerStoreGrant.spec.luau`, alle uebrigen Lune-Specs und `rojo build default.project.json -o build/ToeffliTal.rbxlx` bestehen; Studio bestaetigt `/buy puch_maxi_s`: genau ein Mofa, Guthaben 4201, danach `EconomyGet` identisch.
- **Commit-Empfehlung:** test(server): add acceptance cash grant and buy command
- **Ergebnis 2026-11-10:** `PlayerStore.sessionGrantCash` (sanitiert, abgerundet, nur Session-Minimum, nicht in `cash` gespeichert), Abnahme-Erkennung im Bootstrap (`IsStudio()` oder `AcceptanceMode`-Attribut), 5000 CHF Session-Guthaben, pro Spieler gebundener `/buy`-Chatbefehl über den echten `VehicleBuy`-Handler (Legacy-`Chatted` und `TextChatService.MessageReceived`, Duplikatschutz) inkl. Cleanup bei Leave/Shutdown und `PlayerStoreGrant.spec` (25 Checks) umgesetzt. Selene 0 Fehler, 29/29 Lune-Specs, Rojo-Build ok. Studio-Pruefung `/buy` offen; Task bleibt `[ ]`.

### [ ] Task 36b: Strassen sichtbar, Fahrzeuge geerdet/ausgerichtet, Kollision und E-only-Sitz (Vorbedingung für Task 36)
- **Empfohlenes Modell:** DeepSeek V4.1 Flash | **Eskalation:** MiMo-V2.6 Pro / Kimi K3.1 Pro
- **Modus:** BUILD-MODUS
- **Target-Dateien:** src/server/world/RoadSurface.luau, src/server/world/TerrainBuilder.luau, src/server/world/RoadBuilder.luau, src/server/world/IntersectionBuilder.luau, src/server/world/BridgeBuilder.luau, src/server/vehicle/BicycleSpawner.luau, src/server/vehicle/MopedSpawner.luau, src/server/vehicle/VehicleAssembly.luau, src/server/vehicle/MopedLayout.luau, src/server/bootstrap.server.luau, src/client/controllers/VehiclePhysics.luau, src/client/controllers/VehicleMotion.luau, src/client/controllers/BicycleController.luau, src/client/controllers/MopedController.luau, src/client/controllers/MopedMountController.luau, tests/MopedLayout.spec.luau, tests/VehicleSurface.spec.luau
- **Context-Dateien:** src/server/world/WorldZones.luau, src/server/world/TerrainHeight.luau, src/server/world/ConiferFactory.luau, docs/PLAYTEST.md
- **Agent-Persona:** Roblox-Welt- und Fahrzeug-Integrator für sichtbare Strassen und echte Physik-Fahrzeuge.
- **Ausführungs-Prompt:**
  """
  Behebe die im Studio gemeldeten Darstellungs- und Fahrfehler, ohne Gameplay-Ökonomie oder Serverautorität zu verändern. Messe die tatsächliche Terrainoberfläche zur Bauzeit per Raycast und lege darauf eine **dünne Asphaltdecke** (`RoadSurface`, ~0.5 Studs dick, `SURFACE_MARGIN` über dem höchsten Messpunkt). Kein Terrain-Ausstanzen. Setze Startfahrrad und Mofa per Raycast auf den echten Boden, versetzt seitlich/hinter dem Charakter, und drehe die Modelle so, dass die sichtbare Front auf lokal -Z liegt. Mache die Fahrzeuge zu echten Physik-Assemblies: Teile entankert, verschweisst, `Drive` trägt die Masse (übrige Teile `Massless`); im Stand verankert, beim Aufsitzen entankert und dem Spieler als Netzwerkbesitzer zugewiesen, beim Absteigen wieder verankert (`VehicleAssembly`). Der Client steuert Ausrichtung (`AlignOrientation`, starr, mit Steigungs-Pitch) und Antrieb (`VectorForce`); nur bei Bodenkontakt wird Schub gegeben, sonst greift Gravitation. Auf-/Absteigen nur per E (`Seat.Disabled`). Keine Clientpreise, keine Client-Besitzentscheidung, keine globalen Variablen.
  """
- **Validierung:** `selene` auf den Target-Dateien, `lune run tests/VehicleSurface.spec.luau`, `lune run tests/MopedLayout.spec.luau`, alle übrigen Lune-Specs und `rojo build default.project.json -o build/ToeffliTal.rbxlx` bestehen; Studio bestätigt: Strassen liegen sichtbar auf dem Boden, Fahrrad/Mofa stehen beim Spawn auf den Rädern, Front zeigt in Fahrtrichtung, echte Gravitation/Kollision (kein Durchfahren, kein Fliegen), Steigungen werden geneigt befahren, Auf-/Absteigen nur per E ohne Auto-Sitz.
- **Commit-Empfehlung:** fix(world,vehicle): drape roads on terrain and drive vehicles with real physics
- **Ergebnis 2026-11-10:** Terrain-Ausstanzen entfernt; `RoadBuilder`/`IntersectionBuilder`/`BridgeBuilder` messen die Oberfläche per Raycast und legen eine dünne (0.5) Asphaltdecke mit 0.15 Abstand darüber – kein Schweben, kein Begraben, keine Rampen. Fahrzeuge sind echte Physik-Assemblies: `VehicleAssembly` verankert im Stand und gibt sie beim Aufsitzen an die Engine/den Spieler frei; `VehiclePhysics` (Client) steuert starre Ausrichtung mit Steigungs-Pitch, Vortrieb/Bremse/Grip per `VectorForce` und gibt nur bei Bodenkontakt Schub (kein Fliegen). `BicycleSpawner`/`MopedSpawner` erden per Raycast (Fallback `TerrainHeight`), versetzen den Spawn und loggen die Position; Respawn auf `CharacterAdded`. Sitze `Disabled`, E-only. Selene 0 Fehler, 30/30 Lune-Specs (`VehicleSurface.spec` 29 Checks, `MopedLayout.spec` 129 Checks), Rojo-Build ok. Nachtrag: serverseitige `AlignOrientation` haelt die Fahrzeuge auch ohne Client-Besitz aufrecht, Zielgier wird beim Aufsitzen aktualisiert, Spawn aus der **Charakter-Standhoehe** (`HumanoidRootPart.Y - HipHeight` + Radradius + 0.5), Sitz-Nachsicht 0.75s, **kein Occupant-Poll mehr** (verhinderte sporadisches Wieder-Verankern). Studio-Pruefung offen; Task bleibt `[ ]`.

### [ ] Task 36e: Gebaeude auf spielbare Groesse skalieren
- **Empfohlenes Modell:** DeepSeek V4.1 Flash | **Eskalation:** MiMo-V2.6 Pro / Kimi K3.1 Pro
- **Modus:** BUILD-MODUS
- **Target-Dateien:** src/server/world/BuildingPlacement.luau, src/server/world/BuildingFactory.luau, src/server/world/GarageFactory.luau, src/server/world/GarageWorldBuilder.luau, src/server/world/ChurchBuilder.luau, src/server/world/DonerShopBuilder.luau, src/server/world/WorldLayout.luau, src/server/world/WorldZones.luau
- **Context-Dateien:** src/server/world/VillageBuilder.luau, src/server/world/data/BuildingCatalog.luau, tests/WorldZones.spec.luau, tests/GaragePlacement.spec.luau, tests/BuildingCatalog.spec.luau
- **Agent-Persona:** Roblox-Welt-Skalierer für glaubwürdige Gebäudegrössen ohne Layoutkollisionen.
- **Ausführungs-Prompt:**
  """
  Vergrössere Häuser (Faktor 1.7), Garagen (1.4), Kirche (1.7) und Dönerladen (1.5) einheitlich, ohne Gameplay-Logik zu ändern. Neue Hilfsfunktion `BuildingPlacement` skaliert Modelle und setzt die tiefste Stelle exakt auf den Boden; Garagen werden pivotbasiert platziert, der Döner-Abholpunkt wird nach dem Skalieren exakt zurückgesetzt. Ziehe die Reservierungsflächen nach (`SLOT_FOOTPRINT`, `CHURCH.footprint`, `GARAGE_RADIUS`) und vergrössere `DELIVERY_OFFSET`, damit Lieferpunkte vor der grösseren Fassade liegen. Keine Preise, keine Besitzlogik, keine globalen Variablen.
  """
- **Validierung:** `selene` auf den Target-Dateien, alle Lune-Specs (`WorldZones.spec`, `GaragePlacement.spec`, `BuildingCatalog.spec`, `WorldLayout.spec`) und `rojo build default.project.json -o build/ToeffliTal.rbxlx` bestehen; Studio bestätigt Häuser/Garagen/Kirche/Laden deutlich grösser, keine Überlappung mit Strassen, Gebäude stehen bündig auf dem Boden.
- **Commit-Empfehlung:** feat(world): scale buildings to player-readable sizes
- **Ergebnis 2026-11-10:** `BuildingPlacement` (Skalieren + Boden-Ausrichtung), Häuser 1.7, Garagen 1.4, Kirche 1.7, Laden 1.5; Garagen pivotbasiert, Abholpunkt exakt zurückgesetzt, Reservierungen und Lieferabstand angepasst. Selene 0 Fehler, 30/30 Lune-Specs, Rojo-Build ok. Studio-Sichtprüfung offen; Task bleibt `[ ]`.

### [ ] Task 36f: Start-Spawn auf den Boden und Fahrzeug-Spawn entkoppeln
- **Empfohlenes Modell:** DeepSeek V4.1 Flash | **Eskalation:** MiMo-V2.6 Pro / Kimi K3.1 Pro
- **Modus:** BUILD-MODUS
- **Target-Dateien:** src/server/world/SpawnBuilder.luau, src/server/world/ValleyWorld.luau, src/server/world/BuildingPlacement.luau, src/server/world/VillageBuilder.luau, src/server/world/GarageWorldBuilder.luau, src/server/world/DonerShopBuilder.luau, src/server/world/ChurchBuilder.luau, src/server/vehicle/BicycleSpawner.luau, src/server/vehicle/MopedSpawner.luau
- **Context-Dateien:** src/server/world/WorldLayout.luau, src/server/world/TerrainHeight.luau, docs/PLAYTEST.md
- **Agent-Persona:** Roblox-Spawn-Integrator, der Spawnhöhen und Bodenkontakt robust macht.
- **Ausführungs-Prompt:**
  """
  Behebe den fehlenden Start-Spawn: Ohne `SpawnLocation` setzt Roblox Charaktere bei ca. Y=100 ab, wodurch der Fahrzeug-Spawn die Fallhöhe übernimmt. Baue genau einen `SpawnLocation` am Dönerplatz (`(0, Boden+0.2, 26)`) auf der per Raycast gemessenen Oberfläche. Entkopple den Fahrzeug-Spawn von der Charakterhöhe: Raycast von fester Höhe (Y=512) nach unten, Fallback `TerrainHeight.heightAt`; die Charakterposition dient nur für X/Z und Blickrichtung. Ziehe die Bodenmessung für Häuser, Garagen, Kirche und Laden ebenfalls auf den Bau-Raycast (`BuildingPlacement.surfaceAt`). Keine Preise, keine Besitzlogik, keine globalen Variablen.
  """
- **Validierung:** `selene` auf den Target-Dateien, alle Lune-Specs und `rojo build default.project.json -o build/ToeffliTal.rbxlx` bestehen; Studio bestätigt: Charakter spawnt auf dem Boden, `[Spawn]`-Log zeigt Y nahe der Terrainhöhe (nicht ~100), Fahrrad/Mofa stehen sichtbar neben dem Charakter.
- **Commit-Empfehlung:** fix(world,vehicle): add ground spawn and decouple vehicle spawn height
- **Ergebnis 2026-11-10:** `SpawnBuilder` setzt einen `SpawnLocation` am Dönerplatz auf den per Raycast gemessenen Boden; `BuildingPlacement.surfaceAt` liefert die tatsächliche Oberfläche für Häuser, Garagen, Kirche und Laden; Fahrrad/Mofa spawnen per Raycast von Y=512 (Fallback `TerrainHeight`) unabhängig von der Charakterhöhe. Selene 0 Fehler, 30/30 Lune-Specs, Rojo-Build ok. Studio-Prüfung offen; Task bleibt `[ ]`.
- **Nachtrag 36g (2026-11-10):** Client-seitige `GetNetworkOwner()`-Abfrage entfernt (Server-API, verursachte „Network Ownership API can only be called from the Server"); Coyote-Zeit 0.2 s hält den Schub über kurze Bodenwellen; Beschleunigung Fahrrad 130 / Mofa 180 gegen kraftlose Steigungen. Selene 0 Fehler, 30/30 Lune-Specs, Rojo-Build ok.

### [ ] Task 36h: Strassen bündig in das Terrain malen
- **Empfohlenes Modell:** DeepSeek V4.1 Flash | **Eskalation:** MiMo-V2.6 Pro / Kimi K3.1 Pro
- **Modus:** BUILD-MODUS
- **Target-Dateien:** src/server/world/RoadSurface.luau, src/server/world/RoadPainter.luau, src/server/world/RoadBuilder.luau, src/server/world/IntersectionBuilder.luau, src/server/world/BridgeBuilder.luau, src/server/world/ValleyWorld.luau, tests/VehicleSurface.spec.luau
- **Context-Dateien:** src/server/world/WorldZones.luau, src/server/world/TerrainHeight.luau, src/server/world/TerrainBuilder.luau
- **Agent-Persona:** Roblox-Terrain-Integrator für garantiert bündige Strassen.
- **Ausführungs-Prompt:**
  """
  Ersetze die schwebenden Asphalt-Parts durch buendig in das Terrain gemalten Asphalt: `RoadPainter` stempelt die oberste Voxelreihe aller `ROAD_SEGMENTS`, `STOP_ROADS` und `ROUNDABOUTS` mit `Enum.Material.Asphalt`. `RoadSurface` liefert nur noch reine Regeln (`cellTop`, `stepsFor`, `paintSize`). `RoadBuilder` und `IntersectionBuilder` zeichnen nur Mittellinie und Haltelinien; `BridgeBuilder` setzt ein duennes Deck buendig auf die gemalte Flaeche. Keine Preise, keine Besitzlogik, keine globalen Variablen.
  """
- **Validierung:** `selene` auf den Target-Dateien, alle Lune-Specs (`VehicleSurface.spec`) und `rojo build default.project.json -o build/ToeffliTal.rbxlx` bestehen; Studio bestätigt: Strassen sind durchgehend als Asphalt sichtbar und liegen bündig auf dem Terrain, keine schwebenden oder versinkenden Streifen.
- **Commit-Empfehlung:** fix(world): paint roads flush into terrain
- **Ergebnis 2026-11-10:** `RoadPainter` färbt die oberste Voxelreihe der Strassen/Stopstrassen/Kreisel mit Asphalt; `RoadBuilder` (Mittellinie) und `IntersectionBuilder` (Haltelinien) zeichnen nur noch Linien, `BridgeBuilder` ein dünnes, bündiges Deck. Selene 0 Fehler, 30/30 Lune-Specs, Rojo-Build ok. Studio-Prüfung offen; Task bleibt `[ ]`.
