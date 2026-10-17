<div align="center">

<img src="docs/readme/banner.svg" alt="GymMap — academias perto de você, com a lotação em tempo real" width="100%">

<br><br>

<img src="assets/logo/logoGymMap_splash_icon.png" alt="GymMap" width="104">

# GymMap

**Encontre academias perto de você e saiba quão cheias elas estão — antes de sair de casa.**

[![Flutter](https://img.shields.io/badge/Flutter-3.29+-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.7+-0175C2?logo=dart&logoColor=white)](https://dart.dev)
[![Plataformas](https://img.shields.io/badge/plataformas-Android%20·%20iOS-1FB5A3)](#-como-executar)
[![Mapas](https://img.shields.io/badge/mapas-OpenStreetMap%20·%20vetorial-7EBC6F?logo=openstreetmap&logoColor=white)](https://www.openstreetmap.org)

[Sobre](#-sobre) ·
[Funcionalidades](#-funcionalidades) ·
[Lotação](#-como-funciona-a-lotação) ·
[Planos](#-planos) ·
[Como executar](#-como-executar) ·
[Arquitetura](#-arquitetura)

</div>

---

## ✨ Sobre

O **GymMap** mostra no mapa as academias ao seu redor e quão cheias elas estão agora. A lotação é **colaborativa**: quem está na academia informa, a comunidade confirma ou contesta, e todo mundo vê o resultado em tempo real.

O app funciona **sem cadastro**: você começa com uma conta anônima no aparelho e cria usuário e senha quando quiser, sem perder favoritos nem histórico.

## 🧭 Funcionalidades

<table>
  <tr>
    <td align="center" width="33%"><img src="docs/readme/icones/mapa.svg" width="40" alt=""><br><b>Mapa de academias</b><br><sub>Carregadas conforme você move o mapa, com busca por nome ou endereço</sub></td>
    <td align="center" width="33%"><img src="docs/readme/icones/lotacao.svg" width="40" alt=""><br><b>Lotação colaborativa</b><br><sub>Relatos dos usuários com consenso e tolerância entre votos</sub></td>
    <td align="center" width="33%"><img src="docs/readme/icones/aberta.svg" width="40" alt=""><br><b>Aberta ou fechada</b><br><sub>Indicador de horário; a lotação some quando a academia está fechada</sub></td>
  </tr>
  <tr>
    <td align="center"><img src="docs/readme/icones/historico.svg" width="40" alt=""><br><b>Histórico de 24h</b><br><sub>Como a lotação variou ao longo do dia</sub></td>
    <td align="center"><img src="docs/readme/icones/horario.svg" width="40" alt=""><br><b>Horários de pico</b><br><sub>Os momentos mais movimentados de cada dia</sub></td>
    <td align="center"><img src="docs/readme/icones/comparativo.svg" width="40" alt=""><br><b>Comparativo</b><br><sub>Lotação lado a lado entre academias próximas</sub></td>
  </tr>
  <tr>
    <td align="center"><img src="docs/readme/icones/previsao.svg" width="40" alt=""><br><b>Previsão e alertas</b><br><sub>Lotação esperada nas próximas horas e avisos personalizados</sub></td>
    <td align="center"><img src="docs/readme/icones/favoritos.svg" width="40" alt=""><br><b>Favoritos</b><br><sub>Suas academias sempre à mão</sub></td>
    <td align="center"><img src="docs/readme/icones/comunidade.svg" width="40" alt=""><br><b>Comunidade</b><br><sub>Feed de relatos para confirmar ou contestar</sub></td>
  </tr>
</table>

## 📊 Como funciona a lotação

Cada relato informa um percentual de ocupação. O app combina os relatos recentes, descarta os que destoam do consenso e mostra o nível no próprio pino do mapa:

| Nível | Faixa | No mapa |
| --- | --- | :---: |
| **Baixa** | até 35% | ![](https://img.shields.io/badge/-22%25-4A7DBA) |
| **Moderada** | 36% a 65% | ![](https://img.shields.io/badge/-55%25-6A9ACF) |
| **Alta** | 66% a 85% | ![](https://img.shields.io/badge/-71%25-E09F3E) |
| **Muito alta** | acima de 85% | ![](https://img.shields.io/badge/-93%25-CC4A37) |

## 💎 Planos

| Recurso | Grátis | Essencial | Pro | Elite |
| --- | :---: | :---: | :---: | :---: |
| Lotação atual | ✅ | ✅ | ✅ | ✅ |
| Histórico das últimas 24h | | ✅ | ✅ | ✅ |
| Horários de pico por dia | | | ✅ | ✅ |
| Comparativo entre academias | | | ✅ | ✅ |
| Previsão para as próximas horas | | | | ✅ |
| Alertas personalizados | | | | ✅ |
| Cobertura em qualquer lugar do país | | | | ✅ |

<sub>Nos planos sem cobertura nacional, o mapa mostra academias em até 50 km da sua localização. Pagamento pelo Google Play ou Pix.</sub>

## 🚀 Como executar

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

<details>
<summary><b>Serviços de mapa configuráveis</b></summary>

<br>

| `--dart-define` | Padrão | Uso |
| --- | --- | --- |
| `MAPLIBRE_STYLE_URL` | OpenFreeMap *liberty* | Estilo vetorial (MapLibre Style JSON) do mapa base |
| `MAP_TILE_ATTRIBUTION` | `OpenStreetMap contributors` | Créditos exibidos no mapa (separados por `\|`) |
| `OVERPASS_API_URL` | `overpass-api.de` | Busca de academias; espelhos públicos e o Nominatim entram como reserva |
| `NOMINATIM_BASE_URL` | `nominatim.openstreetmap.org` | Busca de endereços e reserva da busca de academias |

Os servidores públicos do OpenStreetMap servem para desenvolvimento; em produção, use instâncias próprias ou um provedor pago.

</details>

<details>
<summary><b>Testes e análise</b></summary>

<br>

```bash
flutter analyze
flutter test
```

</details>

Deploy em produção e detalhes da API estão em **[docs/BACKEND.md](docs/BACKEND.md)**.

## 🧱 Arquitetura

| Pasta | Conteúdo |
| --- | --- |
| `lib/features/gym_map/domain` | Modelos de academia, lotação, planos e insights |
| `lib/features/gym_map/data` | Lotação colaborativa, assinaturas, cache de academias e serviços de mapa |
| `lib/features/gym_map/presentation` | Tela do mapa, painéis, marcadores e controles |
| `lib/core` | Serviços transversais, como métricas do app |
| `backend/` | Servidor Dart de contas, assinaturas e relatos de lotação |

**Tecnologias:** Flutter · Dart · flutter_map + vector_map_tiles · OpenStreetMap (Overpass / Nominatim) · Geolocator · In-App Purchase · Google Mobile Ads

---

<div align="center">
<sub>Feito com 💪 e Flutter · Dados de mapa © colaboradores do <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a></sub>
</div>
