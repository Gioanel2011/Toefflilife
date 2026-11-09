---
name: Task Dispatcher
description: Den nächsten offenen Microtask als Auswahlbox mit Modell, Modus und Startbefehl anzeigen
---

Der Projektroot ist vom Skill-Verzeichnis aus `../../..`; alle genannten Projektdateien sind relativ dazu.

## Ablauf

1. Lies ausschließlich `docs/TASKS.md`; lade keine weiteren Projektdateien und ändere nichts.
2. Wähle den ersten Task mit `### [ ]`. Falls der Benutzer eine Task-Nummer nennt, wähle ausschliesslich diesen offenen Task.
3. Behandle genau diesen Task als isolierten Prompt; ignoriere alle anderen Tasks.
4. Gib eine saubere Auswahlbox im Chat aus:

   ```text
   ┌──────────────────────────────────────────────────────────┐
   │ Task NN – Titel                                          │
   │ Ziel: Kurzbeschreibung aus dem Ausführungs-Prompt         │
   │ Modell: EMPFOHLENES MODELL                               │
   │ Eskalation: MiMo-V2.6 Pro / Kimi K3.1 Pro                │
   │ Modus: BUILD-MODUS                                       │
   │ Start: @microtask-executor Führe Task NN aus.            │
   └──────────────────────────────────────────────────────────┘
   ```

5. Die Modellwahl folgt ausschliesslich dem Taskfeld:
   - **DeepSeek V4.1 Flash** für Logik, Planung, Datenregeln und Integration.
   - **Muse Spark 1.3** für harte 3D-, Code- und Mathematikpräzision.
   - **Beam 1.0** für UI, Konfiguration und Routine-Boilerplate.
   - **MiMo-V2.6 Pro / Kimi K3.1 Pro** nur als Eskalation nach zwei Fehlversuchen, nie als automatischer Wechsel.
6. Verlange keinen Plan-Modus: Jeder Task wird im **BUILD-MODUS** ausgeführt.
7. Schliesse mit der exakten Startzeile `@microtask-executor Führe Task NN aus.` ab; `NN` ist die zweistellige Task-Nummer.

Falls kein offener Task existiert oder der genannte Task bereits erledigt ist, melde dies kurz, ohne einen anderen Task zu ersetzen.
