---
name: Idea Architect
description: Neue Ideen im Plan-Modus mit dem Projektgedächtnis abgleichen und bestätigte Microtasks logisch einordnen
---

Der Projektroot ist vom Skill-Verzeichnis aus `../../..`; alle genannten Projektdateien sind relativ dazu.

## Ablauf

1. Arbeite im **Plan-Modus mit DeepSeek V4.1 Flash**. Lies nur `docs/MEMORY.md` und `docs/TASKS.md`; keine Code- oder Repository-Suche.
2. Falls keine konkrete Idee vorliegt, frage kurz danach. Gleiche die Idee interaktiv mit Projektbeschreibung, Ist-Zustand, Architekturregeln und vorhandenen Tasks ab.
3. Nenne kompakt Übereinstimmungen, Konflikte, Duplikate, Abhängigkeiten und einen Priorisierungsvorschlag. Stelle gezielte Rückfragen, solange Umfang oder Priorität unklar sind.
4. Lege Änderungen erst nach ausdrücklicher Bestätigung des Vorschlags an. Lösche dann veraltete Tasks, passe überholte Tasks an und füge neue Microtasks an der logisch richtigen Stelle ein. Erledigte Tasks dürfen entfernt werden.
5. Jeder Task umfasst maximal 10–20 Minuten Arbeit und verwendet exakt dieses Format:

   ```markdown
   ### [ ] Task XX: Präziser Titel
   - **Empfohlenes Modell:** DeepSeek V4.1 Flash | Muse Spark 1.3 | Beam 1.0 | **Eskalation:** MiMo-V2.6 Pro / Kimi K3.1 Pro
   - **Modus:** BUILD-MODUS
   - **Target-Dateien:** exakte/ziel/datei.luau
   - **Context-Dateien:** nur/notwendige/interfaces.luau
   - **Agent-Persona:** Exakte Rolle für diesen Task.
   - **Ausführungs-Prompt:**
     """
     Vollständige Instruktion mit Signaturen, Ein- und Ausgaben sowie Verboten.
     """
   - **Validierung:** Exakter Test- oder Ausführungsbefehl
   - **Commit-Empfehlung:** type(scope): kurze Beschreibung
   ```

6. Wähle das Primärmodell nach Aufgabe: DeepSeek V4.1 Flash für Logik/Planung, Muse Spark 1.3 für harte 3D-/Code-/Mathematikpräzision, Beam 1.0 für UI/Configs/Routine. Kimi K3.1 Pro und MiMo-V2.6 Pro sind ausschliesslich Eskalation nach zwei Fehlversuchen. Erfinde keine Provider-ID und behaupte keinen automatischen Modellwechsel.
7. Aktualisiere nach bestätigter Änderung `docs/MEMORY.md` knapp (maximal 40 Zeilen) mit Entscheidung, Ist-Zustand, neuer Priorität und nächstem offenem Task. Implementiere keinen Code.
8. Validiere vor Abschluss die Markdown-Struktur: eindeutige Task-Nummern, intakte Checkboxen und alle Pflichtfelder je Task. Melde die bestätigte Reihenfolge kurz.
