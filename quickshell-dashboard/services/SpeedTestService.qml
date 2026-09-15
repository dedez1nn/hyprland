pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Teste de velocidade sob demanda: no clique (SpeedTestWidget), roda
 * run-speedtest.sh, que mede ping/download/upload contra os endpoints
 * públicos do Cloudflare speed test (speed.cloudflare.com) via curl — sem
 * servidor próprio, sai de verdade pela rede até a internet (mede
 * tethering/wifi/qualquer link real, não loopback).
 *
 * Último resultado persistido em config/speedtest-last.json (mesmo
 * espírito do sizes.json) pra o widget não nascer vazio a cada reload do
 * dashboard.
 */
Singleton {
    id: root

    readonly property string scriptPath: Qt.resolvedUrl("speedtest/run-speedtest.sh").toString().replace("file://", "")

    property string state: "idle" // idle | running | done | error
    property real pingMs: 0
    property real downloadMbps: 0
    property real uploadMbps: 0
    property string lastRunAt: ""

    function runTest() {
        if (root.state === "running") return;
        root.state = "running";
        proc.running = true;
    }

    Process {
        id: proc
        command: ["timeout", "60", "bash", root.scriptPath]
        stdout: StdioCollector {
            id: collector
            onStreamFinished: {
                try {
                    const data = JSON.parse(collector.text);
                    if (data.error) throw new Error("script reportou erro");
                    root.pingMs = data.pingMs;
                    root.downloadMbps = data.downloadMbps;
                    root.uploadMbps = data.uploadMbps;
                    root.lastRunAt = new Date().toISOString();
                    root.state = "done";
                    root.persist();
                } catch (e) {
                    console.error("[SpeedTestService] Falha ao rodar teste:", e, collector.text);
                    root.state = "error";
                }
            }
        }
    }

    function persist() {
        file.setText(JSON.stringify({
            pingMs: root.pingMs,
            downloadMbps: root.downloadMbps,
            uploadMbps: root.uploadMbps,
            lastRunAt: root.lastRunAt
        }, null, 2));
    }

    FileView {
        id: file
        path: Qt.resolvedUrl("../config/speedtest-last.json")
        onLoadedChanged: {
            try {
                const data = JSON.parse(file.text());
                root.pingMs = data.pingMs ?? 0;
                root.downloadMbps = data.downloadMbps ?? 0;
                root.uploadMbps = data.uploadMbps ?? 0;
                root.lastRunAt = data.lastRunAt ?? "";
                if (root.lastRunAt.length > 0) root.state = "done";
            } catch (e) {
                // sem resultado salvo ainda, fica em "idle"
            }
        }
        onLoadFailed: (error) => {}
    }
}
