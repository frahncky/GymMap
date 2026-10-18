# Guia de linguagem do GymMap

Como o GymMap fala com quem usa o app. Vale para todo texto que aparece na tela,
notificação ou loja, em português e em inglês. Os textos ficam em
`lib/l10n/app_pt.arb` (base) e `lib/l10n/app_en.arb`.

## Voz

- **Parceiro de treino:** direto, amigável e útil. Fala com a pessoa ("você"),
  nunca sobre ela.
- **Frases curtas.** Uma ideia por frase.
- **Sem exagero e sem promessa que o app não cumpre.** Nada de números de
  usuários, notas ou "mais popular" sem dado real que os sustente.

## Glossário

| Use | Não use | Inglês |
| --- | --- | --- |
| relato (o que a pessoa envia sobre a lotação) | envio, contribuição, check-in | report |
| enviar relato | contribuir (no botão) | send report |
| confirmar / discordar (de um relato) | validar | confirm / disagree |
| lotação | ocupação, movimento (fora de alertas) | occupancy |
| trajeto (caminho até a academia) | rota, navegação | route |
| entrar / sair (da conta) | login, logout, autenticar | sign in / sign out |
| plano Grátis, Essencial, Pro, Elite | gratuito (como nome), free | Free, Essential, Pro, Elite |
| subir de plano | fazer upgrade | upgrade |
| pontos (por extenso) | pts | points |
| pino (no mapa) | pin, marcador | pin |
| ranking | top, leaderboard | ranking |
| Google Play | Play Store, checkout | Google Play |

## Erros e avisos

1. Diga **o que aconteceu** em palavras simples e **o que fazer**:
   "Não deu para confirmar a compra agora. Tente de novo mais tarde."
2. **Nunca mostre termos técnicos**: backend, webhook, token, gateway, modo
   produção, códigos HTTP, IDs de produto. Eles vão para os registros do app.
3. Não culpe a pessoa. Prefira "Não deu para…" a "Você errou…".
4. Quando houver espera, diga quanto: "Espere 2 min e tente de novo."

## Formato

- **Botões:** verbo no infinitivo, sem ponto final ("Enviar relato",
  "Ver trajeto").
- **Mensagens e explicações:** frases completas, com ponto final.
- **Reticências:** sempre o caractere "…", só para ações em andamento
  ("Carregando mapa…").
- **Tempo relativo:** "há 5 min", "há 2 h" (inglês: "5 min ago").
- **Separador em linha:** "·" ("Sua posição: #3 · 20 pontos").
- **Números e datas:** no formato do idioma (vírgula decimal em português).
- **Concordância:** "academia" é feminino ("academia adicionada",
  "academia tranquila").

## Inglês

Mesma voz e mesmo glossário, em inglês simples e natural. Contrações são bem-vindas
("Couldn't", "You're"). Não traduza nomes de planos nem marcas.

## Antes de publicar um texto

- Ele faz sentido para quem nunca abriu o app?
- Usa os termos do glossário?
- Existe nos dois idiomas? (O teste `test/app_english_l10n_test.dart` pega
  português esquecido nas telas principais.)
