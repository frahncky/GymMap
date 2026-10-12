<div align="center">

<img src="assets/logo/logoGymMap_splash_icon.png" alt="Logo do GymMap" width="140" />

# GymMap

**Encontre academias perto de você e saiba quão cheias elas estão — antes de sair de casa.**

Mapa de academias com lotação colaborativa em tempo real, histórico, horários de pico e previsão.

[![Flutter](https://img.shields.io/badge/Flutter-3.29+-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.7+-0175C2?logo=dart&logoColor=white)](https://dart.dev)
[![Plataforma](https://img.shields.io/badge/plataforma-Android%20%7C%20iOS-0D8B6E)](#)
[![Mapas](https://img.shields.io/badge/mapas-OpenStreetMap-7EBC6F?logo=openstreetmap&logoColor=white)](https://www.openstreetmap.org)
[![Versão](https://img.shields.io/badge/versão-1.0.0-C79A22)](pubspec.yaml)

[Funcionalidades](#-funcionalidades) ·
[Planos](#-planos) ·
[Como rodar](#-como-rodar) ·
[Arquitetura](#-arquitetura) ·
[Documentação técnica](docs/BACKEND.md)

</div>

---

## ✨ Funcionalidades

| | |
|---|---|
| 🗺️ **Mapa de academias** | Academias carregadas automaticamente conforme você move o mapa (dados do OpenStreetMap), com busca por nome ou endereço. |
| 👥 **Lotação colaborativa** | Os próprios usuários informam a lotação e todos veem o nível em tempo real: baixa, moderada, alta ou muito alta. |
| 🕒 **Aberta ou fechada** | Indicador de academia fechada; a lotação é ocultada fora do horário de funcionamento. |
| 📈 **Histórico e horários de pico** | Série das últimas 24h e os horários mais movimentados de cada dia. |
| ⚖️ **Comparativo** | Compare a lotação entre academias próximas para escolher a melhor opção. |
| 🔮 **Previsão e alertas** | Previsão de lotação para as próximas horas e alertas personalizados. |
| ⭐ **Favoritos** | Salve suas academias e acompanhe-as rapidamente. |
| 💬 **Comunidade** | Feed com os relatos de lotação dos usuários, que podem confirmar ou contestar cada relato. |
| 👤 **Perfil e conta** | Comece sem cadastro (conta anônima no aparelho) e crie usuário e senha quando quiser, sem perder seus dados. |

## 💎 Planos

| Recurso | Grátis | Essencial | Pro | Elite |
|---|:---:|:---:|:---:|:---:|
| Lotação atual | ✅ | ✅ | ✅ | ✅ |
| Histórico das últimas 24h | | ✅ | ✅ | ✅ |
| Horários de pico por dia | | | ✅ | ✅ |
| Comparativo entre academias | | | ✅ | ✅ |
| Previsão para as próximas horas | | | | ✅ |
| Alertas personalizados | | | | ✅ |
| Cobertura em qualquer lugar do país | | | | ✅ |
| **Preço** | **R$ 0** | **R$ 4,90/mês** | **R$ 19,90/mês** | **R$ 34,90/mês** |

Assinaturas pelo **Google Play Billing** (renovação automática) com **Pix** como alternativa. Na troca entre planos pagos via Pix, cobra-se apenas a diferença proporcional do ciclo.

## 🚀 Como rodar

**Pré-requisitos:** [Flutter](https://docs.flutter.dev/get-started/install) (Dart 3.7+) e um emulador ou aparelho Android/iOS.

```bash
git clone https://github.com/frahncky/GymMap.git
cd GymMap
flutter pub get
flutter run
```

O app funciona sozinho em modo local. Para usar contas, assinaturas e lotação compartilhada, suba o backend e aponte o app para ele:

```bash
cd backend && dart pub get && cd ..
dart run backend/server.dart        # sobe em http://localhost:8080

flutter run --dart-define PLAN_BACKEND_BASE_URL=http://10.0.2.2:8080
```

> **Endereço do backend:** emulador Android `http://10.0.2.2:8080` · simulador iOS `http://127.0.0.1:8080` · aparelho físico: IP da máquina na rede local (ex.: `http://192.168.0.10:8080`).

### Configuração opcional (`--dart-define`)

| Variável | Para que serve |
|---|---|
| `PLAN_BACKEND_BASE_URL` | URL do backend de contas e assinaturas |
| `PLAN_PRODUCTION_MODE=true` | Desliga o fallback local de cobrança e exige backend + usuário autenticado |
| `MAP_TILE_URL_TEMPLATE` / `MAP_TILE_ATTRIBUTION` | Provedor de tiles do mapa (padrão: OpenStreetMap) |
| `OVERPASS_API_URL` | Instância Overpass usada para buscar academias |
| `NOMINATIM_BASE_URL` | Instância Nominatim usada na busca de endereços |

### Testes

```bash
flutter analyze
flutter test
```

## 🧱 Arquitetura

```
GymMap/
├── lib/
│   ├── main.dart                   # App e navegação (Mapa · Favoritos · Comunidade · Perfil)
│   ├── core/                       # Serviços compartilhados (métricas)
│   └── features/gym_map/
│       ├── data/                   # Lotação colaborativa, cache, assinaturas, notificações
│       ├── domain/                 # Modelos de academia, planos e insights
│       └── presentation/           # Tela do mapa, painéis e widgets
├── backend/                        # API em Dart: auth (JWT), Pix, Google Play, relatos de lotação
├── scripts/                        # Build e release gate de produção (PowerShell)
├── env/                            # Exemplos de configuração do app em produção
└── test/                           # Testes unitários e de widget
```

**Stack:** Flutter · `flutter_map` + OpenStreetMap (Overpass / Nominatim) · `geolocator` · `in_app_purchase` · `google_mobile_ads` · `flutter_local_notifications` · backend em Dart com Postgres (ou arquivo JSON em desenvolvimento) e Docker.

## 📚 Documentação técnica

O guia completo de backend e produção está em **[docs/BACKEND.md](docs/BACKEND.md)**:

- Assinatura do app Android para a Play Store
- Endpoints da API (auth, assinaturas, Pix, Google Play, métricas)
- Deploy em produção com Docker + Postgres e variáveis de ambiente
- Contrato e assinatura HMAC dos webhooks Pix (incluindo Mercado Pago)
- Backup/restore do Postgres e operação em produção

## 🤝 Contribuindo

1. Crie uma branch a partir da `main`.
2. Rode `flutter analyze` e `flutter test` antes de abrir o PR.
3. Descreva no PR o que mudou e como testar.

---

<div align="center">
Feito com 💪 e Flutter · Dados de mapa © colaboradores do <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>
</div>
