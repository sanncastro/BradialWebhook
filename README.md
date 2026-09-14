# Bradial Webhook

Serviço ASP.NET Core que recebe eventos da Bradial, identifica quando um atendimento é transferido para o departamento urgente e envia uma notificação pelo Telegram.

## Arquitetura

```text
Bradial
   |
   | HTTPS + segredo na URL
   v
ngrok (Serviço do Windows)
   |
   | http://127.0.0.1:5200
   v
BradialWebhook (Serviço do Windows)
   |
   | HTTPS
   v
Telegram Bot API
```

O computador precisa permanecer ligado, conectado à internet e sem suspensão. O Visual Studio e terminais não precisam permanecer abertos.

## Funcionamento

O endpoint `POST /api/webhook/bradial`:

1. valida o segredo informado em `?secret=...`;
2. aceita somente JSON e limita o corpo a 64 KB;
3. processa somente eventos `conversation_updated`;
4. confirma que `team_id.current_value` corresponde ao departamento urgente;
5. envia nome e telefone do cliente ao Telegram.

O endpoint `GET /api/webhook/bradial` é uma verificação de disponibilidade e não exige segredo.

## Requisitos

- Windows 10, Windows 11 ou Windows Server 64 bits;
- PowerShell 5.1 ou superior;
- .NET SDK 10 para compilar e publicar;
- conta e domínio reservado no ngrok;
- bot e chat configurados no Telegram;
- PowerShell executado como administrador para instalar serviços.

## Desenvolvimento local

Configure os segredos do usuário sem colocá-los em arquivos:

```powershell
dotnet user-secrets set "Telegram:Token" "SEU_TOKEN"
dotnet user-secrets set "Telegram:ChatId" "SEU_CHAT_ID"
dotnet user-secrets set "Bradial:WebhookSecret" "UM_SEGREDO_COM_PELO_MENOS_32_CARACTERES"
```

Depois execute:

```powershell
dotnet run
```

## Instalação como servidor local

Abra o PowerShell como administrador na raiz do projeto:

```powershell
.\scripts\install.ps1 -PublicDomain "seu-dominio.ngrok-free.dev"
```

O instalador solicita os tokens sem mostrá-los na tela, gera um segredo de webhook e instala:

- `BradialWebhook`, executado como `LocalService`;
- `ngrok`, executado como `LocalSystem`;
- recuperação automática após falhas;
- inicialização automática atrasada;
- executáveis e configurações em `C:\Services`.

Ao final, copie a URL exibida pelo instalador para a configuração do webhook na Bradial.

## Operação

Diagnóstico completo:

```powershell
.\scripts\diagnose.ps1
```

Publicar uma nova versão preservando segredos e serviços:

```powershell
.\scripts\update.ps1
```

Remover os serviços:

```powershell
.\scripts\uninstall.ps1
```

Para remover também os arquivos instalados:

```powershell
.\scripts\uninstall.ps1 -RemoveFiles
```

## Configurações

| Chave | Obrigatória | Finalidade |
|---|---:|---|
| `Telegram__Token` | Sim | Token do bot do Telegram |
| `Telegram__ChatId` | Sim | Chat que recebe notificações |
| `Bradial__WebhookSecret` | Sim | Autenticação do webhook |
| `Bradial__DepartamentoUrgenteId` | Sim | ID do departamento urgente |
| `AllowedHosts` | Sim | Hosts locais e domínio público aceitos |
| `NGROK_AUTHTOKEN` | Sim | Autenticação do agente ngrok |

Em produção, essas configurações ficam no ambiente protegido dos Serviços do Windows. Nunca registre seus valores no GitHub.

## Documentação adicional

- [Migração para outra máquina ou conta](MIGRACAO.md)
- [Histórico de mudanças](CHANGELOG.md)
- [Práticas de segurança](SECURITY.md)
- [Configuração de exemplo](appsettings.example.json)

## Publicação no GitHub

Antes do primeiro envio, execute o diagnóstico de segurança:

```powershell
.\scripts\diagnose.ps1 -ScanRepository
```

Em seguida, inicialize o Git somente se esta pasta ainda não for um repositório:

```powershell
git init
git add .
git status
git commit -m "Documenta instalação e migração do BradialWebhook"
```

Crie no GitHub um repositório **privado e vazio** (sem README, `.gitignore` ou licença gerados pelo site). Depois conecte e envie o projeto:

```powershell
git remote add origin https://github.com/SEU-USUARIO/BradialWebhook.git
git push -u origin main
```

Nas próximas atualizações:

```powershell
git add .
git status
git commit -m "Descreva resumidamente a alteração"
git push
```

Revise sempre o resultado de `git status` antes de cada commit. A pasta local já pode ser reconstruída apenas com o repositório e com os segredos guardados separadamente.
