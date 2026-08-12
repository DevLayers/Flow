# Plano de Implementação — Phone Integration vNext

> Repositório alvo: `P3DROVFX/ii-p3drovfx`  
> Branch de referência: `dev`  
> Escopo: **Contacts**, **scrcpy App Mode** e **scrcpy como backend primário de webcam**  
> Ambiente: Hyprland + Quickshell / Illogical Impulse  
> Status: Plano técnico de implementação — nenhuma alteração de código aplicada por este documento.

---

## 1. Objetivo

Este documento define um plano detalhado para expandir o módulo **Phone** do II em três frentes:

1. **Contacts**
   - Exibir no II os contatos sincronizados pelo KDE Connect.
   - Permitir busca instantânea, favoritos e ações rápidas.
   - Não criar sincronização Android própria: consumir os VCards que o KDE Connect já mantém no desktop.

2. **scrcpy App Mode**
   - Evoluir o scrcpy de um único "mirror da tela" para um gerenciador de sessões.
   - Listar aplicativos Android.
   - Abrir aplicativos em **virtual displays independentes**, com `--flex-display`.
   - Tratar cada janela como uma sessão gerenciada pelo II/Hyprland.
   - Não embutir vídeo no QML e não usar QtMultimedia.

3. **scrcpy como backend primário de webcam**
   - Usar a câmera Android diretamente através do scrcpy.
   - Publicar a câmera em `/dev/videoN` por V4L2.
   - Manter DroidCam como fallback.
   - Preservar a API pública de `PhoneCameraService.qml` para reduzir regressões na UI.

A intenção não é criar um novo "Phone Link" monolítico. O II continuará sendo o **orquestrador de backends especializados**, com estado reativo em QML e processos nativos externos para vídeo/ADB.

---

# 2. Estado atual que deve ser preservado

## 2.1 Phone.qml

O `Phone.qml` já usa o padrão **Hub-and-Spoke**:

- página principal;
- `activeSubPage`;
- `openSubPage(url)`;
- `closeSubPage()`;
- subpáginas carregadas sobre o conteúdo principal.

Esse padrão deve continuar sendo a base para:

- `PhoneContactsPage.qml`;
- `PhoneAppsPage.qml`;
- `PhoneScrcpyPage.qml`;
- `PhoneWebcamPage.qml`;
- `PhoneMicPage.qml`.

**Não criar uma segunda lógica de navegação para Contacts ou Apps.**

---

## 2.2 PhoneFooter.qml

O footer já possui responsabilidade clara:

- scrcpy Mirror;
- Phone Webcam;
- Phone Microphone.

Esses três elementos representam o telefone como **periférico/stream**.

Contacts e Android Apps **não devem virar novos cards nesse footer**, pois conceitualmente são navegação/conteúdo, não periféricos.

O plano propõe criar uma pequena camada de navegação entre `PhoneActionsRow` e Notifications.

---

## 2.3 KdeConnectService.qml

Atualmente concentra:

- dispositivos KDE Connect;
- bateria;
- conectividade;
- notificações;
- pairing;
- ADB reachability;
- Wireless Debugging;
- descoberta mDNS;
- lançamento e tracking de scrcpy;
- ações ADB.

A expansão para múltiplas sessões scrcpy tornaria o singleton ainda maior.

### Decisão

Separar gradualmente a responsabilidade de scrcpy em:

```text
KdeConnectService
    ├── dispositivo / KDE Connect
    ├── ADB connectivity
    ├── wireless host resolution
    └── ações Android simples
            │
            ▼
PhoneScrcpyService
    ├── versão/capabilities
    ├── mirror session
    ├── app sessions
    ├── app catalog
    ├── window identity
    └── lifecycle dos processos
```

`KdeConnectService` continua sendo a fonte de verdade para **qual telefone está ativo e como alcançá-lo**.

`PhoneScrcpyService` passa a ser a fonte de verdade para **o que está rodando através do scrcpy**.

---

# 3. Regras arquiteturais obrigatórias

Estas regras devem ser tratadas como constraints de implementação.

## 3.1 Não usar QtMultimedia

Não tentar:

- renderizar stream H.264/H.265 dentro do QML;
- transformar o Quickshell em cliente do protocolo interno do scrcpy;
- usar VideoOutput/MediaPlayer como mirror;
- colocar V4L2 dentro de um player Qt como caminho principal.

O cliente oficial scrcpy permanece responsável por:

- ADB server;
- decoder;
- SDL;
- input;
- áudio;
- virtual display;
- câmera.

O II controla o processo e a janela.

---

## 3.2 Estado

Seguir a divisão existente:

### `GlobalStates.qml`
Somente estado efêmero/global de UI necessário entre painéis.

Exemplos possíveis:

```qml
property bool phoneAppsOpen: false
property bool phoneContactsOpen: false
```

Adicionar somente se outro módulo realmente precisar ler esses estados.

### `Config.qml`
Preferências configuráveis pelo usuário:

- opções de Contacts;
- favoritos;
- opções do App Mode;
- webcam backend;
- resolução;
- FPS;
- camera facing;
- V4L2.

### `Persistent.qml`
Estado interno que deve sobreviver reload sem virar configuração:

- apps recentes;
- último contato aberto, se necessário;
- última sessão/foco;
- cache metadata version.

### Cache externo
Dados derivados e reconstruíveis:

```text
~/.cache/illogical-impulse/phone/
├── contacts/
├── apps/
└── scrcpy/
```

Não armazenar listas inteiras de contatos em `config.json`.

---

## 3.3 Processos e polling

Evitar Timers fazendo:

```text
pgrep
find
ls
adb shell
```

continuamente.

Preferir:

- `Gio.FileMonitor` para Contacts;
- processo supervisor/eventos para sessões scrcpy;
- callbacks de `Process`;
- sinais;
- IPC;
- refresh explícito quando dispositivo/ADB mudar.

Timers são aceitáveis apenas para:

- debounce;
- elapsed time visual;
- timeout/fallback;
- retry limitado durante conexão.

---

## 3.4 Segurança de dados

Contacts contém PII.

Regras:

- nunca enviar contatos para rede externa;
- não imprimir telefone/email completos em logs normais;
- não persistir VCards completos em Config/Persistent;
- cache de avatar deve ser local;
- ações perigosas não devem ocorrer ao clicar acidentalmente.

A ação "Call" deve inicialmente **abrir o dialer** no celular, e não discar automaticamente.

---

# 4. Arquitetura alvo

```text
                          Phone.qml
                             │
              ┌──────────────┼──────────────┐
              │              │              │
      PhoneNavigation   Notifications    PhoneFooter
              │                              │
       ┌──────┴──────┐              ┌────────┼────────┐
       │             │              │        │        │
   Contacts        Apps          Mirror    Webcam    Mic
       │             │              │        │        │
       ▼             ▼              └────┬───┘        │
PhoneContacts   PhoneAppsPage              │           │
    Page                                     │           │
       │                                     ▼           ▼
       ▼                             PhoneScrcpy   PhoneMic
PhoneContacts                         Service      Service
   Service                               │
       │                                 │
KPeopleVCard                       scrcpy 4.x
       │                           /   |    \
KDE Connect                   mirror  apps  camera
 Android                                  │
                                          ▼
                                    v4l2loopback
                                          │
                                          ▼
                                  OBS/Discord/Meet
```

---

# 5. Ordem geral de implementação

A implementação deve ser feita nesta ordem:

- [ ] **Fase 0 — Preparação e capability layer**
- [ ] **Fase 1 — Contacts backend**
- [ ] **Fase 2 — Contacts UI**
- [ ] **Fase 3 — Refactor scrcpy service**
- [ ] **Fase 4 — Android app catalog**
- [ ] **Fase 5 — scrcpy App Mode**
- [ ] **Fase 6 — Hyprland/window integration**
- [ ] **Fase 7 — scrcpy camera backend**
- [ ] **Fase 8 — DroidCam fallback**
- [ ] **Fase 9 — Settings/dependencies**
- [ ] **Fase 10 — Testes, traduções e AGENTS.md**

Contacts pode começar antes do refactor scrcpy, mas App Mode e Webcam devem compartilhar a capability layer.

---

# 6. Fase 0 — Capability Layer comum

## 6.1 Objetivo

Antes de criar App Mode e migrar webcam, detectar com precisão:

- versão do scrcpy;
- versão Android;
- ADB serial/host;
- suporte a `--flex-display`;
- suporte a camera source;
- V4L2 disponível;
- v4l2loopback disponível.

---

## 6.2 Novas propriedades sugeridas

Em `PhoneScrcpyService.qml`:

```qml
property bool available: false
property string version: ""
property int versionMajor: 0
property int versionMinor: 0

readonly property bool appModeSupported: versionMajor >= 4

property int androidApiLevel: -1
readonly property bool cameraSourceSupported: androidApiLevel >= 31

property bool v4l2CtlPresent: false
property bool v4l2LoopbackInstalled: false
property bool v4l2LoopbackLoaded: false

readonly property bool webcamSupported:
    available
    && KdeConnectService.adbReachable
    && cameraSourceSupported
    && (v4l2LoopbackLoaded || v4l2LoopbackInstalled)
```

Não transformar versões mínimas em opções de usuário.

---

## 6.3 Probes

Executar quando:

- Phone service é habilitado;
- active device muda;
- ADB passa de unavailable → reachable;
- usuário chama `refreshCapabilities()`.

### scrcpy version

```bash
scrcpy --version
```

Parser tolerante:

- ignorar texto adicional;
- extrair `major.minor.patch`;
- não comparar versão como string.

### Android API

```bash
adb ... shell getprop ro.build.version.sdk
```

Usar o mesmo resolved target que o KdeConnectService utiliza.

### V4L2

Verificar:

```bash
command -v v4l2-ctl
command -v v4l2loopback-ctl
lsmod
modinfo v4l2loopback
```

---

## 6.4 Compatibilidade

### scrcpy < 4.0

- Mirror continua funcionando.
- App Mode mostra estado "Requires scrcpy 4.0+".
- Webcam pode continuar disponível se a versão instalada suportar camera source, mas para simplificar o primeiro rollout recomenda-se padronizar pacote em scrcpy >= 4.0.

### Android < 12 / API < 31

- App Mode continua disponível.
- scrcpy Mirror continua disponível.
- Webcam via scrcpy fica indisponível.
- DroidCam é oferecido automaticamente como fallback se instalado.

---

# 7. Feature 1 — Contacts

# 7.1 Fonte de dados

Usar os contatos sincronizados pelo KDE Connect.

Caminho padrão Linux:

```text
${XDG_DATA_HOME:-$HOME/.local/share}/kpeoplevcard/
```

Estrutura esperada:

```text
kpeoplevcard/
└── kdeconnect-<device-or-source>/
    ├── <contact>.vcf
    ├── <contact>.vcf
    └── ...
```

Nunca hardcodar apenas `$HOME/.local/share`.

Resolver:

1. `$XDG_DATA_HOME`, se definido;
2. fallback `~/.local/share`;
3. adicionar `/kpeoplevcard`.

---

# 7.2 Novo backend

Criar:

```text
dots/.config/quickshell/ii/scripts/kdeconnect/contacts_monitor.py
```

ou, para agrupar tudo novo de Phone:

```text
dots/.config/quickshell/ii/scripts/phone/contacts_monitor.py
```

### Recomendação

Usar `scripts/kdeconnect/contacts_monitor.py`, porque a origem dos dados é diretamente KDE Connect/KPeopleVCard.

---

# 7.3 Responsabilidades de contacts_monitor.py

O helper deve:

1. localizar a root `kpeoplevcard`;
2. localizar as fontes disponíveis;
3. associar a melhor fonte ao device ativo;
4. ler `.vcf`;
5. fazer parsing tolerante;
6. observar alterações via `Gio.FileMonitor`;
7. emitir JSON line-delimited;
8. nunca fazer polling periódico.

---

# 7.4 Parsing VCard

Não depender inicialmente de biblioteca Python extra.

Implementar parser mínimo, porém correto para os campos usados na UI.

### Campos

```text
FN
N
TEL
EMAIL
ORG
PHOTO
UID
REV
```

### Requisitos do parser

Suportar:

- linhas folded;
- parâmetros `TYPE=`;
- múltiplos telefones;
- múltiplos emails;
- UTF-8;
- quoted printable quando presente;
- escaped commas/semicolons;
- VCard 2.1;
- VCard 3.0;
- VCard 4.0 na medida necessária.

### Modelo final

```json
{
  "id": "stable-hash-or-uid",
  "displayName": "Pedro",
  "givenName": "Pedro",
  "familyName": "Pessoa",
  "organization": "",
  "phones": [
    {
      "value": "+55...",
      "normalized": "+55...",
      "type": "mobile",
      "primary": true
    }
  ],
  "emails": [],
  "avatarPath": "",
  "source": "kdeconnect-device-id",
  "mtime": 0
}
```

---

# 7.5 IDs estáveis

Prioridade:

1. `UID` do VCard;
2. nome do arquivo;
3. hash de `FN + TEL`.

Não usar índice de array.

O ID precisa continuar estável quando a lista é reordenada.

---

# 7.6 Avatares

Não enviar PHOTO base64 inteira por stdout para o QML.

Quando houver `PHOTO` embutida:

1. decodificar no Python;
2. detectar extensão básica;
3. calcular hash;
4. gravar em:

```text
~/.cache/illogical-impulse/phone/contacts/<hash>.jpg
```

5. retornar apenas `avatarPath`.

Se não houver foto:

- UI gera avatar com inicial;
- usar MaterialShape;
- nenhuma imagem placeholder externa.

---

# 7.7 File monitoring

Usar `Gio.FileMonitor`.

Eventos:

- CREATED;
- CHANGED;
- CHANGES_DONE_HINT;
- DELETED;
- MOVED.

Aplicar debounce curto, por exemplo 150–300 ms, porque uma sincronização pode reescrever muitos VCards em sequência.

Após o debounce:

- reconstruir snapshot;
- comparar hash do snapshot;
- emitir somente se mudou.

---

# 7.8 Protocolo stdout

Exemplo:

```json
{"event":"ready","sourcePath":"...","count":412}
{"event":"snapshot","contacts":[...]}
{"event":"source_changed","sourcePath":"..."}
{"event":"error","code":"no_contact_source","message":"..."}
```

Evitar evento por telefone/email individual se o ganho não justificar a complexidade.

---

# 7.9 Novo singleton QML

Criar:

```text
services/PhoneContactsService.qml
```

## API proposta

```qml
property bool available: false
property bool ready: false
property string sourcePath: ""
property string lastError: ""

property var contacts: []
property string searchQuery: ""
property var filteredContacts: []

readonly property int count: contacts.length

function refresh(): void
function setSearchQuery(query: string): void
function contactById(id: string): var

function copyPhone(number: string): void
function openDialer(number: string): void
function composeSms(number: string): void
function toggleFavorite(contactId: string): void
```

---

# 7.10 Busca

Fazer busca normalizada por:

- displayName;
- organization;
- telefone;
- email.

Normalização:

- lowercase;
- remover accents/diacritics quando possível;
- para telefone, comparar versão sem espaços, `(`, `)`, `-`.

Usar debounce visual pequeno para listas grandes.

---

# 7.11 Favoritos

Persistir apenas IDs:

```qml
Config.options.phone.contacts.favoriteIds
```

Não persistir contato inteiro.

Se um favoriteId desaparecer:

- manter por um tempo não é necessário;
- simplesmente não mostrar o card até o contato reaparecer.

---

# 7.12 Ações rápidas

### Copy

```qml
Quickshell.clipboardText = phoneNumber
```

### Open dialer

Usar ADB:

```bash
adb shell am start \
  -a android.intent.action.DIAL \
  -d tel:<encoded-number>
```

**Não usar `CALL` no MVP.**

### Compose SMS

```bash
adb shell am start \
  -a android.intent.action.SENDTO \
  -d sms:<encoded-number>
```

Essas ações devem reaproveitar um helper de ADB do `KdeConnectService`, sem duplicar lógica de seleção USB/wireless.

---

# 7.13 UI — PhoneContactsPage.qml

Criar:

```text
modules/ii/sidebarPolicies/phone/PhoneContactsPage.qml
```

Estrutura:

```text
Header
├── Back
├── Contacts
└── count/status

Search field

Favorites
└── horizontal list, somente se houver favoritos

Contacts list
├── A
│   ├── Alice
│   └── Amanda
├── B
│   └── Bruno
└── ...

Contact detail inline/overlay
├── avatar
├── name
├── organization
├── phones
├── emails
└── actions
```

---

# 7.14 UI de lista

Cada row:

- avatar circular ou MaterialShape;
- nome;
- telefone principal;
- favorite star, opcional;
- chevron;
- altura determinística.

Usar `ListView`.

Evitar:

- `Repeater` para centenas/milhares de contatos;
- criar todos os delegates simultaneamente.

---

# 7.15 Empty states

Cobrir:

### KDE Connect indisponível
"Install/enable KDE Connect."

### Contacts plugin sem dados
"Enable Contact Sync in KDE Connect on Android and grant Contacts permission."

### Sincronizando
Estado visual neutro; não mostrar erro imediatamente se pasta ainda está sendo criada.

### Lista vazia
"No contacts synced yet."

### Busca sem resultado
"No contacts matching …"

---

# 7.16 Navegação na Phone page

Criar:

```text
PhoneNavigationCards.qml
```

entre:

```text
PhoneActionsRow
↓
PhoneNavigationCards
↓
Notifications
```

Primeiro rollout:

```text
[ Contacts ] [ Android Apps ]
```

Cada card:

- ícone;
- label;
- pequena secondary info;
- `onClicked` emite URL.

`Phone.qml` conecta os sinais a `openSubPage()`.

---

# 7.17 Settings — Contacts

Em `DevicesPhoneConfig.qml`:

```text
Phone Integration
├── KDE Connect
├── Show peripheral cards
└── Contacts
    ├── Show Contacts shortcut
    ├── Show avatars
    └── Sort
        ├── First name
        └── Last name
```

Não criar controles sem necessidade no primeiro rollout.

---

# 7.18 Critérios de aceite — Contacts

- [ ] contatos do telefone aparecem sem app Android adicional;
- [ ] alteração de contato no Android reflete na UI sem reiniciar Quickshell;
- [ ] nenhuma varredura periódica via Timer;
- [ ] 1000+ contatos continuam com scroll fluido;
- [ ] busca por nome funciona;
- [ ] busca por número funciona;
- [ ] favorites persistem;
- [ ] copy number funciona;
- [ ] Open Dialer abre o telefone correto;
- [ ] troca de active device troca a fonte de contatos;
- [ ] nenhum número completo é despejado em logs de debug normais;
- [ ] shell reload não corrompe config.

---

# 8. Feature 2 — Refactor do scrcpy em PhoneScrcpyService

# 8.1 Motivo

O serviço atual já suporta Mirror, mas App Mode exige:

- múltiplas sessões;
- identidade por janela;
- processos independentes;
- apps;
- lifecycle;
- versões;
- capability detection;
- sessões duplicadas;
- foco individual.

Isso não deve continuar crescendo dentro de `KdeConnectService`.

---

# 8.2 Novo singleton

Criar:

```text
services/PhoneScrcpyService.qml
```

Ele consome:

```qml
KdeConnectService.activeDeviceId
KdeConnectService.activeReachable
KdeConnectService.adbReachable
KdeConnectService.resolvedWirelessHost
Config.options.phone.scrcpy
```

---

# 8.3 Compatibilidade durante migração

Primeira etapa:

- adicionar `PhoneScrcpyService`;
- migrar `PhoneScrcpyPage`;
- migrar `PhoneFooter`;
- migrar indicator;
- depois remover propriedades scrcpy antigas do KdeConnectService.

Não deixar dois serviços monitorando o mesmo scrcpy permanentemente.

---

# 8.4 API pública sugerida

```qml
property bool available: false
property string version: ""

property bool mirrorRunning: false
property bool mirrorLaunching: false
property int mirrorElapsedMs: 0
property string mirrorLaunchError: ""

property var apps: []
property bool appsLoading: false
property string appsError: ""

property var sessions: []
readonly property int sessionCount: sessions.length

function launchMirror(): void
function stopMirror(): void
function focusMirror(): void

function refreshApps(): void
function launchApp(packageName: string): void
function stopApp(packageName: string): void
function focusApp(packageName: string): void
function restartApp(packageName: string): void
function stopAllApps(): void

function refreshCapabilities(): void
```

---

# 8.5 Modelo de sessão

```json
{
  "id": "app:org.mozilla.firefox",
  "type": "app",
  "package": "org.mozilla.firefox",
  "appName": "Firefox",
  "windowTitle": "ii-phone-app-org.mozilla.firefox",
  "pid": 12345,
  "state": "launching",
  "startedAt": 0,
  "exitCode": null,
  "lastError": ""
}
```

Tipos:

```text
mirror
app
camera
mic
```

Mesmo que camera/mic continuem em services próprios, títulos/PIDs podem seguir convenção comum.

---

# 8.6 Session supervisor

## Recomendação

Criar:

```text
scripts/phone/scrcpy_session_manager.py
```

### Por que

`execDetached()` é ótimo para uma única janela fire-and-forget, mas ruim para:

- várias sessões;
- saber qual processo terminou;
- associar package → PID;
- emitir erro correto por sessão;
- impedir duplicatas;
- shutdown limpo.

### Função

O supervisor fica aberto enquanto Phone Integration estiver habilitado.

QML → stdin:

```json
{"cmd":"launch","id":"app:org.mozilla.firefox","args":["..."]}
{"cmd":"stop","id":"app:org.mozilla.firefox"}
{"cmd":"stop_all","type":"app"}
```

stdout → QML:

```json
{"event":"started","id":"app:...","pid":1234}
{"event":"exited","id":"app:...","code":0}
{"event":"error","id":"app:...","message":"..."}
```

O helper deve usar `subprocess.Popen` sem shell sempre que possível.

---

# 8.7 Argumentos

Construir argumentos como array.

Evitar:

```text
"scrcpy " + userValue + ...
```

Preferir:

```python
[
    "scrcpy",
    "--serial", serial,
    "--window-title=...",
    ...
]
```

Isso reduz problemas de quoting e injection.

---

# 8.8 Conexão

O `PhoneScrcpyService` não deve reinventar ADB Wireless.

Fluxo:

```text
activeDevice
   ↓
KdeConnectService
   ↓
resolved ADB target
   ↓
PhoneScrcpyService
```

Se for necessário, extrair de `KdeConnectService` uma API pequena:

```qml
function adbTargetArgs(): var
function resolvedAdbSerial(): string
```

para Mirror/App/Webcam/Mic consumirem o mesmo resultado.

---

# 9. Feature 2A — Android App Catalog

# 9.1 Fonte principal

Usar:

```bash
scrcpy --list-apps
```

com o mesmo target ADB.

`--list-apps` é preferível porque o próprio scrcpy conhece o formato esperado e labels.

---

# 9.2 Fallback

Se parsing falhar:

```bash
adb shell pm list packages
```

ou query de launcher activities.

No fallback:

- package name é obrigatório;
- label pode ser igual ao package;
- UI continua funcional.

---

# 9.3 Cache

Salvar cache por device:

```text
~/.cache/illogical-impulse/phone/apps/<device-id>.json
```

Campos:

```json
{
  "deviceId": "...",
  "generatedAt": 0,
  "scrcpyVersion": "4.0",
  "apps": []
}
```

Cache é reconstruível.

---

# 9.4 Refresh

Fazer refresh quando:

- device muda;
- usuário puxa Refresh;
- cache não existe;
- cache é antigo;
- scrcpy version muda.

Não fazer `--list-apps` a cada abertura da page se cache válido existe.

---

# 9.5 Modelo de app

```json
{
  "name": "Firefox",
  "package": "org.mozilla.firefox",
  "system": false,
  "favorite": false,
  "recentScore": 0,
  "iconPath": ""
}
```

---

# 9.6 Ícones

## MVP

Não bloquear App Mode por ícones Android.

Fallback visual:

- MaterialShape;
- primeira letra;
- glyph `android`.

## Fase posterior opcional

Implementar `AndroidAppIconCache`:

1. `pm path <package>`;
2. pull/controlado do APK quando permitido;
3. extrair recurso de icon via ferramenta adequada;
4. converter para PNG cacheado.

Só fazer depois que App Mode estiver estável.

---

# 9.7 Favoritos e recentes

### Favoritos

```qml
Config.options.phone.scrcpy.appMode.favoritePackages
```

### Recentes

```qml
Persistent.states.phone.scrcpy.recentPackages
```

Não confundir favoritos com recência.

---

# 10. Feature 2B — scrcpy App Mode

# 10.1 Requisito

App Mode completo usa scrcpy 4.0+ para `--flex-display`.

Se versão menor:

- card ainda aparece;
- botão fica disabled;
- UI explica "Upgrade scrcpy to 4.0+".

Mirror tradicional não é desativado.

---

# 10.2 Comando base

Conceitualmente:

```bash
scrcpy \
  --new-display=1280x960/160 \
  --flex-display \
  --start-app=org.mozilla.firefox \
  --window-title=ii-phone-app-org.mozilla.firefox \
  --keep-active
```

Argumentos exatos são montados pelo serviço, não pelo QML de UI.

---

# 10.3 Configuração recomendada

Novo bloco:

```qml
phone.scrcpy.appMode: {
    enabled: true,
    flexDisplay: true,
    displayWidth: 1280,
    displayHeight: 960,
    density: 160,
    keepActive: true,
    systemDecorations: true,
    preserveAppOnClose: true,
    audioEnabled: true,
    maxConcurrentSessions: 3,
    favoritePackages: []
}
```

---

# 10.4 Preserve app on close

Por padrão recomenda-se:

```text
--no-vd-destroy-content
```

Motivo:

fechar a janela desktop não deve necessariamente matar o app Android.

Com isso, o conteúdo pode voltar ao display principal em vez de ser destruído.

Oferecer opção avançada:

```text
Close app when desktop window closes
```

Default: **off**.

---

# 10.5 System decorations

Default:

- manter decorações virtuais;
- permite comportamento Android mais previsível.

Toggle avançado:

```text
Hide virtual display system decorations
```

gera:

```text
--no-vd-system-decorations
```

Se desligar decorações e nenhum app conseguir iniciar, mostrar erro claro.

---

# 10.6 IME

Testar:

```text
--display-ime-policy=local
```

como default do App Mode.

Objetivo:

- teclado virtual/IME associado ao virtual display;
- reduzir situações em que input aparece no display principal.

Adicionar fallback se determinado OEM apresentar bug.

---

# 10.7 Uma sessão por package

Regra inicial:

```text
package já está running?
    yes → focus
    no  → launch
```

Não abrir duas instâncias do mesmo package no MVP.

Ações contextuais:

- Focus;
- Restart;
- Stop session;
- Open on phone/main display, futuro.

---

# 10.8 Limite de concorrência

Default:

```text
3 sessões App Mode
```

Quando atingir limite:

- não matar sessão antiga automaticamente;
- abrir pequeno selector "Close one session first";
- mostrar sessions ativas.

Motivo:

múltiplos encoders Android e decoders desktop consomem GPU/CPU/bateria.

---

# 10.9 Títulos de janela

Usar padrão determinístico:

```text
ii-phone-mirror
ii-phone-app-<sanitized-package>
ii-phone-camera
```

O package real deve permanecer no session model; o título pode usar versão sanitized.

---

# 10.10 Hyprland

O II deve gerenciar scrcpy como janela nativa.

### Objetivos

- float por padrão para App Mode;
- foco determinístico;
- títulos estáveis;
- tamanho inicial previsível;
- sem terminal;
- possibilidade de mover para workspace atual;
- possibilidade futura de snap ao Phone panel.

### Não fazer no primeiro rollout

- reparentar janela SDL dentro do QML;
- tentar foreign-surface embedding;
- hacks X11-only;
- depender de QtMultimedia.

---

# 10.11 Focus

`focusApp(package)`:

1. resolve `windowTitle`;
2. usa o mecanismo Hyprland já aceito pelo projeto;
3. fallback por PID/title se necessário.

Se a janela sumiu mas o process manager diz running:

- marcar sessão stale;
- tentar sync;
- não manter status "active" eternamente.

---

# 10.12 PhoneAppsPage.qml

Criar:

```text
modules/ii/sidebarPolicies/phone/PhoneAppsPage.qml
```

Layout:

```text
Header
├── Back
├── Android Apps
├── connection state
└── refresh

Search

Running
├── Firefox      [focus] [stop]
└── WhatsApp     [focus] [stop]

Favorites
└── compact horizontal/grid

All apps
├── app card
├── app card
└── ...
```

---

# 10.13 App card

Conteúdo:

- avatar/icon;
- app name;
- package pequeno opcional;
- running indicator;
- favorite;
- primary click = Launch/Focus.

States:

```text
idle
launching
running
error
unsupported
```

---

# 10.14 Search

Buscar:

- app name;
- package.

Ordenação:

1. running;
2. favorites;
3. recent;
4. alphabetical.

---

# 10.15 Ações adicionais futuras

Não incluir no MVP:

- drag app to desktop;
- pin app to dock;
- standalone `.desktop` generation;
- per-app window rules customizadas;
- app icon extraction avançada.

Mas a arquitetura não deve impedir essas extensões.

---

# 10.16 PhoneScrcpyPage

A página existente continua sendo a configuração de Mirror.

Adicionar um pequeno link:

```text
Android Apps
Open apps in independent virtual displays
[Open App Mode]
```

Não misturar a lista completa de apps dentro de `PhoneScrcpyPage.qml`.

---

# 10.17 Critérios de aceite — App Mode

- [ ] scrcpy Mirror antigo continua funcionando;
- [ ] versão < 4 não quebra Mirror;
- [ ] lista de apps aparece;
- [ ] app pode ser buscado;
- [ ] app abre em virtual display;
- [ ] resize da janela altera o virtual display via flex display;
- [ ] fechar App Mode não fecha Quickshell;
- [ ] reabrir package em execução foca a janela;
- [ ] Stop termina apenas aquela sessão;
- [ ] Stop All não mata Mirror;
- [ ] Mirror e App session podem coexistir;
- [ ] troca de active phone impede ações no device errado;
- [ ] disconnect remove/encerra status corretamente;
- [ ] sem terminal por padrão;
- [ ] nenhuma dependência de QtMultimedia;
- [ ] hot reload do Quickshell não deixa estado falso "running".

---

# 11. Feature 3 — scrcpy como backend primário de Webcam

# 11.1 Estratégia

Manter:

```text
PhoneCameraService.qml
```

como **facade estável** consumida pela UI.

Trocar o backend interno.

Novo resolver:

```text
AUTO
 ├── scrcpy camera disponível? → SCRCPY
 ├── DroidCam disponível?      → DROIDCAM
 └── unavailable
```

---

# 11.2 API pública preservada

Manter o máximo possível:

```qml
property bool running
property bool connecting
property string videoDevice
property string lastError
property int elapsedMs

function startCamera()
function stopCamera()
function toggleCamera()
function flipCamera()
function toggleMirror()
function setRotation(...)
function openExternalPreview()
```

Adicionar:

```qml
property string activeBackend: ""  // "scrcpy" | "droidcam"
property bool scrcpyBackendAvailable: false
property bool droidcamBackendAvailable: false
property int androidApiLevel: -1
property var cameras: []
property bool camerasLoading: false
```

Isso reduz alterações em:

- Phone.qml;
- PhoneFooter.qml;
- PhoneWebcamPage.qml.

---

# 11.3 Backend selection

Config:

```qml
Config.options.phone.webcam.backend
```

Valores:

```text
auto
scrcpy
droidcam
```

### auto

1. scrcpy instalado;
2. ADB reachable;
3. Android API >= 31;
4. v4l2loopback disponível;
5. então scrcpy.

Caso contrário DroidCam.

### scrcpy

Não cair silenciosamente para DroidCam.

Se incompatível:

- erro claro;
- botão para voltar a Auto.

### droidcam

Manter comportamento legado.

---

# 11.4 V4L2 sink

scrcpy precisa de um dispositivo v4l2loopback.

Objetivo:

```text
/dev/videoN
label: ii Phone Camera
```

---

# 11.5 Device management

Preferência:

1. procurar um loopback existente com label do II;
2. se não existir e `v4l2loopback-ctl` suportar dynamic add, criar um device dedicado;
3. se dynamic add não estiver disponível, usar fallback com módulo existente;
4. nunca sobrescrever webcam física.

Nome sugerido:

```text
ii Phone Camera
```

---

# 11.6 Helper V4L2

Criar:

```text
scripts/phone/v4l2_phone_camera.sh
```

ou Python se o lifecycle ficar complexo.

Comandos lógicos:

```text
ensure
find
delete-owned
status
```

O helper deve retornar saída estruturada simples:

```json
{"ok":true,"device":"/dev/video10","owned":true}
```

---

# 11.7 Ownership

O II deve distinguir:

```text
ownedByII = true
```

vs

```text
existingExternalLoopback = true
```

No stop:

- não deletar dispositivo que não foi criado pelo II;
- não descarregar `v4l2loopback` globalmente se outros apps usam o módulo.

---

# 11.8 Launch command — scrcpy camera

Conceitualmente:

```bash
scrcpy \
  --video-source=camera \
  --camera-facing=front \
  --camera-size=1920x1080 \
  --camera-fps=30 \
  --v4l2-sink=/dev/video10 \
  --no-playback \
  --no-audio
```

O serviço deve montar os argumentos como array.

---

# 11.9 Áudio

Webcam backend deve iniciar com:

```text
--no-audio
```

Motivo:

Phone Microphone já possui pipeline separado.

Não misturar:

```text
camera + mic virtual source
```

no primeiro rollout.

Usuário poderá ativar Camera e Phone Microphone independentemente.

---

# 11.10 Camera listing

Quando scrcpy backend estiver disponível:

```bash
scrcpy --list-cameras
scrcpy --list-camera-sizes
```

Carregar somente sob demanda ou ao abrir Webcam page.

Não fazer isso a cada boot.

---

# 11.11 Camera ID

Config:

```qml
phone.webcam.cameraId: ""
```

Se vazio:

```text
cameraFacing
```

é usado.

Se `cameraId` não vazio:

- não enviar `--camera-facing`;
- enviar `--camera-id`.

A UI deve evitar criar combinação inválida.

---

# 11.12 Facing

UI:

```text
Auto
Front
Back
External
```

No MVP pode manter somente:

```text
Front
Back
```

mas modelo do service deve aceitar `external`.

---

# 11.13 Resolution

Primeiro rollout:

```text
Auto
720p
1080p
```

Não assumir que toda câmera suporta exatamente 1920x1080.

Se scrcpy falhar:

- mostrar erro do encoder/camera;
- oferecer Auto;
- opcionalmente tentar downsize controlado.

---

# 11.14 FPS

Adicionar:

```text
Default / 30 / 60
```

Somente enviar `--camera-fps` quando diferente de Default.

Não assumir 60 fps.

---

# 11.15 Mirror

Preferir server/capture transform quando compatível.

Config existente:

```qml
mirrorHorizontally
```

Mapear para capture orientation/transform apropriado depois de validar comportamento com V4L2.

Não usar `v4l2-ctl horizontal_flip` como caminho primário para scrcpy, pois o loopback em si pode não oferecer esse control.

---

# 11.16 Rotation

A rotação precisa ser validada especificamente no caminho V4L2.

Planejar:

- usar transformação de captura suportada pelo scrcpy;
- testar 0/90/180/270;
- não declarar UI como funcional até verificar resultado em OBS/Meet.

Se determinada combinação não for possível no V4L2:

- esconder/desabilitar a opção apenas no backend scrcpy;
- preservar opção no DroidCam fallback se ele suportar.

---

# 11.17 Torch e Zoom

scrcpy suporta esses controles.

Adicionar somente depois do backend básico funcionar.

Possíveis Config fields:

```qml
phone.webcam.torch
phone.webcam.zoom
```

Não são requisitos do primeiro merge.

---

# 11.18 Preview

`openExternalPreview()` permanece.

Prioridade:

```text
mpv
ffplay
vlc
```

Preview usa:

```text
/dev/videoN
```

Não usar QtMultimedia.

---

# 11.19 PhoneWebcamPage migration

Alterações:

### Header
Mostrar backend:

```text
Active · scrcpy
```

ou:

```text
Active · DroidCam fallback
```

### Warning
Trocar:

```text
"DroidCam is not installed"
```

por:

```text
"Phone camera backend is unavailable"
```

e detalhar dependência faltante.

### Backend selector

Adicionar:

```text
Backend
[ Auto ] [ scrcpy ] [ DroidCam ]
```

### Connection

Quando backend = scrcpy:

- usar ADB transport compartilhado;
- não mostrar DroidCam port 4747;
- link para scrcpy/Wireless ADB settings.

Quando backend = droidcam:

- mostrar Wi-Fi/USB legado;
- IP;
- port.

---

# 11.20 PhoneFooter migration

Hoje o card usa disponibilidade DroidCam.

Mudar sem renomear semanticamente o card:

```text
Phone Webcam
```

### Subtitle examples

scrcpy:

```text
scrcpy · /dev/video10
```

DroidCam:

```text
DroidCam fallback · /dev/video2
```

Unavailable:

```text
scrcpy camera unavailable · DroidCam not installed
```

---

# 11.21 DroidCam fallback

Não deletar imediatamente:

- `droidcam-cli`;
- install helper;
- legacy config;
- código de conexão.

Primeiro rollout deve provar scrcpy em múltiplos aparelhos.

Depois de estabilidade:

- manter DroidCam oficialmente como fallback;
- simplificar código duplicado em funções privadas.

---

# 11.22 Backend implementation structure

Dentro de `PhoneCameraService.qml`:

```qml
function _selectBackend(): string
function _startScrcpyCamera(): void
function _startDroidCam(): void
function _stopScrcpyCamera(): void
function _stopDroidCam(): void
```

Evitar um único `startCamera()` com centenas de linhas de `if`.

---

# 11.23 Critérios de aceite — Webcam

- [ ] Android 12+ usa scrcpy em Auto;
- [ ] Android < 12 cai para DroidCam se disponível;
- [ ] backend manual é respeitado;
- [ ] OBS detecta `ii Phone Camera`;
- [ ] Discord/Chromium detectam o V4L2 device;
- [ ] camera para corretamente;
- [ ] device V4L2 externo nunca é deletado;
- [ ] Quickshell reload não deixa status quebrado;
- [ ] camera e mic podem coexistir;
- [ ] camera e mirror têm conflito tratado corretamente se o aparelho não suportar múltiplos encoders;
- [ ] front/back funciona em aparelhos suportados;
- [ ] resolução inválida gera erro claro;
- [ ] sem QtMultimedia;
- [ ] DroidCam permanece utilizável.

---

# 12. Concorrência entre sessões scrcpy

Esta área precisa ser explicitamente testada.

Possíveis sessões simultâneas:

```text
Mirror
App Mode Firefox
App Mode WhatsApp
Camera
Microphone
```

Cada uma pode iniciar encoder/audio/camera distinto no aparelho.

---

## 12.1 Política inicial

Não proibir globalmente múltiplas sessões.

Mas detectar conflitos.

### Exemplo

Se `PhoneCameraService` falhar porque o encoder está ocupado:

- não matar Mirror automaticamente;
- explicar:
  - "Camera could not start while another scrcpy video session is active";
- oferecer ação manual:
  - Stop Mirror and retry.

---

## 12.2 Microfone

O mic scrcpy já é separado.

Se o aparelho não permitir camera + mic em duas sessões:

- documentar;
- considerar futuramente capturar camera + mic numa única sessão;
- não acoplar isso no primeiro merge.

---

# 13. Config.qml — schema proposto

Exemplo conceitual:

```qml
phone: {
    kdeconnectEnabled: true,
    showPeripheralCards: true,

    contacts: {
        enabled: true,
        showShortcut: true,
        showAvatars: true,
        sortMode: "firstName",
        favoriteIds: []
    },

    scrcpy: {
        // manter campos existentes

        appMode: {
            enabled: true,
            flexDisplay: true,
            width: 1280,
            height: 960,
            density: 160,
            keepActive: true,
            systemDecorations: true,
            preserveAppOnClose: true,
            audioEnabled: true,
            maxConcurrentSessions: 3,
            favoritePackages: []
        }
    },

    webcam: {
        backend: "auto",

        cameraId: "",
        cameraFacing: "front",
        resolution: "1920x1080",
        fps: 30,
        mirrorHorizontally: true,
        rotateDegrees: 0,

        v4l2Device: "",
        v4l2Buffer: 0,

        droidcam: {
            connection: "wifi",
            wifiIp: "",
            port: 4747
        }
    }
}
```

---

# 14. Migração de config existente

Não assumir que todos terão config novo.

Durante load:

### Webcam

Config antiga:

```text
phone.webcam.connection
phone.webcam.wifiIp
phone.webcam.port
```

Nova:

```text
phone.webcam.droidcam.*
```

Estratégia:

- ler campo novo se existe;
- fallback para campo legado;
- gravar novo somente quando usuário alterar settings;
- depois de uma ou duas versões, remover fallback legado.

Evitar migração destrutiva no primeiro rollout.

---

# 15. Dependências

Arquivo:

```text
sdata/dist-arch/illogical-impulse-phone/PKGBUILD
```

## Alterar

### scrcpy

Transformar a expectativa em:

```text
scrcpy >= 4.0
```

para App Mode completo.

### android-tools
Continuar obrigatório.

### v4l-utils
Continuar disponível para V4L2 inspection.

### v4l2loopback
Continua requisito da **webcam**, mas não do Phone module inteiro.

Pode permanecer optdepend se UI possui dependency guide por feature.

### DroidCam
Explicitamente fallback.

Descrição do pacote deve deixar de apresentar DroidCam como backend principal da câmera.

---

# 16. Dependency Guide

Atualizar `InstallGuidePopup` / descriptors.

## App Mode

Dependências:

```text
scrcpy >= 4.0
adb/android-tools
```

## Contacts

```text
KDE Connect
Contact Sync enabled on phone
```

Sem dependência Python extra além do stack já usado por Gio/PyGObject.

## Webcam scrcpy

```text
scrcpy
android-tools
Android 12+
v4l2loopback
v4l-utils
```

## Webcam DroidCam fallback

```text
droidcam-cli
DroidCam Android app
v4l2loopback
```

---

# 17. Settings redesign mínimo

Em `DevicesPhoneConfig.qml`:

```text
Phone & scrcpy Integration
├── Enable KDE Connect Service
├── Show peripheral cards
├── Contacts
│   ├── Enabled
│   └── Show avatars
├── scrcpy
│   └── Open scrcpy settings
└── Webcam
    └── Backend: Auto / scrcpy / DroidCam
```

Configurações avançadas permanecem nas subpages.

Evitar transformar `DevicesPhoneConfig` em uma página gigante.

---

# 18. Novos arquivos

## Services

```text
dots/.config/quickshell/ii/services/PhoneContactsService.qml
dots/.config/quickshell/ii/services/PhoneScrcpyService.qml
```

## Phone UI

```text
dots/.config/quickshell/ii/modules/ii/sidebarPolicies/phone/PhoneNavigationCards.qml
dots/.config/quickshell/ii/modules/ii/sidebarPolicies/phone/PhoneContactsPage.qml
dots/.config/quickshell/ii/modules/ii/sidebarPolicies/phone/PhoneAppsPage.qml
```

## Scripts

```text
dots/.config/quickshell/ii/scripts/kdeconnect/contacts_monitor.py
dots/.config/quickshell/ii/scripts/phone/scrcpy_session_manager.py
dots/.config/quickshell/ii/scripts/phone/v4l2_phone_camera.sh
```

O helper V4L2 pode ser Python se a lógica crescer; começar Bash é aceitável se ele permanecer pequeno e determinístico.

---

# 19. Arquivos existentes a alterar

```text
dots/.config/quickshell/ii/services/KdeConnectService.qml
dots/.config/quickshell/ii/services/PhoneCameraService.qml

dots/.config/quickshell/ii/modules/common/Config.qml
dots/.config/quickshell/ii/modules/common/Persistent.qml
dots/.config/quickshell/ii/GlobalStates.qml              # somente se realmente necessário

dots/.config/quickshell/ii/modules/ii/sidebarPolicies/phone/Phone.qml
dots/.config/quickshell/ii/modules/ii/sidebarPolicies/phone/PhoneFooter.qml
dots/.config/quickshell/ii/modules/ii/sidebarPolicies/phone/PhoneScrcpyPage.qml
dots/.config/quickshell/ii/modules/ii/sidebarPolicies/phone/PhoneWebcamPage.qml

dots/.config/quickshell/ii/modules/ii/bar/widgets/indicators/PhoneScrcpyIndicator.qml

dots/.config/quickshell/ii/modules/settings/configs/DevicesPhoneConfig.qml
dots/.config/quickshell/ii/modules/settings/configs/widgets/KdeConnectConfig.qml

sdata/dist-arch/illogical-impulse-phone/PKGBUILD

dots/.config/quickshell/ii/translations/en_US.json
dots/.config/quickshell/ii/translations/pt_BR.json
dots/.config/quickshell/ii/translations/es_MX.json

AGENTS.md
```

---

# 20. Responsabilidade final por arquivo

## KdeConnectService.qml

Deve terminar responsável por:

- KDE Connect daemon;
- device selection;
- connectivity;
- notifications;
- pairing;
- ADB connectivity;
- resolved wireless target;
- ações Android genéricas.

Não deve continuar sendo o session manager do scrcpy.

---

## PhoneScrcpyService.qml

Responsável por:

- scrcpy binary/version;
- capability detection relacionada a scrcpy;
- Mirror session;
- App Mode sessions;
- app catalog;
- lifecycle;
- focus;
- scrcpy process errors.

---

## PhoneContactsService.qml

Responsável por:

- monitor helper;
- contacts list;
- search;
- favorites projection;
- contact actions.

---

## PhoneCameraService.qml

Responsável por:

- webcam abstraction;
- backend resolver;
- V4L2 device;
- scrcpy camera;
- DroidCam fallback;
- camera state.

---

## PhoneMicService.qml

Sem refactor obrigatório neste escopo.

Somente ajustar se existir código duplicado de scrcpy target que possa consumir helper novo.

---

# 21. IPC / Debug endpoints

Adicionar handlers simples.

## contacts

```text
qs ipc call phoneContacts status
qs ipc call phoneContacts refresh
```

`status`:

```json
{
  "ready": true,
  "count": 412,
  "source": "...",
  "deviceId": "..."
}
```

Sem listar telefones.

---

## scrcpy

```text
qs ipc call phoneScrcpy status
qs ipc call phoneScrcpy sessions
qs ipc call phoneScrcpy refreshApps
```

---

## camera

```text
qs ipc call phoneCamera status
```

Retorno:

```json
{
  "backend":"scrcpy",
  "running":true,
  "device":"/dev/video10",
  "androidApi":35
}
```

---

# 22. Logging

Prefixos:

```text
[PhoneContactsService]
[PhoneScrcpyService]
[PhoneCameraService]
[ScrcpySessionManager]
```

Logs devem priorizar:

- state transition;
- error;
- backend selection;
- device ID truncado se necessário;
- package name é aceitável;
- não logar conteúdo de contatos.

---

# 23. Performance

## Contacts

- `ListView`;
- snapshot JSON apenas quando arquivo muda;
- debounce;
- avatar cache;
- nenhuma foto base64 em binding QML.

## Apps

- cache por device;
- não rodar `--list-apps` a toda abertura;
- delegates lazy;
- limitar sessões simultâneas.

## Camera

- sem preview QML;
- `--no-playback`;
- V4L2 direto;
- preview externo só quando solicitado.

---

# 24. Hot reload e recuperação

## Contacts

Quando QML recarregar:

- helper reinicia;
- snapshot é reconstruído;
- nenhum estado crítico perdido.

## App Mode

scrcpy windows podem sobreviver ao reload dependendo do supervisor/lifecycle.

Decidir explicitamente:

### Recomendação
Session manager é filho do Quickshell e termina junto dele.

No reload:

- processos scrcpy previamente iniciados podem terminar;
- service volta a estado limpo.

Se no futuro quisermos sessões sobreviverem a reload:
- transformar supervisor em processo externo persistente;
- fora do escopo atual.

## Camera

No reload:

- se processo camera morreu, marcar false;
- V4L2 owned device pode permanecer;
- cleanup deve ser idempotente.

---

# 25. Error model

Evitar um único `lastError = "unknown"`.

Categorias:

```text
missing_dependency
adb_unreachable
unsupported_scrcpy_version
unsupported_android_version
no_contact_source
contacts_parse_error
app_catalog_error
session_limit
scrcpy_launch_failed
camera_list_failed
camera_encoder_failed
v4l2_unavailable
v4l2_create_failed
droidcam_unavailable
device_disconnected
```

UI traduz categoria para mensagem amigável.

Detalhe bruto pode ir somente ao log.

---

# 26. Testes manuais — matriz mínima

## Devices

Testar pelo menos:

```text
Android 12+
Android 14/15+
USB ADB
Wireless ADB
KDE Connect online
KDE Connect offline
```

Se possível:

```text
Android < 12
```

para verificar DroidCam fallback.

---

# 27. Testes — Contacts

1. abrir Phone;
2. abrir Contacts;
3. verificar count;
4. buscar nome;
5. buscar telefone;
6. adicionar favorito;
7. fechar/reabrir;
8. editar contato no celular;
9. verificar update;
10. criar contato;
11. deletar contato;
12. trocar device ativo;
13. desconectar KDE Connect;
14. reload Quickshell durante sync.

---

# 28. Testes — App Mode

1. `scrcpy 4.x`;
2. refresh apps;
3. abrir Firefox;
4. resize;
5. abrir segundo app;
6. focus app 1;
7. close app 2;
8. reabrir package já ativo;
9. testar session limit;
10. disconnect phone;
11. reconnect;
12. Wireless ADB;
13. USB ADB;
14. Mirror + App Mode;
15. Quickshell hot reload.

---

# 29. Testes — Webcam

Aplicações:

```text
OBS
Chromium/Meet
Discord
mpv preview
```

Cenários:

```text
front 720p
front 1080p
back 1080p
30 fps
60 fps se suportado
mirror
rotation
USB
wireless
camera + mic
camera + mirror
DroidCam forced
Auto fallback
```

---

# 30. Critério de regressão

Nenhuma feature nova pode quebrar:

- KDE Connect notifications;
- clipboard;
- send files;
- SFTP;
- LocalSend;
- Mirror atual;
- Phone Mic;
- sidebar detach;
- Phone page entrance animations;
- dependency guide.

---

# 31. Traduções

Todas as strings novas devem entrar em:

```text
translations/en_US.json
translations/pt_BR.json
translations/es_MX.json
```

Categorias:

```text
Contacts
No contacts synced yet
Search contacts
Favorites
Open dialer
Compose SMS
Android Apps
Running apps
Launch app
Focus app
Stop app
Stop all
Requires scrcpy 4.0 or newer
Phone Webcam
Backend
Automatic
scrcpy
DroidCam fallback
Android 12 or newer is required
Virtual camera
```

Seguir regras de `.arg(String(...))` documentadas no projeto.

---

# 32. Atualização do AGENTS.md

Ao concluir cada feature arquitetural, adicionar seção.

Sugestão:

```text
## Módulos Especiais: Phone Contacts (KDE Connect VCard Bridge)

### O Problema
...

### A Solução
...

### Arquivos Envolvidos
...
```

```text
## Módulos Especiais: scrcpy App Mode (Virtual/Flex Displays)

### O Problema
...

### A Solução
...

### Session Architecture
...

### Arquivos Envolvidos
...
```

```text
## Módulos Especiais: Phone Webcam Backend Resolver (scrcpy + DroidCam)

### O Problema
...

### A Solução
...

### Backend Selection
...

### Arquivos Envolvidos
...
```

Atualizar também o sumário do AGENTS.

---

# 33. Estratégia de commits

Evitar um mega-commit.

## Commit 1

```text
feat(phone): add contacts backend service
```

- monitor;
- parser;
- service;
- sem UI grande.

## Commit 2

```text
feat(phone): add contacts page and navigation
```

## Commit 3

```text
refactor(phone): extract scrcpy session service
```

Mirror deve continuar 100% funcional aqui.

## Commit 4

```text
feat(phone): add Android app catalog
```

## Commit 5

```text
feat(phone): add scrcpy virtual app mode
```

## Commit 6

```text
feat(phone): manage scrcpy app windows on Hyprland
```

## Commit 7

```text
refactor(phone): add scrcpy primary webcam backend
```

## Commit 8

```text
feat(phone): keep DroidCam as automatic webcam fallback
```

## Commit 9

```text
docs(phone): document contacts, app mode and webcam architecture
```

---

# 34. Gate entre fases

Não avançar App Mode antes de:

- Mirror continuar estável após extração do service.

Não migrar Webcam antes de:

- `PhoneScrcpyService` resolver ADB target corretamente;
- capability checks estarem confiáveis.

Não remover DroidCam antes de:

- scrcpy camera passar testes reais em múltiplos dispositivos.

---

# 35. Definição de pronto — projeto completo

O projeto pode ser considerado concluído quando:

## Contacts
- [ ] lista real sincronizada pelo KDE Connect;
- [ ] search;
- [ ] favorites;
- [ ] detail/action UI;
- [ ] live filesystem updates;
- [ ] troca de device.

## App Mode
- [ ] app catalog;
- [ ] search;
- [ ] favorites/recent;
- [ ] virtual flex display;
- [ ] sessões;
- [ ] focus/stop;
- [ ] limit;
- [ ] Hyprland window identity.

## Webcam
- [ ] scrcpy primary em Android 12+;
- [ ] V4L2;
- [ ] OBS/Meet/Discord;
- [ ] backend Auto;
- [ ] DroidCam fallback;
- [ ] UI backend-aware.

## Arquitetura
- [ ] KdeConnectService não gerencia mais scrcpy sessions;
- [ ] nenhum QtMultimedia;
- [ ] sem polling contínuo desnecessário;
- [ ] config migration;
- [ ] dependency guide;
- [ ] translations;
- [ ] AGENTS atualizado.

---

# 36. Itens explicitamente fora do escopo

Não implementar junto deste plano:

- áudio de chamadas telefônicas;
- Bluetooth HFP;
- histórico de chamadas;
- ii Companion Android;
- Phone Link-style SMS rewrite;
- Gallery/Recent Photos;
- embedding real da janela SDL no QML;
- protocolo interno do scrcpy;
- geração de `.desktop` por app Android;
- Android app icon extraction avançada;
- calendário Android.

Esses itens podem ser fases futuras sem alterar a arquitetura proposta.

---

# 37. Riscos conhecidos

## R1 — OEMs Android

Virtual displays e input podem variar.

Mitigação:

- capability/error reporting;
- não esconder stderr;
- fallback para Mirror normal.

## R2 — múltiplos encoders

Alguns aparelhos limitam sessões simultâneas.

Mitigação:

- session limit;
- erro claro;
- não matar sessão automaticamente.

## R3 — V4L2 / Secure Boot / DKMS

`v4l2loopback` pode falhar por Secure Boot ou kernel update.

Mitigação:

- dependency guide;
- diagnóstico separado;
- DroidCam não resolve ausência do próprio loopback se também depender dele.

## R4 — Contacts incompletos

KDE Connect Contact Sync pode estar desabilitado ou com permission negada.

Mitigação:

- empty state específico;
- não classificar imediatamente como parser failure.

## R5 — app list lento

`--list-apps` pode levar segundos.

Mitigação:

- cache;
- refresh explícito;
- loading state assíncrono.

---

# 38. Resultado esperado

Ao final, o Phone do II deixa de ser apenas:

```text
notifications + mirror + webcam + mic
```

e passa a ter:

```text
Phone Hub
├── device status
├── quick KDE Connect actions
├── Contacts
├── Android Apps
│   ├── favorites
│   ├── recent
│   └── flex virtual windows
├── notifications
├── scrcpy Mirror
├── Phone Webcam
│   ├── scrcpy primary
│   └── DroidCam fallback
└── Phone Microphone
```

Mantendo:

- Quickshell como UI/orchestrator;
- Hyprland como window manager;
- KDE Connect como device/data backbone;
- ADB como Android control channel;
- scrcpy como media/display backend;
- PipeWire/V4L2 como integração de áudio/vídeo do Linux.

---

# 39. Referências técnicas utilizadas no planejamento

## scrcpy oficial

- Virtual display / flex display:  
  https://github.com/Genymobile/scrcpy/blob/master/doc/virtual-display.md

- Start apps / list apps:  
  https://github.com/Genymobile/scrcpy/blob/master/doc/device.md

- Camera source:  
  https://github.com/Genymobile/scrcpy/blob/master/doc/camera.md

- Video / V4L2:  
  https://github.com/Genymobile/scrcpy/blob/master/doc/video.md

- Window controls:  
  https://github.com/Genymobile/scrcpy/blob/master/doc/window.md

- scrcpy repository / current feature overview:  
  https://github.com/Genymobile/scrcpy

## KDE Connect

- Contacts synchronization / VCard location:  
  https://userbase.kde.org/KDEConnect/en

## V4L2 Loopback

- Dynamic devices / module options:  
  https://github.com/v4l2loopback/v4l2loopback

---

# 40. Próximo passo recomendado

Implementar primeiro:

```text
Fase 0
↓
PhoneContactsService
↓
PhoneContactsPage
```

e só depois iniciar o refactor de scrcpy.

Isso entrega uma feature funcional independente rapidamente e reduz o risco de misturar três mudanças grandes ao mesmo tempo.

Depois:

```text
extract PhoneScrcpyService
↓
prove Mirror regression-free
↓
App catalog
↓
App Mode
↓
scrcpy webcam
↓
DroidCam fallback validation
```

Esse encadeamento mantém o branch `dev` utilizável em cada etapa e permite testar regressões antes de avançar para a próxima camada.
