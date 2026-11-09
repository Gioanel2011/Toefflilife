# Projektregeln für schnelle, ressourcenschonende Microtasks

## Modell- und Moduszuordnung

- **PLANUNG & ARCHITEKTUR:** ausschliesslich **DeepSeek V4.1 Flash im Plan-Modus**.
- **CODE-UMSETZUNG & MATHEMATIK:** **Muse Spark 1.3 Contributor** oder **DeepSeek V4.1 Flash im Build-Modus**.
- **ROUTINE & UI/BOILERPLATE:** **Beam 1.0 (Free Tier) im Build-Modus**.
- **NOTFALL-ESKALATION:** **Kimi K3.1 Pro** oder **MiMo-V2.6 Pro** dürfen ausschliesslich eingesetzt werden, wenn ein Task nach zwei Versuchen scheitert. Die Eskalation wird ausdrücklich dokumentiert; es gibt keinen automatischen Modellwechsel.

## Arbeitsweise

- Vor jedem Task dürfen ausschliesslich die im Task genannten **Target-Dateien** und **Context-Dateien** geladen werden. Kein unaufgefordertes Repository-Scanning.
- Pro Durchlauf wird genau ein Task-Block als isolierter Prompt ausgeführt. Persona, Modell, Modus, Prompt, Validierung und Commit-Empfehlung stammen ausschliesslich aus diesem Block.
- Neue oder fehlende Target-Dateien dürfen angelegt werden. Context-Dateien dürfen gelesen, aber nicht verändert werden.
- Keine globalen Variablen. Änderungen bleiben auf das Taskziel begrenzt.
- Vor Abschluss ist die exakt angegebene Validierung auszuführen und ihr Ergebnis kurz zu berichten.
- Nach erfolgreichem Task müssen `docs/TASKS.md` auf `[x]` und `docs/MEMORY.md` mit aktuellem Status und nächstem Task aktualisiert werden. Ohne bestandene Validierung darf kein `[x]` gesetzt werden.
- Bei zwei Fehlversuchen bleibt der Task offen und wird ausdrücklich für MiMo-V2.6 Pro oder Kimi K3.1 Pro eskaliert.
- Die Commit-Empfehlung ist nur eine Vorlage. Kein Commit und keine andere Git-Mutation ohne ausdrückliche Anweisung des Benutzers.
