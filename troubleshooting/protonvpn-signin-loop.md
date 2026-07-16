# ProtonVPN: `protonvpn signin` parece entrar em loop infinito

> Investigado em 2026-07-16. Efeito colateral direto de [[proton-bridge-nao-abre]] — mesma causa raiz que já tinha quebrado o `apolo` (ver [[proton-api-keyring-migracao]]). Este é o **terceiro** app afetado pela desativação do `org.freedesktop.secrets`. Se aparecer um quarto, o padrão de diagnóstico e correção é o mesmo dos três: identificar o backend de keyring/secrets em uso e migrar pra `pass`/GPG.

## Sintoma

Rodar `protonvpn signin` parece nunca terminar — o comando fica pendurado (ou o usuário tem a impressão de estar num loop de autenticação, precisando digitar credenciais de novo e de novo).

## Causa raiz (dois problemas empilhados, não um só)

### 1. Backend de keyring do ProtonVPN quebrado (mesma causa dos outros dois casos)

O ProtonVPN Linux (`python-proton-vpn-api-core` + `python-proton-keyring-linux`) persiste a sessão/token de login via um sistema de plugins do `proton-core` (`proton.loader.Loader`, grupo de entry points `proton_loader_keyring`). Backends registrados por padrão, em ordem de prioridade:

| prioridade | nome            | classe                                                          |
|-----------:|-----------------|------------------------------------------------------------------|
| 5.0        | `secret_service`| `proton.keyring_linux.secretservice:KeyringBackendLinuxSecretService` |
| 4.0        | `libsecret`     | `proton.keyring_linux.libsecret:LibsecretKeyringBackend`         |
| -1000      | `json`          | `proton.keyring.textfile:KeyringBackendJsonFiles` (texto puro, sem cifra) |

Com `org.freedesktop.secrets` desativado (ver [[proton-bridge-nao-abre]]), o backend `secret_service` não falha graciosamente: o método `_validate()` deixa vazar um `dbus_next`/`jeepney` `DBusErrorResponse` (`NameHasNoOwner: Could not activate remote peer 'org.freedesktop.secrets': unit failed`) que **não é capturado** por `_is_backend_working()` (que só trata `keyring.errors.InitError/KeyringLocked/NoKeyringError`). Isso quebra `Loader.get('keyring')` inteiro em vez de cair pro próximo backend da lista.

Nos logs (`~/.cache/Proton/VPN/logs/vpn-cli.log`) dava pra ver que, num primeiro momento (antes do secrets service ser desativado de vez), o erro era outro — `secret_service` falhava com `Failed to create the collection: Prompt dismissed.` (o mesmo `gcr-prompter` quebrado descrito em [[proton-bridge-nao-abre]]) e o app conseguia cair pro backend `libsecret`. Depois que o D-Bus service foi desativado de vez, nem isso funcionou mais.

### 2. Processo zumbi do waybar segurando o lock de sessão (o que de fato gerava a sensação de "loop infinito")

`~/.config/waybar/protonvpn-status.sh` chama `protonvpn status` periodicamente pra atualizar o widget da barra. Esse script **não tem timeout** na chamada (`status_output="$("$PROTONVPN_BIN" status 2>&1)"`). Quando o keyring quebrou (por volta de 08:20 de 2026-07-16), uma dessas chamadas de `protonvpn status` ficou presa para sempre (`wchan: __x64_sys_epoll_wait`, sem consumir CPU) **segurando o lock file** `/run/user/1000/Proton/proton-sso.lock`.

Todo `protonvpn` CLI (incluindo `signin` e `connect`) precisa desse lock pra rodar. Com ele preso por um processo zumbi havia ~5h, qualquer tentativa de `protonvpn signin` feita manualmente ficava **bloqueada indefinidamente** esperando o lock (`wchan: locks_lock_inode_wait`) — isso é o que parecia "loop infinito": o comando não retornava erro nem sucesso, só ficava pendurado, e cada nova tentativa (Ctrl-C + repetir) caía na mesma trava.

Em paralelo, o `protonvpn-autoconnect.service` (`systemd --user`, `ExecStart=protonvpn connect`) ficava reiniciando (`Restart=on-failure`) e falhando com `Error: Authentication required. Please sign in with 'protonvpn signin'` a cada tentativa — sintoma visível, mas não a causa do travamento do `signin` manual.

## Diagnóstico (comandos usados)

```bash
# achar quem segura o lock de sessão do ProtonVPN
fuser -v /run/user/1000/Proton/proton-sso.lock

# ver em que o processo está bloqueado
cat /proc/<PID>/wchan; echo
ls -la /proc/<PID>/fd    # confirma o fd aberto no .lock

# testar diretamente qual backend de keyring o proton-core escolheria
python3 -c "
from proton.loader import Loader
for pc in Loader.get_all('keyring'):
    print(pc)
print(Loader.get('keyring'))
"
```

## Correção aplicada

### 1. Matar o processo zumbi e liberar o lock

```bash
kill -TERM <PID do "protonvpn status" preso>   # achado via fuser acima
systemctl --user stop protonvpn-autoconnect.service   # pra não competir durante o signin manual
```

### 2. Backend de keyring próprio, baseado em `pass`/GPG (mesmo padrão do `apolo`)

Repositório: `~/proton-vpn-keyring-pass/` (`proton_keyring_pass.py` + `pyproject.toml`).

- Chave GPG dedicada, sem senha, só pra essa automação (headless, sem pinentry):
  ```bash
  gpg --batch --gen-key <<'EOF'
  %no-protection
  Key-Type: eddsa
  Key-Curve: ed25519
  Key-Usage: sign
  Subkey-Type: ecdh
  Subkey-Curve: cv25519
  Subkey-Usage: encrypt
  Name-Real: ProtonVPN Automation
  Name-Email: protonvpn-automation@localhost
  Expire-Date: 0
  %commit
  EOF
  ```
  Fingerprint: **`B88421F3FB805646C4A15A969E89EE179A44DA04`**

- Subpasta isolada no password-store, com `.gpg-id` próprio (mesmo motivo do `apolo`: sem isso, `pass insert` herdaria o `.gpg-id` da pasta pai — a chave pessoal, com senha — e voltaria a precisar de `pinentry`):
  ```bash
  mkdir -p ~/.password-store/protonvpn
  echo "B88421F3FB805646C4A15A969E89EE179A44DA04" > ~/.password-store/protonvpn/.gpg-id
  ```

- `proton_keyring_pass.py`: subclasse de `proton.keyring._base.Keyring` (mesmo padrão do `KeyringBackendJsonFiles` embutido, mas gravando via `pass insert -m -f` / `pass show` / `pass rm --force` em vez de arquivo texto puro). `_get_priority()` retorna **10.0** — maior que `secret_service` (5.0) e `libsecret` (4.0) — de forma que o `Loader` do proton-core escolhe esse backend **primeiro** e nunca chega a invocar os backends quebrados. `_validate()` confere `pass` no PATH **e** a existência do `.gpg-id` isolado (mesma checagem defensiva do `apolo`).

- Registrado via entry point `proton_loader_keyring` no `pyproject.toml`:
  ```toml
  [project.entry-points.proton_loader_keyring]
  pass = "proton_keyring_pass:PassKeyringBackend"
  ```

- Instalado no ambiente do usuário (Arch bloqueia `pip install` direto por ser "externally managed" — `--user` é seguro aqui porque só grava em `~/.local/lib/python3.14/site-packages`, não mexe em nada gerenciado pelo `pacman`):
  ```bash
  cd ~/proton-vpn-keyring-pass && pip install --user --break-system-packages .
  ```

O binário `/usr/bin/protonvpn` roda com `#!/usr/bin/python` (Python de sistema, sem venv) e `site.ENABLE_USER_SITE = True`, então o entry point instalado em `--user` é descoberto normalmente por `importlib.metadata.entry_points()` sem precisar tocar em nada dentro de `/usr/lib/python3.14/site-packages` (que é gerenciado pelo `pacman` e seria sobrescrito em updates).

## Como verificar se está tudo OK

```bash
python3 -c "
from proton.loader import Loader
print(Loader.get('keyring'))   # deve imprimir PassKeyringBackend
"

python3 -c "
from proton.loader import Loader
K = Loader.get('keyring')()
K['selftest'] = {'foo': 'bar'}
assert K['selftest'] == {'foo': 'bar'}
del K['selftest']
print('OK, sem prompt')
"

# não deve haver ninguém segurando o lock quando nenhum protonvpn estiver rodando
fuser -v /run/user/1000/Proton/proton-sso.lock   # deve vir vazio
```

Se `Loader.get('keyring')` não imprimir `PassKeyringBackend`, confira `pip show proton-vpn-keyring-pass` (deve estar instalado) e se `~/.password-store/protonvpn/.gpg-id` existe.

## Instruções para próximas vezes

- **Se `protonvpn signin`/`connect`/`status` ficar pendurado sem erro nem retorno**: antes de qualquer outra coisa, rode `fuser -v /run/user/1000/Proton/proton-sso.lock`. Se aparecer algum PID, é um processo zumbi segurando o lock (provavelmente disparado pelo `protonvpn-status.sh` do waybar) — mate-o (`kill -TERM <PID>`, depois `-9` se resistir) e o comando pendurado deve destravar sozinho. **Isso não é o mesmo problema do backend de keyring** — pode acontecer de novo mesmo com o backend `pass` funcionando, porque a causa é a falta de timeout no script do waybar.
- **Hardening recomendado, ainda não aplicado**: `~/.config/waybar/protonvpn-status.sh` linha 31 deveria usar `timeout 10 "$PROTONVPN_BIN" status` em vez de chamar sem timeout — isso evitaria que uma trava futura do CLI (por qualquer motivo, não só keyring) vire um processo zumbi segurando o lock por horas. Ainda não apliquei essa mudança; só documentando a recomendação.
- **Não reverta a desativação do `org.freedesktop.secrets`** (traria de volta o travamento do Bridge — ver [[proton-bridge-nao-abre]]). O padrão de correção pra qualquer app novo afetado é sempre o mesmo: identificar o backend de secrets que ele usa e migrar pra `pass`/GPG, com chave dedicada sem senha se o app rodar headless (sem TTY/sem humano pra responder `pinentry`).
- **Se o pacote `python-proton-vpn-api-core` for atualizado** e a lista de backends/prioridades mudar, reconfirme com `Loader.get_all('keyring')` que `PassKeyringBackend` (prioridade 10.0) continua vindo antes de `secret_service`/`libsecret`. Não deveria quebrar — `pip install --user` não é tocado por updates do `pacman` — mas vale checar se a API do `Loader`/`Keyring` mudou.
- **Se o vault do `pass` da automação for perdido** (`~/.password-store/protonvpn/` apagado sem querer): a chave GPG em si continua em `~/.gnupg`; basta recriar o roteamento com `mkdir -p ~/.password-store/protonvpn && echo B88421F3FB805646C4A15A969E89EE179A44DA04 > ~/.password-store/protonvpn/.gpg-id` e rodar `protonvpn signin` de novo (a sessão antiga já era inacessível de qualquer forma, não há nada pra migrar).
