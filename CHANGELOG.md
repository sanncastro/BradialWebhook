# Histórico de mudanças

As mudanças relevantes deste projeto são registradas neste arquivo.

## [Não publicado]

### Adicionado

- documentação para operação, segurança e migração;
- scripts idempotentes de instalação, atualização, diagnóstico e remoção;
- modelo de configuração sem segredos;
- regras adicionais para impedir publicação acidental de credenciais.

## [2026-09-14]

### Corrigido

- serviço ngrok deixou de depender do pacote Microsoft Store/MSIX;
- executável oficial assinado do ngrok passou a ser instalado em `C:\Services\ngrok`;
- caminho quebrado de uma versão removida do ngrok foi substituído por caminho permanente.

## [2026-07-22]

### Adicionado

- execução do ASP.NET Core como Serviço do Windows;
- publicação autossuficiente para Windows x64;
- serviços `BradialWebhook` e `ngrok` com inicialização automática;
- recuperação automática após falhas;
- execução da aplicação com privilégios reduzidos (`LocalService`);
- armazenamento dos segredos no ambiente protegido do serviço.

## [2026-07-13]

### Corrigido

- encaminhamento ngrok alterado para `http://127.0.0.1:5200`;
- remoção do redirecionamento HTTP para HTTPS atrás do túnel;
- tratamento de corpo vazio e JSON inválido;
- aceitação de `team_id` numérico ou textual;
- correção da URL relativa usada para chamar o Telegram;
- falhas do Telegram passaram a retornar erro explícito.

### Segurança

- token do Telegram removido do código-fonte;
- segredo obrigatório adicionado à URL do webhook;
- comparação do segredo em tempo constante;
- limite de 64 KB para o payload;
- aceite restrito a JSON;
- payloads com dados pessoais deixaram de ser gravados em arquivos;
- dependência `Microsoft.OpenApi` atualizada para uma versão corrigida.
