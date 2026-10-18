// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get settingsLanguageTitle => 'Idioma';

  @override
  String get settingsLanguageSystem => 'Idioma do aparelho';

  @override
  String get settingsLanguagePortuguese => 'Português';

  @override
  String get settingsLanguageEnglish => 'English';

  @override
  String get planFreeActive => 'Plano gratuito ativo';

  @override
  String planValidUntil(String date) {
    return 'Válido até $date';
  }

  @override
  String durationDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dias',
      one: '1 dia',
    );
    return '$_temp0';
  }

  @override
  String durationHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count horas',
      one: '1 hora',
    );
    return '$_temp0';
  }

  @override
  String get durationUnderOneHour => 'menos de 1 hora';

  @override
  String planExpiresSoon(String plan, String window) {
    return 'Seu plano $plan expira em $window. Renovação somente manual, quando você decidir.';
  }

  @override
  String get authInitializing => 'Carregando sua conta…';

  @override
  String get authProductionNoBackend => 'Contas indisponíveis no momento.';

  @override
  String get authNoBackend => 'Contas indisponíveis no momento.';

  @override
  String get authProductionNeedsSession => 'Entre na sua conta para assinar.';

  @override
  String get authAnonymousAccount =>
      'Você está usando o app sem conta. Crie uma para não perder sua assinatura ao trocar de celular.';

  @override
  String authSessionActive(String user) {
    return 'Conectado como $user';
  }

  @override
  String get authNotSignedIn => 'Você não entrou na sua conta.';

  @override
  String get playUnavailable =>
      'A Google Play não está disponível neste aparelho.';

  @override
  String get playListenFailed =>
      'Não deu para acompanhar suas compras agora. Tente de novo mais tarde.';

  @override
  String get playLoadProductsFailed =>
      'Não deu para carregar os planos agora. Tente de novo mais tarde.';

  @override
  String get playProductsNotFound =>
      'Alguns planos não estão disponíveis agora.';

  @override
  String get playLoadProductsError =>
      'Não deu para carregar os planos agora. Tente de novo mais tarde.';

  @override
  String authTooManyAttemptsWait(String wait) {
    return 'Muitas tentativas de entrar. Espere $wait e tente de novo.';
  }

  @override
  String get authTooManyAttempts =>
      'Muitas tentativas de entrar. Espere um pouco e tente de novo.';

  @override
  String get authInvalidCredentials => 'Usuário ou senha inválidos.';

  @override
  String get authMissingCredentials => 'Informe usuário e senha.';

  @override
  String get authInvalidUsername =>
      'O usuário deve ter de 3 a 32 caracteres: letras minúsculas, números, ponto, hífen ou sublinhado.';

  @override
  String get authUsernameTaken => 'Este usuário já está em uso.';

  @override
  String get authPasswordTooShort =>
      'A senha precisa ter pelo menos 8 caracteres.';

  @override
  String get authAlreadyRegistered =>
      'Este aparelho já está ligado a uma conta.';

  @override
  String get authUnauthorized => 'Sua sessão expirou. Entre de novo.';

  @override
  String get authFailed => 'Não deu para entrar agora. Tente de novo.';

  @override
  String billingRateLimitedWait(String wait) {
    return 'Muitas tentativas. Espere $wait e tente de novo.';
  }

  @override
  String get billingRateLimited =>
      'Muitas tentativas. Espere um pouco e tente de novo.';

  @override
  String get billingProductionNeedsBackend =>
      'Assinaturas indisponíveis no momento. Tente mais tarde.';

  @override
  String get billingPlayNeedsBackend =>
      'Assinaturas indisponíveis no momento. Tente mais tarde.';

  @override
  String get billingProductionNeedsUser => 'Entre na sua conta para assinar.';

  @override
  String get billingProductNotFound =>
      'Este plano não está disponível na Google Play agora.';

  @override
  String get billingCheckoutNotStarted =>
      'Não deu para abrir o pagamento na Google Play. Tente de novo.';

  @override
  String get billingProductMissing =>
      'Não deu para identificar o plano. Tente de novo.';

  @override
  String get billingTokenMissing =>
      'Não deu para confirmar a compra. Tente de novo.';

  @override
  String get billingPurchaseNotActive =>
      'A Google Play ainda está processando sua compra. Tente de novo em alguns minutos.';

  @override
  String get billingPurchaseNotFound =>
      'Não encontramos essa compra na Google Play.';

  @override
  String get billingProductMismatch =>
      'A compra não corresponde ao plano escolhido.';

  @override
  String get billingPackageMismatch => 'Essa compra pertence a outro app.';

  @override
  String get billingPlayUnauthorized =>
      'Não deu para confirmar a compra agora. Tente de novo mais tarde.';

  @override
  String get billingValidationUnavailable =>
      'Não deu para confirmar a compra agora. Tente de novo mais tarde.';

  @override
  String get billingPendingWebhook =>
      'Seu pagamento ainda está sendo confirmado. Tente de novo em alguns segundos.';

  @override
  String get billingPixUnavailable =>
      'O Pix está indisponível no momento. Tente de novo em instantes.';

  @override
  String get billingInvalidWebhook =>
      'Não deu para confirmar o pagamento. Fale com o suporte.';

  @override
  String get billingSessionExpiredOrForbidden =>
      'Sua sessão expirou. Entre de novo.';

  @override
  String get billingSessionExpired => 'Sua sessão expirou. Entre de novo.';

  @override
  String get billingGenericFailure =>
      'Não deu para concluir a assinatura agora. Tente de novo.';

  @override
  String get planExpiredBackToFree =>
      'Sua assinatura terminou. Você voltou para o plano Grátis.';

  @override
  String get subscriptionInitializing =>
      'Os planos ainda estão carregando. Tente de novo em instantes.';

  @override
  String get planFreeActivated => 'Você está no plano Grátis.';

  @override
  String get authNoBackendForLogin => 'Contas indisponíveis no momento.';

  @override
  String authAccountCreated(String user) {
    return 'Conta criada. Boas-vindas, $user!';
  }

  @override
  String authSignedIn(String user) {
    return 'Você entrou como $user.';
  }

  @override
  String get authCreateAccount => 'Criar conta';

  @override
  String get authSignInMonthly => 'Entrar na sua conta';

  @override
  String get authUsernameLabel => 'Usuário';

  @override
  String get authUsernameHelper =>
      '3 a 32 caracteres: a-z, 0-9, ponto, hífen ou _';

  @override
  String get authPasswordLabel => 'Senha';

  @override
  String get authPasswordHelper => 'Mínimo de 8 caracteres';

  @override
  String get actionCancel => 'Cancelar';

  @override
  String get authCreating => 'Criando…';

  @override
  String get authSigningIn => 'Entrando…';

  @override
  String get authSignIn => 'Entrar';

  @override
  String get authNoSession => 'Você não entrou em nenhuma conta.';

  @override
  String get authSignedOut => 'Você saiu da sua conta.';

  @override
  String get authSignOutFailed => 'Não deu para sair agora. Tente de novo.';

  @override
  String get playFinishPayment =>
      'Conclua o pagamento na Google Play para ativar o plano.';

  @override
  String get playPurchaseFailed =>
      'Não deu para concluir a compra na Google Play.';

  @override
  String get playPaymentCanceled => 'Pagamento cancelado.';

  @override
  String get playUnknownProduct =>
      'Este plano não é reconhecido. Atualize o app e tente de novo.';

  @override
  String planActivatedSuccess(String plan) {
    return 'Plano $plan ativado!';
  }

  @override
  String get playFinalizeFailed =>
      'Compra confirmada. A Google Play ainda está finalizando o pagamento.';

  @override
  String get priceFreeMonthly => 'R\$ 0/mês';

  @override
  String pricePerMonth(String price) {
    return '$price/mês';
  }

  @override
  String get planCurrent => 'Plano atual';

  @override
  String get planContinueFree => 'Continuar no Grátis';

  @override
  String get planBackToFree => 'Voltar ao Grátis';

  @override
  String get planSubscribe => 'Assinar';

  @override
  String get planUpgrade => 'Subir de plano';

  @override
  String get planChange => 'Trocar plano';

  @override
  String promoUntil(String message, String deadline) {
    return '$message • até $deadline';
  }

  @override
  String get planIncludesPro => 'Inclui tudo do Pro';

  @override
  String get planStartFreeTrial => 'Começar teste grátis';

  @override
  String get planMostPopular => 'RECOMENDADO';

  @override
  String get planInstantAccess => 'Acesso imediato. Cancele quando quiser.';

  @override
  String get planFeatureLiveOccupancy => 'Lotação em tempo real';

  @override
  String get planFeatureHistory => 'Histórico 24h';

  @override
  String get planFeaturePeakCompare => 'Picos e comparativo';

  @override
  String get planFeatureForecast => 'Previsão e alertas';

  @override
  String get planFeatureNationwide => 'Cobertura nacional';

  @override
  String get planQuickComparison => 'Comparativo rápido';

  @override
  String planAvailableIn(String plan) {
    return 'Disponível no plano $plan';
  }

  @override
  String planUnavailableIn(String plan) {
    return 'Indisponível no plano $plan';
  }

  @override
  String get planAvailable => 'Disponível';

  @override
  String get planUnavailable => 'Indisponível';

  @override
  String get paywallTitle => 'Aproveite o GymMap ao máximo';

  @override
  String get paywallSubtitle =>
      'Escolha o plano ideal para lotação, previsão e comparativos.';

  @override
  String get subscriptionLoading => 'Carregando assinatura…';

  @override
  String get authSignOut => 'Sair';

  @override
  String get planContinueWithFree => 'Continuar no plano Grátis';

  @override
  String get actionClose => 'Fechar';

  @override
  String get planNameFree => 'Grátis';

  @override
  String get planNameSmart => 'Essencial';

  @override
  String get insightCurrentOccupancy => 'Lotação atual';

  @override
  String get insightHistory24h => 'Histórico das últimas 24h';

  @override
  String get insightPeakHours => 'Horários de pico por dia';

  @override
  String get insightCompareGyms => 'Comparativo entre academias';

  @override
  String get insightForecast => 'Previsão de lotação para próximas horas';

  @override
  String get insightNationwide => 'Cobertura em qualquer lugar do país';

  @override
  String get insightAlerts => 'Alertas personalizados';

  @override
  String get communityYourRegion => 'Sua região';

  @override
  String get communityRegionUnavailable => 'Região indisponível';

  @override
  String distanceMetersFromYou(String meters) {
    return '$meters m de você';
  }

  @override
  String distanceKmFromYou(String km) {
    return '$km km de você';
  }

  @override
  String get communityPhotoCaptionRecent =>
      'Foto recente enviada por quem treinou na unidade.';

  @override
  String get communityPhotoCaptionRecord =>
      'Registro recente da comunidade nessa academia.';

  @override
  String get distanceUnknown => 'Distância não informada';

  @override
  String timeAgoMinutes(String count) {
    return 'há $count min';
  }

  @override
  String timeAgoHours(String count) {
    return 'há $count h';
  }

  @override
  String timeAgoDays(String count) {
    return 'há $count d';
  }

  @override
  String get occupancyLevelLow => 'Baixa';

  @override
  String get occupancyLevelModerate => 'Moderada';

  @override
  String get occupancyLevelHigh => 'Alta';

  @override
  String get communityAnonymousUser => 'Usuário anônimo';

  @override
  String get communityYou => 'Você';

  @override
  String communityThanksValidation(String points) {
    return 'Obrigado por confirmar! +$points pontos.';
  }

  @override
  String get communityTitle => 'Comunidade';

  @override
  String get communityLoadingReports => 'Carregando relatos da sua região…';

  @override
  String get communityNoReportsYet =>
      'Ainda não há relatos recentes das academias da sua região.';

  @override
  String get communityRecentRegionReports =>
      'Relatos recentes das academias da sua região.';

  @override
  String get communityFeedDescription =>
      'Relatos recentes de quem treina perto de você.';

  @override
  String get communityTopContributors => 'Quem mais contribuiu na semana';

  @override
  String communityYourPosition(String rank) {
    return 'Sua posição: $rank';
  }

  @override
  String communityRegion(String region) {
    return 'Região: $region';
  }

  @override
  String get communityNotEnoughRanking =>
      'Ainda não há relatos suficientes para um ranking.';

  @override
  String get communityEnableLocationRanking =>
      'Ative a localização para ver o ranking da sua região.';

  @override
  String get communityRealDataWeek => 'Dados reais dos últimos 7 dias';

  @override
  String communityPointsShort(String points) {
    return '$points pontos';
  }

  @override
  String communityYourPoints(String points) {
    return 'Seus pontos: $points';
  }

  @override
  String get communityPointsPerValidation => '+2 pontos por confirmação';

  @override
  String get communityContributeOnMap => 'Contribuir no mapa';

  @override
  String get communityRecentRegionTitle => 'Relatos recentes da sua região';

  @override
  String get communityRecentTitle => 'Relatos recentes';

  @override
  String get communityRefreshReports => 'Atualizar relatos';

  @override
  String get communityEmptyRegion =>
      'Sem relatos recentes na sua região agora. Abra o mapa e contribua para aparecer aqui.';

  @override
  String get communityEnableLocationReports =>
      'Ative sua localização para ver relatos recentes da sua região.';

  @override
  String get communityPhotoByCommunity => 'Foto enviada pela comunidade.';

  @override
  String communityConfirm(String count) {
    return 'Confirmo ($count)';
  }

  @override
  String communityDisagree(String count) {
    return 'Discordo ($count)';
  }

  @override
  String get profileDefaultName => 'Usuário GymMap';

  @override
  String get profileSavePreferenceFailed =>
      'Não foi possível salvar esta preferência agora.';

  @override
  String get profileLoadPhotoFailed => 'Não foi possível carregar a foto.';

  @override
  String get profilePickPhotoFailed => 'Não foi possível selecionar a foto.';

  @override
  String get profileNameRequired => 'Informe um nome para o perfil.';

  @override
  String get profileSaveFailed => 'Não foi possível salvar o perfil.';

  @override
  String get profileEdit => 'Editar perfil';

  @override
  String get profileChangePhoto => 'Trocar foto';

  @override
  String get profileRemovePhoto => 'Remover';

  @override
  String get profileNameLabel => 'Nome';

  @override
  String get profileNameHint => 'Como você quer aparecer';

  @override
  String get actionSave => 'Salvar';

  @override
  String get profileUpdated => 'Perfil atualizado.';

  @override
  String get profileTitle => 'Perfil';

  @override
  String profileCurrentPlan(String plan) {
    return 'Plano atual: $plan';
  }

  @override
  String get profileVisible => 'Perfil visível';

  @override
  String get profilePrivate => 'Perfil privado';

  @override
  String get actionOpenMap => 'Abrir mapa';

  @override
  String get profilePublicTitle => 'Permitir visualização pública';

  @override
  String get profilePublicSubtitle =>
      'Permite que seu nome e foto apareçam na comunidade.';

  @override
  String get profilePushTitle => 'Notificações';

  @override
  String get profilePushSubtitle => 'Receber alertas de lotação e novidades.';

  @override
  String get profileLocationAlertsTitle => 'Alertas por localização';

  @override
  String get profileLocationAlertsSubtitle =>
      'Avisar quando houver academia com lotação baixa perto de você.';

  @override
  String get profileHapticsTitle => 'Vibração';

  @override
  String get profileHapticsSubtitle => 'Vibrar em ações importantes.';

  @override
  String get profileDataSaverTitle => 'Economia de dados';

  @override
  String get profileDataSaverSubtitle =>
      'Reduzir atualizações em segundo plano.';

  @override
  String get favoritesDefaultName => 'Academia favorita';

  @override
  String get favoritesLoadFailed => 'Não foi possível carregar seus favoritos.';

  @override
  String get actionRetry => 'Tentar novamente';

  @override
  String get favoritesTitle => 'Favoritos';

  @override
  String get favoritesEmpty => 'Você ainda não marcou academias favoritas.';

  @override
  String favoritesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count academias salvas.',
      one: '1 academia salva.',
    );
    return '$_temp0';
  }

  @override
  String get favoritesHint =>
      'Use o ícone de coração no painel da academia para salvar seus favoritos.';

  @override
  String get favoritesViewMap => 'Ver mapa';

  @override
  String get navMap => 'Mapa';

  @override
  String get navFavorites => 'Favoritos';

  @override
  String get navCommunity => 'Comunidade';

  @override
  String get navProfile => 'Perfil';

  @override
  String headerCommunityPointsLabel(String points) {
    return 'Pontos da comunidade: $points';
  }

  @override
  String get headerCommunityPointsHint => 'Toque para abrir o ranking semanal';

  @override
  String get headerOpenRanking => 'Abrir ranking da comunidade';

  @override
  String get headerPlanSettings => 'Planos e assinatura';

  @override
  String get headerPlanSettingsHint => 'Toque para abrir opções de assinatura';

  @override
  String get searchFieldLabel => 'Campo de busca';

  @override
  String get searchFieldHint => 'Digite academia, bairro ou cidade';

  @override
  String get searchPlaceholder => 'Buscar academia, bairro ou cidade';

  @override
  String get searchLocationTooltip => 'Buscar localização';

  @override
  String get searchClearTooltip => 'Limpar busca';

  @override
  String filterSemanticsLabel(String filter) {
    return 'Filtro $filter';
  }

  @override
  String get filterTapToRemove => 'Toque novamente para remover o filtro';

  @override
  String get filterTapToApply => 'Toque para aplicar o filtro';

  @override
  String get emptyZoomIn =>
      'Aproxime o mapa para carregar academias automaticamente.';

  @override
  String get emptyNoFilterMatch =>
      'Nenhuma academia corresponde aos filtros ativos.';

  @override
  String get emptyNoSearchResults =>
      'Nenhum resultado encontrado para sua busca.';

  @override
  String get emptyNoNearbyGyms => 'Nenhuma academia encontrada perto de você.';

  @override
  String get filterClearAll => 'Limpar filtros';

  @override
  String get adLabel => 'Anúncio · assine um plano para remover.';

  @override
  String get tutorialTitle => 'Dicas rápidas do mapa';

  @override
  String get tutorialSearch => 'Use a busca para academia, bairro ou cidade.';

  @override
  String get tutorialFilters => 'Use os filtros para refinar os resultados.';

  @override
  String get tutorialPin =>
      'Toque no pino para ver detalhes e enviar um relato.';

  @override
  String get tutorialGotIt => 'Entendi';

  @override
  String get tutorialShowNearest => 'Ver próxima';

  @override
  String get tutorialSkip => 'Pular tutorial';

  @override
  String get panelFavoriteGym => 'Academia favorita';

  @override
  String get panelAddGymToFavorites => 'Adicionar academia aos favoritos';

  @override
  String get panelToggleFavoriteHint => 'Toque para alternar favorito';

  @override
  String get panelRemoveFavorite => 'Remover dos favoritos';

  @override
  String get panelAddFavorite => 'Adicionar aos favoritos';

  @override
  String get gymClosed => 'Fechada';

  @override
  String panelStatus(String status) {
    return 'Lotação: $status';
  }

  @override
  String get panelClosedNotice =>
      'Academia fechada agora. A lotação volta a aparecer quando abrir.';

  @override
  String panelReportsSummary(String total, String recent) {
    return '$total relatos no total · $recent recentes';
  }

  @override
  String panelLastReport(String time) {
    return 'Último relato: $time';
  }

  @override
  String get panelViewRoute => 'Ver trajeto';

  @override
  String get panelUpdateOccupancy => 'Como está a lotação agora?';

  @override
  String get panelSendingReport => 'Enviando relato…';

  @override
  String get panelContribute => 'Enviar relato';

  @override
  String get panelContributeClosed =>
      'Você pode enviar relatos quando a academia estiver aberta.';

  @override
  String get chartPeak => 'Pico';

  @override
  String get chartAverage => 'Média';

  @override
  String get panelPeakOfDay => 'Pico do dia';

  @override
  String get panelReference => 'referência';

  @override
  String get panelForecast => 'Previsão das próximas horas';

  @override
  String reportBlockedWait(String minutes) {
    return 'Você enviou um relato há pouco. Envie outro em $minutes min.';
  }

  @override
  String get subscriptionActivated => 'Assinatura ativada!';

  @override
  String planUnlocked(String plan) {
    return 'Plano $plan liberado!';
  }

  @override
  String get actionContinue => 'Continuar';

  @override
  String get communityCurrentLocation => 'Sua localização atual';

  @override
  String get communityCurrentRegion => 'Região atual';

  @override
  String get communityNoRanking => 'sem ranking';

  @override
  String get communityTop10 => 'As 10 pessoas que mais contribuíram na semana';

  @override
  String communityCurrentPosition(String rank, String points) {
    return 'Sua posição: $rank · $points pontos';
  }

  @override
  String get communityRankingUpdating => 'Atualizando ranking…';

  @override
  String get communityRankingRealInfo =>
      'Pontos dos últimos 7 dias. Cada relato válido vale +5 pontos.';

  @override
  String get communityRankingInfo =>
      'Cada relato válido vale +5 pontos. Continue contribuindo para subir no ranking.';

  @override
  String get communityRankingEmpty =>
      'Ainda não há pontos suficientes nesta região.';

  @override
  String get locationNotificationTitle => 'GymMap está usando sua localização';

  @override
  String get locationNotificationText =>
      'Para avisar sobre academias tranquilas perto de você.';

  @override
  String get locationEnableGps => 'Ative o GPS para ver onde você está.';

  @override
  String get locationNoPermission =>
      'Sem acesso à localização. Você pode permitir depois nas configurações.';

  @override
  String get locationDeniedForever =>
      'O acesso à localização foi negado. Permita nas configurações do aparelho.';

  @override
  String get locationDenied => 'Acesso à localização negado.';

  @override
  String get locationTimeout =>
      'Sua localização demorou a responder. Tente de novo.';

  @override
  String get locationUnavailable =>
      'Não deu para encontrar sua localização agora.';

  @override
  String get locationPromptTitle => 'Permitir localização?';

  @override
  String get locationPromptBody =>
      'Com a localização ativa, o GymMap encontra academias próximas automaticamente e calcula distância em tempo real.';

  @override
  String get locationPromptLater => 'Agora não';

  @override
  String get locationPromptAllow => 'Permitir';

  @override
  String get controlsNorthLabel => 'Reorientar mapa para norte';

  @override
  String get controlsNorthHint =>
      'Toque para voltar a orientação para zero grau';

  @override
  String get controlsNorthTooltip => 'Reorientar para norte';

  @override
  String get controlsMyLocationLabel => 'Centralizar no meu local';

  @override
  String get controlsMyLocationHint =>
      'Toque para mover o mapa para a sua posição atual';

  @override
  String get controlsMyLocationTooltip => 'Minha localização';

  @override
  String get controlsUpdatingGymsLabel => 'Atualizando academias no mapa';

  @override
  String get controlsUpdatingGyms => 'Atualizando academias…';

  @override
  String get controlsYourLocation => 'Sua localização no mapa';

  @override
  String get coverageEnableLocation =>
      'Ative a localização para ver academias da sua região no plano atual.';

  @override
  String get coverageEliteOnly =>
      'Outras regiões são exclusivas do plano Elite.';

  @override
  String get filterOpenNow => 'Abertas agora';

  @override
  String get filterLowCrowd => 'Lotação baixa';

  @override
  String get filterClasses => 'Aulas';

  @override
  String get filterCardio => 'Cardio';

  @override
  String get filterPool => 'Com piscina';

  @override
  String get filterFavorites => 'Favoritas';

  @override
  String hoursOpenUntil(String time) {
    return 'Aberta até $time';
  }

  @override
  String hoursOpensAt(String time) {
    return 'Abre às $time';
  }

  @override
  String hoursOpensTomorrow(String time) {
    return 'Abre amanhã às $time';
  }

  @override
  String hoursToday(String open, String close) {
    return 'Hoje: $open - $close';
  }

  @override
  String get mapDisabledInTest => 'Mapa desativado no modo de teste';

  @override
  String get mapLocatingYou => 'Localizando você…';

  @override
  String get mapUnavailableRetry =>
      'Mapa indisponível. Toque para tentar de novo';

  @override
  String get mapLoading => 'Carregando mapa…';

  @override
  String get mapOpenGoogleMapsFailed =>
      'Não deu para abrir o Google Maps agora.';

  @override
  String favoriteAdded(String gym) {
    return '$gym adicionada aos favoritos.';
  }

  @override
  String favoriteRemoved(String gym) {
    return '$gym removida dos favoritos.';
  }

  @override
  String get tutorialNoGymToHighlight =>
      'Nenhuma academia disponível para destacar agora.';

  @override
  String get searchFailed => 'Não deu para buscar esse local agora.';

  @override
  String get searchNotFound =>
      'Local não encontrado. Tente bairro, cidade ou endereço.';

  @override
  String get searchParseFailed =>
      'Não entendemos esse local. Tente outro endereço.';

  @override
  String get searchTimeout => 'A busca demorou demais. Tente de novo.';

  @override
  String get searchError => 'Não deu para buscar esse local.';

  @override
  String get occupancyLevelVeryHigh => 'Muito alta';

  @override
  String get timeNoInfo => 'sem informações';

  @override
  String get timeNow => 'agora';

  @override
  String timeMinutesAgo(String count) {
    return 'há $count min';
  }

  @override
  String timeHoursAgo(String count) {
    return 'há $count h';
  }

  @override
  String markerOccupancySemantics(String percent) {
    return 'lotação de $percent por cento';
  }

  @override
  String get markerClosedNow => 'fechada agora';

  @override
  String get markerFavoriteSuffix => ', favorita';

  @override
  String get markerTapHint => 'Toque para abrir os detalhes da academia';

  @override
  String get markerGoodMoment => 'Bom momento';

  @override
  String reportThanks(String gym, String percent, String trust) {
    return 'Obrigado pelo relato! +5 pontos\n$gym agora em $percent% (confiança de $trust%).';
  }

  @override
  String get alertVeryHighNow =>
      'Lotação muito alta agora. Considere treinar em outro horário.';

  @override
  String alertBestWindow(String hour, String percent) {
    return 'Melhor horário previsto: por volta das ${hour}h ($percent%).';
  }

  @override
  String alertLessCrowded(String gym, String delta) {
    return '$gym está menos cheia agora ($delta pontos a menos).';
  }

  @override
  String get alertStableFlow => 'Movimento estável nas próximas horas.';

  @override
  String get pushChannelName => 'Alertas de lotação';

  @override
  String get pushChannelDescription =>
      'Avisos de academias tranquilas perto de você.';

  @override
  String get pushLowCrowdTitle => 'Academia tranquila perto de você';

  @override
  String pushLowCrowdBody(String gym, String percent, String distance) {
    return '$gym com $percent% agora, a $distance de você.';
  }

  @override
  String get gymFoundOnMap => 'Academia encontrada no mapa';

  @override
  String get controlsPlaces => 'Escolher locais do mapa';

  @override
  String get placesTitle => 'Locais no mapa';

  @override
  String get placesSubtitle =>
      'Marque o que você quer ver. As academias aparecem sempre.';

  @override
  String get placesShowAll => 'Mostrar tudo';

  @override
  String get placesHideAll => 'Ocultar tudo';

  @override
  String get placesTransport => 'Transporte (paradas de ônibus, estações)';

  @override
  String get placesFood => 'Alimentação';

  @override
  String get placesShops => 'Comércio';

  @override
  String get placesHealth => 'Saúde';

  @override
  String get placesEducation => 'Educação';

  @override
  String get placesServices => 'Serviços (bancos, correios…)';

  @override
  String get placesLeisure => 'Lazer e turismo';

  @override
  String get placesReligion => 'Templos e igrejas';

  @override
  String get placesOther => 'Outros';

  @override
  String get gymUnnamed => 'Academia';

  @override
  String get routeCalculating => 'Calculando trajeto…';

  @override
  String get routeFailed => 'Não foi possível calcular o trajeto agora.';

  @override
  String get routeWalking => 'A pé';

  @override
  String get routeDriving => 'Carro';

  @override
  String get routeOpenInGoogleMaps => 'Navegar no Google Maps';

  @override
  String get amenityWeights => 'Musculação';

  @override
  String get amenityCardio => 'Cardio';

  @override
  String get amenityGroupClasses => 'Aulas coletivas';

  @override
  String get amenityPool => 'Piscina';

  @override
  String get routeHideCard => 'Ocultar cartão (o trajeto continua no mapa)';

  @override
  String get routeEnd => 'Encerrar trajeto';

  @override
  String get routeRecalculating => 'Recalculando trajeto…';

  @override
  String get routeArrived => 'Você chegou à academia.';

  @override
  String get amenityCrossfit => 'Crossfit';

  @override
  String get amenityPilates => 'Pilates';

  @override
  String get amenityMartialArts => 'Lutas';

  @override
  String get amenityFunctionalDance => 'Dança e funcional';

  @override
  String get amenityLockerRoom => 'Vestiário com chuveiro';

  @override
  String get amenityAirConditioning => 'Ar-condicionado';

  @override
  String get amenityParking => 'Estacionamento';

  @override
  String get amenityAccessibility => 'Acessibilidade';

  @override
  String get amenityOpen24h => 'Aberta 24h';

  @override
  String get amenityPersonalTrainer => 'Personal trainer';

  @override
  String get amenityFitnessAssessment => 'Avaliação física';

  @override
  String get amenityAddTooltip => 'Marcar o que a academia oferece';

  @override
  String amenitySheetTitle(String gym) {
    return 'O que a $gym oferece?';
  }

  @override
  String amenitySheetSubtitle(String needed) {
    return 'Marque o que você sabe. Um item aparece para todos quando $needed pessoas confirmam.';
  }

  @override
  String amenityStatusConfirmed(String count) {
    return 'Confirmado por $count pessoas';
  }

  @override
  String amenityStatusPending(String count, String needed) {
    return '$count de $needed confirmações';
  }

  @override
  String get amenityStatusRejected => 'A comunidade diz que não tem';

  @override
  String get amenityPointsHint =>
      'Você ganha 2 pontos por item quando a comunidade confirmar o que você marcou.';

  @override
  String get amenitySave => 'Enviar';

  @override
  String amenitySaved(String points) {
    return 'Obrigado! +$points pontos.';
  }

  @override
  String get amenitySavedNoPoints =>
      'Obrigado! Você ganha pontos quando outras pessoas confirmarem.';

  @override
  String get amenitySaveFailed =>
      'Não deu para enviar agora. Tente de novo mais tarde.';

  @override
  String get amenityUnavailable =>
      'Marcar o que a academia oferece não está disponível agora.';

  @override
  String get rewardsTitle => 'Troque seus pontos';

  @override
  String rewardsOffer(String cost, String days) {
    return '$cost pontos = $days dias do plano Essencial';
  }

  @override
  String rewardsProgress(String balance, String cost) {
    return 'Você tem $balance de $cost pontos';
  }

  @override
  String get rewardsHowToEarn =>
      '+5 pontos por relato e +2 por item que você marcou e a comunidade confirmou.';

  @override
  String rewardsRedeem(String days) {
    return 'Trocar por $days dias';
  }

  @override
  String rewardsRedeemed(String days) {
    return 'Pronto! Você ganhou $days dias do plano Essencial.';
  }

  @override
  String get rewardsHigherPlan => 'Seu plano já inclui tudo do Essencial.';

  @override
  String get rewardsFailed =>
      'Não deu para trocar agora. Tente de novo mais tarde.';

  @override
  String get markerNoOccupancy => 'sem informação de lotação';

  @override
  String get panelNoDataBadge => 'Sem dados';

  @override
  String get panelNoOccupancyNotice =>
      'Ainda não há relatos suficientes. Envie o seu: com 3 relatos, a lotação aparece para todos.';

  @override
  String get panelInsightsNeedReports =>
      'O histórico, o pico e as previsões aparecem quando esta academia tiver relatos suficientes.';
}
