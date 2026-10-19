# GymMap no Northflank Sandbox

Preparação para teste fechado, sem usar Render e sem contratar recursos pagos.
Nenhum recurso foi provisionado por este documento.

O plano Sandbox oferece dois serviços, um banco e dois jobs gratuitos, com
compute sempre ativo. A plataforma exige um meio de pagamento para verificar
a identidade mesmo no plano gratuito. Escolha **Developer Sandbox**, use apenas
recursos marcados como gratuitos e não ative Pay-as-you-go, BYOC ou upgrades.
O provedor destina o Sandbox a testes, não a produção pública.

Fontes oficiais:

- [Plano e limites](https://northflank.com/pricing)
- [Verificação de pagamento e uso do Sandbox](https://northflank.com/docs/v1/application/billing/pricing-on-northflank)
- [Build e deploy](https://northflank.com/docs/v1/application/getting-started/build-and-deploy-your-code)
- [PostgreSQL](https://northflank.com/docs/v1/application/databases-and-persistence/deploy-databases-on-northflank/deploy-postgresql-on-northflank)

## Configuração concreta

1. Entre em https://app.northflank.com, selecione Developer Sandbox e conecte
   o GitHub que contém `frahncky/GymMap`.
2. Crie um projeto chamado `gymmap-teste`. Use uma região disponível no Sandbox
   e mantenha banco e API no mesmo projeto/região.
3. Crie um addon PostgreSQL com o plano gratuito e uma única instância. Aguarde
   ficar disponível. Não exponha o banco publicamente.
4. Crie um **Combined service** chamado `gymmap-api`, a partir deste repositório
   e da branch que contém as correções revisadas.
5. Configure build por Dockerfile, caminho `/backend/Dockerfile`, contexto `/`.
   Mantenha o plano gratuito e uma única instância. O Dockerfile já compila o
   servidor e inclui as páginas de privacidade e exclusão.
6. Adicione uma porta pública HTTP chamada `http`, porta interna `8080`.
   A plataforma gera o domínio HTTPS e o certificado; não é necessário comprar
   domínio. Não invente o endereço: copie o atribuído pelo painel.
7. Configure verificação de saúde HTTP `GET /v1/health` na porta `8080`.

## Variáveis do serviço

Use variáveis de runtime/secret group, nunca argumentos de build para segredos.
As variáveis existentes em `backend/.env.production` podem ser reaproveitadas
somente se contiverem credenciais reais e seguras. Não copie esse arquivo para
o Git nem para o chat.

| Variável | Configuração |
| --- | --- |
| `HOST` | `0.0.0.0` |
| `PORT` | `8080` |
| `BACKEND_PRODUCTION_MODE` | `true` |
| `DATABASE_URL` | Vincule o segredo `POSTGRES_URI` do addon ao nome `DATABASE_URL`; preserve as opções TLS fornecidas pelo painel |
| `CORS_ALLOW_ORIGIN` | Origem HTTPS pública atribuída à API, sem caminho |
| `JWT_HS256_SECRET` | Segredo aleatório forte exclusivo deste ambiente |
| `ADMIN_API_TOKEN` | Token aleatório forte, com pelo menos 24 caracteres |
| `WEBHOOK_SIGNING_SECRET` | Segredo real de assinatura de webhooks |
| `AUTH_DEFAULT_PASSWORD` | Vazio |
| `AUTH_USERS_JSON` | `{}`; usuários finais são criados pelo próprio app |
| `PLAY_PACKAGE_NAME` | `com.devia.gymmap` |
| `PLAY_SERVICE_ACCOUNT_JSON_BASE64` | Credencial da conta de serviço autorizada a validar compras no Play Console |
| `PLAY_PRODUCT_ID_SMART` | `smart_mensal` |
| `PLAY_PRODUCT_ID_PRO` | `pro_mensal` |
| `PLAY_PRODUCT_ID_ELITE` | `elite_mensal` |
| `PLAY_BILLING_ALLOW_UNVERIFIED` | `false` |
| `PIX_PROVIDER_MODE` | `external`, conforme a validação de produção existente |
| `PIX_PROVIDER_VENDOR` | `mercado_pago` se este for o provedor usado |
| `PIX_PROVIDER_BASE_URL` | URL real do provedor de pagamentos |
| `PIX_PROVIDER_API_KEY` | Credencial real do provedor de pagamentos |
| `PIX_MP_DEFAULT_PAYER_EMAIL` | E-mail exigido pela integração Mercado Pago |
| `PIX_MP_NOTIFICATION_URL` | `<URL_HTTPS_DA_API>/v1/webhooks/pix` |
| `TRUST_PROXY_HEADERS` | `true` se o ingresso da plataforma controlar esses cabeçalhos |

Para outros provedores Pix, confira também `WEBHOOK_TOKEN` e os caminhos de
cobrança no exemplo `backend/.env.production.example`. Não use credenciais
fictícias para apenas ultrapassar a validação.

O servidor agora interrompe a inicialização se o PostgreSQL falhar em produção,
em vez de usar silenciosamente um arquivo temporário do container.

## Finalização

Depois do deploy, confira os logs e abra a URL pública com `/v1/health`.
Atualize o app com a URL real usando:

```powershell
./scripts/set_production_backend.ps1 -BaseUrl 'https://DOMINIO_REAL_DA_API'
./scripts/check_production_api.ps1
./scripts/release_gate_production.ps1
```

Cadastre `<URL_HTTPS_DA_API>/privacy` e `/delete-account` no Play Console.
Enquanto não houver uma URL real de uma API implantada, a geração para
publicação permanece bloqueada. O arquivo `env/app.production.json` não contém
mais a URL do provedor anterior.
