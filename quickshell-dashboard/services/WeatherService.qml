pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Clima via Open-Meteo, com localização detectada por IP.
 *
 * Cuidado: o usuário usa ProtonVPN. Se a geolocalização por IP fosse feita
 * sem cuidado, com a VPN conectada ela apontaria pro servidor de saída da
 * VPN, não pro local real. Por isso a consulta de IP é bindada na interface
 * de rede física (wlan, eth ou en, nunca a interface da VPN), contornando a
 * rota da VPN.
 *
 * O Kill Switch do ProtonVPN bloqueia até esse tráfego bindado na interface
 * física (curl --interface retorna vazio). Nesse caso NÃO caímos para o
 * método sem bind, pois isso pegaria a rota default da VPN e retornaria a
 * localização do servidor de saída, não a real. Em vez disso, reusamos a
 * última localização detectada com sucesso (cache em disco). O fallback
 * sem bind só é usado se nunca houve um cache válido (ex: primeiro boot).
 */
Singleton {
    id: root

    property real latitude: 0
    property real longitude: 0
    property string cityName: ""
    property bool locationReady: false

    property real temperature: 0
    property int weatherCode: 0
    property bool isDay: true
    property int humidity: 0
    property real windSpeed: 0
    property bool ready: false
    property bool error: false

    function weatherDescription(code) {
        const map = {
            0: "Céu limpo", 1: "Predominantemente limpo", 2: "Parcialmente nublado", 3: "Nublado",
            45: "Nevoeiro", 48: "Nevoeiro com geada",
            51: "Garoa leve", 53: "Garoa moderada", 55: "Garoa densa",
            56: "Garoa congelante leve", 57: "Garoa congelante densa",
            61: "Chuva leve", 63: "Chuva moderada", 65: "Chuva forte",
            66: "Chuva congelante leve", 67: "Chuva congelante forte",
            71: "Neve leve", 73: "Neve moderada", 75: "Neve forte", 77: "Grãos de neve",
            80: "Pancadas de chuva leves", 81: "Pancadas de chuva moderadas", 82: "Pancadas de chuva violentas",
            85: "Pancadas de neve leves", 86: "Pancadas de neve fortes",
            95: "Trovoada", 96: "Trovoada com granizo leve", 99: "Trovoada com granizo forte"
        };
        return map[code] ?? "Condição desconhecida";
    }

    function weatherIcon(code, isDayNow) {
        if (code === 0) return isDayNow ? "☀️" : "🌙";
        if (code === 1 || code === 2) return isDayNow ? "🌤️" : "☁️";
        if (code === 3) return "☁️";
        if (code === 45 || code === 48) return "🌫️";
        if ([51, 53, 55, 56, 57].includes(code)) return "🌦️";
        if ([61, 63, 65, 66, 67, 80, 81, 82].includes(code)) return "🌧️";
        if ([71, 73, 75, 77, 85, 86].includes(code)) return "🌨️";
        if ([95, 96, 99].includes(code)) return "⛈️";
        return "❓";
    }

    // A geolocalização por IP às vezes acerta o provedor mas erra a cidade
    // exata (comum em ISPs regionais). Correções manuais conhecidas ficam
    // aqui: cidade que a IP costuma devolver -> localização real.
    readonly property var cityOverrides: ({
        "São Sebastião do Paraíso": { name: "Passos", lat: -20.71889, lon: -46.60972 }
    })

    readonly property string description: weatherDescription(weatherCode)
    readonly property string icon: weatherIcon(weatherCode, isDay)
    readonly property string temperatureText: ready ? Math.round(temperature) + "°C" : "--°C"

    function refreshLocation() {
        locateProc.running = true
    }

    function refreshWeather() {
        if (!locationReady) return;
        weatherProc.running = true
    }

    Component.onCompleted: refreshLocation()

    // Rede pode mudar (notebook trocando de wifi, VPN conectando/desconectando)
    Timer {
        interval: 3 * 60 * 60 * 1000
        running: true
        repeat: true
        onTriggered: root.refreshLocation()
    }

    Timer {
        interval: 15 * 60 * 1000
        running: true
        repeat: true
        onTriggered: root.refreshWeather()
    }

    Process {
        id: locateProc
        // ip-api.com (http puro, porta 80) trava nessa rede independente da
        // VPN; ipwho.is via https é confiável e também traz lat/lon.
        command: ["bash", "-c", `
            CACHE="$HOME/.cache/quickshell/weather-location.json"
            IFACE=$(ip -brief addr show | awk '$1 ~ /^(wl|eth|en)/ && $2=="UP" {print $1; exit}')
            RESULT=""
            if [ -n "$IFACE" ]; then
                RESULT=$(curl -s --interface "$IFACE" --max-time 5 "https://ipwho.is/")
            fi
            if [ -n "$RESULT" ] && echo "$RESULT" | grep -qE '"success":[[:space:]]*true'; then
                mkdir -p "$(dirname "$CACHE")"
                echo "$RESULT" > "$CACHE"
                echo "$RESULT"
            elif [ -f "$CACHE" ]; then
                cat "$CACHE"
            else
                curl -s --max-time 5 "https://ipwho.is/"
            fi
        `]
        stdout: StdioCollector {
            id: locateCollector
            onStreamFinished: {
                try {
                    const data = JSON.parse(locateCollector.text);
                    if (data.success) {
                        const override = root.cityOverrides[data.city];
                        root.latitude = override ? override.lat : data.latitude;
                        root.longitude = override ? override.lon : data.longitude;
                        root.cityName = override ? override.name : data.city;
                        root.locationReady = true;
                        root.refreshWeather();
                    } else {
                        root.error = true;
                    }
                } catch (e) {
                    console.error("[WeatherService] Falha ao geolocalizar:", e);
                    root.error = true;
                }
            }
        }
    }

    Process {
        id: weatherProc
        command: ["bash", "-c",
            `curl -s --max-time 5 "https://api.open-meteo.com/v1/forecast?latitude=${root.latitude}&longitude=${root.longitude}&current=temperature_2m,weather_code,relative_humidity_2m,wind_speed_10m,is_day&timezone=auto"`
        ]
        stdout: StdioCollector {
            id: weatherCollector
            onStreamFinished: {
                try {
                    const data = JSON.parse(weatherCollector.text);
                    const c = data.current;
                    root.temperature = c.temperature_2m;
                    root.weatherCode = c.weather_code;
                    root.humidity = c.relative_humidity_2m;
                    root.windSpeed = c.wind_speed_10m;
                    root.isDay = c.is_day === 1;
                    root.ready = true;
                    root.error = false;
                } catch (e) {
                    console.error("[WeatherService] Falha ao buscar clima:", e);
                    root.error = true;
                }
            }
        }
    }
}
