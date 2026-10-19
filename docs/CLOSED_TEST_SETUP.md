# GymMap — preparação para o teste fechado

Identificador Android: `com.devia.gymmap`. Responsável: DevIA.
Suporte e privacidade: `francisco.dsantos.viana@gmail.com`.

Para hospedagem gratuita de teste, veja [NORTHFLANK_FREE.md](NORTHFLANK_FREE.md).

## Assinatura

A chave de upload fica em `android/keystore/gymmap-upload.jks` e as credenciais
em `android/key.properties`. Esses arquivos são ignorados pelo Git. Guarde uma
cópia segura de ambos fora deste projeto antes de enviar o primeiro AAB. Não
substitua a chave após o primeiro envio sem seguir o processo da Play Console.

O script `scripts/setup_android_signing.ps1` preserva chaves existentes. A opção
`-CreateIfMissing` é apenas para uma primeira publicação. Builds de release não
usam mais uma chave de debug como alternativa.

## Servidor e páginas públicas

O backend atualizado fornece:

- `GET /privacy`: política de privacidade.
- `GET /delete-account`: exclusão pelo navegador ou contato de suporte.
- `POST /v1/account/delete`: exclusão autenticada com confirmação explícita;
  contas cadastradas exigem a senha atual.

O Dockerfile inclui as páginas na imagem final. A implantação deve usar a raiz
do repositório como contexto e `backend/Dockerfile` como Dockerfile. Por exemplo:

```powershell
docker build -f backend/Dockerfile -t gymmap-backend .
```

Na hospedagem escolhida, implante esta versão e mantenha as variáveis
de produção configuradas no painel. Não envie `.env.production`, senhas ou a
chave Android ao Git. Configure `HOST=0.0.0.0` e a porta fornecida pela hospedagem.
Não crie outro serviço ou banco pago sem avaliar o custo.

Após a implantação, confira:

```powershell
./scripts/check_production_api.ps1
```

O script exige HTTPS, saúde da API, modo de produção, validação de compras Play
configurada e páginas públicas acessíveis. Defina a URL HTTPS atribuída pela
hospedagem em `PLAN_BACKEND_BASE_URL` no arquivo `env/app.production.json`.
Uma expiração de conexão não comprova que o servidor está desligado: confira
também a conectividade do ambiente, os logs, o estado do serviço, a URL atribuída,
as configurações de domínio e a conexão ao PostgreSQL no painel da hospedagem.

## Validação e artefato

```powershell
./scripts/release_gate_production.ps1
```

Essa validação analisa e testa app e backend, valida o ambiente, consulta a API
online e gera `build/app/outputs/bundle/release/app-release.aab`. Para gerar
somente o artefato local, use `./scripts/build_app_production.ps1`.
`-SkipOnlineChecks` no release gate é uma exceção explícita para diagnóstico;
não comprova prontidão de publicação. `-SkipBuild` não valida um AAB novo.

## Play Console e aparelho

Cadastre estas URLs depois de confirmar que respondem publicamente:

- Política: `<URL_HTTPS_DO_BACKEND>/privacy`.
- Exclusão de conta: `<URL_HTTPS_DO_BACKEND>/delete-account`.

Declare os dados realmente tratados pelo app e SDKs em Segurança dos dados,
incluindo conta, contribuições, localização, pagamentos, identificadores e
anúncios conforme as opções habilitadas. Confira ficha, classificação, anúncios,
acesso para revisão, produtos de assinatura e lista de testadores no Console.

Instale a versão pela faixa de teste e confira: localização permitida e negada,
mapa, login/cadastro, envio de relatos e votos, perda de conexão, compra de teste,
restauração e exclusão. Excluir uma conta do GymMap não cancela a assinatura na
loja; o app e a página de exclusão oferecem o link de gerenciamento da Play.

Não desinstale uma versão de debug para instalar a release sem antes preservar
seus dados. As assinaturas diferentes podem impedir a atualização direta.
