# Bradial Webhook

Integração em ASP.NET Core que recebe eventos de atendimento da Bradial e envia uma notificação ao Telegram quando uma conversa é transferida para um departamento configurado.

## O que o projeto demonstra

- Recebimento e validação de webhooks em uma API REST;
- processamento de eventos JSON e identificação de alterações no departamento;
- integração com a Telegram Bot API usando `HttpClient`;
- configuração de segredos fora do código-fonte;
- instalação e atualização como serviço do Windows, com túnel ngrok.

## Fluxo

```text
Bradial → HTTPS/ngrok → API ASP.NET Core → Telegram Bot API
```

O endpoint `POST /api/webhook/bradial` valida o segredo da URL, aceita JSON de até 64 KB e processa eventos `conversation_updated`. Quando `team_id.current_value` corresponde ao departamento configurado, envia ao chat do Telegram o nome e o telefone recebidos no evento.

O endpoint `GET /api/webhook/bradial` permite verificar a disponibilidade do serviço. Ele não exige o segredo do POST.

## Tecnologias

C#, ASP.NET Core (.NET 10), PowerShell, Windows Services, ngrok e Telegram Bot API.

## Executar localmente

Instale o .NET SDK 10 e configure um bot e um chat no Telegram. Defina o ID do departamento em `Bradial:DepartamentoUrgenteId` e armazene os demais valores com user-secrets:

```powershell
dotnet user-secrets set "Telegram:Token" "SEU_TOKEN"
dotnet user-secrets set "Telegram:ChatId" "SEU_CHAT_ID"
dotnet user-secrets set "Bradial:WebhookSecret" "UM_SEGREDO_COM_PELO_MENOS_32_CARACTERES"
dotnet user-secrets set "Bradial:DepartamentoUrgenteId" "ID_DO_DEPARTAMENTO"
dotnet run
```

Um modelo das chaves está em [appsettings.example.json](appsettings.example.json). Não publique valores reais em commits, issues ou capturas de tela.

## Instalação no Windows

Em PowerShell aberto como administrador, na raiz do projeto:

```powershell
.\scripts\install.ps1 -PublicDomain "seu-dominio.ngrok-free.dev" -DepartamentoUrgenteId 12345
```

O instalador solicita os tokens, gera um segredo para o webhook e configura a aplicação e o ngrok como serviços do Windows. A máquina precisa permanecer ligada e conectada à internet.

Comandos de manutenção:

```powershell
.\scripts\diagnose.ps1
.\scripts\update.ps1
.\scripts\uninstall.ps1
```

Leia [MIGRACAO.md](MIGRACAO.md) para transferência entre máquinas, [SECURITY.md](SECURITY.md) para cuidados com segredos e [CHANGELOG.md](CHANGELOG.md) para o histórico técnico.

## Autoria e contexto

Projeto desenvolvido por Alexsander Castro para automatizar notificações de atendimentos urgentes. Antes de reutilizá-lo em outro ambiente, configure seus próprios acessos, domínio e identificadores.