# Tracker Studio

Tracker Studio is an open-source project maintained by LocaliTel.

Plataforma Flutter aberta para bancada, configuracao, validacao e diagnostico de rastreadores e dispositivos de telemetria.

O projeto esta sendo migrado de uma implementacao inicialmente centrada em Suntech para uma arquitetura neutra, extensivel por plugins de equipamentos, fabricantes, protocolos, integracoes e fluxos operacionais.

## Visao

- Core livre e independente de fabricante.
- Plugins oficiais e comunitarios por equipamento/protocolo.
- Fluxos de diagnostico e instalacao reutilizaveis.
- Catalogos de comandos e manuais isolados por plugin.
- Integracoes externas sem credenciais privilegiadas no aplicativo.
- Base preparada para extensoes gratuitas e comerciais sem fechar o core.

## Estado atual

O comportamento Suntech existente continua preservado durante a migracao. A fundacao da API de plugins esta em `lib/core/plugins`, e o plano arquitetural completo esta em `docs/plugin-architecture.md`.

A extracao do codigo Suntech para `plugins/suntech` deve ser feita de forma incremental e protegida pelos testes existentes.

## Compatibilidade de plataformas

O Tracker Studio foi desenvolvido com Flutter Desktop e tem como objetivo funcionar em:

- macOS;
- Windows;
- Linux.

> [!IMPORTANT]
> Ate o momento, o projeto foi executado e testado apenas no macOS. Windows e Linux ainda nao foram validados oficialmente. Nessas plataformas podem existir ajustes pendentes relacionados a compilacao, drivers USB, descoberta de portas seriais, permissoes do sistema e empacotamento.

Contribuicoes para testes, correcoes e validacao no Windows e Linux sao bem-vindas.

## Requisitos gerais

Antes de executar o projeto, instale:

- Flutter SDK compativel com Dart `>=3.4.0 <4.0.0`;
- Git;
- ferramentas de compilacao da plataforma escolhida;
- driver USB ou serial exigido pelo equipamento utilizado.

Verifique o ambiente:

```bash
flutter doctor -v
```

Corrija os itens apontados pelo Flutter antes de continuar.

## Executar no macOS

Esta e a plataforma atualmente testada.

### 1. Instale os requisitos

Instale:

- Xcode pela App Store;
- Xcode Command Line Tools;
- Flutter SDK;
- CocoaPods, caso seja solicitado por alguma dependencia.

Aceite a licenca do Xcode:

```bash
sudo xcodebuild -license accept
```

Habilite o suporte desktop:

```bash
flutter config --enable-macos-desktop
```

### 2. Clone o repositorio

```bash
git clone https://github.com/BrunoFelisbino/tracker-studio.git
cd tracker-studio
```

### 3. Instale as dependencias

```bash
flutter pub get
```

### 4. Verifique o projeto

```bash
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
```

### 5. Execute

```bash
flutter run -d macos --debug --dart-define=AUTH_ENABLED=false
```

### 6. Gere o build

```bash
flutter build macos
```

O aplicativo gerado normalmente fica em:

```text
build/macos/Build/Products/Release/
```

### Acesso USB e serial no macOS

As portas seriais normalmente aparecem com nomes semelhantes a:

```text
/dev/cu.usbserial-*
/dev/cu.usbmodem-*
```

Liste as portas disponiveis:

```bash
ls /dev/cu.*
```

Caso o dispositivo nao apareca:

1. confirme se o cabo USB transmite dados;
2. instale o driver correto do conversor USB/serial;
3. feche outros programas que possam estar usando a porta;
4. desconecte e conecte o equipamento novamente;
5. execute novamente o aplicativo.

## Executar no Windows

> [!WARNING]
> O fluxo abaixo ainda nao foi validado oficialmente neste projeto.

### 1. Instale os requisitos

Instale:

- Flutter SDK;
- Git for Windows;
- Visual Studio 2022;
- workload `Desktop development with C++`;
- Windows 10 SDK ou Windows 11 SDK;
- driver USB/serial do equipamento.

Habilite o desktop Windows:

```powershell
flutter config --enable-windows-desktop
```

### 2. Clone e prepare

```powershell
git clone https://github.com/BrunoFelisbino/tracker-studio.git
cd tracker-studio
flutter pub get
```

### 3. Verifique

```powershell
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
```

### 4. Execute

```powershell
flutter run -d windows --debug --dart-define=AUTH_ENABLED=false
```

### 5. Gere o build

```powershell
flutter build windows
```

O build normalmente fica em:

```text
build\windows\x64\runner\Release\
```

No Windows, os dispositivos seriais normalmente aparecem como `COM3`, `COM4`, `COM5` e similares. Confirme a porta no Gerenciador de Dispositivos.

## Executar no Linux

> [!WARNING]
> O fluxo abaixo ainda nao foi validado oficialmente neste projeto.

### 1. Instale as dependencias

Exemplo para Ubuntu ou Debian:

```bash
sudo apt update
sudo apt install -y clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev git
```

Instale o Flutter SDK e habilite o desktop Linux:

```bash
flutter config --enable-linux-desktop
```

### 2. Configure o acesso serial

Adicione o usuario ao grupo `dialout`:

```bash
sudo usermod -aG dialout "$USER"
```

Depois, encerre a sessao do sistema e entre novamente.

Portas comuns:

```text
/dev/ttyUSB0
/dev/ttyACM0
```

Para listar:

```bash
ls -l /dev/ttyUSB* /dev/ttyACM* 2>/dev/null
```

### 3. Clone e prepare

```bash
git clone https://github.com/BrunoFelisbino/tracker-studio.git
cd tracker-studio
flutter pub get
```

### 4. Verifique

```bash
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
```

### 5. Execute

```bash
flutter run -d linux --debug --dart-define=AUTH_ENABLED=false
```

### 6. Gere o build

```bash
flutter build linux
```

O build normalmente fica em:

```text
build/linux/x64/release/bundle/
```

## Problemas comuns

### Nenhum dispositivo desktop encontrado

Execute:

```bash
flutter devices
```

Confirme que o suporte da plataforma esta habilitado:

```bash
flutter config
```

### Porta serial nao aparece

Verifique:

- cabo USB com suporte a dados;
- driver do conversor USB/serial;
- permissoes do sistema;
- porta ocupada por outro aplicativo;
- compatibilidade do equipamento com a plataforma;
- dispositivo ligado e alimentado corretamente.

### Porta serial ocupada

Feche programas como:

- terminal serial;
- Arduino IDE;
- monitor de porta;
- configurador do fabricante;
- outra instancia do Tracker Studio.

### Testar sem equipamento fisico

Plugins e funcionalidades genericas devem oferecer fixtures sinteticas, transporte mock ou modo demonstracao sempre que possivel. Nunca inclua IMEI, ICCID, telefone, placa, coordenadas ou dados reais de clientes nos testes.

## Configuracao local

Copie `.env.example` para `.env` apenas quando alguma integracao local exigir variaveis. Nunca envie credenciais reais ao Git.

```bash
cp .env.example .env
```

Segredos de banco, tokens administrativos e chaves privadas nao podem ser distribuidos no aplicativo Flutter. Use backend ou armazenamento seguro apropriado.

## Documentação

- `docs/plugin-architecture.md` — Plugin system and migration plan.
- `docs/architecture.md` — High-level architecture and data flow.
- `docs/teltonika-support.md` — Teltonika FMB device support details.
- `docs/io-catalog.md` — IO definition catalog system.
- `docs/capture-privacy.md` — Capture log sanitisation and retention.
- `docs/public-security-audit.md` — Pre-publication security checklist.

## Criando plugins

Um plugin implementa `TrackerStudioPlugin`, declara seu `PluginManifest` e cria uma `TrackerPluginSession`. O core resolve plugins por `DeviceIdentity` e usa capacidades declaradas para montar a experiencia.

Consulte `docs/plugin-architecture.md` antes de adicionar codigo especifico de fabricante.

## Seguranca

Leia `SECURITY.md` antes de publicar, contribuir ou relatar vulnerabilidades. O repositorio somente deve se tornar publico depois da rotacao dos segredos expostos e limpeza completa do historico Git.

## Contribuicao

Pull requests devem manter o core neutro, incluir testes e usar apenas dados sinteticos em fixtures, logs, capturas e relatorios.

Ao testar no Windows ou Linux, informe na contribuicao:

- sistema operacional e versao;
- versao do Flutter;
- arquitetura do computador;
- fabricante e modelo do equipamento;
- tipo de conexao utilizado;
- resultado de `flutter doctor -v`;
- erros encontrados sem expor dados sensiveis.
