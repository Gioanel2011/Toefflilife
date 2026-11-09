# Projektgedächtnis – Töffli Tal
Stand: 2026-11-09

## Projekt
„Töffli Tal“: Schweizer Roblox-Open-World für max. 15 Spieler; Server autoritativ, Rojo/Rokit/Selene/StyLua/Lune.

## Ist-Zustand
- Toolchain 7.7.1/0.32.0/2.6.0/1.70.1/0.11.1; Build erzeugt `build/ToeffliTal.rbxlx`.
- Backend/Shared/Client-Basis und Greybox-Welt (Task 01) vorhanden.
- Erledigt Task 02–05: Fahrradspawn, E-Mount, Delivery-Remotes + Prompt.
- Erledigt Task 07–10: WorldLayout, WorldZones, TerrainHeight, BuildingCatalog.
- Erledigt Task 14–19: Terrain/Wasser/Strassen/DonerShop/Kirche/Doerfer.
- Erledigt Task 20–24: Weiden, Vegetation, Atmosphaere, Kreuzungen, Bruecken.
- Erledigt Task 25–28: Schilder, 15 Garagen, GarageService, Grasfelder.
- Erledigt Task 29: `GrassController` (reine `swayOffset`/`selectActiveChunks`/`isChunkInRange`; ein Heartbeat-Sammelupdate 0.15s, max 24 Chunks, NEAR 120/FAR 150, Amplitude 0.08) + `GrassMotion.spec` 30/30 + Bootstrap-Start/Stop; Selene 0 Fehler. Studio-Sichtcheck offen.
- Erledigt Task 30: `ValleyWorld` greybox-frei (keine Alt-Konstanten, Waende, Marker, Pads); `build` idempotent via `cleanup` (entfernt nur Root `ValleyWorld`), feste Build-Reihenfolge; Daten-APIs aus `WorldLayout`, `getBounds`/`MAX_PLAYERS` erhalten. Selene 0 Fehler; Studio-Doppelbuild offen.
- Erledigt Task 33: Minimal-Loop verkabelt (generischer Router + `VehicleSelect`/`EconomyGet`, `DeliveryService` Array-Format + `Vector3`=`"vector"`, `AtmosphereBuilder` `ColorShift_Top/_Bottom`); Selene 0 Fehler, DeliveryService.spec grün, Rojo-Build ok.
- Erledigt Task 06: Studio-Lauf 3 mit frischer Rojo-Place; MS-01…MS-11 11/11 bestanden (Details `docs/PLAYTEST.md` 13.8). Resthinweis: projektexterne `cloud_…`-Meldung.
- Erledigt Task 31: Abnahmeliste in `docs/PLAYTEST.md` Abschnitt 14 (30 Checks) mit eindeutigem Erwartungsergebnis und Feld für tatsächliches Ergebnis pro kritischem Pfad; keine erfundenen Ergebnisse.

## Konventionen
- Serverautoritativ; keine Client-Preise. Keine globalen Variablen.
- Nur Target-Dateien ändern; ein Task pro Durchlauf; Validierung vor `[x]`; Git nur als Empfehlung.
- Planung: DeepSeek V4.1 Flash (Plan). Code/Math: Muse Spark 1.3 / DeepSeek Build.
- Routine/UI: Beam 1.0 Build. Eskalation nur nach 2 Fehlversuchen (MiMo-V2.6 Pro/Kimi K3.1 Pro).

## Queue
- Offen: Task 32. Naechster: Task 32 (DeepSeek V4.1 Flash, Build; Eskalation MiMo-V2.6 Pro/Kimi K3.1 Pro).
