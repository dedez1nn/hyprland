pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Eventos do Proton Calendar via link público .ics (ver README.md — Proton
 * não tem API/CalDAV oficial, só esse link de compartilhamento).
 *
 * Limitações conhecidas (MVP):
 * - Eventos recorrentes (RRULE) não são expandidos: só aparece a primeira
 *   ocorrência tal como está no feed. Melhorar depois se fizer falta.
 * - DTSTART com TZID (sem "Z") é tratado como horário local direto, sem
 *   conversão de fuso. Funciona bem quando os eventos são criados no mesmo
 *   fuso do sistema (America/Sao_Paulo), que é o caso normal de uso pessoal.
 */
Singleton {
    id: root

    property var events: []
    // Todos os eventos parseados do feed, sem corte de "próximos 10" nem
    // filtro de data — usado pela grade de mês navegável (ClockCalendar),
    // que precisa achar eventos em meses passados/futuros além da janela
    // de "próximos eventos" que `events` mantém.
    property var allEvents: []
    property bool ready: false
    property bool error: false
    readonly property bool configured: SecretsService.protonCalendarIcsUrl.length > 0

    function unfold(raw) {
        const lines = raw.replace(/\r\n/g, "\n").split("\n");
        const result = [];
        for (const line of lines) {
            if ((line.startsWith(" ") || line.startsWith("\t")) && result.length > 0) {
                result[result.length - 1] += line.slice(1);
            } else {
                result.push(line);
            }
        }
        return result;
    }

    function parseDate(value) {
        const m = value.match(/^(\d{4})(\d{2})(\d{2})(?:T(\d{2})(\d{2})(\d{2})(Z)?)?$/);
        if (!m) return null;
        const year = Number(m[1]), month = Number(m[2]) - 1, day = Number(m[3]);
        if (m[4] === undefined) {
            return { date: new Date(year, month, day), allDay: true };
        }
        const hour = Number(m[4]), minute = Number(m[5]), second = Number(m[6]);
        if (m[7] === "Z") {
            return { date: new Date(Date.UTC(year, month, day, hour, minute, second)), allDay: false };
        }
        return { date: new Date(year, month, day, hour, minute, second), allDay: false };
    }

    function unescapeText(value) {
        return value.replace(/\\n/gi, " ").replace(/\\,/g, ",").replace(/\\;/g, ";").replace(/\\\\/g, "\\");
    }

    function parseIcs(text) {
        const lines = root.unfold(text);
        const parsed = [];
        let current = null;

        for (const line of lines) {
            if (line === "BEGIN:VEVENT") {
                current = {};
            } else if (line === "END:VEVENT") {
                if (current && current.summary && current.start) parsed.push(current);
                current = null;
            } else if (current) {
                const idx = line.indexOf(":");
                if (idx === -1) continue;
                const key = line.slice(0, idx);
                const value = line.slice(idx + 1);
                const prop = key.split(";")[0];

                if (prop === "SUMMARY") {
                    current.summary = root.unescapeText(value);
                } else if (prop === "DTSTART") {
                    const parsedDate = root.parseDate(value);
                    if (parsedDate) {
                        current.start = parsedDate.date;
                        current.allDay = parsedDate.allDay;
                    }
                } else if (prop === "DTEND") {
                    const parsedDate = root.parseDate(value);
                    if (parsedDate) current.end = parsedDate.date;
                }
            }
        }
        return parsed;
    }

    function refresh() {
        if (!root.configured) return;
        fetchProc.running = true
    }

    Component.onCompleted: refresh()

    Connections {
        target: SecretsService
        function onProtonCalendarIcsUrlChanged() { root.refresh() }
    }

    Timer {
        interval: 30 * 60 * 1000
        running: true
        repeat: true
        onTriggered: root.refresh()
    }

    Process {
        id: fetchProc
        command: ["bash", "-c", `curl -sL --max-time 10 "${SecretsService.protonCalendarIcsUrl}"`]
        stdout: StdioCollector {
            id: icsCollector
            onStreamFinished: {
                try {
                    const all = root.parseIcs(icsCollector.text);
                    root.allEvents = all.slice().sort((a, b) => a.start - b.start);
                    const cutoff = new Date(Date.now() - 24 * 60 * 60 * 1000);
                    root.events = root.allEvents
                        .filter(e => e.start >= cutoff)
                        .slice(0, 10);
                    root.ready = true;
                    root.error = false;
                } catch (e) {
                    console.error("[CalendarService] Falha ao processar calendário:", e);
                    root.error = true;
                }
            }
        }
    }
}
