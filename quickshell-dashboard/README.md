# Quickshell Dashboard

Widgets extras pro setup Hyprland, construídos em Quickshell (QML), no mesmo
padrão do módulo `~/.config/quickshell/overview` já existente neste repo.

**Status:** em desenvolvimento dentro do repo, ainda não simlinkado em
`~/.config/quickshell/` (roda direto do caminho do repo, ver seção
"Autostart"). Widgets, identidade visual, autostart e notas do Notion (parte
5) já aprovados; parte 6 (dock) segue pendente.

**Comportamento de área de trabalho:** o dashboard só fica visível quando o
workspace focado está sem janelas (`HyprlandWorkspaceService`, via
`hyprctl activeworkspace -j` + eventos do Hyprland) — funciona como uma área
de trabalho, não uma sobreposição por cima do que você está usando. Assim que
qualquer janela abre no workspace, ele some sozinho.

**Layout:** os widgets ficam espalhados pela tela em vez de empilhados num
canto — boas-vindas no topo central, calendário à esquerda no meio, YouTube
Music à direita no meio, clima no canto inferior direito
(`modules/DashboardWindow.qml`, `Config.position.margin` controla a
distância padrão de cada um até a borda). Todo card pode ser arrastado
segurando em qualquer área vazia dele (botões próprios, como os do
MusicPlayer, continuam clicáveis) — a posição fica salva em
`config/positions.json` e volta no próximo reload, sobrescrevendo
a posição padrão. Ver `WidgetPositionService.qml` e a seção "Arrastar
widgets" abaixo.

**Identidade visual — Relevo Suave:** os cards (`common/widgets/Card.qml`)
têm fundo semi-transparente (~72% de opacidade, deixa o wallpaper aparecer
de leve) com uma borda fina cinza-clara pra marcar o contorno
(`Appearance.colors.cardBackground`/`cardBorder`); o "relevo" vem de duas
`RectangularShadow` (QtQuick.Effects) sobrepostas — uma escura deslocada
pra baixo/direita, uma clara e sutil deslocada pra cima/esquerda —
simulando o card esculpido do próprio fundo. Cores em
`Appearance.colors.shadowDark`/`shadowLight`.

## Widgets planejados

1. **Card de boas-vindas** — avatar (placeholder por enquanto, sem foto),
   saudação e tempo de atividade do sistema (uptime).
2. **Relógio + calendário com eventos** — data/hora ao vivo, eventos vindos do
   link público `.ics` do Proton Calendar (Configurações → Calendário →
   Compartilhar → Obter link). Não existe API/CalDAV oficial do Proton
   Calendar (diferente do Mail, que tem o Bridge) — o link público é o único
   caminho suportado.
3. **Clima (Open-Meteo)** — localização detectada por IP (geolocalização
   aproximada), sem precisar configurar cidade fixa. Sem necessidade de API
   key (Open-Meteo é público).
4. **Mini player de música (somente YouTube Music)** — via MPRIS/`playerctl`.
   O Firefox já expõe MPRIS com `xesam:url` da aba tocando; o widget só
   aparece quando a URL ativa é `music.youtube.com` (filtra qualquer outro
   player/aba).
5. **Notas rápidas com Notion** — integração real via API do Notion (token,
   ver `config/secrets.example.json`). Nunca comitar o token. Lista tudo que
   a integração enxerga (`/v1/search`) e permite abrir e editar os blocos de
   texto de qualquer página.
6. **Dock/taskbar preta** — ícones de apps abertos (via `hyprctl clients -j`,
   igual ao `HyprlandData.qml` do módulo overview) + apps fixados. Clique
   direito num ícone abre menu pra fixar/desafixar, como uma taskbar de
   verdade. Lista de fixados persistida em `config/dock-pinned.json`,
   escrita pelo próprio widget.

## O que já foi implementado, por widget

### Card de boas-vindas (`modules/WelcomeCard.qml`)
- Avatar placeholder: círculo colorido com a inicial do nome (`Config.welcomeCard.greetingName`), sem foto — trocar por `Image` quando tiver uma definida.
- Saudação por horário: "Bom dia"/"Boa tarde"/"Boa noite"/"Boa madrugada", calculada em `ClockService.greetingPeriod` a partir da hora atual.
- "Tempo de atividade: `xxh xxm`" — tempo ativo *na sessão* (exclui tempo ocioso, via `ActiveTimeService.qml`, ver seção "Geral" abaixo). `UptimeService.qml` (uptime do sistema) segue no repo mas não é mais usado por este card.
- "streak: N dias" — dias seguidos com pelo menos um commit em `~/repos/*` (`CommitStreakService.qml`), com o ícone `common/assets/git.png` (64×64, redimensionado a partir de `~/Imagens/git.png`) ao lado do rótulo.

### Relógio + calendário (`modules/ClockCalendar.qml`)
- Relógio ao vivo (hora:minuto) e data por extenso em pt_BR, com capitalização corrigida manualmente (só a primeira letra — `toLocaleDateString` do Qt captura tudo em minúsculo).
- Eventos do Proton Calendar: busca e parseia o link `.ics` público (Proton não tem API/CalDAV oficial pro Calendar — só Mail tem Bridge). Mostra até 4 próximos eventos, com estados de "não configurado", "carregando", "erro" e "sem eventos".
- Limitações conhecidas do parser (`services/CalendarService.qml`): eventos recorrentes (RRULE) não são expandidos, só a primeira ocorrência aparece; horários com `TZID` são tratados como horário local direto, sem conversão de fuso (funciona bem pra eventos criados no fuso do próprio sistema).
- Tira da semana corrente (segunda a domingo, hoje destacado, pontinho nos dias com evento) + mensagem "N eventos essa semana". Pendência: grade de mês navegável, ver `BACKLOG.md`.

### Clima (`modules/Weather.qml` + `services/WeatherService.qml`)
- Geolocalização por IP (`ip-api.com`) + Open-Meteo (sem precisar de API key).
- Cuidado com ProtonVPN: a consulta de IP é bindada na interface de rede física (`wlan`/`eth`/`en`, detectada automaticamente), nunca a interface da VPN — testado e confirmado com a VPN conectada de verdade. Sem isso, a geolocalização apontaria pro servidor de saída da VPN.
- Correção manual de cidade: quando o IP geolocaliza errado (aconteceu com "São Sebastião do Paraíso" em vez de "Passos"), um mapa `cityOverrides` corrige lat/lon/nome automaticamente.
- Card em duas partes empilhadas: `Row` com ícone + temperatura/descrição/cidade (centralizada), e embaixo uma `Row` única com os 6 indicadores lado a lado — umidade, vento, probabilidade de chuva, visibilidade, nascer e pôr do sol. Cada um com um ícone próprio em `common/assets/` (`humidity.svg`, `wind.svg`, `rain-chance.svg`, `visibility.svg`, `sunrise.svg`, `sunset.svg`). O card cresce lateralmente pra caber tudo numa linha só (`implicitWidth: content.implicitWidth + 40`, não usa mais o `Config.clock.width` padrão dos outros cards).
- Probabilidade de chuva vem de `daily.precipitation_probability_max` (máxima do dia); visibilidade vem de `hourly.visibility` pegando o índice da hora atual (`hourly.time` do Open-Meteo é indexado por hora do dia, 0–23, com `forecast_days=1`); nascer/pôr do sol vêm de `daily.sunrise`/`sunset` (Open-Meteo já devolve em horário local com `timezone=auto`, só corta a parte da data).

### Mini player (`modules/MusicPlayer.qml` + `services/MediaService.qml`)
- Poll no `playerctl` a cada 2s, juntando metadados de todos os players MPRIS ativos (`-a`) e filtrando só o que tem `music.youtube.com` na URL (`xesam:url`) — YouTube normal, Spotify etc. ficam ignorados.
- O Firefox expõe MPRIS por aba com a URL real tocando, então funciona sem precisar de app dedicado do YouTube Music.
- Mostra capa (com fallback 🎵 se não tiver `artUrl`), título, artista, e controles clicáveis (⏮ ⏸/▶ ⏭ via `playerctl -p <player> <ação>`).
- Card só aparece quando `MediaService.active` é verdadeiro (algo tocando em `music.youtube.com`); caso contrário fica completamente escondido.

### Notas rápidas com Notion (`modules/QuickNotes.qml` + `services/NotionService.qml`)
- Lista tudo que a integração enxerga via `POST /v1/search` (páginas e databases compartilhadas com ela no Notion — menu "..." → Connections de cada página; compartilhar uma página raiz propaga pras subpáginas), em vez de fixar uma database só.
- Clicar num item busca os blocos de primeiro nível (`GET /v1/blocks/{id}/children`) e mostra cada um numa caixa de texto editável; "Salvar" faz `PATCH /v1/blocks/{id}` de cada bloco alterado, "+ nova nota" acrescenta um parágrafo vazio (`PATCH /v1/blocks/{id}/children`).
- Todo `curl` vai com os argumentos como lista (`command: [...]`), nunca como string `bash -c` — o texto dos blocos é digitado pelo usuário e vai direto no corpo da requisição, então interpolar numa string de shell arriscaria injeção de comando.
- Blocos `to_do` mostram checkbox de verdade (☐/☑, clicável em modo edição) com texto riscado quando marcado, em vez de só o texto puxado.
- Blocos filhos (ex: checklist indentada sob um parágrafo) são buscados recursivamente — um `GET /children` extra por bloco com `has_children: true`, até 4 níveis de profundidade — e mostrados com indentação visual.
- Limitações conhecidas: só os tipos paragraph/heading_1-3/bulleted_list_item/numbered_list_item/to_do são lidos e editáveis (outros tipos aparecem como "(bloco não suportado)", somente-leitura); acima de 4 níveis de aninhamento os blocos não são mais expandidos; sem rich text de verdade (só texto plano — negrito/cor/link não sobrevivem a uma edição salva pelo widget).
- Fonte das notas escala junto com o seletor 1×/2×/3× (`noteFontSize`), em vez de ficar do mesmo tamanho enquanto só o card cresce; texto um pouco mais grosso (`Font.Medium`, headings em `Font.Bold`) e mais branco (`noteTextColor`) que o padrão do dashboard, pra melhorar a leitura de páginas com texto denso.
- Pra digitar dentro do `TextEdit` de um bloco funcionar, `modules/DashboardWindow.qml` precisou trocar `WlrLayershell.keyboardFocus` de `None` pra `OnDemand` — com `None` a janela nunca recebe teclado de verdade no protocolo Wayland, mesmo com o QML achando que o campo tem foco. `OnDemand` só cede foco de teclado quando algo dentro da janela pede (ex: clicar numa nota), sem afetar os outros widgets (nenhum é campo de texto).

### Dock/taskbar preta — não iniciado
Planejado (parte 6): ícones de apps abertos + fixados, clique direito pra fixar/desafixar.

### Comportamento geral (`services/HyprlandWorkspaceService.qml`)
- O dashboard inteiro só fica visível quando o workspace focado está sem janelas (`hyprctl activeworkspace -j`, atualizado via eventos do Hyprland) — funciona como uma área de trabalho, não uma sobreposição por cima do que você está usando.
- Identidade visual: "Relevo Suave" (ver seção acima) — fundo translúcido, borda fina cinza-clara e sombra dupla em vez do retângulo liso e opaco genérico de antes. Fonte "Open Sans" (`Appearance.font.family`), instalada de verdade no sistema — antes era "Rubik", nunca instalada, e caía num fallback silencioso do fontconfig.
- Layout espalhado pela tela (ver seção "Layout" acima), em vez de empilhado num canto.

### Autostart (`~/.config/systemd/user/quickshell-dashboard.service`)
Roda como serviço de usuário do systemd, apontando direto pro caminho do
repo (`qs -p .../quickshell-dashboard`) — não depende de symlink em
`~/.config/quickshell/`. Iniciado automaticamente no login do Hyprland via
`exec-once = systemctl --user start quickshell-dashboard.service`
(`configs/Startup_Apps.conf`), com `Restart=on-failure` caso o processo
caia.

```bash
systemctl --user status quickshell-dashboard.service   # ver estado/logs
systemctl --user restart quickshell-dashboard.service  # aplicar mudança de QML
systemctl --user disable --now quickshell-dashboard.service  # desligar de vez
```

Precisa de `HYPRLAND_INSTANCE_SIGNATURE` importada pro ambiente do systemd
(`Startup_Apps.conf`, linhas de `dbus-update-activation-environment` /
`systemctl --user import-environment`) — sem isso o `hyprctl` usado pelo
`HyprlandWorkspaceService` não acha a instância do Hyprland quando chamado
de dentro do serviço.

### Arrastar widgets (`common/widgets/Card.qml` + `services/WidgetPositionService.qml`)
Todo card inteiro é arrastável — passar o mouse por cima muda o cursor pra
mãozinha aberta, e segurando em qualquer ponto move o card (fica com
z-index mais alto durante o arraste, pra não ficar atrás de outro). A
`MouseArea` de arrastar cobre o card todo mas é declarada antes do
conteúdo de cada widget dentro do `Card`, então qualquer botão próprio
(ex: os controles do MusicPlayer) fica por cima na ordem de pintura e
continua clicável normalmente — só onde não tem nada por cima é que o
clique vira arrasto.

Enquanto o arraste está ativo (`WidgetPositionService.dragging`), a mask
da janela (`DashboardWindow.qml`) vira a tela inteira em vez de só a área
dos cards — sem isso, o Hyprland para de mandar eventos de mouse pra
janela assim que o cursor sai da área (minúscula) do card, e o arraste se
desfaz sozinho no meio do caminho.

Ao soltar, a posição (`x`, `y`) é salva em `config/positions.json` via
`WidgetPositionService.set()` (usa `FileView.setText()` do próprio
Quickshell, sem processo externo). No próximo reload/reinício, cada
widget lê a posição salva; sem entrada pro widget, cai na posição padrão
calculada em `DashboardWindow.qml`. Esse arquivo é local (depende da
resolução da tela) e por isso está no `.gitignore`.

## Arquitetura

Mesma convenção do `overview`: `shell.qml` como entry point, `common/` pra
tema e widgets reutilizáveis, `services/` pra singletons que buscam dados
(processo externo, HTTP, arquivo), `modules/` pros componentes visuais.

```
quickshell-dashboard/
├── README.md
├── shell.qml
├── common/
│   ├── Config.qml            # tamanhos, posições, toggles de cada widget
│   ├── Appearance.qml        # paleta de cores, fontes, raio de borda
│   ├── assets/
│   │   ├── git.png            # ícone do streak de commits (64×64)
│   │   └── *.svg               # ícones do card de clima (humidity, wind, rain-chance, visibility, sunrise, sunset)
│   └── widgets/
│       ├── Card.qml          # fundo relevo suave + alça de arrastar
│       └── StyledText.qml
├── services/
│   ├── ClockService.qml
│   ├── UptimeService.qml               # uptime do sistema (não usado no card mais)
│   ├── ActiveTimeService.qml           # tempo ativo na sessão (exclui idle)
│   ├── CommitStreakService.qml         # streak de dias com commit em ~/repos/*
│   ├── WeatherService.qml              # geolocalização IP + Open-Meteo
│   ├── SecretsService.qml              # lê config/secrets.json
│   ├── CalendarService.qml             # fetch + parse do .ics do Proton
│   ├── MediaService.qml                # playerctl, filtro music.youtube.com
│   ├── HyprlandWorkspaceService.qml    # mostra/esconde por workspace vazio
│   ├── WidgetPositionService.qml       # posição dos cards arrastados
│   ├── NotionService.qml               # busca (/v1/search) + blocos de página do Notion
│   └── HyprlandApps.qml                # (parte 6, ainda não existe)
├── modules/
│   ├── WelcomeCard.qml
│   ├── ClockCalendar.qml
│   ├── Weather.qml
│   ├── MusicPlayer.qml
│   ├── DashboardWindow.qml   # janela layer-shell com os widgets espalhados
│   ├── QuickNotes.qml        # lista + edição de páginas do Notion
│   └── Dock.qml              # (parte 6, ainda não existe)
└── config/
    ├── secrets.example.json  # template (token Notion, link .ics Proton)
    ├── secrets.json          # real, nunca commitado — você cria a partir do template
    ├── positions.json        # posição dos cards arrastados, nunca commitado
    └── dock-pinned.json      # (parte 6, ainda não existe)
```

## Fases de implementação

- [x] **Parte 1** — scaffold (`shell.qml`, `Config.qml`, `Appearance.qml`,
      `StyledText.qml`) + `WelcomeCard` (avatar placeholder, saudação,
      uptime) + `ClockCalendar` (só relógio por enquanto, calendário entra na
      parte 3).
- [x] **Parte 2** — `Weather` (geolocalização IP + Open-Meteo). Cuidado
      especial: a consulta de IP é bindada na interface de rede física
      (nunca a da VPN), porque o usuário usa ProtonVPN — testado e
      confirmado com a VPN conectada de verdade (sem o bind, geolocalizava
      pro servidor de saída da VPN; com o bind, pega a localização real).
- [x] **Parte 3** — `CalendarService` (fetch/parse `.ics` do Proton) + eventos
      dentro do `ClockCalendar`. Falta você colocar o link real em
      `config/secrets.json` (ver seção "Segredos" abaixo) — sem ele o card
      mostra "Calendário não configurado".
- [x] **Parte 4** — `MediaService` + `MusicPlayer` (MPRIS/`playerctl`,
      filtro `music.youtube.com`). Testado com o próprio Firefox expondo
      MPRIS por aba.
- [x] **Parte 5** — `QuickNotes` + `NotionService`: busca tudo que a
      integração enxerga (`/v1/search`) em vez de database fixa, abre
      página e edita blocos de texto (`PATCH /v1/blocks/{id}`). Falta
      você criar a integração e compartilhar as páginas desejadas (ver
      seção "Segredos" abaixo) — sem isso o card mostra "Notion não
      configurado".
- [ ] **Parte 6** — `Dock` (apps abertos + fixados, clique direito pra
      pin/unpin).
- [x] **Extra (não numerado)** — `HyprlandWorkspaceService`: o dashboard
      inteiro mostra/esconde sozinho conforme o workspace focado tem ou não
      janelas, em vez de precisar de comando manual.

## Segredos

`config/secrets.json` **não é commitado** — está no `.gitignore` deste
diretório. Crie a partir do template e preencha editando direto no editor,
sem colar nenhum token/link em chat ou log:

```bash
cp config/secrets.example.json config/secrets.json
```

Campos:

- `protonCalendarIcsUrl` — link público do Proton Calendar (Configurações →
  Calendário → Compartilhar → Obter link). Quem tiver esse link lê seu
  calendário, trate como senha.
- `notion.token` — token da integração do Notion. Criar em
  [notion.so/my-integrations](https://www.notion.so/my-integrations)
  ("+ New integration", tipo "Internal"), copiar o "Internal Integration
  Secret". Depois, em cada página raiz que o widget deve enxergar (compartilhar
  uma propaga pras subpáginas): menu "..." → "Connections" → adicionar a
  integração criada. Sem isso, `/v1/search` não retorna nada mesmo com token
  válido.

## Testar antes de instalar

Pra rodar sem mexer em `~/.config/quickshell/`, dá pra apontar o Quickshell
pra este diretório diretamente:

```bash
qs -p /home/andrelmi/repos/hyprland/quickshell-dashboard
```

Isso abre os widgets na sua sessão Hyprland atual só pra teste visual — nada
é instalado/symlinkado até você aprovar.
