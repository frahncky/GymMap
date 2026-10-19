# Firebase do GymMap

- Projeto: `gymmap-devia-b77b38`
- Nome: GymMap
- Pacote Android: `com.devia.gymmap`
- [Abrir console do projeto](https://console.firebase.google.com/project/gymmap-devia-b77b38/overview)

O projeto foi criado sem ativar faturamento. O plano Blaze de outro projeto
não é transferido automaticamente: este projeto precisa ser vinculado à conta
de faturamento escolhida pelo responsável no Console.

As correções locais de assinatura, privacidade, exclusão de conta e testes já
estão no repositório. A configuração `.firebaserc` aponta para este projeto.
A API de produção ainda precisa ser adaptada e implantada. O backend atual é
Dart/PostgreSQL e não se torna uma Cloud Function apenas por criar o projeto.

Antes da implantação, definir os serviços que serão usados e suas cotas,
configurar os segredos somente no provedor e confirmar o faturamento. Firebase
Authentication/Firestore podem substituir partes do backend; tarefas como
validação de compras, Pix, recompensas e exclusão completa precisam continuar
sendo executadas em ambiente confiável de servidor.

Ao concluir a implantação, configurar a URL HTTPS real no app com
`scripts/set_production_backend.ps1`, revisar a verificação de saúde para a
arquitetura escolhida e gerar o AAB atualizado. As verificações atuais ainda
esperam o backend Dart com PostgreSQL.

Fonte: [Planos e faturamento do Firebase](https://firebase.google.com/docs/projects/billing/firebase-pricing-plans).
