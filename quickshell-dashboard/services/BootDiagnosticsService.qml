pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

/**
 * As 4 métricas dos widgets de diagnóstico de boot (Entropy/KernelTaint/
 * BootStatus/SystemdBootTime — ver BootSessionService pra quando eles
 * aparecem/somem). Cada Process roda um comando de leitura só, sem
 * argumento nenhum vindo de input do usuário, então nenhum risco de
 * injeção — mas mesmo assim tudo como lista de argv, nunca `bash -c`
 * concatenado, pelo mesmo hábito do NotionService.
 */
Singleton {
    id: root

    // Entropy disponível (/proc/sys/kernel/random/entropy_avail):
    // atualiza com frequência, é o valor mais dinâmico dos quatro.
    property int entropy: 0
    property bool entropyReady: false

    // Faixas de avaliação da entropia (sem cor aqui — quem decide a
    // paleta é o widget, que já importa Appearance; este serviço fica
    // livre de depender de common/). Kernels modernos (getrandom() com
    // CRNG) mantêm o pool baixo e estável (tipicamente 256, o "cheio")
    // mesmo saudáveis — não é mais "quanto maior, melhor" como nos
    // kernels antigos com /dev/random bloqueante; por isso "Ótima" é uma
    // faixa (>=224), não só ">= algum mínimo". Abaixo de 32 é o ponto em
    // que geração de chaves pode começar a bloquear esperando entropia.
    // `severity` vai de 0 (melhor) a 4 (pior), pro widget escalar cor.
    readonly property var entropyLevels: [
        { min: 224, label: "Ótima", severity: 0 },
        { min: 160, label: "Boa", severity: 1 },
        { min: 96, label: "Adequada", severity: 2 },
        { min: 32, label: "Baixa", severity: 3 },
        { min: 0, label: "Crítica", severity: 4 }
    ]

    function entropyLevelFor(value) {
        return root.entropyLevels.find(l => value >= l.min) || root.entropyLevels[root.entropyLevels.length - 1];
    }

    // Kernel taint (/proc/sys/kernel/tainted): bitmask de "por que o
    // kernel não está mais limpo" — ver tainted-kernels.rst do próprio
    // kernel. Raramente muda em runtime, mas não é imutável (um módulo
    // problemático pode taintar o kernel a qualquer momento).
    property int taintValue: 0
    property bool taintReady: false
    readonly property var taintFlags: [
        { bit: 0, letter: "G/P", desc: "Módulo proprietário carregado" },
        { bit: 1, letter: "F", desc: "Módulo carregado à força" },
        { bit: 2, letter: "S", desc: "SMP em hardware fora de especificação" },
        { bit: 3, letter: "R", desc: "Módulo descarregado à força" },
        { bit: 4, letter: "M", desc: "Machine Check Exception (erro de hardware)" },
        { bit: 5, letter: "B", desc: "Página de memória corrompida" },
        { bit: 6, letter: "U", desc: "Taint pedido pelo userspace" },
        { bit: 7, letter: "D", desc: "Kernel morreu (OOPS/BUG anterior)" },
        { bit: 8, letter: "A", desc: "Tabela ACPI sobrescrita" },
        { bit: 9, letter: "W", desc: "Kernel emitiu um warning" },
        { bit: 10, letter: "C", desc: "Driver staging carregado" },
        { bit: 11, letter: "I", desc: "Workaround de firmware aplicado" },
        { bit: 12, letter: "O", desc: "Módulo fora da árvore do kernel" },
        { bit: 13, letter: "E", desc: "Módulo não assinado carregado" },
        { bit: 14, letter: "L", desc: "Soft lockup detectado" },
        { bit: 15, letter: "K", desc: "Kernel com live patch aplicado" },
        { bit: 16, letter: "X", desc: "Taint auxiliar (específico da distro)" },
        { bit: 17, letter: "T", desc: "Compilado sem randomização de struct" }
    ]
    readonly property var activeTaintFlags: root.taintFlags.filter(f => (root.taintValue & (1 << f.bit)) !== 0)

    // Status geral do boot (systemctl is-system-running) + unidades que
    // falharam, se degraded.
    property string systemState: ""
    property var failedUnits: []
    property bool bootStatusReady: false

    // Tempo que o systemd levou pra subir tudo (systemd-analyze). Só
    // fica pronto de verdade depois que o boot termina — antes disso o
    // comando responde com erro ("Bootup is not yet finished"), por
    // isso o retry: root.bootTimeReady só vira true no primeiro sucesso.
    property string bootTimeRaw: ""
    property var bootTimeParts: []
    property string bootTimeTotal: ""
    // Soma só das fases que o systemd de fato controla (kernel + initrd
    // + userspace) — firmware e loader são BIOS/GRUB, tempo que nenhuma
    // configuração do sistema operacional muda; incluir eles na
    // avaliação puniria a máquina por um firmware lento sem relação
    // nenhuma com a saúde do userspace.
    property real bootOsSeconds: 0
    property bool bootTimeReady: false

    // `severity` 0 (melhor) a 3 (pior), mesma ideia do entropyLevels.
    readonly property var bootRatingLevels: [
        { max: 8, label: "Excelente", severity: 0 },
        { max: 15, label: "Bom", severity: 1 },
        { max: 30, label: "Regular", severity: 2 },
        { max: Infinity, label: "Lento", severity: 3 }
    ]

    function bootRatingFor(seconds) {
        return root.bootRatingLevels.find(l => seconds <= l.max) || root.bootRatingLevels[root.bootRatingLevels.length - 1];
    }

    function decodeTaint(value) {
        return root.taintFlags.filter(f => (value & (1 << f.bit)) !== 0);
    }

    // "4.260s" -> 4.26, "551ms" -> 0.551
    function durationToSeconds(text) {
        const match = text.match(/([\d.]+)(ms|s)/);
        if (!match) return 0;
        const value = parseFloat(match[1]);
        return match[2] === "ms" ? value / 1000 : value;
    }

    function parseAnalyzeLine(text) {
        const line = (text.split("\n")[0] || "").trim();
        const match = line.match(/^Startup finished in (.+?)\s*=\s*(.+?)\.?$/);
        if (!match) return { raw: line, parts: [], total: "", osSeconds: 0 };
        const parts = match[1].split("+").map(s => s.trim());
        const osSeconds = parts
            .filter(p => !p.includes("(firmware)") && !p.includes("(loader)"))
            .reduce((sum, p) => sum + root.durationToSeconds(p), 0);
        return { raw: line, parts, total: match[2].trim(), osSeconds };
    }

    Component.onCompleted: {
        entropyProc.running = true;
        taintProc.running = true;
        stateProc.running = true;
        failedProc.running = true;
        analyzeProc.running = true;
    }

    Timer {
        interval: 4000
        running: true
        repeat: true
        onTriggered: entropyProc.running = true
    }

    Timer {
        interval: 30000
        running: true
        repeat: true
        onTriggered: {
            taintProc.running = true;
            stateProc.running = true;
            failedProc.running = true;
        }
    }

    // Some sozinho assim que systemd-analyze funcionar de primeira —
    // depois disso o valor não muda mais até o próximo boot.
    Timer {
        interval: 5000
        running: !root.bootTimeReady
        repeat: true
        onTriggered: analyzeProc.running = true
    }

    Process {
        id: entropyProc
        command: ["cat", "/proc/sys/kernel/random/entropy_avail"]
        stdout: StdioCollector {
            id: entropyCollector
            onStreamFinished: {
                const n = parseInt(entropyCollector.text.trim(), 10);
                if (!isNaN(n)) {
                    root.entropy = n;
                    root.entropyReady = true;
                }
            }
        }
    }

    Process {
        id: taintProc
        command: ["cat", "/proc/sys/kernel/tainted"]
        stdout: StdioCollector {
            id: taintCollector
            onStreamFinished: {
                const n = parseInt(taintCollector.text.trim(), 10);
                if (!isNaN(n)) {
                    root.taintValue = n;
                    root.taintReady = true;
                }
            }
        }
    }

    Process {
        id: stateProc
        command: ["systemctl", "is-system-running"]
        stdout: StdioCollector {
            id: stateCollector
            onStreamFinished: {
                root.systemState = stateCollector.text.trim();
                root.bootStatusReady = true;
            }
        }
    }

    Process {
        id: failedProc
        command: ["systemctl", "--failed", "--no-legend", "--plain"]
        stdout: StdioCollector {
            id: failedCollector
            onStreamFinished: {
                root.failedUnits = failedCollector.text.split("\n").map(l => l.trim().split(/\s+/)[0]).filter(u => u.length > 0);
            }
        }
    }

    Process {
        id: analyzeProc
        command: ["systemd-analyze"]
        stdout: StdioCollector {
            id: analyzeCollector
            onStreamFinished: {
                const parsed = root.parseAnalyzeLine(analyzeCollector.text);
                if (parsed.total.length > 0) {
                    root.bootTimeRaw = parsed.raw;
                    root.bootTimeParts = parsed.parts;
                    root.bootTimeTotal = parsed.total;
                    root.bootOsSeconds = parsed.osSeconds;
                    root.bootTimeReady = true;
                }
            }
        }
    }
}
