# Plano de Implementação — Welcome Experience vNext

> Repositório alvo: `P3DROVFX/ii-p3drovfx`  
> Branch de referência: `dev`  
> Escopo: redesign e modularização do onboarding `welcome.qml`  
> Ambiente: Hyprland + Quickshell + Material You / Material 3 Expressive  
> Status: implementação parcial iniciada; sete arquivos QML existem como rascunho e ainda não foram integrados ou validados.

---

## 1. Objetivo

Transformar o Welcome atual em uma experiência de configuração inicial inspirada no fluxo de primeiro uso dos dispositivos Google Pixel.

O usuário deve poder avançar por seis páginas para conhecer e personalizar o II, mas sem ser obrigado a configurar recursos, instalar dependências ou seguir uma ordem rígida.

O fluxo final deve oferecer:

- seis páginas modulares;
- título e ícone dinâmicos;
- linha de progresso clicável;
- navegação `Anterior` e `Próximo`;
- transições direcionais suaves;
- acesso livre a qualquer etapa;
- configurações rápidas de alto impacto;
- tutoriais em subpáginas;
- diagnóstico não bloqueante;
- deep links para o Settings;
- reutilização dos dialogs da Sidebar Dashboard;
- execução dentro do processo principal do II.

---

## 2. Princípios de experiência

### 2.1 Fluxo guiado, não obrigatório

A interface deve sugerir uma sequência lógica, mas nunca impedir o usuário de:

- pular uma etapa;
- voltar para uma etapa anterior;
- abrir diretamente uma etapa pela linha de progresso;
- fechar o Welcome;
- concluir com integrações opcionais pendentes.

O progresso representa páginas visitadas, não tarefas obrigatórias concluídas.

### 2.2 Pouco texto por superfície

Cada página deve comunicar apenas o necessário para a próxima decisão.

Explicações extensas devem ficar em:

- subpáginas de tutorial;
- `NoticeBox` contextual;
- Settings;
- documentação externa.

### 2.3 Uma ação primária por página

O botão `Próximo` permanece como ação primária do fluxo. Ações como abrir Settings, tutorial, dialog ou link externo devem ter tratamento visual secundário.

### 2.4 Continuidade espacial

Avançar deve deslizar o conteúdo para a esquerda. Voltar deve deslizar o conteúdo para a direita.

A animação deve:

- usar os tokens de `Appearance.animation.*`;
- animar transformação/posição e opacidade, sem animar layout;
- ser interrompível por nova navegação;
- respeitar o multiplicador global de animações;
- evitar scale decorativo, bounce genérico e pulse.

---

## 3. Estado atual da implementação

### 3.1 Arquivos já criados

Os seguintes arquivos existem em `modules/welcome/`:

```text
modules/welcome/
├── WelcomeActionCard.qml
├── WelcomeEssentialsPage.qml
├── WelcomeKeybindCard.qml
├── WelcomePersonalizePage.qml
├── WelcomePresetsPage.qml
├── WelcomeStartPage.qml
└── WelcomeTutorialRegistry.qml
```

### 3.2 O que os rascunhos já cobrem

- `WelcomeActionCard.qml`
  - card reutilizável com ícone Material, título, descrição, status e seleção;
  - preparado para ações de navegação e escolhas expressivas.

- `WelcomeKeybindCard.qml`
  - card compacto para atalhos com até três teclas;
  - reutiliza `KeyboardKey` e tokens do design system.

- `WelcomeTutorialRegistry.qml`
  - metadados iniciais de Gmail, TickTick, Google Calendar e Google Drive;
  - prevê tempo estimado, página do Settings, passos e `videoUrl` futuro.

- `WelcomeStartPage.qml`
  - hero de boas-vindas;
  - cards de Wi-Fi, Bluetooth e saída de áudio;
  - sinais para abrir os dialogs reais;
  - acesso secundário ao Settings.

- `WelcomePresetsPage.qml`
  - empty state reservado para os três presets futuros;
  - nenhum preset fictício ou alteração automática de configuração.

- `WelcomePersonalizePage.qml`
  - wallpaper, light/dark e paleta Material You;
  - escolhas expressivas para Default e Connect;
  - posição da barra;
  - estilo do OSD;
  - estilo dos quick toggles;
  - toggle do Overview;
  - verificações iniciais de incompatibilidade.

- `WelcomeEssentialsPage.qml`
  - grade de atalhos essenciais;
  - acesso ao cheatsheet, Settings, GitHub e wiki.

### 3.3 Limitações do estado atual

Os arquivos acima são rascunhos estruturais e ainda precisam de revisão antes da integração.

Ainda não foi feito:

- validação de sintaxe e imports QML;
- inspeção visual;
- teste responsivo;
- revisão final das strings traduzíveis;
- conexão com `welcome.qml`;
- criação do fluxo das seis páginas;
- criação das páginas Aprender e Diagnóstico;
- instanciação dos dialogs;
- migração in-process;
- alteração de IPC;
- atualização do `AGENTS.md`.

O arquivo `welcome.qml` atual permanece sem alterações feitas por esta implementação parcial.

---

## 4. Arquitetura de navegação alvo

```text
WelcomeWindow
│
├── WelcomeHeader
│   ├── MaterialShape + ícone dinâmico
│   ├── título dinâmico
│   ├── subtítulo curto
│   ├── "Etapa N de 6"
│   └── botão Close
│
├── WelcomeProgress
│   └── 6 segmentos clicáveis
│
├── WelcomeFlow
│   ├── 1. StartPage
│   ├── 2. PresetsPage
│   ├── 3. PersonalizePage
│   ├── 4. EssentialsPage
│   ├── 5. LearnPage
│   └── 6. DiagnosticsPage
│
├── WelcomeNavigation
│   ├── Anterior
│   ├── indicador de página
│   └── Próximo / Concluir
│
└── Dialog loaders
    ├── WifiDialog
    ├── BluetoothDialog
    └── VolumeDialog
```

### 4.1 Estado efêmero do fluxo

O estado de navegação deve ser local à janela:

```qml
property int currentPage: 0
property int previousPage: 0
property int highestVisitedPage: 0
property int transitionDirection: 1
```

Não gravar a página atual em `Config`.

Persistir progresso somente se houver uma necessidade real de produto. Caso isso seja adicionado depois, usar `Persistent.qml` e listas explicitamente tipadas.

### 4.2 Troca de páginas

Usar um trilho horizontal controlado programaticamente ou um host equivalente que:

- não dependa de swipe para funcionar;
- mantenha `Anterior` e `Próximo` sempre disponíveis;
- permita clicar nos seis segmentos de progresso;
- preserve o scroll vertical de cada página durante a sessão;
- bloqueie input no conteúdo anterior durante a transição;
- aceite nova navegação sem deixar páginas em posições intermediárias.

### 4.3 Teclado

Comportamento esperado:

- `Tab`: percorre controles na ordem visual;
- `Enter`/`Space`: ativa o controle focado;
- `Alt+Left` ou botão lateral: página anterior;
- `Alt+Right`: próxima página;
- `Escape`: fecha tutorial/dialog primeiro; fecha o Welcome somente quando não houver overlay aberto.

---

## 5. Cabeçalho e progresso

### 5.1 Cabeçalho dinâmico

Metadados das páginas:

| Etapa | Título | Ícone Material | Papel |
| --- | --- | --- | --- |
| 1 | Boas-vindas ao II | `waving_hand` | Introdução e conexões básicas |
| 2 | Presets do II | `auto_awesome` | Presets oficiais futuros |
| 3 | Personalize seu II | `palette` | Aparência e comportamento |
| 4 | Conheça o II | `keyboard` | Atalhos e recursos essenciais |
| 5 | Aprenda e conecte | `school` | Tutoriais e integrações |
| 6 | Diagnóstico final | `health_and_safety` | Estado do sistema e conclusão |

O ícone deve ficar dentro de um `MaterialShape` expressivo à esquerda do título.

O botão Close deve ter alvo interativo de pelo menos 44 px e ser levemente maior que o botão atual.

### 5.2 Linha de progresso

Cada segmento deve possuir estado visual distinto:

- atual;
- visitado;
- ainda não visitado;
- hover/focus;
- pressionado.

Não usar border. A diferenciação deve ser feita com:

- preenchimento;
- contraste;
- largura do segmento atual;
- ícone ou label acessível;
- peso tipográfico.

O usuário pode clicar em qualquer segmento, inclusive etapas futuras.

### 5.3 Remoção do `Show next time`

Remover o toggle da barra superior.

O arquivo `first_run.txt` continua definindo apenas a abertura automática inicial. Reabrir manualmente o Welcome não deve alterar essa marcação.

---

## 6. Definição das seis páginas

## 6.1 Página 1 — Boas-vindas

### Objetivo

Apresentar o II e permitir que o usuário deixe conectividade e áudio utilizáveis antes de continuar.

### Conteúdo

- hero curto de boas-vindas;
- explicação de que todas as etapas são opcionais;
- card Wi-Fi com rede/estado atual;
- card Bluetooth com adaptador e dispositivo conectado;
- card de saída de áudio com dispositivo e volume;
- acesso secundário ao Settings.

### Dialogs reutilizados

```text
modules/ii/sidebarDashboard/wifiNetworks/WifiDialog.qml
modules/ii/sidebarDashboard/bluetoothDevices/BluetoothDialog.qml
modules/ii/sidebarDashboard/volumeMixer/VolumeDialog.qml
```

Não duplicar descoberta, senha, pairing ou seleção PipeWire dentro do Welcome.

---

## 6.2 Página 2 — Presets

### Objetivo atual

Reservar a etapa para três presets oficiais que serão definidos posteriormente pelo usuário.

### Versão inicial

- empty state central;
- texto curto informando que os presets serão adicionados;
- nenhum card falso;
- nenhuma alteração em `Config`.

### Arquitetura futura

Cada preset poderá conter:

- ID estável;
- nome;
- descrição curta;
- preview;
- lista resumida de mudanças;
- payload de configurações;
- botão aplicar;
- mecanismo de desfazer.

A definição dos presets não faz parte do escopo inicial deste plano.

---

## 6.3 Página 3 — Personalização

### Objetivo

Reunir escolhas visuais de grande impacto sem transformar a página numa pilha longa de toggles.

### Bloco Aparência

- wallpaper;
- modo claro/escuro;
- paleta Material You;
- deep link para Colors & Themes.

### Bloco Shell Mode

Dois cards grandes:

- Default;
- Connect.

Cada card deve ter:

- ícone;
- título;
- uma linha de descrição;
- seleção evidente;
- estado indisponível quando necessário.

Um `NoticeBox` curto explica o modo ativo.

As regras já existentes no Settings devem ser preservadas:

- `floatingNotch.centerInBar` bloqueia Connect;
- Floating Dynamic Island ativa pode impedir retorno imediato ao Default;
- opções incompatíveis devem informar o motivo;
- não permitir produzir uma combinação impossível.

Idealmente, essas regras devem ser centralizadas em um helper/controlador compartilhado antes de haver duas implementações independentes.

### Bloco Barra e preferências rápidas

- posição: Top, Left, Bottom, Right;
- estilo do OSD: Android ou Minimal;
- Overview ativado/desativado;
- quick toggles: Classic ou Android;
- deep links para opções avançadas.

No Connect, a personalização do OSD deve ficar indisponível com uma explicação curta.

---

## 6.4 Página 4 — Keybinds e informações

### Objetivo

Dar autonomia para o usuário explorar o II depois que o Welcome for fechado.

### Atalhos principais

- Settings;
- Control Dashboard;
- AI Sidebar;
- Overview;
- App Launcher;
- Cheatsheet;
- Wallpaper Selector;
- reabrir o Welcome.

### Destinos úteis

- Cheatsheet completo;
- Settings;
- repositório GitHub;
- wiki;
- perfil do projeto, se ainda for útil no layout final.

Não duplicar o cheatsheet completo nesta página.

---

## 6.5 Página 5 — Aprender e conectar

### Objetivo

Apresentar tutoriais opcionais para integrações que exigem configuração externa.

### Catálogo inicial

- Gmail;
- TickTick;
- Google Calendar com `khal` e `vdirsyncer`;
- Google Drive com `rclone`.

Cada card deve mostrar:

- ícone;
- título;
- descrição curta;
- tempo estimado;
- estado detectado;
- ação `Configurar`, `Continuar` ou `Ver novamente`.

### Subpágina de tutorial

```text
LearnPage
    └── TutorialPage
        ├── introdução
        ├── pré-requisitos
        ├── passos
        ├── ações contextuais
        ├── verificação
        ├── troubleshooting recolhido
        └── vídeo opcional
```

A subpágina deve deslizar sobre o catálogo e possuir retorno previsível. A etapa global continua sendo a página 5.

### Conteúdo compartilhado

O tutorial de Gmail deve reaproveitar ou extrair o conteúdo existente em:

```text
modules/ii/cheatsheet/email/EmailAuth.qml
```

Não manter duas listas independentes de passos OAuth.

TickTick e Drive devem direcionar para `tasksAccounts` quando for necessário inserir credenciais ou alterar opções.

### Vídeos futuros

O modelo já prevê `videoUrl`.

Versão inicial:

- `videoUrl` vazio mostra `Vídeo em breve`;
- nenhum player é carregado;
- nenhuma requisição de rede é feita para thumbnails ausentes.

Versão futura:

- thumbnail;
- duração;
- botão para abrir YouTube externamente;
- embed somente se houver justificativa e dependência adequada.

---

## 6.6 Página 6 — Diagnóstico

### Objetivo

Mostrar se os principais recursos estão prontos e oferecer uma rota de recuperação, sem bloquear a conclusão.

### Verificações iniciais

| Item | Fonte sugerida |
| --- | --- |
| Wi-Fi | `Network.wifiStatus` |
| Bluetooth | `BluetoothStatus.available/enabled/connected` |
| Áudio | `Audio.ready` e sink atual |
| Gmail | `EmailService.credentialsConfigured/authenticated` |
| TickTick | `TickTickService.available` |
| khal | `CalendarService.khalAvailable` |
| vdirsyncer | nova verificação somente leitura |
| rclone | `GoogleDriveService.rcloneInstalled` |
| Google Drive | `GoogleDriveService.configured` |

### Estados visuais

- Pronto;
- Opcional;
- Não configurado;
- Dependência ausente;
- Atenção necessária;
- Verificando.

Cada estado deve usar ícone e texto, nunca apenas cor.

### Ações de recuperação

- abrir tutorial correspondente;
- abrir página do Settings;
- copiar comando;
- verificar novamente.

Nenhuma dependência deve ser instalada automaticamente.

### Conclusão

O botão `Concluir` fecha o Welcome mesmo quando itens opcionais estiverem pendentes.

A página deve informar o atalho correto para reabrir o Welcome.

---

## 7. Integração com Settings

### 7.1 Deep links

Expandir o IPC existente para aceitar IDs estáveis do `SettingsPageRegistry`:

```qml
IpcHandler {
    target: "settings"

    function openPage(pageId: string): void {
        GlobalStates.settingsPendingPageName = pageId;
        GlobalStates.settingsOpen = true;
    }
}
```

Destinos iniciais:

```text
colors
bar
overview
overlays
tasksAccounts
cheatSheet
languageTime
```

Não usar `settings toggle` nos CTAs, porque isso pode fechar uma janela que já esteja aberta.

### 7.2 Seções e subpáginas

Uma evolução posterior pode adicionar:

```text
settings.openSection(pageId, sectionTitle)
settings.openSubPage(pageId, subPageId)
```

Isso não deve bloquear a primeira versão. Abrir a página correta já é suficiente para o MVP.

---

## 8. Migração do Welcome para o processo principal

## 8.1 Problema atual

`FirstRunExperience.qml` inicia:

```text
qs -p welcome.qml
```

O Welcome externo importa `Config` e pode escrever no mesmo `config.json` usado pelo processo principal.

Isso cria risco de:

- dois `FileView` observando o mesmo arquivo;
- corridas durante hot reload;
- escritas concorrentes;
- sobrescrita de dados ainda não carregados;
- corrupção ou reset de configuração.

## 8.2 Arquitetura alvo

Seguir o padrão já usado pelo Settings:

```text
shell.qml
    └── Loader / LazyLoader
        └── WelcomeWindow.qml
```

Adicionar em `GlobalStates.qml`:

```qml
property bool welcomeOpen: false
```

Adicionar IPC:

```qml
IpcHandler {
    target: "welcome"
    function open(): void { GlobalStates.welcomeOpen = true }
    function close(): void { GlobalStates.welcomeOpen = false }
    function toggle(): void { GlobalStates.welcomeOpen = !GlobalStates.welcomeOpen }
}
```

`FirstRunExperience.handleFirstRun()` deve abrir o estado in-process em vez de iniciar outro engine Quickshell.

## 8.3 Compatibilidade de entrada

Decidir durante a implementação se `welcome.qml`:

1. vira o próprio `WelcomeWindow` carregado in-process; ou
2. permanece como wrapper compatível enquanto a implementação visual mora em `modules/welcome/WelcomeWindow.qml`.

Preferência: manter `welcome.qml` pequeno e usar componentes modulares em `modules/welcome/`.

---

## 9. Estrutura de arquivos alvo

```text
modules/welcome/
├── WelcomeWindow.qml
├── WelcomeFlow.qml
├── WelcomeHeader.qml
├── WelcomeProgress.qml
├── WelcomeNavigation.qml
├── WelcomeActionCard.qml                 # já criado, revisar
├── WelcomeKeybindCard.qml                # já criado, revisar
├── WelcomeStatusCard.qml                 # pendente
├── WelcomeTutorialRegistry.qml           # já criado, revisar
├── WelcomeStartPage.qml                  # já criado, revisar
├── WelcomePresetsPage.qml                # já criado, revisar
├── WelcomePersonalizePage.qml            # já criado, revisar
├── WelcomeEssentialsPage.qml             # já criado, revisar
├── WelcomeLearnPage.qml                  # pendente
├── WelcomeDiagnosticsPage.qml            # pendente
└── tutorials/
    ├── WelcomeTutorialPage.qml           # pendente
    ├── GmailTutorialData.qml             # avaliar extração compartilhada
    ├── TickTickTutorialData.qml
    ├── CalendarTutorialData.qml
    └── GoogleDriveTutorialData.qml
```

Arquivos existentes previstos para alteração:

```text
welcome.qml
shell.qml
GlobalStates.qml
services/FirstRunExperience.qml
```

Possíveis alterações adicionais:

```text
modules/ii/cheatsheet/email/EmailAuth.qml
services/CalendarService.qml
```

Somente alterar esses arquivos quando houver necessidade confirmada.

---

## 10. Ordem de implementação a partir do ponto atual

## Fase 1 — Revisar o rascunho existente

- [x] Criar `WelcomeActionCard.qml`.
- [x] Criar `WelcomeKeybindCard.qml`.
- [x] Criar registro inicial de tutoriais.
- [x] Criar rascunho da página Início.
- [x] Criar placeholder de Presets.
- [x] Criar rascunho da página Personalização.
- [x] Criar rascunho da página Essenciais.
- [ ] Validar imports e propriedades dos sete arquivos.
- [ ] Corrigir strings ainda não reativas a `Translation.tr`.
- [ ] Verificar se todos os componentes escolhidos existem na API atual.
- [ ] Remover qualquer duplicação ou binding arriscado antes da integração.
- [ ] Revisar responsividade das grids.

## Fase 2 — Scaffold do fluxo

- [ ] Criar `WelcomeHeader.qml`.
- [ ] Criar `WelcomeProgress.qml`.
- [ ] Criar `WelcomeNavigation.qml`.
- [ ] Criar `WelcomeFlow.qml`.
- [ ] Definir metadados das seis páginas em uma única fonte de verdade.
- [ ] Implementar `Anterior`, `Próximo`, salto livre e `Concluir`.
- [ ] Implementar animação direcional suave.
- [ ] Preservar scroll de cada página durante a sessão.
- [ ] Bloquear input na página anterior durante transições.

## Fase 3 — Aprender e tutoriais

- [ ] Criar `WelcomeLearnPage.qml`.
- [ ] Criar `WelcomeTutorialPage.qml`.
- [ ] Implementar abertura e retorno de subpáginas.
- [ ] Extrair/reutilizar os passos do Gmail.
- [ ] Revisar passos de TickTick contra a implementação atual.
- [ ] Especificar fluxo real de `khal`/`vdirsyncer`.
- [ ] Reutilizar status e ações do Google Drive.
- [ ] Implementar placeholder de vídeo.
- [ ] Adicionar verificação contextual por tutorial.

## Fase 4 — Diagnóstico

- [ ] Criar `WelcomeStatusCard.qml`.
- [ ] Criar `WelcomeDiagnosticsPage.qml`.
- [ ] Conectar estados dos serviços existentes.
- [ ] Adicionar detecção somente leitura do `vdirsyncer`.
- [ ] Implementar `Verificar novamente` sem polling contínuo.
- [ ] Adicionar ações de recuperação.
- [ ] Garantir que nenhum item opcional bloqueie a conclusão.

## Fase 5 — Dialogs da página inicial

- [ ] Instanciar `WifiDialog` por `Loader`.
- [ ] Instanciar `BluetoothDialog` por `Loader`.
- [ ] Instanciar `VolumeDialog { isSink: true }` por `Loader`.
- [ ] Replicar os gatilhos necessários de scan/discovery.
- [ ] Parar discovery Bluetooth ao fechar o dialog.
- [ ] Garantir foco e comportamento de `Escape`.
- [ ] Descarregar dialogs quando não estiverem em uso.

## Fase 6 — Processo principal e IPC

- [ ] Adicionar `GlobalStates.welcomeOpen` sem interferir nas alterações locais existentes.
- [ ] Adicionar handler IPC `welcome`.
- [ ] Adicionar `settings.openPage(pageId)`.
- [ ] Criar loader in-process no `shell.qml` após revisar o ciclo de vida.
- [ ] Alterar `FirstRunExperience` para abrir o Welcome in-process.
- [ ] Remover escrita concorrente de Config.
- [ ] Preservar a abertura manual pelo atalho existente.

## Fase 7 — Integração visual final

- [ ] Substituir o conteúdo monolítico de `welcome.qml` pelo novo host.
- [ ] Aumentar levemente a janela em relação aos atuais 1050 × 740.
- [ ] Manter tamanho mínimo utilizável em telas menores.
- [ ] Remover `Show next time`.
- [ ] Implementar title e MaterialShape dinâmicos.
- [ ] Aumentar o botão Close.
- [ ] Remover a notificação disparada em todo fechamento.
- [ ] Revisar hierarquia visual, densidade e alinhamento.

## Fase 8 — Validação e documentação

- [ ] Executar validação QML disponível no projeto.
- [ ] Abrir o Welcome em sessão real do II.
- [ ] Inspecionar `qs log -f -c ii`.
- [ ] Corrigir warnings, bindings inválidos e loops.
- [ ] Testar light/dark e diferentes wallpapers.
- [ ] Testar todas as posições da barra.
- [ ] Testar Default/Connect e estados bloqueados.
- [ ] Testar dialogs e foco de teclado.
- [ ] Testar reabertura após fechar.
- [ ] Atualizar `AGENTS.md` com a arquitetura implementada.
- [ ] Atualizar o sumário dinâmico do `AGENTS.md`.

---

## 11. Regras de implementação obrigatórias

- Não usar borders.
- Não usar cores, fontes ou raios hardcoded.
- Não criar botões, switches, sliders ou dialogs básicos do zero quando já houver widget equivalente.
- Não usar pulse, breathing ou glow contínuo.
- Não usar scale como decoração de entrada.
- Usar `Appearance.animation.*` para animações.
- Usar `MaterialSymbol` e `MaterialShape` para linguagem visual.
- Manter alvos interativos de pelo menos 44 px.
- Não instalar dependências automaticamente.
- Não criar polling contínuo para diagnóstico.
- Não duplicar lógica de autenticação ou configuração existente.
- Não escrever listas persistentes como `property var` dentro de `JsonObject`.
- Encadear chamadas `String.arg()` e converter números com `String(...)`.
- Não alterar ou restaurar mudanças locais não relacionadas do worktree.

---

## 12. Matriz de testes

### Navegação

- página inicial → próxima;
- próxima → anterior;
- salto 1 → 6;
- salto 6 → 2;
- navegação durante animação;
- fechar com tutorial aberto;
- fechar com dialog aberto;
- reabrir após concluir;
- reabrir após fechar no meio do fluxo.

### Layout

- janela padrão;
- tamanho mínimo;
- janela maximizada;
- escala Qt diferente de 1;
- textos traduzidos mais longos;
- grids com uma, duas e três colunas;
- ausência de scroll horizontal.

### Configuração

- Default → Connect;
- Connect → Default;
- `centerInBar` ativo;
- Floating Dynamic Island ativa;
- barra Top/Left/Bottom/Right;
- OSD Android/Minimal;
- Overview on/off;
- quick toggles Classic/Android.

### Integrações

- Wi-Fi desligado;
- Wi-Fi sem rede;
- rede conectada;
- Bluetooth indisponível;
- Bluetooth desligado;
- dispositivo conectado;
- PipeWire sem sink pronto;
- Gmail sem credenciais e autenticado;
- TickTick sem token e disponível;
- khal ausente/presente;
- vdirsyncer ausente/presente;
- rclone ausente/presente;
- Drive não configurado/configurado.

### Estabilidade

- apenas um processo grava `Config`;
- ausência de binding loops;
- ausência de `String.arg(): Invalid arguments`;
- dialogs descarregados quando fechados;
- nenhuma descoberta Bluetooth deixada ativa;
- nenhuma requisição de vídeo quando `videoUrl` estiver vazio;
- logs limpos após várias aberturas.

---

## 13. Critérios de aceite

A feature poderá ser considerada concluída quando:

1. As seis páginas estiverem acessíveis e funcionais.
2. O usuário puder navegar livremente sem completar nenhuma configuração.
3. O progresso e o título refletirem corretamente a página atual.
4. A transição for direcional, suave e interrompível.
5. Wi-Fi, Bluetooth e áudio reutilizarem os dialogs reais.
6. Default/Connect respeitarem todas as incompatibilidades existentes.
7. A página Aprender abrir os quatro tutoriais em subpáginas.
8. A ausência de vídeos não produzir áreas quebradas ou requisições desnecessárias.
9. O Diagnóstico mostrar estados reais e ações de recuperação.
10. O usuário puder concluir com integrações opcionais pendentes.
11. O Welcome rodar dentro do processo principal do II.
12. Settings abrir sempre na página correta sem comportamento de toggle acidental.
13. Não houver warnings críticos, binding loops ou múltiplos escritores de Config.
14. O layout funcionar no tamanho mínimo e com navegação por teclado.
15. A arquitetura final estiver documentada no `AGENTS.md`.

---

## 14. Fora do escopo inicial

- definir o conteúdo real dos três presets;
- instalar dependências pelo Welcome;
- autenticação OAuth inteiramente dentro do Welcome;
- reprodução embutida de YouTube;
- download automático de thumbnails;
- tornar integrações obrigatórias;
- sincronizar progresso do onboarding entre máquinas;
- analytics ou telemetria do onboarding;
- redesign completo dos dialogs reutilizados;
- duplicar todas as configurações disponíveis no Settings.

---

## 15. Ponto exato de retomada

Ao retomar a implementação, a primeira atividade deve ser:

```text
Revisar e validar os sete arquivos existentes em modules/welcome/
```

Somente depois dessa revisão deve ser criado o scaffold de navegação.

Não começar novamente do zero e não recriar componentes que já existem.

