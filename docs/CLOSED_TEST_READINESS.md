# Teste fechado Android

Esta lista exige evidências da versão que será enviada, não de builds antigos.

- [x] Chave de upload criada para a primeira publicação; release não usa assinatura de debug como alternativa.
- [ ] Cópia de segurança da chave e de `android/key.properties` guardada fora do projeto.
- [x] Política preparada com responsável DevIA e contato; link adicionado ao app.
- [x] Exclusão de conta e dados implementada no app e em página para navegador.
- [ ] Backend atualizado implantado; páginas públicas acessíveis e declaradas no Play Console.
- [ ] API de produção responde em HTTPS e persiste os dados após reinício.
- [ ] Assinaturas e restauração testadas com conta de teste da Play.
- [x] Análise sem problemas e testes aprovados: 60 do app e 7 do backend.
- [ ] AAB atual gerado com configuração de produção e assinatura de upload.
- [ ] Instalação pela faixa de teste em aparelho real: mapa, localização negada/permitida, cadastro, login, relatos, rede indisponível e exclusão de conta.
- [ ] Play Console: ficha da loja, Segurança dos dados, classificação, anúncios, acesso ao app e testadores conferidos.

Não marcar etapas externas como concluídas apenas por uma compilação local passar.

A URL do provedor anterior foi removida da configuração local. A geração do
AAB de publicação exige a URL HTTPS real da nova API. O projeto Firebase
`gymmap-devia-b77b38` foi criado e vinculado ao repositório em `.firebaserc`,
inicialmente no plano Spark, sem conta de faturamento vinculada. A ativação do
Blaze e a adaptação/implantação do backend no Firebase ainda estão pendentes.
