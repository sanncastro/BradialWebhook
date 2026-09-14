# Segurança

## Dados secretos

Nunca publique:

- token do Telegram;
- Chat ID quando ele for considerado sensível pela organização;
- authtoken do ngrok;
- segredo usado na URL do webhook;
- arquivos de certificados ou perfis de publicação.

O repositório contém apenas nomes de configurações e exemplos fictícios. Os scripts solicitam os valores durante a instalação e os armazenam no ambiente dos Serviços do Windows.

## Se um segredo vazar

1. Telegram: gere um novo token no BotFather.
2. ngrok: revogue o authtoken no painel e gere outro.
3. Webhook: reinstale com um novo `WebhookSecret` e atualize a URL na Bradial.
4. Remova o segredo do histórico Git; apagá-lo somente do arquivo atual não é suficiente.
5. Considere o segredo comprometido mesmo que o repositório seja privado.

## Antes de publicar no GitHub

```powershell
.\scripts\diagnose.ps1 -ScanRepository
git status
git diff --cached
```

Não publique arquivos de `C:\Services`, o Registro do Windows, dumps de processo ou exportações de configuração contendo valores reais.

## Exposição da aplicação

- o Kestrel escuta apenas em `127.0.0.1:5200`;
- o acesso externo ocorre por HTTPS pelo ngrok;
- o POST exige segredo com no mínimo 32 caracteres;
- o corpo é limitado a 64 KB;
- somente JSON é processado;
- os logs não devem conter payloads integrais nem tokens.

## Atualizações

Revise periodicamente as dependências:

```powershell
dotnet list package --vulnerable --include-transitive
```

Baixe o ngrok somente do endereço oficial. O instalador valida a assinatura digital antes de substituir o executável.
