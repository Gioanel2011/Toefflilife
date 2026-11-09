---
name: Microtask Executor
description: Genau einen Task aus der neuen Warteschlange isoliert ausführen, validieren und den Projektstand aktualisieren
---

Der Projektroot ist vom Skill-Verzeichnis aus `../../..`; alle genannten Projektdateien sind relativ dazu.

## Ablauf

1. Lies ausschliesslich `docs/TASKS.md`. Wähle den vom Benutzer genannten offenen Task, sonst den ersten Task mit `### [ ]`.
2. Übernimm die `Agent-Persona` und den vollständigen `Ausführungs-Prompt` als isolierte Anweisung. Prüfe, dass der Task **BUILD-MODUS** verlangt; im Plan-Modus darf nicht implementiert werden.
3. Zeige die Modell-Empfehlung und Eskalationsoption aus dem Task kurz an, ohne einen Modellwechsel vorzutäuschen oder automatisch durchzuführen.
4. Lade ausschliesslich die genannten `Target-Dateien` und `Context-Dateien`. Fehlende Target-Dateien dürfen angelegt werden. Keine Repository-Suche, keine weiteren Tasks und keine unaufgeforderten Zusatzdateien.
5. Implementiere ausschliesslich das Taskziel. Context-Dateien dürfen gelesen, aber nicht verändert werden. Keine globalen Variablen und keine Änderungen ausserhalb der Target-Dateien.
6. Führe exakt die unter `Validierung` genannte Prüfung aus und berichte das Ergebnis kompakt.
7. Nur bei Erfolg:
   - Markiere genau diesen Task in `docs/TASKS.md` mit `[x]`.
   - Aktualisiere `docs/MEMORY.md` knapp auf maximal 40 Zeilen mit erledigtem Task, geänderten Targets, Testergebnis, aktuellem Status und nächstem offenen Task.
   - Nenne direkt den nächsten offenen Task samt empfohlenem Modell, Eskalation und Modus.
8. Bei einem Fehlversuch bleibt der Task offen; keine Erfolgsmarkierung. Beim zweiten Fehlversuch melde ausdrücklich die erforderliche Eskalation an MiMo-V2.6 Pro oder Kimi K3.1 Pro.
9. Die `Commit-Empfehlung` ist nur eine Vorlage. Keinen Commit und keine andere Git-Mutation ohne ausdrückliche Benutzeranweisung ausführen.

Beende mit einer kurzen Meldung zu Target-Dateien, Validierung, aktualisiertem Gedächtnis und nächstem Task.
