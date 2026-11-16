# Projektgedächtnis – Töffli Tal
Stand: 2026-11-13

## Projekt
„Töffli Tal“: Schweizer Roblox-Open-World, max 15 Spieler; serverautoritativ, Rojo/Rokit/Selene/StyLua/Lune.

## Ist-Zustand
- Toolchain 7.7.1/0.32.0/2.6.0/1.70.1/0.11.1; Build `build/ToeffliTal.rbxlx`.
- Erledigt 01–05: Welt-Bootstrap, Fahrradspawn, E-Mount, Delivery-Remotes + Prompt.
- Erledigt 07–10: WorldLayout, WorldZones, TerrainHeight, BuildingCatalog.
- Erledigt 14–19: Terrain/Wasser/Strassen/DonerShop/Kirche/Doerfer.
- Erledigt 20–24: Weiden, Vegetation, Atmosphaere, Kreuzungen, Bruecken.
- Erledigt 25–28: Schilder, 15 Garagen, GarageService, Grasfelder.
- Erledigt 29/30/33/06/31: Grasbewegung, ValleyWorld idempotent, Minimal-Loop, Minimal-Abnahme (MS-01…MS-11 11/11), QA-Checkliste (30 Checks).
- Erledigt 34/35 (Code): kanonische Studio-IDs + Guthaben-Snapshot; Profil-/PlayerStore-/GameplayHandler (12 Aktionen). Studio-Mehrclient offen.
- Task 36/36a/36b/36e/36f/36g/36h im Code fertig, Studio-Pruefung offen (Mofa-Spawner, /buy-Testguthaben, Physik-Assemblies, Gebaeudeskalierung, Boden-Spawn, Coyote/Netzwerkfix, Asphalt in Terrain gemalt). Selene 0 Fehler, Lune-Specs gruen, Rojo-Build ok.
- SwissMap: 10000x8000, 84.070 Parts, 312 Haeuser, 15 Garagen, 4800 Tannen, 9 Weiden, 12 Acker, 12 PointLights, 6 JobPoints; neues Place `Place1` (Backup Version 45). Keine screen_capture mit Kameraposition (blockiert Editor-Kamera).
- Erledigt 41: Gras 0.05->0.02. Erledigt 42: Dachfenster/Gauben (`roofDormer` + 2 Aufrufe) entfernt. Je Selene 0 Fehler.
- Task 43 im Code fertig, Build offen: VILLAGES rf 215/143/150, rb 320/240/245, rs 300/230/225, count 27/17/15; gapLeft random(3,5); 6 neue Minor-Ringe (hw 6, tStart/tEnd). Selene 0 Fehler (117 Warnungen).
- Task 44 im Code fertig, Build offen: `rollHouse` nur Sattel; neues Flachdach-Quartier bei Talort (`buildModernBlock`/`Carport`/`Quarter`: 3 Zeilen 4/4/3, eigene Quartierstrasse, Innenhof, Anbindung via `connectToRoad`); MODERN-Zone von Dorfhaeusern freigehalten. Selene 0 Fehler (127 Warnungen).
- Task 45 im Code fertig, Build offen: Laternen-Offset `hw + 1.8` -> `hw + 3.9` (Gruenstreifen), `hedgeZ` `-(lot - 1.2)` -> `-(lot - 2.6)`, Briefkasten folgt `hedgeZ + 0.4`. Selene 0 Fehler (127 Warnungen).
- Task 46 im Code fertig: `roofGutter` erzeugt nur noch ein Fallrohr pro Satteldachhaus (vorne/Strassenseite), Rinnenschleife ueber beide Dachseiten bleibt; Flachdachhaeuser unveraendert ohne Fallrohr. Selene 0 Fehler (127 Warnungen).
- Task 48 im Code fertig, Build offen: `nearNode`/`nearestNode`, Linien-Cut bei `r + 2`, Stopplinie `r + 1.2` + Schild im Gruenstreifen, 48-Segment-Randsteinring (0.5) + innerorts Trottoirring (`r + 1.75`, 2.5) mit Arm-Oeffnungen, Durchgangsarme aus ROADLIST abgeleitet. Selene 0 Fehler (133 Warnungen).
- Task 49 im Code fertig, Build offen: Kreisel als Knoten (Zufahrten enden `Rout + 1`, Asphaltbogen bis `Rout + 1.2` auf `ROAD_TOP`, Randsteinring `Rout` + innerorts Trottoirring `Rout + 1.75`, Arm-Oeffnungen, Insel unveraendert); Netz-Pruefung als `print`/`warn` (Knoten, Arme, Sackgassen, Segmente < `2*hw`, Knotenabstand, Armwinkel < 35 Grad). Selene 0 Fehler (132 Warnungen).
- **2026-11-16 "keine 3-Ecke mehr" (47/48/49 fertig):** Ursache der Dreiecke war die See-Ausweich-Funktion (`lakeD < 1.34` inkl. Rauschen): sie verschob Spline-Punkte knapp ausserhalb des Wassers um 40-90 Studs und riss 80-Studs-Sprungsegmente in die Strassen, die quer durch andere Strassen schnitten. Neu: Push nur im Wasser (`l < 1.03` -> `1.07`), danach 12 Glaettungspaesse + Nachpruefung. Zusaetzlich: `Waldstrasse` aus dem See verschoben, `Hofweg Nord` entfernt, `Seerandstrasse` entfernt (lief 455 Studs deckungsgleich auf der `Westtalstrasse`), `Seestrasse` muendet aus Sueden (vorher 33-Grad-Knick), neuer Endpunkt-Pass erzeugt fuer jedes Road-Endpunktpaar < 14 Studs einen Knoten (reihenfolgeunabhaengig), Knotenradius `hwMax * 2.2`, keine Knoten am Kreisel (`Rout + 6`). Messung im Place: Asphalt-Ueberlappung **2416 -> 14** Proben, **0** Asphalt im Wasser, **0** Enden < 40 Grad; Vollbuild `FERTIG!`, 22 Knoten / 2 Kreisverkehre / 87045 Parts, keine Winkel-/Distanz-/Stummel-Warnungen. Selene 0 Fehler.
- **RoadKit-Status:** im Place **0 MeshParts / 0 Vorlagen** (nur `RoadKit_Showcase`). Der Generator nutzt Kit-Kacheln nur, wenn Modelle mit `Road_*`/`Bridge_*` in `ReplicatedStorage.RoadKit` oder in `Workspace` liegen (Import durch den Nutzer, `C:\Users\Gio\Desktop\RoadKit_fertig3`). Sobald vorhanden: Meldung `[Swiss Map] RoadKit: N Vorlagen`, und inneroertliche Nebenstrassen werden **statt** der prozeduralen Platte mit Kit-Kacheln gebaut (`kitRoad`, seit 2026-11-16 ohne darunterliegenden Asphalt). Ohne Kit: Warnung `RoadKit fehlt (0 Vorlagen) - graue Platzhalterkacheln aktiv`.
- **2026-11-17 Kit-Netz fertig gebaut (Platzhalter):** `KIT_ROADS = true`, neues rechtwinkliges Netz (20 Strassen, 46 Knoten, 45 Abschnitte) auf 72-Studs-Raster; Haupt hw 9 (Kachel 36), Dorf hw 6 (Kachel 24). Kachel-Kompiler erzeugt 21 Kurven, 20 T-Stuecke, 1 4-Weg (X-Kreuzung Hauptstrasse Ost x Bahnhofstrasse) und 655 Geraden; zwei Kreisel aus Curve90-Ring + T-Seitenkacheln (Arme 90 Studs). Studio-Build `FERTIG!`, 52 921 Parts, 236 Haeuser, 15 Garagen; Messung: **0 Ueberlappungen**, 0 Kacheln im See. Solange die GLB fehlen, setzt der Kompiler graue `PLATZHALTER_*`-Platten (697). Naechster Schritt: 17 GLB importieren -> Build -> Sichtpruefung (dann verschwinden die Platzhalter).

## Konventionen
- Serverautoritativ; keine Client-Preise. Keine globalen Variablen.
- Nur Target-Dateien aendern; ein Task pro Durchlauf; Validierung vor [x]; Git nur als Empfehlung.
- Planung: DeepSeek V4.1 Flash (Plan). Code/Math: Muse Spark / DeepSeek Build.
- Routine/UI: Beam 1.0 Build. Eskalation nur nach 2 Fehlversuchen (MiMo-V2.6 Pro/Kimi K3.1 Pro).

## Queue
- Offen: 36/36a/36b/36e/36f/36h (Studio-Pruefung), 32 (15-Spieler-Abnahme), 43/44/45 (Code fertig, Vollbuild+Sicht offen), **RoadKit-Import** (Nutzer importiert `C:\Users\Gio\Desktop\RoadKit_fertig3` -> danach Vollbuild, damit die Kit-Kacheln die prozeduralen Dorfstrassen ersetzen). Erledigt: 41/42/46/47/48/49. Naechster: nach Kit-Import Vollbuild + Sicht, dann 43/44/45 abnehmen.
- **Nachtrag 2026-11-13 (Strassennetz-Tasks 47-49):** Netz-Tasks 47 (Registry/Kreuzungsflaeche), 48 (Randstein-/Trottoirringe) und 49 (Kreisel + Netzbericht) sind im Code fertig; es fehlt der gemeinsame Studio-Vollbuild mit Sichtpruefung. Studio war bei Task 49 im Play-Modus, daher kein Build durch den Agenten.
