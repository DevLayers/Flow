# Google Drive Auto Backup — Integração para o II Settings

Feature de auto-backup para o Google Drive, com design rico em cards, gráficos de uso, e elementos diversificados — minimizando o uso de `ConfigSwitch`.

## User Review Required

> [!IMPORTANT]
> Esta feature requer um **Google Cloud Project com a API do Google Drive habilitada**. As credenciais de OAuth2 (Client ID + Client Secret) serão reutilizadas do mesmo projeto usado para o Gmail (já existente em `.env`), mas com escopo adicional `https://www.googleapis.com/auth/drive.file`.

> [!WARNING]
> **Dependência externa**: O backend de sincronização usa `rclone` (https://rclone.org/), que é a forma mais robusta e testada de interagir com Google Drive em Linux via CLI. `rclone` deve ser instalado no sistema (`pacman -S rclone`).

## Open Questions

> [!IMPORTANT]
> 1. **rclone vs API direta**: O plano usa `rclone` como backend de sync (amplamente adotado, suporta resumable uploads, delta sync, bandwidth limiting). Uma alternativa seria usar a API REST do Drive diretamente via Python, mas isso seria muito mais complexo e frágil. Prefere `rclone`?
> 2. **Escopo de backup**: O plano assume que o usuário configura **pastas locais arbitrárias** para backup (ex: `~/Documents`, `~/Pictures`, `~/.config`). Deseja incluir templates pré-definidos (ex: "Backup configs do Hyprland", "Backup wallpapers")?
> 3. **Localização no Settings**: O plano coloca a feature como seção **dentro do TasksAccountsConfig.qml** (expandindo a página existente). Alternativamente, poderia ser uma **página separada** no Settings. Qual prefere?

---

## Proposed Changes

A implementação é dividida em 4 camadas: **Config (persistência)**, **Service (lógica)**, **Scripts (backend)**, **UI (settings page)**.

---

### 1. Config — Persistência no `Config.qml`

Adicionar um novo `JsonObject` `googleDrive` dentro do bloco `options` do [Config.qml](file:///home/pedro/Downloads/ii-vynx/dots/.config/quickshell/ii/modules/common/Config.qml), seguindo o mesmo padrão de tipagem segura (`list<string>` nunca `list<var>`).

#### [MODIFY] [Config.qml](file:///home/pedro/Downloads/ii-vynx/dots/.config/quickshell/ii/modules/common/Config.qml)

Nova seção `googleDrive` no `JsonObject options`:

```qml
property JsonObject googleDrive: JsonObject {
    // Master toggle
    property bool enabled: false
    
    // Sync schedule
    property string syncInterval: "1h"          // "15m", "30m", "1h", "3h", "6h", "12h", "24h", "manual"
    property bool syncOnBoot: true               // Run backup on shell startup
    property bool syncOnNetworkChange: false      // Re-sync when network connects
    
    // Bandwidth
    property int bandwidthLimitKbps: 0            // 0 = unlimited
    property bool pauseOnMeteredConnection: true
    
    // Backup folders (user-configured list of local paths)
    property list<string> backupFolders: []
    
    // Exclusions (glob patterns)
    property list<string> excludePatterns: ["*.tmp", "*.swp", "*.lock", "node_modules/", ".git/", "__pycache__/"]
    
    // Drive destination
    property string driveBasePath: "ii-backup"    // Remote folder name on Drive
    
    // Notifications
    property bool notifyOnComplete: true
    property bool notifyOnError: true
    
    // History
    property int keepVersions: 3                  // Number of versions to keep (rclone --backup-dir)
    property bool deleteRemoteOrphans: false       // Delete files on Drive that no longer exist locally
    
    // Stats (read by UI, written by service)
    property string lastSyncTime: ""
    property string lastSyncStatus: ""            // "success", "error", "running", "never"
    property int lastSyncFileCount: 0
    property real lastSyncSizeMb: 0.0
    property real totalDriveUsageMb: 0.0
    property real driveQuotaMb: 0.0
}
```

---

### 2. Service — `GoogleDriveService.qml`

Singleton que gerencia a lógica de sincronização, agenda timer, e expõe estado reativo.

#### [NEW] [GoogleDriveService.qml](file:///home/pedro/Downloads/ii-vynx/dots/.config/quickshell/ii/services/GoogleDriveService.qml)

**Responsabilidades:**
- Verificar se `rclone` está instalado
- Configurar o remote `rclone` para Google Drive via OAuth2 (reutilizando credentials do `.env` ou Keyring)
- Agendar backups via `Timer` QML baseado em `syncInterval`
- Executar `rclone sync` via `Process` com output parsing
- Expor propriedades reativas: `syncing`, `progress`, `lastSyncTime`, `errorMessage`, `driveUsage`
- Expor histórico de syncs recentes como `ListModel` para o gráfico de atividade
- Calcular estatísticas de uso do Drive via `rclone about`

**Propriedades principais:**
```qml
// State
property bool rcloneInstalled: false
property bool configured: false
property bool syncing: false
property real progress: 0.0               // 0.0-1.0 durante sync
property string currentFile: ""            // Arquivo sendo transferido
property int filesTransferred: 0
property int filesTotal: 0
property real bytesTransferred: 0.0
property real bytesTotal: 0.0
property string errorMessage: ""

// Drive info
property real driveUsedMb: 0.0
property real driveQuotaMb: 15360.0        // 15GB free
property real driveBackupUsageMb: 0.0

// History (últimas 7 syncs para gráfico de atividade)  
property list<var> syncHistory: []         // [{time, fileCount, sizeMb, status}]

// Functions
function startSync() { ... }
function cancelSync() { ... }
function setupRclone() { ... }              // Configura o remote
function checkRclone() { ... }             // Verifica instalação
function fetchDriveInfo() { ... }          // rclone about
function addBackupFolder(path) { ... }
function removeBackupFolder(index) { ... }
```

**Timer de agendamento:**
```qml
Timer {
    id: syncTimer
    interval: {
        const map = {"15m": 900000, "30m": 1800000, "1h": 3600000, "3h": 10800000, 
                      "6h": 21600000, "12h": 43200000, "24h": 86400000};
        return map[Config.options.googleDrive.syncInterval] || 3600000;
    }
    repeat: true
    running: Config.options.googleDrive.enabled && Config.options.googleDrive.syncInterval !== "manual"
    onTriggered: startSync()
}
```

---

### 3. Scripts — Backend Python/Bash

#### [NEW] `scripts/gdrive/` — Diretório de scripts

##### [NEW] [setup_rclone.py](file:///home/pedro/Downloads/ii-vynx/dots/.config/quickshell/ii/scripts/gdrive/setup_rclone.py)
- Recebe `client_id`, `client_secret` como argumentos
- Configura o remote `rclone` chamado `ii-gdrive` com tipo `drive`
- Abre browser para OAuth2 consent via `rclone authorize "drive"`
- Retorna `"OK"` ou `"ERROR: <msg>"` no stdout

##### [NEW] [sync.sh](file:///home/pedro/Downloads/ii-vynx/dots/.config/quickshell/ii/scripts/gdrive/sync.sh)
- Wrapper para `rclone sync` com:
  - `--progress --stats-one-line-date --stats 2s` (para parsing de progresso)
  - `--exclude-from` gerado dos patterns de exclusão
  - `--bwlimit` se configurado
  - `--backup-dir` para versionamento
  - `--log-file` para persistência de logs
- Output estruturado (JSON por linha) para o QML parsear progresso em tempo real

##### [NEW] [drive_info.py](file:///home/pedro/Downloads/ii-vynx/dots/.config/quickshell/ii/scripts/gdrive/drive_info.py)
- Executa `rclone about ii-gdrive: --json`
- Executa `rclone size ii-gdrive:<driveBasePath> --json`
- Retorna JSON com `{total, used, free, backupSize}`

##### [NEW] [check_rclone.sh](file:///home/pedro/Downloads/ii-vynx/dots/.config/quickshell/ii/scripts/gdrive/check_rclone.sh)
- Verifica se `rclone` está no PATH
- Verifica se o remote `ii-gdrive` existe
- Retorna JSON `{installed: bool, configured: bool, version: string}`

---

### 4. UI — Página de Settings (Redesign do TasksAccountsConfig)

A seção Google Drive no `TasksAccountsConfig.qml` terá um design **rico em cards, gráficos e elementos variados**, evitando excesso de `ConfigSwitch`.

#### [MODIFY] [TasksAccountsConfig.qml](file:///home/pedro/Downloads/ii-vynx/dots/.config/quickshell/ii/modules/settings/configs/TasksAccountsConfig.qml)

**Layout proposto (de cima para baixo):**

---

##### Card 1 — **Drive Status Hero Card** (estilo `HeroCard` do WeatherPopup)
Um card grande no topo mostrando o status geral, inspirado no card hero do popup de clima.

```
┌────────────────────────────────────────────────────────────────┐
│  ☁ [MaterialShape Cookie]    [Pill: "Connected" / "Setup"]    │
│                                                                │
│  Google Drive Backup                                           │
│  Last sync: 2h ago · 142 files · 3.2 GB                       │
│                                                                │
│  ┌─────────────────────────────────────────────────┐          │
│  │  [==============================            ]   │          │
│  │  8.2 GB / 15 GB used                            │          │
│  └─────────────────────────────────────────────────┘          │
│                                                                │
│  [  ▶ Sync Now  ]        [  ⚙ Configure  ]                   │
└────────────────────────────────────────────────────────────────┘
```

**Elementos usados:** `MaterialShape` (ícone decorativo com shape Cookie9Sided + `cloud_sync`), `StyledText`, `StyledProgressBar` (usage bar), pills de status, `RippleButton` para ações.

**Cor de fundo:** `colSecondaryContainer` (como o HeroCard), com `colOnSecondaryContainer` para textos.

---

##### Card 2 — **Sync Activity Graph** (estilo metrics)
Card com mini gráfico `Graph` sparkline mostrando atividade dos últimos 7 backups.

```
┌────────────────────────────────────────────────────────────────┐
│  📊 Sync Activity                               Last 7 syncs  │
│  ┌─────────────────────────────────────────────────┐          │
│  │         ╱\      ╱\                               │          │
│  │    ╱\  ╱  \    ╱  \  ╱\                          │          │
│  │ ╱ ╱  \/    \  ╱    \/  \                         │          │
│  │╱╱         \╱╱                                    │          │
│  └─────────────────────────────────────────────────┘          │
│  ─ Mon ─ Tue ─ Wed ─ Thu ─ Fri ─ Sat ─ Sun ─                 │
│                                                                │
│  ┌──────┐  ┌──────┐  ┌──────┐                                │
│  │ 142  │  │ 3.2  │  │ 0    │                                │
│  │ files│  │ GB   │  │ errors│                                │
│  └──────┘  └──────┘  └──────┘                                │
└────────────────────────────────────────────────────────────────┘
```

**Elementos usados:** `Graph` (sparkline), `StyledText` para métricas individuais em mini-cards (retângulos com `colLayer2`).

---

##### Card 3 — **Backup Folders** (lista interativa com drag/add/remove)
Card com lista de pastas de backup, usando `ConfigListView` ou `StyledListView` com delegates ricos.

```
┌────────────────────────────────────────────────────────────────┐
│  📁 Backup Folders                        [ + Add Folder ]    │
│                                                                │
│  ┌───────────────────────────────────────────────────────┐    │
│  │  📄 ~/Documents              23.1 MB    [  ✕  ]      │    │
│  ├───────────────────────────────────────────────────────┤    │
│  │  🖼 ~/Pictures              156.8 MB    [  ✕  ]      │    │
│  ├───────────────────────────────────────────────────────┤    │
│  │  ⚙ ~/.config/quickshell/ii    4.2 MB   [  ✕  ]      │    │
│  └───────────────────────────────────────────────────────┘    │
│                                                                │
│  PagePlaceholder if empty:                                     │
│  "No folders configured. Add a folder to start backing up."    │
└────────────────────────────────────────────────────────────────┘
```

**Elementos usados:** `RippleButton` com ícone para cada pasta (dinâmico: `folder`, `image`, `settings`), `RippleButton` de adicionar (estilo FAB), `PagePlaceholder` se vazio, diálogo nativo de seleção de pasta via `Process` (`zenity --file-selection --directory`).

---

##### Card 4 — **Schedule** (seletor visual grande, não switch)
Card com `ConfigSelectionArray` estilo botões segmentados grandes para escolher o intervalo.

```
┌────────────────────────────────────────────────────────────────┐
│  🕐 Sync Schedule                                              │
│                                                                │
│  ┌──────┬──────┬──────┬──────┬──────┬──────┬──────┬────────┐ │
│  │ 15m  │ 30m  │  1h  │  3h  │  6h  │ 12h  │ 24h  │ Manual │ │
│  └──────┴──────┴──────┴──────┴──────┴──────┴──────┴────────┘ │
│                                                                │
│  ConfigSwitch: "Sync on boot"                                  │
│  ConfigSwitch: "Sync when network connects"                    │
└────────────────────────────────────────────────────────────────┘
```

**Elementos usados:** `ConfigSelectionArray` (horizontal, visual, já existe), 2 `ConfigSwitch` abaixo (estes sim justificam switches pois são toggles booleanos puros).

---

##### Card 5 — **Transfer Settings** (sliders e spinboxes)
Card para bandwidth e versionamento — usando `ConfigSlider`, `ConfigSpinBox`, `ConfigSelectionArray`.

```
┌────────────────────────────────────────────────────────────────┐
│  ⚡ Transfer                                                   │
│                                                                │
│  Bandwidth limit                                               │
│  [===========|===================================] 0 (∞)       │
│                  ConfigSlider: 0-10000 KB/s                    │
│                                                                │
│  ConfigSwitch: "Pause on metered connections"                  │
│                                                                │
│  Versions to keep                                              │
│  [ - ]  3  [ + ]      ConfigSpinBox: 1-10                     │
│                                                                │
│  Orphan policy                                                 │
│  ┌─────────────────┬────────────────────┐                     │
│  │ Keep on Drive    │ Delete from Drive   │                     │
│  └─────────────────┴────────────────────┘                     │
│       ConfigSelectionArray (2 options)                          │
└────────────────────────────────────────────────────────────────┘
```

---

##### Card 6 — **Exclusion Patterns** (lista editável)
Card com `ConfigListView` para patterns de exclusão, usando `ConfigTextField` + botão de adicionar.

```
┌────────────────────────────────────────────────────────────────┐
│  🚫 Exclude Patterns                     [ + Add Pattern ]    │
│                                                                │
│  ┌───────────────────────────────────────────────────────┐    │
│  │  *.tmp                                    [  ✕  ]     │    │
│  │  *.swp                                    [  ✕  ]     │    │
│  │  node_modules/                            [  ✕  ]     │    │
│  │  .git/                                    [  ✕  ]     │    │
│  │  __pycache__/                             [  ✕  ]     │    │
│  └───────────────────────────────────────────────────────┘    │
└────────────────────────────────────────────────────────────────┘
```

---

##### Card 7 — **Notifications** (apenas 2 switches)

```
┌────────────────────────────────────────────────────────────────┐
│  🔔 Notifications                                              │
│                                                                │
│  ConfigSwitch: "Notify on backup complete"                     │
│  ConfigSwitch: "Notify on errors"                              │
└────────────────────────────────────────────────────────────────┘
```

---

##### Card 8 — **Drive Destination & Setup** (expandável/colapsável)

```
┌────────────────────────────────────────────────────────────────┐
│  ☁ Drive Configuration                                        │
│                                                                │
│  ConfigTextField: "Remote folder name"  [ii-backup]            │
│                                                                │
│  HelperLinkBox: "Google Cloud Console"                         │
│    "Enable the Drive API in your Google Cloud project."        │
│    [ Open Console ]                                            │
│                                                                │
│  RippleButton: "🔑 Authorize Google Drive" (PrimaryContainer) │
│  RippleButton: "🔄 Re-authenticate" (SecondaryContainer)      │
│                                                                │
│  NoticeBox: "Uses the same Google Cloud project as Gmail."     │
└────────────────────────────────────────────────────────────────┘
```

---

### 5. Registro no SettingsPageRegistry

#### [MODIFY] [SettingsPageRegistry.qml](file:///home/pedro/Downloads/ii-vynx/dots/.config/quickshell/ii/modules/common/SettingsPageRegistry.qml)

Adicionar `"Google Drive"`, `"Backup"`, `"Cloud backup"` aos `aliases` da entrada `tasksAccounts`:

```qml
{
    "id": "tasksAccounts",
    "name": "Tasks & Accounts",
    "icon": "checklist",
    "component": "modules/settings/configs/TasksAccountsConfig.qml",
    "subPages": [],
    "aliases": ["Core Services", "TickTick", "Tasks", "Accounts", "Google Drive", "Backup", "Cloud backup", "rclone"]
}
```

---

### 6. Registro do Service no `qmldir`

#### [MODIFY] [qmldir](file:///home/pedro/Downloads/ii-vynx/dots/.config/quickshell/ii/services/qmldir)

Adicionar:
```
singleton GoogleDriveService 1.0 GoogleDriveService.qml
```

---

## Resumo de Arquivos

| Ação | Arquivo | Descrição |
|------|---------|-----------|
| MODIFY | `modules/common/Config.qml` | Adicionar `JsonObject googleDrive` com todas as propriedades |
| NEW | `services/GoogleDriveService.qml` | Singleton: timer, sync, rclone management, drive stats |
| NEW | `scripts/gdrive/setup_rclone.py` | Configuração do remote rclone com OAuth2 |
| NEW | `scripts/gdrive/sync.sh` | Wrapper de `rclone sync` com output JSON |
| NEW | `scripts/gdrive/drive_info.py` | Busca uso do Drive e tamanho do backup |
| NEW | `scripts/gdrive/check_rclone.sh` | Verifica instalação e configuração do rclone |
| MODIFY | `modules/settings/configs/TasksAccountsConfig.qml` | UI completa: hero card, gráfico, folder list, schedule, etc |
| MODIFY | `modules/common/SettingsPageRegistry.qml` | Aliases de busca |
| MODIFY | `services/qmldir` | Registro do singleton |

---

## Verification Plan

### Automated Tests
```bash
# Verificar que o shell inicia sem crashes após modificar Config.qml
qs log -f -c ii | head -50

# Verificar que rclone está instalável
pacman -Qi rclone || echo "rclone not installed"

# Testar script de check isoladamente
bash scripts/gdrive/check_rclone.sh

# Testar script de info isoladamente
python3 scripts/gdrive/drive_info.py
```

### Manual Verification
1. Abrir Settings → Tasks & Accounts → verificar que a seção Google Drive aparece
2. Verificar que o Hero Card mostra "Setup Required" quando não configurado
3. Clicar "Authorize Google Drive" → deve abrir browser com OAuth2 consent
4. Após autorizar, verificar que o status muda para "Connected"
5. Adicionar pasta de backup → verificar que aparece na lista
6. Clicar "Sync Now" → verificar progresso no Hero Card
7. Verificar que o gráfico de atividade atualiza após sync
8. Mudar schedule → verificar que o timer dispara no intervalo correto
9. Verificar que `config.json` salva e restaura todas as preferências após reboot

### Design Consistency
- Verificar que todas as cores usam `Appearance.colors.*` / `Appearance.m3colors.*`
- Verificar que não há borders (proibido pelo projeto)
- Verificar que animações usam `Appearance.animation.*`
- Verificar que arredondamentos usam `Appearance.rounding.*`
- Verificar que ícones usam Material Symbols via `MaterialSymbol`
