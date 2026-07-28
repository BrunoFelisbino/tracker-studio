# Tracker Studio Flutter

Primeira migracao da ultima versao do configurador para Flutter.

## Objetivo desta camada

- manter a experiencia simples;
- espelhar o que ja funcionava no configurador atual;
- corrigir os erros conhecidos antes de ligar no hardware real;
- preparar a tela para receber dados reais de USB, SMS, GPRS e LocaliTel.

## Estado atual

`tracker_session_state.dart` contem um estado demonstrativo tipado que representa uma sessao real de bancada.

`tracker_studio_live_screen.dart` renderiza a tela operacional com:

- conexao USB/serial;
- rede/GPRS consolidada;
- backup original;
- configuracao desejada;
- comandos por canal;
- checklist de testes;
- diagnostico;
- logs;
- bloco LocaliTel.

## Experiência visual

- o Tracker Studio usa o design system técnico local, com superfícies escuras,
  grid/radar de baixa intensidade e cores semânticas para telemetria;
- mudanças entre Agenda, Teste Rápido e Laboratório usam apenas transições
  implícitas do Flutter (fade e deslocamento curto), sem loop contínuo ou
  dependência adicional;
- o mapa é exibido dentro do card de localização quando há coordenadas e pode
  ser expandido para inspeção; ele continua sendo apenas visualização local;
- a cobertura LocaliTel é consultada pela ponte HTTP da API Tracker. A
  credencial do provedor permanece somente no ambiente da API e nunca é
  enviada ao aplicativo;
- a aprovação de um teste é persistente na sessão. Leituras posteriores ficam
  nos logs e não são concatenadas no card, evitando dados repetidos.

## Regras corrigidas desde a migracao

- rede conectada por GPRS nao deve aparecer como aguardando por causa de um campo bruto isolado;
- codigo de rede `255` gera aviso, mas nao sobrescreve pacote GPRS real;
- teste concluido nao deve resetar para 0/3 por leitura parcial;
- endereco vem da LocaliTel ou do cache de ultima consulta valida;
- bateria backup ST8210 com valor maior que 0 deve aparecer como presente;
- bloqueio/desbloqueio so deve aprovar com readback ou estado observado.

## Proximo passo

Substituir `TrackerSessionState.demo()` por provider real conectado ao motor do configurador:

1. porta serial;
2. parser ST8210/ST310;
3. checklist persistente por sessao;
4. cliente LocaliTel;
5. comando SMS/GPRS;
6. restauracao por backup.
