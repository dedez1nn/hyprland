# Backlog

Lista viva de tudo que foi pedido pro Quickshell Dashboard, widget por
widget. `[x]` é o que já está implementado (ver detalhes técnicos no
`README.md`); `[ ]` é o que falta ou foi pedido depois e ainda não entrou.
Atualizar aqui sempre que surgir um pedido novo, antes de implementar.

## Card de boas-vindas

- [x] Avatar (placeholder por enquanto, sem foto)
- [x] Saudação por horário (bom dia / boa tarde / boa noite / boa madrugada)
- [x] Tempo de atividade do sistema (uptime, via `/proc/uptime` —
      `UptimeService.qml`, não usado mais no card, ver item abaixo)
- [x] **Streak de commits** — varre `~/repos/*` via `git log --all` (sem
      filtro de autor), conta dias seguidos com pelo menos 1 commit,
      considerando "vivo" até virar o dia mesmo sem commit ainda hoje
      (`CommitStreakService.qml`)
- [x] **Tempo de atividade na sessão** — substituiu o uptime bruto no
      card. Detecção de idle via protocolo `ext-idle-notify`
      (`Quickshell.Wayland.IdleMonitor`, timeout de 120s), acumulando só os
      segundos ativos (`ActiveTimeService.qml`). Zera quando o Quickshell
      reinicia (coincide com o login, já que sobe via systemd)

## Relógio + calendário

- [x] Relógio ao vivo (hora + data por extenso em pt_BR)
- [x] Eventos do Proton Calendar via link `.ics` público (lista simples, até
      4 próximos eventos)
- [x] **Tira da semana corrente** — segunda a domingo, dia de hoje
      destacado, pontinho embaixo do dia que tem evento, mais a mensagem
      "N eventos essa semana" (`modules/ClockCalendar.qml`)
- [ ] **Grade de mês navegável** — a tira acima só mostra a semana atual;
      falta um calendário de verdade com navegação entre meses, se quiser
      ir além disso
- [ ] (limitação conhecida, não pedida — documentar) eventos recorrentes
      (RRULE) ainda não são expandidos, só a primeira ocorrência aparece

## Clima (Open-Meteo)

- [x] Temperatura, ícone, descrição, cidade — geolocalização por IP
- [x] Bind na interface de rede física pra não pegar a localização do
      servidor de saída da VPN (usuário usa ProtonVPN)
- [x] Correção manual de cidade errada (ex: IP geolocalizava "São Sebastião
      do Paraíso" em vez de "Passos")
- [x] Umidade e vento exibidos no card (`WeatherService.humidity`/`windSpeed`)
- [x] **Mais dados no card** — probabilidade de chuva
      (`precipitation_probability_max` do `daily`), visibilidade
      (`hourly.visibility`, hora atual), nascer e pôr do sol
      (`daily.sunrise`/`sunset`). Card virou `Row` (ícone + temp/descrição,
      centralizada) + `Row` única com os 6 stats (umidade, vento, chuva,
      visibilidade, nascer, pôr do sol) lado a lado — card cresce
      lateralmente pra caber tudo numa linha só, em vez de espremer numa
      largura fixa
      (`modules/Weather.qml`).
- [ ] **Outras informações** — a definir (sensação térmica? previsão dos
      próximos dias?)

## Mini player (YouTube Music)

- [x] Detecção via MPRIS/`playerctl`, filtrando só `music.youtube.com`
- [x] Capa (com fallback), título, artista
- [x] Controles: anterior, play/pause, próxima

## Notas rápidas (Notion)

- [x] **Busca tudo que a integração enxerga** — em vez de fixar uma
      database, usa `POST /v1/search` (sem filtro), que devolve toda
      página/database compartilhada com a integração no Notion (menu
      "..." → Connections). Compartilhar uma página raiz propaga pras
      subpáginas dela — responsabilidade do usuário lá na UI do Notion,
      não tem como fazer pelo código (`services/NotionService.qml`)
- [x] **Abrir e editar página** — clicar num item da lista busca os
      blocos de primeiro nível (`GET /v1/blocks/{id}/children`) e mostra
      cada um numa caixa de texto editável; "Salvar" faz `PATCH
      /v1/blocks/{id}` de cada bloco alterado, "+ nova nota" acrescenta
      um parágrafo vazio (`PATCH /v1/blocks/{id}/children`)
      (`modules/QuickNotes.qml`)
- [ ] (limitação conhecida, não pedida — documentar) só os tipos
      paragraph/heading_1-3/bulleted_list_item/numbered_list_item/to_do
      são lidos e editáveis; qualquer outro tipo (tabela, imagem, blocos
      aninhados) aparece como "(bloco não suportado)", somente-leitura
- [x] **Checklist indentada sob outro bloco** — blocos filhos (ex: uma
      lista de `to_do` indentada sob um parágrafo de data, como "24/08:")
      não apareciam, porque só o primeiro nível de `children` da página
      era buscado. Agora `NotionService` busca recursivamente (um GET
      `/children` extra por bloco com `has_children: true`) até 4 níveis
      de profundidade, com indentação visual proporcional
      (`modules/QuickNotes.qml`)
- [x] **Checkbox visível nos blocos `to_do`** — antes só o texto aparecia;
      agora desenha ☐/☑ (clicável em modo edição) e risca o texto quando
      marcado
- [x] **Letra pequena mesmo em 2×/3×** — o seletor de tamanho só crescia
      o card, não a fonte lá dentro. Agora o texto das notas
      (`noteFontSize`) cresce junto com `sizeLevel`, além de mais grosso
      (`Font.Medium`, títulos/headings em `Font.Bold`) e mais branco
      (`noteTextColor`, "#f5f7ff") que o texto padrão do dashboard
      (`modules/QuickNotes.qml`). De quebra, a fonte declarada em
      `Appearance.qml` trocou de "Rubik" (nunca instalada, sempre caiu
      num fallback silencioso) pra "Open Sans" (instalada de verdade) —
      efeito em todos os widgets, não só nas notas
- [ ] (limitação conhecida) sem rich text de verdade — só texto plano;
      negrito/cor/link do bloco original não sobrevivem a uma edição
      salva pelo widget
- [x] **Modo leitura por padrão + botão Editar** — página abre só pra
      leitura; botão "Editar" (branco, canto superior) libera a edição
      das caixas de texto; botão "Salvar" (branco, embaixo das notas)
      grava via API e volta pro modo leitura (`modules/QuickNotes.qml`)
- [x] **Seletor de tamanho 1×/2×/3×** — canto superior direito do card,
      multiplica `implicitWidth`/`implicitHeight` do widget inteiro
      (dobra/triplica). Não é persistido entre reloads (sempre volta pra
      1× no restart do Quickshell) — se fizer falta, dá pra guardar em
      `WidgetPositionService`/`config/positions.json` depois

## Dock/taskbar preta

- [ ] Não iniciado — planejado pra parte 6: ícones de apps abertos +
      fixados, clique direito pra fixar/desafixar

## Geral / transversal

- [x] Mostra/esconde sozinho conforme o workspace atual tem ou não janelas
      (`HyprlandWorkspaceService`)
- [x] **Identidade visual própria** — "Relevo Suave": fundo translúcido
      (~72% opacidade) com borda fina cinza-clara, mais uma sombra
      (`RectangularShadow` do QtQuick.Effects, só a escura desde a
      otimização de memória abaixo) simulando o card esculpido do próprio
      fundo, em vez do retângulo liso e opaco genérico de antes
      (`common/widgets/Card.qml`). Fonte "Rubik" segue declarada mas não
      instalada no sistema (cai no fallback Noto Sans) — pendente se
      quiser resolver.
- [x] **Layout espalhado pela tela** — boas-vindas no topo central,
      calendário à esquerda no meio, YouTube Music à direita no meio, clima
      no canto inferior direito (`modules/DashboardWindow.qml`), em vez de
      empilhados num canto só.
- [x] **Autostart via systemd** — `~/.config/systemd/user/quickshell-dashboard.service`,
      iniciado no login do Hyprland (`configs/Startup_Apps.conf`). Ver
      seção "Autostart" no `README.md`.
- [x] **Arrastar os cards** — card inteiro é arrastável (sem alça
      dedicada; botões próprios, como os do MusicPlayer, continuam
      clicáveis por ficarem por cima na ordem de pintura), cursor muda pra
      mãozinha ao passar o mouse. Posição salva em `config/positions.json`
      (`WidgetPositionService.qml`) e restaurada no próximo reload. Ver
      seção "Arrastar widgets" no `README.md`.
      - Correção: a mask da janela (que limita onde ela aceita clique)
        cobria só a área de cada card — o Hyprland parava de mandar
        eventos de mouse assim que o cursor saía dali durante o arraste,
        "soltando" o card sozinho. Agora, enquanto `WidgetPositionService.dragging`
        é true, a mask vira a tela inteira; volta ao normal ao soltar.
- [x] **Otimização de memória** — cortada a sombra clara de cada card (só
      sobrou a escura), reduzindo pela metade os shaders `RectangularShadow`
      ativos (8 → 4 no total). Poll do `MediaService`/`playerctl` foi de 2s
      pra 4s. O baseline de ~80-100MB é o custo fixo de rodar Quickshell/Qt
      Quick com efeitos GPU, não dá pra cortar muito mais sem abrir mão de
      sombra/transparência.
