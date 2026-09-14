# Migração do BradialWebhook

Este documento permite reconstruir a solução em outra máquina ou sob outra conta sem depender do histórico das conversas no Codex.

## O que acompanha o repositório

- código-fonte da aplicação;
- modelo de configuração;
- definição do túnel ngrok;
- scripts de instalação, atualização, diagnóstico e remoção;
- histórico técnico e instruções operacionais.

## O que não acompanha o repositório

Por segurança, os itens abaixo precisam ser fornecidos novamente:

- token do bot do Telegram;
- ID do chat do Telegram;
- token da conta ngrok;
- segredo do webhook;
- configuração do webhook dentro da Bradial;
- serviços e permissões do Windows;
- histórico de conversas do Codex/ChatGPT.

## Antes de migrar

1. Confirme que o projeto atualizado está em um repositório Git privado.
2. Registre fora do GitHub qual conta é proprietária do bot, do ngrok e da Bradial.
3. Confirme o ID do departamento urgente.
4. Tenha acesso ao BotFather para rotacionar o token do Telegram, se necessário.
5. Tenha acesso ao painel do ngrok e ao domínio reservado.
6. Planeje uma janela curta de indisponibilidade.

Não copie tokens por mensagem, documento público ou commit Git. O procedimento recomendado é gerar novos tokens na nova conta.

## Instalação na nova máquina

### 1. Preparar a máquina

- instalar Git e .NET SDK 10;
- desabilitar suspensão automática;
- garantir conexão estável com a internet;
- copiar ou clonar o repositório;
- abrir PowerShell como administrador.

### 2. Instalar

Na raiz do projeto:

```powershell
.\scripts\install.ps1 `
  -PublicDomain "seu-dominio.ngrok-free.dev" `
  -DepartamentoUrgenteId 46497
```

O script solicitará:

- token do Telegram;
- Chat ID do Telegram;
- authtoken do ngrok.

O segredo do webhook é gerado automaticamente. Para preservar uma URL já configurada, informe-o explicitamente:

```powershell
.\scripts\install.ps1 `
  -PublicDomain "seu-dominio.ngrok-free.dev" `
  -WebhookSecret "SEGREDO_EXISTENTE_COM_32_OU_MAIS_CARACTERES"
```

### 3. Atualizar a Bradial

Copie exatamente a URL exibida pelo instalador:

```text
https://seu-dominio.ngrok-free.dev/api/webhook/bradial?secret=SEGREDO_GERADO
```

### 4. Validar

```powershell
.\scripts\diagnose.ps1
```

Depois transfira um atendimento de teste para o departamento urgente e confirme a mensagem no Telegram.

### 5. Encerrar a máquina antiga

Somente após validar a nova instalação:

```powershell
.\scripts\uninstall.ps1
```

Um domínio ngrok reservado deve ter apenas um agente ativo para evitar conflito.

## Atualização de versão

Na nova máquina, atualize o repositório e execute:

```powershell
git pull
.\scripts\update.ps1
```

O script republica a aplicação sem substituir os segredos do serviço.

## Recuperação e rollback

Antes de uma atualização importante, copie `C:\Services\BradialWebhook` para uma pasta de backup protegida. Se a nova versão falhar:

1. pare `BradialWebhook`;
2. restaure os arquivos da versão anterior;
3. inicie o serviço;
4. execute `diagnose.ps1`.

## Checklist final

- [ ] `BradialWebhook` está `Running`.
- [ ] `ngrok` está `Running`.
- [ ] `http://127.0.0.1:5200/api/webhook/bradial` responde 200.
- [ ] o domínio público responde 200.
- [ ] a Bradial usa a URL com o segredo correto.
- [ ] uma transferência urgente gera mensagem no Telegram.
- [ ] a máquina não entra em suspensão.
- [ ] os tokens não estão no GitHub.
