# apolo (proton-api): migração de secret-tool para pass/GPG

> Contexto: 2026-07-16, efeito colateral direto de [[proton-bridge-nao-abre]] — leia aquele documento primeiro pra entender por que `org.freedesktop.secrets` foi desativado no sistema.

## Sintoma

Na UI do `apolo` (Settings), ao tentar salvar a senha do Bridge:

```
erro ao salvar
senha: keyring indisponível (secret-tool?)
```

## Causa

`~/proton-api/apolo/secrets.py` guardava a senha do Bridge e das contas IMAP via `secret-tool` (CLI do libsecret), que fala com `org.freedesktop.secrets` por D-Bus. Esse serviço foi **desativado de propósito** no sistema (`Exec=/usr/bin/false` em `/usr/share/dbus-1/services/org.freedesktop.secrets.service`) pra resolver o travamento do Proton Mail Bridge — ver [[proton-bridge-nao-abre]]. Consequência direta: `secret-tool` para de funcionar pra qualquer app, incluindo o `apolo`.

Detalhe extra encontrado no código (`ui/settings.py`, antes da correção): quando `secrets.store_password()` falhava, a senha **não caía em nenhum fallback** — o comentário no código dizia explicitamente "a senha NÃO vai pro `.env` — fica só no keyring". Ou seja, não era só um aviso cosmético: a senha realmente não estava sendo salva em lugar nenhum.

## Restrição que guiou a escolha da solução

O módulo `secrets.py` já documentava por que Secret Service tinha sido escolhido originalmente: o `apolo run` roda via **timer do systemd --user**, sem TTY e sem humano pra responder prompt algum. Qualquer solução tinha que continuar funcionando 100% headless.

Isso descartou a opção óbvia de "usar a mesma chave GPG pessoal que o Bridge usa" — essa chave **tem senha** (confirmado nesta mesma investigação: abre um `pinentry-qt` e um humano precisa digitar). Usá-la faria o timer do apolo travar esperando pinentry sempre que o cache do `gpg-agent` expirasse (TTL padrão ~10 min) — pior que o problema original.

## Solução aplicada

### 1. Chave GPG dedicada, sem senha, só para essa automação

```bash
gpg --batch --gen-key <<'EOF'
%no-protection
Key-Type: eddsa
Key-Curve: ed25519
Key-Usage: sign
Subkey-Type: ecdh
Subkey-Curve: cv25519
Subkey-Usage: encrypt
Name-Real: Apolo Automation
Name-Email: apolo-automation@localhost
Expire-Date: 0
%commit
EOF
```

Fingerprint gerada: **`FFB7DD86C6172FF341EA6BFBE29B9119DF6E8364`**
(`gpg --list-secret-keys apolo-automation@localhost` pra conferir/gerenciar; certificado de revogação em `~/.gnupg/openpgp-revocs.d/`)

`%no-protection` faz o GPG nunca chamar `pinentry` pra essa chave — decripta na hora, sem humano.

### 2. Subpasta dedicada no password-store, com `.gpg-id` próprio

```bash
mkdir -p ~/.password-store/apolo
echo "FFB7DD86C6172FF341EA6BFBE29B9119DF6E8364" > ~/.password-store/apolo/.gpg-id
```

Isso faz `pass insert apolo/...` encriptar **só** pra essa chave, isolado do resto do password-store (que usa a chave pessoal `6D5FE79EC651FEFF37CECFCF6C01C869487E9118`, a mesma usada pelo `pass-app` do Proton Bridge). Comprometer a chave da automação não expõe o resto do cofre.

**Se `~/.password-store/apolo/.gpg-id` sumir ou for apagado sem querer** (já aconteceu uma vez nesta investigação, por engano): basta recriar com o comando acima — a chave GPG em si continua existindo em `~/.gnupg`, só o arquivo de roteamento do `pass` precisa existir.

### 3. `apolo/secrets.py` reescrito para usar `pass` em vez de `secret-tool`

Mesma API pública (`disponivel`, `store_password`, `lookup_password`, `clear_password`, `store_account_password`, `lookup_account_password`, `clear_account_password`) — nenhum outro arquivo do projeto precisou mudar a chamada, só a implementação por dentro.

Mapeamento de entradas:
- Senha do Bridge → `apolo/bridge-password`
- Senha de conta IMAP → `apolo/imap-account/<account_id>` (`/` no `account_id` é trocado por `_` por segurança, embora não devesse ocorrer na prática)

`disponivel()` agora confere **duas coisas**: se o binário `pass` existe no PATH, **e** se `~/.password-store/apolo/.gpg-id` existe. A segunda checagem importa: sem ela, um `pass insert` em `apolo/...` herdaria o `.gpg-id` da pasta pai (a chave pessoal, com senha) e o timer sem TTY voltaria a travar — silenciosamente, sem essa checagem explícita.

Comandos usados internamente (via `subprocess`, timeout de 5s):
```bash
pass insert -m -f <path>   # grava (stdin = valor, -f evita prompt de confirmação de overwrite)
pass show <path>           # lê
pass rm --force <path>     # remove
```

Também corrigidas duas mensagens de erro que citavam `secret-tool/libsecret` (desatualizadas): `ui/imap_setup.py:153` e `cli.py:1021` (esta última também dizia "Instale libsecret", que não faz mais sentido).

## Como verificar se está tudo OK

```bash
cd ~/proton-api
python3 -c "
from apolo import secrets
print('disponivel:', secrets.disponivel())
assert secrets.store_password('teste') and secrets.lookup_password() == 'teste'
assert secrets.clear_password()
print('OK, sem prompt')
"
```
Se isso rodar em menos de 1s sem abrir nenhuma janela, está funcionando. Se `disponivel()` vier `False`, confira se `~/.password-store/apolo/.gpg-id` existe e se `pass` está instalado (`which pass`).

## Migração de senhas já existentes

Este fix **não migra automaticamente** senhas que já estavam guardadas no Secret Service antigo (via `secret-tool`, antes de tudo isso quebrar) — elas ficaram inacessíveis quando o serviço foi desativado. Se a senha do Bridge ou de alguma conta IMAP "sumiu" depois dessa mudança, é só entrar de novo na tela de Settings/IMAP do `apolo` e digitar — vai ser salva no novo esquema (`pass`) automaticamente.

## Pra quem for mexer de novo

- Não delete `~/.password-store/apolo/` nem a chave GPG `apolo-automation@localhost` sem migrar as senhas antes (`pass show apolo/bridge-password` etc. pra recuperar em texto puro, se precisar).
- Se algum dia o gnome-keyring for consertado de verdade (login collection com senha em branco, ver [[proton-bridge-nao-abre]]), **não é necessário reverter essa migração** — `pass`/GPG continua sendo uma solução válida e mais isolada (chave própria, sem depender de D-Bus/sessão gráfica). Reverter só faria sentido se quisesse voltar a usar literalmente o Secret Service por algum motivo específico.
