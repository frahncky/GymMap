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
  String get authInitializing => 'Autenticação ainda inicializando';

  @override
  String get authProductionNoBackend =>
      'Modo produção ativo sem backend remoto configurado';

  @override
  String get authNoBackend => 'Backend remoto não configurado no app';

  @override
  String get authProductionNeedsSession =>
      'Modo produção exige sessão autenticada';

  @override
  String get authAnonymousAccount =>
      'Conta anônima neste aparelho. Crie uma conta para não perder sua assinatura ao trocar de celular.';

  @override
  String authSessionActive(String user) {
    return 'Sessão ativa para $user';
  }

  @override
  String get authNotSignedIn => 'Sessão não autenticada';

  @override
  String get playLoadingProducts => 'Google Play: carregando produtos...';

  @override
  String get playUnavailable => 'Google Play indisponível neste aparelho.';

  @override
  String get playProductsMissing =>
      'Google Play: um ou mais produtos ainda não encontrados.';

  @override
  String get playReady => 'Google Play pronto para checkout.';

  @override
  String get playListenFailed => 'Falha ao escutar compras do Google Play.';

  @override
  String get playLoadProductsFailed =>
      'Não foi possível carregar produtos do Google Play.';

  @override
  String playProductsNotFound(String ids) {
    return 'Produtos não encontrados no Google Play: $ids';
  }

  @override
  String get playLoadProductsError =>
      'Falha ao carregar produtos do Google Play.';

  @override
  String authTooManyAttemptsWait(String wait) {
    return 'Muitas tentativas de login. Aguarde $wait.';
  }

  @override
  String get authTooManyAttempts =>
      'Muitas tentativas de login. Aguarde um pouco e tente novamente.';

  @override
  String get authInvalidCredentials => 'Usuário ou senha inválidos.';

  @override
  String get authMissingCredentials => 'Informe usuário e senha.';

  @override
  String get authInvalidUsername =>
      'Usuário deve ter de 3 a 32 caracteres: letras minúsculas, números, ponto, hífen ou sublinhado.';

  @override
  String get authUsernameTaken => 'Este usuário já está em uso.';

  @override
  String get authPasswordTooShort =>
      'A senha precisa ter pelo menos 8 caracteres.';

  @override
  String get authAlreadyRegistered =>
      'Esta sessão já pertence a uma conta registrada.';

  @override
  String get authUnauthorized => 'Sessão não autorizada.';

  @override
  String get authFailed => 'Falha de autenticação';

  @override
  String billingRateLimitedWait(String wait) {
    return 'Limite de tentativas atingido. Aguarde $wait.';
  }

  @override
  String get billingRateLimited =>
      'Limite de tentativas atingido. Aguarde um pouco e tente novamente.';

  @override
  String get billingProductionNeedsBackend =>
      'Modo produção exige backend remoto configurado.';

  @override
  String get billingPlayNeedsBackend =>
      'Checkout no Google Play exige backend remoto configurado.';

  @override
  String get billingProductionNeedsUser =>
      'Modo produção exige usuário autenticado.';

  @override
  String get billingProductNotFound =>
      'Produto de assinatura não encontrado no Google Play.';

  @override
  String get billingCheckoutNotStarted =>
      'Não foi possível iniciar checkout no Google Play.';

  @override
  String get billingProductMissing => 'Produto da assinatura não informado.';

  @override
  String get billingTokenMissing => 'Token de compra ausente. Tente novamente.';

  @override
  String get billingPurchaseNotActive =>
      'Compra ainda não está ativa no Google Play.';

  @override
  String get billingPurchaseNotFound => 'Compra não encontrada no Google Play.';

  @override
  String get billingProductMismatch =>
      'Produto da compra não corresponde ao plano selecionado.';

  @override
  String get billingPackageMismatch => 'Compra vinculada a outro aplicativo.';

  @override
  String get billingPlayUnauthorized =>
      'Backend sem permissão para validar Google Play. Verifique credenciais.';

  @override
  String get billingValidationUnavailable =>
      'Não foi possível validar a compra no Google Play agora.';

  @override
  String get billingPendingWebhook =>
      'Pagamento ainda não confirmado pelo webhook. Aguarde alguns segundos e tente novamente.';

  @override
  String get billingPixUnavailable =>
      'Gateway Pix indisponível no momento. Tente novamente em instantes.';

  @override
  String get billingInvalidWebhook =>
      'Webhook do pagamento inválido. Contate o suporte.';

  @override
  String get billingSessionExpiredOrForbidden =>
      'Sessão expirada ou sem permissão. Faça login novamente.';

  @override
  String get billingSessionExpired => 'Sessão expirada. Faça login novamente.';

  @override
  String get billingGenericFailure =>
      'Não foi possível processar a assinatura agora.';

  @override
  String get planExpiredBackToFree =>
      'Assinatura expirada. O app voltou para o plano gratuito.';

  @override
  String get subscriptionInitializing =>
      'Assinatura ainda está inicializando. Tente novamente.';

  @override
  String get planFreeActivated => 'Plano gratuito ativado.';

  @override
  String get authNoBackendForLogin =>
      'Backend remoto não configurado para login.';

  @override
  String authAccountCreated(String user) {
    return 'Conta criada para $user.';
  }

  @override
  String authSignedIn(String user) {
    return 'Login concluído para $user.';
  }

  @override
  String get authCreateAccount => 'Criar conta';

  @override
  String get authSignInMonthly => 'Entrar no plano mensal';

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
  String get authCreating => 'Criando...';

  @override
  String get authSigningIn => 'Entrando...';

  @override
  String get authSignIn => 'Entrar';

  @override
  String get authNoSession => 'Não existe sessão autenticada.';

  @override
  String get authSignedOut => 'Sessão encerrada.';

  @override
  String get authSignOutFailed => 'Não foi possível encerrar sessão agora.';

  @override
  String get playFinishPayment =>
      'Finalize o pagamento no Google Play para ativar o plano.';

  @override
  String get playPurchaseFailed => 'Falha ao processar compra no Google Play.';

  @override
  String get playPaymentCanceled => 'Pagamento cancelado no Google Play.';

  @override
  String playUnknownProduct(String id) {
    return 'Produto desconhecido no Google Play: $id';
  }

  @override
  String planActivatedSuccess(String plan) {
    return 'Assinatura $plan ativada com sucesso.';
  }

  @override
  String get playFinalizeFailed =>
      'Compra validada, mas não foi possível finalizar no Google Play.';

  @override
  String get priceFreeMonthly => 'R\$ 0/mês';

  @override
  String pricePerMonth(String price) {
    return '$price/mês';
  }

  @override
  String get planCurrent => 'Plano atual';

  @override
  String get planContinueFree => 'Continuar grátis';

  @override
  String get planBackToFree => 'Voltar ao gratuito';

  @override
  String get planSubscribe => 'Assinar';

  @override
  String get planUpgrade => 'Fazer upgrade';

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
  String get planMostPopular => 'MAIS POPULAR';

  @override
  String get planInstantAccess =>
      'Acesso imediato e cancelamento quando quiser.';

  @override
  String get planFeatureLiveOccupancy => 'Lotação em tempo real';

  @override
  String get planFeatureHistory => 'Histórico 24h';

  @override
  String get planFeaturePeakCompare => 'Pico e comparativo';

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
  String get paywallTitle => 'Desbloqueie o máximo do GymMap';

  @override
  String get paywallSubtitle =>
      'Escolha o plano ideal para lotação, previsão e comparativos.';

  @override
  String get paywallSocialProof => '+10.000 usuários premium ativos';

  @override
  String get paywallRating => 'Nota média 4.8/5 em avaliações verificadas.';

  @override
  String get subscriptionLoading => 'Carregando assinatura...';

  @override
  String get authSignOut => 'Sair';

  @override
  String get planContinueWithFree => 'Continuar com plano gratuito';

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
    return 'Obrigado por validar! +$points pontos na comunidade.';
  }

  @override
  String get communityTitle => 'Comunidade';

  @override
  String get communityLoadingReports => 'Carregando relatos da sua região...';

  @override
  String get communityNoReportsYet =>
      'Ainda não há relatos recentes das academias da sua região.';

  @override
  String get communityRecentRegionReports =>
      'Relatos recentes das academias da sua região.';

  @override
  String get communityFeedDescription =>
      'Feed de relatos recentes com validação colaborativa.';

  @override
  String get communityTopContributors => 'Top contribuidores da semana';

  @override
  String communityYourPosition(String rank) {
    return 'Sua posição: $rank';
  }

  @override
  String communityRegion(String region) {
    return 'Região: $region';
  }

  @override
  String get communityNotEnoughRanking => 'Ainda não há ranking suficiente.';

  @override
  String get communityEnableLocationRanking =>
      'Ative a localização para carregar ranking real.';

  @override
  String get communityRealDataWeek => 'Dados reais dos últimos 7 dias';

  @override
  String communityPointsShort(String points) {
    return '$points pts';
  }

  @override
  String communityYourPoints(String points) {
    return 'Seus pontos: $points';
  }

  @override
  String get communityPointsPerValidation => '+2 por validação';

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
  String get profilePushTitle => 'Notificações push';

  @override
  String get profilePushSubtitle =>
      'Receber alertas de lotação e atualizações.';

  @override
  String get profileLocationAlertsTitle => 'Alertas por localização';

  @override
  String get profileLocationAlertsSubtitle =>
      'Avisar quando houver academia com lotação baixa perto de você.';

  @override
  String get profileHapticsTitle => 'Feedback vibratório';

  @override
  String get profileHapticsSubtitle => 'Usar vibração em ações importantes.';

  @override
  String get profileDataSaverTitle => 'Modo economia de dados';

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
  String get headerPlanSettings => 'Configurações de plano';

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
  String get emptyNoNearbyGyms =>
      'Nenhuma academia cadastrada próxima da sua localização.';

  @override
  String get filterClearAll => 'Limpar filtros';

  @override
  String get adLabel => 'Publicidade: faça upgrade para remover anúncios.';

  @override
  String get tutorialTitle => 'Dicas rápidas do mapa';

  @override
  String get tutorialSearch => 'Use a busca para academia, bairro ou cidade.';

  @override
  String get tutorialFilters => 'Ative os toggles para filtrar os resultados.';

  @override
  String get tutorialPin => 'Toque no pin para abrir detalhes e enviar relato.';

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
    return 'Status: $status';
  }

  @override
  String get panelClosedNotice =>
      'Academia fechada agora. Lotação oculta no mapa.';

  @override
  String panelReportsSummary(String total, String recent) {
    return '$total relatos totais | $recent relatos recentes';
  }

  @override
  String panelLastReport(String time) {
    return 'Último relato: $time';
  }

  @override
  String get panelViewRoute => 'Ver rota';

  @override
  String get panelUpdateOccupancy => 'Atualize a lotação desta academia';

  @override
  String get panelSendingReport => 'Enviando relato...';

  @override
  String get panelContribute => 'Contribuir';

  @override
  String get panelContributeClosed =>
      'Contribuição de lotação disponível apenas com academia aberta.';

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
    return 'Envio bloqueado temporariamente. Aguarde $minutes min para novo relato.';
  }

  @override
  String get subscriptionActivated => 'Assinatura ativada!';

  @override
  String planUnlocked(String plan) {
    return 'Plano $plan liberado com sucesso.';
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
  String get communityTop10 => 'Top 10 contribuidores da semana';

  @override
  String communityCurrentPosition(String rank, String points) {
    return 'Sua posição atual: $rank  .  $points pts';
  }

  @override
  String get communityRankingUpdating => 'Atualizando ranking...';

  @override
  String get communityRankingRealInfo =>
      'Pontuação real dos últimos 7 dias. Cada envio válido soma +5 pontos.';

  @override
  String get communityRankingInfo =>
      'Cada envio válido soma +5 pontos. Continue contribuindo para subir no ranking.';

  @override
  String get communityRankingEmpty =>
      'Ainda não há pontuação suficiente nesta região.';

  @override
  String get locationNotificationTitle => 'GymMap localização ativa';

  @override
  String get locationNotificationText =>
      'GymMap está atualizando sua localização em segundo plano.';

  @override
  String get locationEnableGps =>
      'Ative o GPS para centralizar sua localização.';

  @override
  String get locationNoPermission =>
      'Sem permissão de localização. Você pode ativar isso depois nas configurações.';

  @override
  String get locationDeniedForever =>
      'Permissão de localização negada permanentemente. Ajuste nas configurações do aparelho.';

  @override
  String get locationDenied => 'Permissão de localização negada.';

  @override
  String get locationTimeout =>
      'Tempo esgotado ao obter localização. Tente novamente em instantes.';

  @override
  String get locationUnavailable =>
      'Não foi possível obter sua localização no momento.';

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
  String get controlsUpdatingGyms => 'Atualizando academias...';

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
  String get mapLocatingYou => 'Localizando você...';

  @override
  String get mapUnavailableRetry => 'Mapa indisponível. Tentar novamente';

  @override
  String get mapLoading => 'Carregando mapa...';

  @override
  String get mapOpenGoogleMapsFailed =>
      'Não foi possível abrir o Google Maps agora.';

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
  String get searchFailed => 'Não foi possível buscar esta localização agora.';

  @override
  String get searchNotFound =>
      'Local não encontrado. Tente bairro, cidade ou endereço.';

  @override
  String get searchParseFailed =>
      'Não foi possível interpretar essa localização.';

  @override
  String get searchTimeout => 'Tempo esgotado ao buscar essa localização.';

  @override
  String get searchError => 'Não foi possível buscar essa localização.';

  @override
  String get occupancyLevelVeryHigh => 'Muito alta';

  @override
  String get timeNoInfo => 'sem informações';

  @override
  String get timeNow => 'agora';

  @override
  String timeMinutesAgo(String count) {
    return '$count min atrás';
  }

  @override
  String timeHoursAgo(String count) {
    return '$count h atrás';
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
    return 'Obrigado por contribuir! +5 pontos\n$gym atualizado para $percent% (conf. $trust%).';
  }

  @override
  String get alertVeryHighNow =>
      'Lotação muito alta agora. Considere treinar em outro horário.';

  @override
  String alertBestWindow(String hour, String percent) {
    return 'Melhor janela prevista perto de ${hour}h ($percent%).';
  }

  @override
  String alertLessCrowded(String gym, String delta) {
    return '$gym está $delta pp menos lotada agora.';
  }

  @override
  String get alertStableFlow =>
      'Fluxo estável nas próximas horas para esta academia.';

  @override
  String get pushChannelName => 'Alertas contextuais';

  @override
  String get pushChannelDescription =>
      'Alertas quando houver academia com lotação baixa próxima.';

  @override
  String get pushLowCrowdTitle => 'Academia com lotação baixa perto';

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
  String get placesServices => 'Serviços (bancos, correios...)';

  @override
  String get placesLeisure => 'Lazer e turismo';

  @override
  String get placesReligion => 'Templos e igrejas';

  @override
  String get placesOther => 'Outros';

  @override
  String get gymUnnamed => 'Academia';
}
