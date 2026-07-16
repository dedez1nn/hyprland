# Proton Mail Bridge não abre (Hyprland)

> Última investigação: 2026-07-16. Se o sintoma voltar, leia este documento inteiro antes de tentar qualquer coisa — o problema tem uma cadeia de causas não óbvia e várias abordagens já foram testadas e descartadas.

## Sintoma

O usuário clica/lança o Proton Mail Bridge e a janela nunca aparece. Se tentar abrir de novo, falha rápido com algo como:

```
ERRO Instance already exists ... (PID : XXXX ...)
ERRO Server did not provide gRPC Focus service configuration.
FATA Captured exception: Server did not provide gRPC Focus service configuration.
```

Isso **não é o erro real** — é só o sintoma de que já existe uma instância travada rodando em background e a nova tentativa não consegue focar a janela dela (que nunca existiu de verdade).

## Causa raiz (cadeia completa)

1. Proton Bridge, ao iniciar, roda uma etapa chamada `"Creating keychain list"` que **testa todos os backends de keychain disponíveis**, começando pelo `SecretServiceDBus` (gnome-keyring via D-Bus), antes de usar o backend configurado (`~/.config/protonmail/bridge-v3/keychain.json`, campo `Helper`, que estava como `pass-app`).
2. O componente gráfico de prompt do gnome-keyring (`gcr-prompter`, processo separado que registra `org.gnome.keyring.SystemPrompter` no D-Bus) está **quebrado nesta sessão Hyprland**: ele processa o pedido de prompt internamente (loga "creating new GcrPromptDialog prompt", faz o "secret exchange", chama "PromptReady") mas **nunca desenha uma janela de verdade na tela**. Confirmado via `hyprctl clients` monitorando em tempo real durante várias tentativas — nenhuma janela do gcr-prompter jamais aparece, mesmo reiniciando o processo do zero.
   - No log do systemd (`journalctl --user _COMM=gcr-prompter`) a primeira tentativa, ainda no login, falha com `cannot open display:` (o DISPLAY provavelmente não estava pronto ainda). Uma segunda instância assume o nome D-Bus com sucesso, mas o comportamento de nunca renderizar persiste mesmo depois de matar e deixar reiniciar essa segunda instância.
3. Como ninguém nunca responde a esse prompt (porque ele não aparece), o Bridge **trava ~3 minutos** no backend `SecretServiceDBus` até desistir com:
   ```
   level="warning" msg="Failed to add test credentials to keychain" error="failed to prompt: prompt timed out" helper="*keychain.SecretServiceDBusHelper"
   ```
4. O processo `bridge-gui` (a GUI em si, processo separado do núcleo `bridge`) tem sua **própria paciência de ~3 minutos** esperando o núcleo (`bridge`) terminar de inicializar e expor o serviço gRPC. Esse tempo se esgota **quase exatamente junto** com o timeout do `SecretServiceDBus`, então o `bridge-gui` sempre crasha (`FATA ... Failed to launch ... error="exit status 1"` no log `_lau_...log`) **antes** do núcleo sequer chegar a tentar o backend seguinte (`pass-app`, que funciona).
5. Resultado: os dois travamentos somados sempre estouram a paciência da GUI. A janela nunca tem chance de aparecer, mesmo que o backend `pass-app`/`gpg`/`pinentry` funcione perfeitamente (e funciona — foi testado e confirmado).

## Backend que funciona: `pass-app`

- `~/.config/protonmail/bridge-v3/keychain.json` tem `"Helper": "pass-app"` — o Bridge guarda a chave do vault via `pass` (gerenciador de senhas baseado em GPG), na entrada:
  ```
  pass show "docker-credential-helpers/cHJvdG9ubWFpbC9icmlkZ2UtdjMvdXNlcnMvYnJpZGdlLXZhdWx0LWtleQ==/bridge-vault-key"
  ```
- Isso depende de `gpg` → `gpg-agent` → `pinentry` para pedir a senha da chave GPG.
- **Problema secundário encontrado e já corrigido**: não existia `~/.gnupg/gpg-agent.conf`, então o `gpg-agent` usava o binário `pinentry` genérico, que sob Hyprland (sem sessão GNOME/KDE completa) provavelmente caía num modo que não conseguia mostrar prompt algum (travava para sempre, sem erro).
- **Correção aplicada**: criado `~/.gnupg/gpg-agent.conf` com:
  ```
  pinentry-program /usr/bin/pinentry-qt
  ```
  e reiniciado com `gpgconf --kill gpg-agent`. Testado e confirmado que o `pinentry-qt` abre janela normalmente e o usuário consegue digitar a senha.
- **Atenção**: o cache da senha no `gpg-agent` tem TTL padrão (~10 min). Se demorar demais entre digitar a senha e o Bridge realmente precisar dela, pode ser necessário digitar de novo.

## Correção final aplicada (a que resolveu de vez)

Como o `gcr-prompter`/`SecretServiceDBus` está fundamentalmente quebrado nesta sessão e consome sozinho toda a paciência da GUI, a solução foi **fazer esse backend falhar instantaneamente** em vez de travar 3 minutos, liberando tempo de sobra para o `pass-app`/`pinentry` (que funciona) responder dentro da janela de paciência do `bridge-gui`.

Três arquivos foram alterados:

### 1. `~/.gnupg/gpg-agent.conf` (criado, sem sudo)
```
pinentry-program /usr/bin/pinentry-qt
```

### 2. `~/.config/autostart/gnome-keyring-secrets.desktop` (criado, sem sudo)
Cópia de `/etc/xdg/autostart/gnome-keyring-secrets.desktop` com `Hidden=true` adicionado no final — desabilita o autostart do componente `secrets` do gnome-keyring **só para este usuário**, sem tocar no componente `pkcs11` (usado por certificados/smartcard, autostart separado em `gnome-keyring-pkcs11.desktop`, não mexido).

### 3. `/usr/share/dbus-1/services/org.freedesktop.secrets.service` (editado com sudo — mudança de sistema, não faz parte do dotfiles)
```diff
- Exec=/usr/bin/gnome-keyring-daemon --start --foreground --components=secrets
+ Exec=/usr/bin/false
```
Isso faz **qualquer tentativa de ativação D-Bus** do serviço `org.freedesktop.secrets` (não só do Bridge — de qualquer app) falhar na hora com `Could not activate remote peer: unit failed`, em vez de reabrir um gnome-keyring que nunca vai conseguir mostrar prompt mesmo.

Depois de aplicar os 3, matar qualquer processo `gnome-keyring-daemon` residual e relançar o Bridge (`/usr/lib/protonmail/bridge/proton-bridge`) resolveu — o núcleo passou pelo `SecretServiceDBus` em ~2s (falha rápida), usou `pass-app` com sucesso (`"Keychain is usable." keychain="Pass"`), e a janela abriu.

## Efeito colateral conhecido (aceito pelo usuário em 2026-07-16)

Com `org.freedesktop.secrets` desativado no sistema todo, **qualquer app que dependa de libsecret/Secret Service** para salvar ou ler credenciais (ex.: "salvar senha" de navegadores, algumas integrações de VS Code, chaveiros de apps GTK) pode passar a falhar ao tentar. Isso já estava efetivamente quebrado antes (o prompt nunca funcionava mesmo), então o custo adicional é baixo, mas vale monitorar se algo relacionado a "salvar senha" parar de funcionar em outro app.

**Já se confirmou um caso real**: o projeto `~/proton-api` (apolo) usava `secret-tool`/Secret Service pra guardar a senha do Bridge e das contas IMAP, e passou a falhar com `"erro ao salvar senha: keyring indisponível (secret-tool?)"`. Ver [[proton-api-keyring-migracao]] pra detalhes de como foi corrigido (migrado pra `pass`/GPG com uma chave dedicada sem senha, em vez de reverter o fix do Bridge). Se aparecer outro app com sintoma parecido, o padrão de solução é o mesmo: **não reverter o `/usr/bin/false`** (isso traz de volta o travamento de 3 minutos do Bridge) — em vez disso, migrar aquele app específico pra `pass`/GPG, ou, se ele tolerar interação humana ocasional (diferente do timer do apolo), pro `pinentry-qt` normal.

### Por que não reverter o Bridge em vez disso

Considerado e descartado: reativar `org.freedesktop.secrets` só resolveria o `apolo` e reintroduziria o problema original do Bridge (volta a travar 3 min e nunca abrir). A causa raiz de fundo (SDDM com **autologin** pra `andrelmi`, que faz o `gnome-keyring` nunca ter uma collection "login" desbloqueada automaticamente via PAM, então qualquer app que precise dela cai no `gcr-prompter` quebrado) não foi corrigida — só contornada. Se um dia alguém quiser resolver isso raiz (e eliminar a necessidade de migrar cada app pra `pass`), o caminho seria configurar a collection "login" do gnome-keyring com **senha em branco** (auto-desbloqueia sozinha ao iniciar o daemon, sem precisar do `gcr-prompter` nem de PAM/autologin funcionando). Isso foi cogitado nesta investigação mas não implementado — o usuário preferiu manter `secrets` desativado e migrar o `apolo` para `pass`/GPG.

## Se o problema voltar (ex.: após update do sistema, reinstalação do gnome-keyring, etc.)

Verifique nesta ordem:

1. **O Bridge ainda não abre?** Rode:
   ```bash
   tail -30 ~/.local/share/protonmail/bridge-v3/logs/$(ls -t ~/.local/share/protonmail/bridge-v3/logs/ | grep _bri_ | head -1)
   ```
   Se parar em `"Creating keychain list"` por mais de alguns segundos, o problema voltou.

2. **`/usr/share/dbus-1/services/org.freedesktop.secrets.service` ainda tem `Exec=/usr/bin/false`?**
   Um update do pacote `gnome-keyring` provavelmente **sobrescreve esse arquivo de volta ao original**. Se sim, repita o `sed` com sudo:
   ```bash
   sudo sed -i 's#Exec=/usr/bin/gnome-keyring-daemon.*#Exec=/usr/bin/false#' /usr/share/dbus-1/services/org.freedesktop.secrets.service
   ```

3. **`~/.gnupg/gpg-agent.conf` ainda existe com `pinentry-program /usr/bin/pinentry-qt`?**

4. **Testar o backend `pass-app` isoladamente** (precisa de um humano na tela para responder ao pinentry):
   ```bash
   pass show "docker-credential-helpers/cHJvdG9ubWFpbC9icmlkZ2UtdjMvdXNlcnMvYnJpZGdlLXZhdWx0LWtleQ==/bridge-vault-key"
   ```
   Se uma janela do pinentry-qt aparecer e a senha for aceita, o backend está OK.

5. **Matar tudo e relançar limpo:**
   ```bash
   pkill -x bridge; pkill -x bridge-gui
   rm -f ~/.cache/protonmail/bridge-v3/bridge-v3.lock ~/.cache/protonmail/bridge-v3/bridge-v3-gui.lock
   pkill gnome-keyring-daemon  # se algum resíduo estiver rodando
   /usr/lib/protonmail/bridge/proton-bridge &
   ```

## Abordagens já tentadas e descartadas (não perca tempo repetindo)

- **Override de usuário do D-Bus service** (`~/.local/share/dbus-1/services/org.freedesktop.secrets.service` com `Exec=/bin/false`, sem sudo): **não funcionou**. A sessão usa `dbus-broker` (não o `dbus-daemon` clássico), e ele ignorou o override do usuário, sempre ativando a versão real em `/usr/share/dbus-1/services/`. Se quiser investigar de novo, seria preciso entender o mecanismo de reload/prioridade de service dirs do `dbus-broker` especificamente — não é um simples "arquivo com mesmo nome em XDG_DATA_HOME ganha".
- **Reiniciar só o `gcr-prompter`** (matar o processo e deixar o D-Bus reativar): não resolveu — a nova instância continua não desenhando janela nenhuma.
- **Rodar `bridge --grpc --no-window` manualmente e depois abrir `bridge-gui` separado esperando anexar**: não é suportado pela arquitetura do Bridge. O `bridge-gui` sempre spawna seu próprio processo `bridge` filho (com `--parent-pid` apontando pra si mesmo); não existe um jeito simples de "anexar" a um núcleo já rodando standalone.
- **Mascarar as units systemd `gnome-keyring-daemon.service`/`.socket`**: já estavam mascaradas de antes e **não impediam nada**, porque o gnome-keyring nesta sessão é ativado via arquivo de serviço D-Bus clássico (`/usr/share/dbus-1/services/org.freedesktop.secrets.service`) e via autostart XDG (`.desktop` em `/etc/xdg/autostart/`), não via essas units.

## Contexto do ambiente (para diagnosticar coisas parecidas no futuro)

- Compositor: Hyprland (Wayland), sessão iniciada via SDDM.
- Barramento de sessão: `dbus-broker` (não `dbus-daemon` clássico) — importante porque muda como overrides de serviço D-Bus se comportam.
- `/home` é uma partição separada (`/dev/nvme0n1p10`) — não é relevante pra esse bug específico, mas ver [[proton-api-setup]] pra contexto geral do sistema.
- Versão do Bridge no momento da investigação: `3.25.0` (tag `br-223`).
