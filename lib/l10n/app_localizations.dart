import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_pt.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('pt'),
  ];

  /// No description provided for @settingsLanguageTitle.
  ///
  /// In pt, this message translates to:
  /// **'Idioma'**
  String get settingsLanguageTitle;

  /// No description provided for @settingsLanguageSystem.
  ///
  /// In pt, this message translates to:
  /// **'Idioma do aparelho'**
  String get settingsLanguageSystem;

  /// No description provided for @settingsLanguagePortuguese.
  ///
  /// In pt, this message translates to:
  /// **'Português'**
  String get settingsLanguagePortuguese;

  /// No description provided for @settingsLanguageEnglish.
  ///
  /// In pt, this message translates to:
  /// **'English'**
  String get settingsLanguageEnglish;

  /// No description provided for @planFreeActive.
  ///
  /// In pt, this message translates to:
  /// **'Plano gratuito ativo'**
  String get planFreeActive;

  /// No description provided for @planValidUntil.
  ///
  /// In pt, this message translates to:
  /// **'Válido até {date}'**
  String planValidUntil(String date);

  /// No description provided for @durationDays.
  ///
  /// In pt, this message translates to:
  /// **'{count, plural, =1{1 dia} other{{count} dias}}'**
  String durationDays(int count);

  /// No description provided for @durationHours.
  ///
  /// In pt, this message translates to:
  /// **'{count, plural, =1{1 hora} other{{count} horas}}'**
  String durationHours(int count);

  /// No description provided for @durationUnderOneHour.
  ///
  /// In pt, this message translates to:
  /// **'menos de 1 hora'**
  String get durationUnderOneHour;

  /// No description provided for @planExpiresSoon.
  ///
  /// In pt, this message translates to:
  /// **'Seu plano {plan} expira em {window}. Renovação somente manual, quando você decidir.'**
  String planExpiresSoon(String plan, String window);

  /// No description provided for @authInitializing.
  ///
  /// In pt, this message translates to:
  /// **'Carregando sua conta…'**
  String get authInitializing;

  /// No description provided for @authProductionNoBackend.
  ///
  /// In pt, this message translates to:
  /// **'Contas indisponíveis no momento.'**
  String get authProductionNoBackend;

  /// No description provided for @authNoBackend.
  ///
  /// In pt, this message translates to:
  /// **'Contas indisponíveis no momento.'**
  String get authNoBackend;

  /// No description provided for @authProductionNeedsSession.
  ///
  /// In pt, this message translates to:
  /// **'Entre na sua conta para assinar.'**
  String get authProductionNeedsSession;

  /// No description provided for @authAnonymousAccount.
  ///
  /// In pt, this message translates to:
  /// **'Você está usando o app sem conta. Crie uma para não perder sua assinatura ao trocar de celular.'**
  String get authAnonymousAccount;

  /// No description provided for @authSessionActive.
  ///
  /// In pt, this message translates to:
  /// **'Conectado como {user}'**
  String authSessionActive(String user);

  /// No description provided for @authNotSignedIn.
  ///
  /// In pt, this message translates to:
  /// **'Você não entrou na sua conta.'**
  String get authNotSignedIn;

  /// No description provided for @playUnavailable.
  ///
  /// In pt, this message translates to:
  /// **'A Google Play não está disponível neste aparelho.'**
  String get playUnavailable;

  /// No description provided for @playListenFailed.
  ///
  /// In pt, this message translates to:
  /// **'Não deu para acompanhar suas compras agora. Tente de novo mais tarde.'**
  String get playListenFailed;

  /// No description provided for @playLoadProductsFailed.
  ///
  /// In pt, this message translates to:
  /// **'Não deu para carregar os planos agora. Tente de novo mais tarde.'**
  String get playLoadProductsFailed;

  /// No description provided for @playProductsNotFound.
  ///
  /// In pt, this message translates to:
  /// **'Alguns planos não estão disponíveis agora.'**
  String get playProductsNotFound;

  /// No description provided for @playLoadProductsError.
  ///
  /// In pt, this message translates to:
  /// **'Não deu para carregar os planos agora. Tente de novo mais tarde.'**
  String get playLoadProductsError;

  /// No description provided for @authTooManyAttemptsWait.
  ///
  /// In pt, this message translates to:
  /// **'Muitas tentativas de entrar. Espere {wait} e tente de novo.'**
  String authTooManyAttemptsWait(String wait);

  /// No description provided for @authTooManyAttempts.
  ///
  /// In pt, this message translates to:
  /// **'Muitas tentativas de entrar. Espere um pouco e tente de novo.'**
  String get authTooManyAttempts;

  /// No description provided for @authInvalidCredentials.
  ///
  /// In pt, this message translates to:
  /// **'Usuário ou senha inválidos.'**
  String get authInvalidCredentials;

  /// No description provided for @authMissingCredentials.
  ///
  /// In pt, this message translates to:
  /// **'Informe usuário e senha.'**
  String get authMissingCredentials;

  /// No description provided for @authInvalidUsername.
  ///
  /// In pt, this message translates to:
  /// **'O usuário deve ter de 3 a 32 caracteres: letras minúsculas, números, ponto, hífen ou sublinhado.'**
  String get authInvalidUsername;

  /// No description provided for @authUsernameTaken.
  ///
  /// In pt, this message translates to:
  /// **'Este usuário já está em uso.'**
  String get authUsernameTaken;

  /// No description provided for @authPasswordTooShort.
  ///
  /// In pt, this message translates to:
  /// **'A senha precisa ter pelo menos 8 caracteres.'**
  String get authPasswordTooShort;

  /// No description provided for @authAlreadyRegistered.
  ///
  /// In pt, this message translates to:
  /// **'Este aparelho já está ligado a uma conta.'**
  String get authAlreadyRegistered;

  /// No description provided for @authUnauthorized.
  ///
  /// In pt, this message translates to:
  /// **'Sua sessão expirou. Entre de novo.'**
  String get authUnauthorized;

  /// No description provided for @authFailed.
  ///
  /// In pt, this message translates to:
  /// **'Não deu para entrar agora. Tente de novo.'**
  String get authFailed;

  /// No description provided for @billingRateLimitedWait.
  ///
  /// In pt, this message translates to:
  /// **'Muitas tentativas. Espere {wait} e tente de novo.'**
  String billingRateLimitedWait(String wait);

  /// No description provided for @billingRateLimited.
  ///
  /// In pt, this message translates to:
  /// **'Muitas tentativas. Espere um pouco e tente de novo.'**
  String get billingRateLimited;

  /// No description provided for @billingProductionNeedsBackend.
  ///
  /// In pt, this message translates to:
  /// **'Assinaturas indisponíveis no momento. Tente mais tarde.'**
  String get billingProductionNeedsBackend;

  /// No description provided for @billingPlayNeedsBackend.
  ///
  /// In pt, this message translates to:
  /// **'Assinaturas indisponíveis no momento. Tente mais tarde.'**
  String get billingPlayNeedsBackend;

  /// No description provided for @billingProductionNeedsUser.
  ///
  /// In pt, this message translates to:
  /// **'Entre na sua conta para assinar.'**
  String get billingProductionNeedsUser;

  /// No description provided for @billingProductNotFound.
  ///
  /// In pt, this message translates to:
  /// **'Este plano não está disponível na Google Play agora.'**
  String get billingProductNotFound;

  /// No description provided for @billingCheckoutNotStarted.
  ///
  /// In pt, this message translates to:
  /// **'Não deu para abrir o pagamento na Google Play. Tente de novo.'**
  String get billingCheckoutNotStarted;

  /// No description provided for @billingProductMissing.
  ///
  /// In pt, this message translates to:
  /// **'Não deu para identificar o plano. Tente de novo.'**
  String get billingProductMissing;

  /// No description provided for @billingTokenMissing.
  ///
  /// In pt, this message translates to:
  /// **'Não deu para confirmar a compra. Tente de novo.'**
  String get billingTokenMissing;

  /// No description provided for @billingPurchaseNotActive.
  ///
  /// In pt, this message translates to:
  /// **'A Google Play ainda está processando sua compra. Tente de novo em alguns minutos.'**
  String get billingPurchaseNotActive;

  /// No description provided for @billingPurchaseNotFound.
  ///
  /// In pt, this message translates to:
  /// **'Não encontramos essa compra na Google Play.'**
  String get billingPurchaseNotFound;

  /// No description provided for @billingProductMismatch.
  ///
  /// In pt, this message translates to:
  /// **'A compra não corresponde ao plano escolhido.'**
  String get billingProductMismatch;

  /// No description provided for @billingPackageMismatch.
  ///
  /// In pt, this message translates to:
  /// **'Essa compra pertence a outro app.'**
  String get billingPackageMismatch;

  /// No description provided for @billingPlayUnauthorized.
  ///
  /// In pt, this message translates to:
  /// **'Não deu para confirmar a compra agora. Tente de novo mais tarde.'**
  String get billingPlayUnauthorized;

  /// No description provided for @billingValidationUnavailable.
  ///
  /// In pt, this message translates to:
  /// **'Não deu para confirmar a compra agora. Tente de novo mais tarde.'**
  String get billingValidationUnavailable;

  /// No description provided for @billingPendingWebhook.
  ///
  /// In pt, this message translates to:
  /// **'Seu pagamento ainda está sendo confirmado. Tente de novo em alguns segundos.'**
  String get billingPendingWebhook;

  /// No description provided for @billingPixUnavailable.
  ///
  /// In pt, this message translates to:
  /// **'O Pix está indisponível no momento. Tente de novo em instantes.'**
  String get billingPixUnavailable;

  /// No description provided for @billingInvalidWebhook.
  ///
  /// In pt, this message translates to:
  /// **'Não deu para confirmar o pagamento. Fale com o suporte.'**
  String get billingInvalidWebhook;

  /// No description provided for @billingSessionExpiredOrForbidden.
  ///
  /// In pt, this message translates to:
  /// **'Sua sessão expirou. Entre de novo.'**
  String get billingSessionExpiredOrForbidden;

  /// No description provided for @billingSessionExpired.
  ///
  /// In pt, this message translates to:
  /// **'Sua sessão expirou. Entre de novo.'**
  String get billingSessionExpired;

  /// No description provided for @billingGenericFailure.
  ///
  /// In pt, this message translates to:
  /// **'Não deu para concluir a assinatura agora. Tente de novo.'**
  String get billingGenericFailure;

  /// No description provided for @planExpiredBackToFree.
  ///
  /// In pt, this message translates to:
  /// **'Sua assinatura terminou. Você voltou para o plano Grátis.'**
  String get planExpiredBackToFree;

  /// No description provided for @subscriptionInitializing.
  ///
  /// In pt, this message translates to:
  /// **'Os planos ainda estão carregando. Tente de novo em instantes.'**
  String get subscriptionInitializing;

  /// No description provided for @planFreeActivated.
  ///
  /// In pt, this message translates to:
  /// **'Você está no plano Grátis.'**
  String get planFreeActivated;

  /// No description provided for @authNoBackendForLogin.
  ///
  /// In pt, this message translates to:
  /// **'Contas indisponíveis no momento.'**
  String get authNoBackendForLogin;

  /// No description provided for @authAccountCreated.
  ///
  /// In pt, this message translates to:
  /// **'Conta criada. Boas-vindas, {user}!'**
  String authAccountCreated(String user);

  /// No description provided for @authSignedIn.
  ///
  /// In pt, this message translates to:
  /// **'Você entrou como {user}.'**
  String authSignedIn(String user);

  /// No description provided for @authCreateAccount.
  ///
  /// In pt, this message translates to:
  /// **'Criar conta'**
  String get authCreateAccount;

  /// No description provided for @authSignInMonthly.
  ///
  /// In pt, this message translates to:
  /// **'Entrar na sua conta'**
  String get authSignInMonthly;

  /// No description provided for @authUsernameLabel.
  ///
  /// In pt, this message translates to:
  /// **'Usuário'**
  String get authUsernameLabel;

  /// No description provided for @authUsernameHelper.
  ///
  /// In pt, this message translates to:
  /// **'3 a 32 caracteres: a-z, 0-9, ponto, hífen ou _'**
  String get authUsernameHelper;

  /// No description provided for @authPasswordLabel.
  ///
  /// In pt, this message translates to:
  /// **'Senha'**
  String get authPasswordLabel;

  /// No description provided for @authPasswordHelper.
  ///
  /// In pt, this message translates to:
  /// **'Mínimo de 8 caracteres'**
  String get authPasswordHelper;

  /// No description provided for @actionCancel.
  ///
  /// In pt, this message translates to:
  /// **'Cancelar'**
  String get actionCancel;

  /// No description provided for @authCreating.
  ///
  /// In pt, this message translates to:
  /// **'Criando…'**
  String get authCreating;

  /// No description provided for @authSigningIn.
  ///
  /// In pt, this message translates to:
  /// **'Entrando…'**
  String get authSigningIn;

  /// No description provided for @authSignIn.
  ///
  /// In pt, this message translates to:
  /// **'Entrar'**
  String get authSignIn;

  /// No description provided for @authNoSession.
  ///
  /// In pt, this message translates to:
  /// **'Você não entrou em nenhuma conta.'**
  String get authNoSession;

  /// No description provided for @authSignedOut.
  ///
  /// In pt, this message translates to:
  /// **'Você saiu da sua conta.'**
  String get authSignedOut;

  /// No description provided for @authSignOutFailed.
  ///
  /// In pt, this message translates to:
  /// **'Não deu para sair agora. Tente de novo.'**
  String get authSignOutFailed;

  /// No description provided for @playFinishPayment.
  ///
  /// In pt, this message translates to:
  /// **'Conclua o pagamento na Google Play para ativar o plano.'**
  String get playFinishPayment;

  /// No description provided for @playPurchaseFailed.
  ///
  /// In pt, this message translates to:
  /// **'Não deu para concluir a compra na Google Play.'**
  String get playPurchaseFailed;

  /// No description provided for @playPaymentCanceled.
  ///
  /// In pt, this message translates to:
  /// **'Pagamento cancelado.'**
  String get playPaymentCanceled;

  /// No description provided for @playUnknownProduct.
  ///
  /// In pt, this message translates to:
  /// **'Este plano não é reconhecido. Atualize o app e tente de novo.'**
  String get playUnknownProduct;

  /// No description provided for @planActivatedSuccess.
  ///
  /// In pt, this message translates to:
  /// **'Plano {plan} ativado!'**
  String planActivatedSuccess(String plan);

  /// No description provided for @playFinalizeFailed.
  ///
  /// In pt, this message translates to:
  /// **'Compra confirmada. A Google Play ainda está finalizando o pagamento.'**
  String get playFinalizeFailed;

  /// No description provided for @priceFreeMonthly.
  ///
  /// In pt, this message translates to:
  /// **'R\$ 0/mês'**
  String get priceFreeMonthly;

  /// No description provided for @pricePerMonth.
  ///
  /// In pt, this message translates to:
  /// **'{price}/mês'**
  String pricePerMonth(String price);

  /// No description provided for @planCurrent.
  ///
  /// In pt, this message translates to:
  /// **'Plano atual'**
  String get planCurrent;

  /// No description provided for @planContinueFree.
  ///
  /// In pt, this message translates to:
  /// **'Continuar no Grátis'**
  String get planContinueFree;

  /// No description provided for @planBackToFree.
  ///
  /// In pt, this message translates to:
  /// **'Voltar ao Grátis'**
  String get planBackToFree;

  /// No description provided for @planSubscribe.
  ///
  /// In pt, this message translates to:
  /// **'Assinar'**
  String get planSubscribe;

  /// No description provided for @planUpgrade.
  ///
  /// In pt, this message translates to:
  /// **'Subir de plano'**
  String get planUpgrade;

  /// No description provided for @planChange.
  ///
  /// In pt, this message translates to:
  /// **'Trocar plano'**
  String get planChange;

  /// No description provided for @promoUntil.
  ///
  /// In pt, this message translates to:
  /// **'{message} • até {deadline}'**
  String promoUntil(String message, String deadline);

  /// No description provided for @planIncludesPro.
  ///
  /// In pt, this message translates to:
  /// **'Inclui tudo do Pro'**
  String get planIncludesPro;

  /// No description provided for @planStartFreeTrial.
  ///
  /// In pt, this message translates to:
  /// **'Começar teste grátis'**
  String get planStartFreeTrial;

  /// No description provided for @planMostPopular.
  ///
  /// In pt, this message translates to:
  /// **'RECOMENDADO'**
  String get planMostPopular;

  /// No description provided for @planInstantAccess.
  ///
  /// In pt, this message translates to:
  /// **'Acesso imediato. Cancele quando quiser.'**
  String get planInstantAccess;

  /// No description provided for @planFeatureLiveOccupancy.
  ///
  /// In pt, this message translates to:
  /// **'Lotação em tempo real'**
  String get planFeatureLiveOccupancy;

  /// No description provided for @planFeatureHistory.
  ///
  /// In pt, this message translates to:
  /// **'Histórico 24h'**
  String get planFeatureHistory;

  /// No description provided for @planFeaturePeakCompare.
  ///
  /// In pt, this message translates to:
  /// **'Picos e comparativo'**
  String get planFeaturePeakCompare;

  /// No description provided for @planFeatureForecast.
  ///
  /// In pt, this message translates to:
  /// **'Previsão e alertas'**
  String get planFeatureForecast;

  /// No description provided for @planFeatureNationwide.
  ///
  /// In pt, this message translates to:
  /// **'Cobertura nacional'**
  String get planFeatureNationwide;

  /// No description provided for @planQuickComparison.
  ///
  /// In pt, this message translates to:
  /// **'Comparativo rápido'**
  String get planQuickComparison;

  /// No description provided for @planAvailableIn.
  ///
  /// In pt, this message translates to:
  /// **'Disponível no plano {plan}'**
  String planAvailableIn(String plan);

  /// No description provided for @planUnavailableIn.
  ///
  /// In pt, this message translates to:
  /// **'Indisponível no plano {plan}'**
  String planUnavailableIn(String plan);

  /// No description provided for @planAvailable.
  ///
  /// In pt, this message translates to:
  /// **'Disponível'**
  String get planAvailable;

  /// No description provided for @planUnavailable.
  ///
  /// In pt, this message translates to:
  /// **'Indisponível'**
  String get planUnavailable;

  /// No description provided for @paywallTitle.
  ///
  /// In pt, this message translates to:
  /// **'Aproveite o GymMap ao máximo'**
  String get paywallTitle;

  /// No description provided for @paywallSubtitle.
  ///
  /// In pt, this message translates to:
  /// **'Escolha o plano ideal para lotação, previsão e comparativos.'**
  String get paywallSubtitle;

  /// No description provided for @subscriptionLoading.
  ///
  /// In pt, this message translates to:
  /// **'Carregando assinatura…'**
  String get subscriptionLoading;

  /// No description provided for @authSignOut.
  ///
  /// In pt, this message translates to:
  /// **'Sair'**
  String get authSignOut;

  /// No description provided for @planContinueWithFree.
  ///
  /// In pt, this message translates to:
  /// **'Continuar no plano Grátis'**
  String get planContinueWithFree;

  /// No description provided for @actionClose.
  ///
  /// In pt, this message translates to:
  /// **'Fechar'**
  String get actionClose;

  /// No description provided for @planNameFree.
  ///
  /// In pt, this message translates to:
  /// **'Grátis'**
  String get planNameFree;

  /// No description provided for @planNameSmart.
  ///
  /// In pt, this message translates to:
  /// **'Essencial'**
  String get planNameSmart;

  /// No description provided for @insightCurrentOccupancy.
  ///
  /// In pt, this message translates to:
  /// **'Lotação atual'**
  String get insightCurrentOccupancy;

  /// No description provided for @insightHistory24h.
  ///
  /// In pt, this message translates to:
  /// **'Histórico das últimas 24h'**
  String get insightHistory24h;

  /// No description provided for @insightPeakHours.
  ///
  /// In pt, this message translates to:
  /// **'Horários de pico por dia'**
  String get insightPeakHours;

  /// No description provided for @insightCompareGyms.
  ///
  /// In pt, this message translates to:
  /// **'Comparativo entre academias'**
  String get insightCompareGyms;

  /// No description provided for @insightForecast.
  ///
  /// In pt, this message translates to:
  /// **'Previsão de lotação para próximas horas'**
  String get insightForecast;

  /// No description provided for @insightNationwide.
  ///
  /// In pt, this message translates to:
  /// **'Cobertura em qualquer lugar do país'**
  String get insightNationwide;

  /// No description provided for @insightAlerts.
  ///
  /// In pt, this message translates to:
  /// **'Alertas personalizados'**
  String get insightAlerts;

  /// No description provided for @communityYourRegion.
  ///
  /// In pt, this message translates to:
  /// **'Sua região'**
  String get communityYourRegion;

  /// No description provided for @communityRegionUnavailable.
  ///
  /// In pt, this message translates to:
  /// **'Região indisponível'**
  String get communityRegionUnavailable;

  /// No description provided for @distanceMetersFromYou.
  ///
  /// In pt, this message translates to:
  /// **'{meters} m de você'**
  String distanceMetersFromYou(String meters);

  /// No description provided for @distanceKmFromYou.
  ///
  /// In pt, this message translates to:
  /// **'{km} km de você'**
  String distanceKmFromYou(String km);

  /// No description provided for @communityPhotoCaptionRecent.
  ///
  /// In pt, this message translates to:
  /// **'Foto recente enviada por quem treinou na unidade.'**
  String get communityPhotoCaptionRecent;

  /// No description provided for @communityPhotoCaptionRecord.
  ///
  /// In pt, this message translates to:
  /// **'Registro recente da comunidade nessa academia.'**
  String get communityPhotoCaptionRecord;

  /// No description provided for @distanceUnknown.
  ///
  /// In pt, this message translates to:
  /// **'Distância não informada'**
  String get distanceUnknown;

  /// No description provided for @timeAgoMinutes.
  ///
  /// In pt, this message translates to:
  /// **'há {count} min'**
  String timeAgoMinutes(String count);

  /// No description provided for @timeAgoHours.
  ///
  /// In pt, this message translates to:
  /// **'há {count} h'**
  String timeAgoHours(String count);

  /// No description provided for @timeAgoDays.
  ///
  /// In pt, this message translates to:
  /// **'há {count} d'**
  String timeAgoDays(String count);

  /// No description provided for @occupancyLevelLow.
  ///
  /// In pt, this message translates to:
  /// **'Baixa'**
  String get occupancyLevelLow;

  /// No description provided for @occupancyLevelModerate.
  ///
  /// In pt, this message translates to:
  /// **'Moderada'**
  String get occupancyLevelModerate;

  /// No description provided for @occupancyLevelHigh.
  ///
  /// In pt, this message translates to:
  /// **'Alta'**
  String get occupancyLevelHigh;

  /// No description provided for @communityAnonymousUser.
  ///
  /// In pt, this message translates to:
  /// **'Usuário anônimo'**
  String get communityAnonymousUser;

  /// No description provided for @communityYou.
  ///
  /// In pt, this message translates to:
  /// **'Você'**
  String get communityYou;

  /// No description provided for @communityThanksValidation.
  ///
  /// In pt, this message translates to:
  /// **'Obrigado por confirmar! +{points} pontos.'**
  String communityThanksValidation(String points);

  /// No description provided for @communityTitle.
  ///
  /// In pt, this message translates to:
  /// **'Comunidade'**
  String get communityTitle;

  /// No description provided for @communityLoadingReports.
  ///
  /// In pt, this message translates to:
  /// **'Carregando relatos da sua região…'**
  String get communityLoadingReports;

  /// No description provided for @communityNoReportsYet.
  ///
  /// In pt, this message translates to:
  /// **'Ainda não há relatos recentes das academias da sua região.'**
  String get communityNoReportsYet;

  /// No description provided for @communityRecentRegionReports.
  ///
  /// In pt, this message translates to:
  /// **'Relatos recentes das academias da sua região.'**
  String get communityRecentRegionReports;

  /// No description provided for @communityFeedDescription.
  ///
  /// In pt, this message translates to:
  /// **'Relatos recentes de quem treina perto de você.'**
  String get communityFeedDescription;

  /// No description provided for @communityTopContributors.
  ///
  /// In pt, this message translates to:
  /// **'Quem mais contribuiu na semana'**
  String get communityTopContributors;

  /// No description provided for @communityYourPosition.
  ///
  /// In pt, this message translates to:
  /// **'Sua posição: {rank}'**
  String communityYourPosition(String rank);

  /// No description provided for @communityRegion.
  ///
  /// In pt, this message translates to:
  /// **'Região: {region}'**
  String communityRegion(String region);

  /// No description provided for @communityNotEnoughRanking.
  ///
  /// In pt, this message translates to:
  /// **'Ainda não há relatos suficientes para um ranking.'**
  String get communityNotEnoughRanking;

  /// No description provided for @communityEnableLocationRanking.
  ///
  /// In pt, this message translates to:
  /// **'Ative a localização para ver o ranking da sua região.'**
  String get communityEnableLocationRanking;

  /// No description provided for @communityRealDataWeek.
  ///
  /// In pt, this message translates to:
  /// **'Dados reais dos últimos 7 dias'**
  String get communityRealDataWeek;

  /// No description provided for @communityPointsShort.
  ///
  /// In pt, this message translates to:
  /// **'{points} pontos'**
  String communityPointsShort(String points);

  /// No description provided for @communityYourPoints.
  ///
  /// In pt, this message translates to:
  /// **'Seus pontos: {points}'**
  String communityYourPoints(String points);

  /// No description provided for @communityPointsPerValidation.
  ///
  /// In pt, this message translates to:
  /// **'+2 pontos por confirmação'**
  String get communityPointsPerValidation;

  /// No description provided for @communityContributeOnMap.
  ///
  /// In pt, this message translates to:
  /// **'Contribuir no mapa'**
  String get communityContributeOnMap;

  /// No description provided for @communityRecentRegionTitle.
  ///
  /// In pt, this message translates to:
  /// **'Relatos recentes da sua região'**
  String get communityRecentRegionTitle;

  /// No description provided for @communityRecentTitle.
  ///
  /// In pt, this message translates to:
  /// **'Relatos recentes'**
  String get communityRecentTitle;

  /// No description provided for @communityRefreshReports.
  ///
  /// In pt, this message translates to:
  /// **'Atualizar relatos'**
  String get communityRefreshReports;

  /// No description provided for @communityEmptyRegion.
  ///
  /// In pt, this message translates to:
  /// **'Sem relatos recentes na sua região agora. Abra o mapa e contribua para aparecer aqui.'**
  String get communityEmptyRegion;

  /// No description provided for @communityEnableLocationReports.
  ///
  /// In pt, this message translates to:
  /// **'Ative sua localização para ver relatos recentes da sua região.'**
  String get communityEnableLocationReports;

  /// No description provided for @communityPhotoByCommunity.
  ///
  /// In pt, this message translates to:
  /// **'Foto enviada pela comunidade.'**
  String get communityPhotoByCommunity;

  /// No description provided for @communityConfirm.
  ///
  /// In pt, this message translates to:
  /// **'Confirmo ({count})'**
  String communityConfirm(String count);

  /// No description provided for @communityDisagree.
  ///
  /// In pt, this message translates to:
  /// **'Discordo ({count})'**
  String communityDisagree(String count);

  /// No description provided for @profileDefaultName.
  ///
  /// In pt, this message translates to:
  /// **'Usuário GymMap'**
  String get profileDefaultName;

  /// No description provided for @profileSavePreferenceFailed.
  ///
  /// In pt, this message translates to:
  /// **'Não foi possível salvar esta preferência agora.'**
  String get profileSavePreferenceFailed;

  /// No description provided for @profileLoadPhotoFailed.
  ///
  /// In pt, this message translates to:
  /// **'Não foi possível carregar a foto.'**
  String get profileLoadPhotoFailed;

  /// No description provided for @profilePickPhotoFailed.
  ///
  /// In pt, this message translates to:
  /// **'Não foi possível selecionar a foto.'**
  String get profilePickPhotoFailed;

  /// No description provided for @profileNameRequired.
  ///
  /// In pt, this message translates to:
  /// **'Informe um nome para o perfil.'**
  String get profileNameRequired;

  /// No description provided for @profileSaveFailed.
  ///
  /// In pt, this message translates to:
  /// **'Não foi possível salvar o perfil.'**
  String get profileSaveFailed;

  /// No description provided for @profileEdit.
  ///
  /// In pt, this message translates to:
  /// **'Editar perfil'**
  String get profileEdit;

  /// No description provided for @profileChangePhoto.
  ///
  /// In pt, this message translates to:
  /// **'Trocar foto'**
  String get profileChangePhoto;

  /// No description provided for @profileRemovePhoto.
  ///
  /// In pt, this message translates to:
  /// **'Remover'**
  String get profileRemovePhoto;

  /// No description provided for @profileNameLabel.
  ///
  /// In pt, this message translates to:
  /// **'Nome'**
  String get profileNameLabel;

  /// No description provided for @profileNameHint.
  ///
  /// In pt, this message translates to:
  /// **'Como você quer aparecer'**
  String get profileNameHint;

  /// No description provided for @actionSave.
  ///
  /// In pt, this message translates to:
  /// **'Salvar'**
  String get actionSave;

  /// No description provided for @profileUpdated.
  ///
  /// In pt, this message translates to:
  /// **'Perfil atualizado.'**
  String get profileUpdated;

  /// No description provided for @profileTitle.
  ///
  /// In pt, this message translates to:
  /// **'Perfil'**
  String get profileTitle;

  /// No description provided for @profileCurrentPlan.
  ///
  /// In pt, this message translates to:
  /// **'Plano atual: {plan}'**
  String profileCurrentPlan(String plan);

  /// No description provided for @profileVisible.
  ///
  /// In pt, this message translates to:
  /// **'Perfil visível'**
  String get profileVisible;

  /// No description provided for @profilePrivate.
  ///
  /// In pt, this message translates to:
  /// **'Perfil privado'**
  String get profilePrivate;

  /// No description provided for @actionOpenMap.
  ///
  /// In pt, this message translates to:
  /// **'Abrir mapa'**
  String get actionOpenMap;

  /// No description provided for @profilePublicTitle.
  ///
  /// In pt, this message translates to:
  /// **'Permitir visualização pública'**
  String get profilePublicTitle;

  /// No description provided for @profilePublicSubtitle.
  ///
  /// In pt, this message translates to:
  /// **'Permite que seu nome e foto apareçam na comunidade.'**
  String get profilePublicSubtitle;

  /// No description provided for @profilePushTitle.
  ///
  /// In pt, this message translates to:
  /// **'Notificações'**
  String get profilePushTitle;

  /// No description provided for @profilePushSubtitle.
  ///
  /// In pt, this message translates to:
  /// **'Receber alertas de lotação e novidades.'**
  String get profilePushSubtitle;

  /// No description provided for @profileLocationAlertsTitle.
  ///
  /// In pt, this message translates to:
  /// **'Alertas por localização'**
  String get profileLocationAlertsTitle;

  /// No description provided for @profileLocationAlertsSubtitle.
  ///
  /// In pt, this message translates to:
  /// **'Avisar quando houver academia com lotação baixa perto de você.'**
  String get profileLocationAlertsSubtitle;

  /// No description provided for @profileHapticsTitle.
  ///
  /// In pt, this message translates to:
  /// **'Vibração'**
  String get profileHapticsTitle;

  /// No description provided for @profileHapticsSubtitle.
  ///
  /// In pt, this message translates to:
  /// **'Vibrar em ações importantes.'**
  String get profileHapticsSubtitle;

  /// No description provided for @profileDataSaverTitle.
  ///
  /// In pt, this message translates to:
  /// **'Economia de dados'**
  String get profileDataSaverTitle;

  /// No description provided for @profileDataSaverSubtitle.
  ///
  /// In pt, this message translates to:
  /// **'Reduzir atualizações em segundo plano.'**
  String get profileDataSaverSubtitle;

  /// No description provided for @favoritesDefaultName.
  ///
  /// In pt, this message translates to:
  /// **'Academia favorita'**
  String get favoritesDefaultName;

  /// No description provided for @favoritesLoadFailed.
  ///
  /// In pt, this message translates to:
  /// **'Não foi possível carregar seus favoritos.'**
  String get favoritesLoadFailed;

  /// No description provided for @actionRetry.
  ///
  /// In pt, this message translates to:
  /// **'Tentar novamente'**
  String get actionRetry;

  /// No description provided for @favoritesTitle.
  ///
  /// In pt, this message translates to:
  /// **'Favoritos'**
  String get favoritesTitle;

  /// No description provided for @favoritesEmpty.
  ///
  /// In pt, this message translates to:
  /// **'Você ainda não marcou academias favoritas.'**
  String get favoritesEmpty;

  /// No description provided for @favoritesCount.
  ///
  /// In pt, this message translates to:
  /// **'{count, plural, =1{1 academia salva.} other{{count} academias salvas.}}'**
  String favoritesCount(int count);

  /// No description provided for @favoritesHint.
  ///
  /// In pt, this message translates to:
  /// **'Use o ícone de coração no painel da academia para salvar seus favoritos.'**
  String get favoritesHint;

  /// No description provided for @favoritesViewMap.
  ///
  /// In pt, this message translates to:
  /// **'Ver mapa'**
  String get favoritesViewMap;

  /// No description provided for @navMap.
  ///
  /// In pt, this message translates to:
  /// **'Mapa'**
  String get navMap;

  /// No description provided for @navFavorites.
  ///
  /// In pt, this message translates to:
  /// **'Favoritos'**
  String get navFavorites;

  /// No description provided for @navCommunity.
  ///
  /// In pt, this message translates to:
  /// **'Comunidade'**
  String get navCommunity;

  /// No description provided for @navProfile.
  ///
  /// In pt, this message translates to:
  /// **'Perfil'**
  String get navProfile;

  /// No description provided for @headerCommunityPointsLabel.
  ///
  /// In pt, this message translates to:
  /// **'Pontos da comunidade: {points}'**
  String headerCommunityPointsLabel(String points);

  /// No description provided for @headerCommunityPointsHint.
  ///
  /// In pt, this message translates to:
  /// **'Toque para abrir o ranking semanal'**
  String get headerCommunityPointsHint;

  /// No description provided for @headerOpenRanking.
  ///
  /// In pt, this message translates to:
  /// **'Abrir ranking da comunidade'**
  String get headerOpenRanking;

  /// No description provided for @headerPlanSettings.
  ///
  /// In pt, this message translates to:
  /// **'Planos e assinatura'**
  String get headerPlanSettings;

  /// No description provided for @headerPlanSettingsHint.
  ///
  /// In pt, this message translates to:
  /// **'Toque para abrir opções de assinatura'**
  String get headerPlanSettingsHint;

  /// No description provided for @searchFieldLabel.
  ///
  /// In pt, this message translates to:
  /// **'Campo de busca'**
  String get searchFieldLabel;

  /// No description provided for @searchFieldHint.
  ///
  /// In pt, this message translates to:
  /// **'Digite academia, bairro ou cidade'**
  String get searchFieldHint;

  /// No description provided for @searchPlaceholder.
  ///
  /// In pt, this message translates to:
  /// **'Buscar academia, bairro ou cidade'**
  String get searchPlaceholder;

  /// No description provided for @searchLocationTooltip.
  ///
  /// In pt, this message translates to:
  /// **'Buscar localização'**
  String get searchLocationTooltip;

  /// No description provided for @searchClearTooltip.
  ///
  /// In pt, this message translates to:
  /// **'Limpar busca'**
  String get searchClearTooltip;

  /// No description provided for @filterSemanticsLabel.
  ///
  /// In pt, this message translates to:
  /// **'Filtro {filter}'**
  String filterSemanticsLabel(String filter);

  /// No description provided for @filterTapToRemove.
  ///
  /// In pt, this message translates to:
  /// **'Toque novamente para remover o filtro'**
  String get filterTapToRemove;

  /// No description provided for @filterTapToApply.
  ///
  /// In pt, this message translates to:
  /// **'Toque para aplicar o filtro'**
  String get filterTapToApply;

  /// No description provided for @emptyZoomIn.
  ///
  /// In pt, this message translates to:
  /// **'Aproxime o mapa para carregar academias automaticamente.'**
  String get emptyZoomIn;

  /// No description provided for @emptyNoFilterMatch.
  ///
  /// In pt, this message translates to:
  /// **'Nenhuma academia corresponde aos filtros ativos.'**
  String get emptyNoFilterMatch;

  /// No description provided for @emptyNoSearchResults.
  ///
  /// In pt, this message translates to:
  /// **'Nenhum resultado encontrado para sua busca.'**
  String get emptyNoSearchResults;

  /// No description provided for @emptyNoNearbyGyms.
  ///
  /// In pt, this message translates to:
  /// **'Nenhuma academia encontrada perto de você.'**
  String get emptyNoNearbyGyms;

  /// No description provided for @filterClearAll.
  ///
  /// In pt, this message translates to:
  /// **'Limpar filtros'**
  String get filterClearAll;

  /// No description provided for @adLabel.
  ///
  /// In pt, this message translates to:
  /// **'Anúncio · assine um plano para remover.'**
  String get adLabel;

  /// No description provided for @tutorialTitle.
  ///
  /// In pt, this message translates to:
  /// **'Dicas rápidas do mapa'**
  String get tutorialTitle;

  /// No description provided for @tutorialSearch.
  ///
  /// In pt, this message translates to:
  /// **'Use a busca para academia, bairro ou cidade.'**
  String get tutorialSearch;

  /// No description provided for @tutorialFilters.
  ///
  /// In pt, this message translates to:
  /// **'Use os filtros para refinar os resultados.'**
  String get tutorialFilters;

  /// No description provided for @tutorialPin.
  ///
  /// In pt, this message translates to:
  /// **'Toque no pino para ver detalhes e enviar um relato.'**
  String get tutorialPin;

  /// No description provided for @tutorialGotIt.
  ///
  /// In pt, this message translates to:
  /// **'Entendi'**
  String get tutorialGotIt;

  /// No description provided for @tutorialShowNearest.
  ///
  /// In pt, this message translates to:
  /// **'Ver próxima'**
  String get tutorialShowNearest;

  /// No description provided for @tutorialSkip.
  ///
  /// In pt, this message translates to:
  /// **'Pular tutorial'**
  String get tutorialSkip;

  /// No description provided for @panelFavoriteGym.
  ///
  /// In pt, this message translates to:
  /// **'Academia favorita'**
  String get panelFavoriteGym;

  /// No description provided for @panelAddGymToFavorites.
  ///
  /// In pt, this message translates to:
  /// **'Adicionar academia aos favoritos'**
  String get panelAddGymToFavorites;

  /// No description provided for @panelToggleFavoriteHint.
  ///
  /// In pt, this message translates to:
  /// **'Toque para alternar favorito'**
  String get panelToggleFavoriteHint;

  /// No description provided for @panelRemoveFavorite.
  ///
  /// In pt, this message translates to:
  /// **'Remover dos favoritos'**
  String get panelRemoveFavorite;

  /// No description provided for @panelAddFavorite.
  ///
  /// In pt, this message translates to:
  /// **'Adicionar aos favoritos'**
  String get panelAddFavorite;

  /// No description provided for @gymClosed.
  ///
  /// In pt, this message translates to:
  /// **'Fechada'**
  String get gymClosed;

  /// No description provided for @panelStatus.
  ///
  /// In pt, this message translates to:
  /// **'Lotação: {status}'**
  String panelStatus(String status);

  /// No description provided for @panelClosedNotice.
  ///
  /// In pt, this message translates to:
  /// **'Academia fechada agora. A lotação volta a aparecer quando abrir.'**
  String get panelClosedNotice;

  /// No description provided for @panelReportsSummary.
  ///
  /// In pt, this message translates to:
  /// **'{total} relatos no total · {recent} recentes'**
  String panelReportsSummary(String total, String recent);

  /// No description provided for @panelLastReport.
  ///
  /// In pt, this message translates to:
  /// **'Último relato: {time}'**
  String panelLastReport(String time);

  /// No description provided for @panelViewRoute.
  ///
  /// In pt, this message translates to:
  /// **'Ver trajeto'**
  String get panelViewRoute;

  /// No description provided for @panelUpdateOccupancy.
  ///
  /// In pt, this message translates to:
  /// **'Como está a lotação agora?'**
  String get panelUpdateOccupancy;

  /// No description provided for @panelSendingReport.
  ///
  /// In pt, this message translates to:
  /// **'Enviando relato…'**
  String get panelSendingReport;

  /// No description provided for @panelContribute.
  ///
  /// In pt, this message translates to:
  /// **'Enviar relato'**
  String get panelContribute;

  /// No description provided for @panelContributeClosed.
  ///
  /// In pt, this message translates to:
  /// **'Você pode enviar relatos quando a academia estiver aberta.'**
  String get panelContributeClosed;

  /// No description provided for @chartPeak.
  ///
  /// In pt, this message translates to:
  /// **'Pico'**
  String get chartPeak;

  /// No description provided for @chartAverage.
  ///
  /// In pt, this message translates to:
  /// **'Média'**
  String get chartAverage;

  /// No description provided for @panelPeakOfDay.
  ///
  /// In pt, this message translates to:
  /// **'Pico do dia'**
  String get panelPeakOfDay;

  /// No description provided for @panelReference.
  ///
  /// In pt, this message translates to:
  /// **'referência'**
  String get panelReference;

  /// No description provided for @panelForecast.
  ///
  /// In pt, this message translates to:
  /// **'Previsão das próximas horas'**
  String get panelForecast;

  /// No description provided for @reportBlockedWait.
  ///
  /// In pt, this message translates to:
  /// **'Você enviou um relato há pouco. Envie outro em {minutes} min.'**
  String reportBlockedWait(String minutes);

  /// No description provided for @subscriptionActivated.
  ///
  /// In pt, this message translates to:
  /// **'Assinatura ativada!'**
  String get subscriptionActivated;

  /// No description provided for @planUnlocked.
  ///
  /// In pt, this message translates to:
  /// **'Plano {plan} liberado!'**
  String planUnlocked(String plan);

  /// No description provided for @actionContinue.
  ///
  /// In pt, this message translates to:
  /// **'Continuar'**
  String get actionContinue;

  /// No description provided for @communityCurrentLocation.
  ///
  /// In pt, this message translates to:
  /// **'Sua localização atual'**
  String get communityCurrentLocation;

  /// No description provided for @communityCurrentRegion.
  ///
  /// In pt, this message translates to:
  /// **'Região atual'**
  String get communityCurrentRegion;

  /// No description provided for @communityNoRanking.
  ///
  /// In pt, this message translates to:
  /// **'sem ranking'**
  String get communityNoRanking;

  /// No description provided for @communityTop10.
  ///
  /// In pt, this message translates to:
  /// **'As 10 pessoas que mais contribuíram na semana'**
  String get communityTop10;

  /// No description provided for @communityCurrentPosition.
  ///
  /// In pt, this message translates to:
  /// **'Sua posição: {rank} · {points} pontos'**
  String communityCurrentPosition(String rank, String points);

  /// No description provided for @communityRankingUpdating.
  ///
  /// In pt, this message translates to:
  /// **'Atualizando ranking…'**
  String get communityRankingUpdating;

  /// No description provided for @communityRankingRealInfo.
  ///
  /// In pt, this message translates to:
  /// **'Pontos dos últimos 7 dias. Cada relato válido vale +5 pontos.'**
  String get communityRankingRealInfo;

  /// No description provided for @communityRankingInfo.
  ///
  /// In pt, this message translates to:
  /// **'Cada relato válido vale +5 pontos. Continue contribuindo para subir no ranking.'**
  String get communityRankingInfo;

  /// No description provided for @communityRankingEmpty.
  ///
  /// In pt, this message translates to:
  /// **'Ainda não há pontos suficientes nesta região.'**
  String get communityRankingEmpty;

  /// No description provided for @locationNotificationTitle.
  ///
  /// In pt, this message translates to:
  /// **'GymMap está usando sua localização'**
  String get locationNotificationTitle;

  /// No description provided for @locationNotificationText.
  ///
  /// In pt, this message translates to:
  /// **'Para avisar sobre academias tranquilas perto de você.'**
  String get locationNotificationText;

  /// No description provided for @locationEnableGps.
  ///
  /// In pt, this message translates to:
  /// **'Ative o GPS para ver onde você está.'**
  String get locationEnableGps;

  /// No description provided for @locationNoPermission.
  ///
  /// In pt, this message translates to:
  /// **'Sem acesso à localização. Você pode permitir depois nas configurações.'**
  String get locationNoPermission;

  /// No description provided for @locationDeniedForever.
  ///
  /// In pt, this message translates to:
  /// **'O acesso à localização foi negado. Permita nas configurações do aparelho.'**
  String get locationDeniedForever;

  /// No description provided for @locationDenied.
  ///
  /// In pt, this message translates to:
  /// **'Acesso à localização negado.'**
  String get locationDenied;

  /// No description provided for @locationTimeout.
  ///
  /// In pt, this message translates to:
  /// **'Sua localização demorou a responder. Tente de novo.'**
  String get locationTimeout;

  /// No description provided for @locationUnavailable.
  ///
  /// In pt, this message translates to:
  /// **'Não deu para encontrar sua localização agora.'**
  String get locationUnavailable;

  /// No description provided for @locationPromptTitle.
  ///
  /// In pt, this message translates to:
  /// **'Permitir localização?'**
  String get locationPromptTitle;

  /// No description provided for @locationPromptBody.
  ///
  /// In pt, this message translates to:
  /// **'Com a localização ativa, o GymMap encontra academias próximas automaticamente e calcula distância em tempo real.'**
  String get locationPromptBody;

  /// No description provided for @locationPromptLater.
  ///
  /// In pt, this message translates to:
  /// **'Agora não'**
  String get locationPromptLater;

  /// No description provided for @locationPromptAllow.
  ///
  /// In pt, this message translates to:
  /// **'Permitir'**
  String get locationPromptAllow;

  /// No description provided for @controlsNorthLabel.
  ///
  /// In pt, this message translates to:
  /// **'Reorientar mapa para norte'**
  String get controlsNorthLabel;

  /// No description provided for @controlsNorthHint.
  ///
  /// In pt, this message translates to:
  /// **'Toque para voltar a orientação para zero grau'**
  String get controlsNorthHint;

  /// No description provided for @controlsNorthTooltip.
  ///
  /// In pt, this message translates to:
  /// **'Reorientar para norte'**
  String get controlsNorthTooltip;

  /// No description provided for @controlsMyLocationLabel.
  ///
  /// In pt, this message translates to:
  /// **'Centralizar no meu local'**
  String get controlsMyLocationLabel;

  /// No description provided for @controlsMyLocationHint.
  ///
  /// In pt, this message translates to:
  /// **'Toque para mover o mapa para a sua posição atual'**
  String get controlsMyLocationHint;

  /// No description provided for @controlsMyLocationTooltip.
  ///
  /// In pt, this message translates to:
  /// **'Minha localização'**
  String get controlsMyLocationTooltip;

  /// No description provided for @controlsUpdatingGymsLabel.
  ///
  /// In pt, this message translates to:
  /// **'Atualizando academias no mapa'**
  String get controlsUpdatingGymsLabel;

  /// No description provided for @controlsUpdatingGyms.
  ///
  /// In pt, this message translates to:
  /// **'Atualizando academias…'**
  String get controlsUpdatingGyms;

  /// No description provided for @controlsYourLocation.
  ///
  /// In pt, this message translates to:
  /// **'Sua localização no mapa'**
  String get controlsYourLocation;

  /// No description provided for @coverageEnableLocation.
  ///
  /// In pt, this message translates to:
  /// **'Ative a localização para ver academias da sua região no plano atual.'**
  String get coverageEnableLocation;

  /// No description provided for @coverageEliteOnly.
  ///
  /// In pt, this message translates to:
  /// **'Outras regiões são exclusivas do plano Elite.'**
  String get coverageEliteOnly;

  /// No description provided for @filterOpenNow.
  ///
  /// In pt, this message translates to:
  /// **'Abertas agora'**
  String get filterOpenNow;

  /// No description provided for @filterLowCrowd.
  ///
  /// In pt, this message translates to:
  /// **'Lotação baixa'**
  String get filterLowCrowd;

  /// No description provided for @filterClasses.
  ///
  /// In pt, this message translates to:
  /// **'Aulas'**
  String get filterClasses;

  /// No description provided for @filterCardio.
  ///
  /// In pt, this message translates to:
  /// **'Cardio'**
  String get filterCardio;

  /// No description provided for @filterPool.
  ///
  /// In pt, this message translates to:
  /// **'Com piscina'**
  String get filterPool;

  /// No description provided for @filterFavorites.
  ///
  /// In pt, this message translates to:
  /// **'Favoritas'**
  String get filterFavorites;

  /// No description provided for @hoursOpenUntil.
  ///
  /// In pt, this message translates to:
  /// **'Aberta até {time}'**
  String hoursOpenUntil(String time);

  /// No description provided for @hoursOpensAt.
  ///
  /// In pt, this message translates to:
  /// **'Abre às {time}'**
  String hoursOpensAt(String time);

  /// No description provided for @hoursOpensTomorrow.
  ///
  /// In pt, this message translates to:
  /// **'Abre amanhã às {time}'**
  String hoursOpensTomorrow(String time);

  /// No description provided for @hoursToday.
  ///
  /// In pt, this message translates to:
  /// **'Hoje: {open} - {close}'**
  String hoursToday(String open, String close);

  /// No description provided for @mapDisabledInTest.
  ///
  /// In pt, this message translates to:
  /// **'Mapa desativado no modo de teste'**
  String get mapDisabledInTest;

  /// No description provided for @mapLocatingYou.
  ///
  /// In pt, this message translates to:
  /// **'Localizando você…'**
  String get mapLocatingYou;

  /// No description provided for @mapUnavailableRetry.
  ///
  /// In pt, this message translates to:
  /// **'Mapa indisponível. Toque para tentar de novo'**
  String get mapUnavailableRetry;

  /// No description provided for @mapLoading.
  ///
  /// In pt, this message translates to:
  /// **'Carregando mapa…'**
  String get mapLoading;

  /// No description provided for @mapOpenGoogleMapsFailed.
  ///
  /// In pt, this message translates to:
  /// **'Não deu para abrir o Google Maps agora.'**
  String get mapOpenGoogleMapsFailed;

  /// No description provided for @favoriteAdded.
  ///
  /// In pt, this message translates to:
  /// **'{gym} adicionada aos favoritos.'**
  String favoriteAdded(String gym);

  /// No description provided for @favoriteRemoved.
  ///
  /// In pt, this message translates to:
  /// **'{gym} removida dos favoritos.'**
  String favoriteRemoved(String gym);

  /// No description provided for @tutorialNoGymToHighlight.
  ///
  /// In pt, this message translates to:
  /// **'Nenhuma academia disponível para destacar agora.'**
  String get tutorialNoGymToHighlight;

  /// No description provided for @searchFailed.
  ///
  /// In pt, this message translates to:
  /// **'Não deu para buscar esse local agora.'**
  String get searchFailed;

  /// No description provided for @searchNotFound.
  ///
  /// In pt, this message translates to:
  /// **'Local não encontrado. Tente bairro, cidade ou endereço.'**
  String get searchNotFound;

  /// No description provided for @searchParseFailed.
  ///
  /// In pt, this message translates to:
  /// **'Não entendemos esse local. Tente outro endereço.'**
  String get searchParseFailed;

  /// No description provided for @searchTimeout.
  ///
  /// In pt, this message translates to:
  /// **'A busca demorou demais. Tente de novo.'**
  String get searchTimeout;

  /// No description provided for @searchError.
  ///
  /// In pt, this message translates to:
  /// **'Não deu para buscar esse local.'**
  String get searchError;

  /// No description provided for @occupancyLevelVeryHigh.
  ///
  /// In pt, this message translates to:
  /// **'Muito alta'**
  String get occupancyLevelVeryHigh;

  /// No description provided for @timeNoInfo.
  ///
  /// In pt, this message translates to:
  /// **'sem informações'**
  String get timeNoInfo;

  /// No description provided for @timeNow.
  ///
  /// In pt, this message translates to:
  /// **'agora'**
  String get timeNow;

  /// No description provided for @timeMinutesAgo.
  ///
  /// In pt, this message translates to:
  /// **'há {count} min'**
  String timeMinutesAgo(String count);

  /// No description provided for @timeHoursAgo.
  ///
  /// In pt, this message translates to:
  /// **'há {count} h'**
  String timeHoursAgo(String count);

  /// No description provided for @markerOccupancySemantics.
  ///
  /// In pt, this message translates to:
  /// **'lotação de {percent} por cento'**
  String markerOccupancySemantics(String percent);

  /// No description provided for @markerClosedNow.
  ///
  /// In pt, this message translates to:
  /// **'fechada agora'**
  String get markerClosedNow;

  /// No description provided for @markerFavoriteSuffix.
  ///
  /// In pt, this message translates to:
  /// **', favorita'**
  String get markerFavoriteSuffix;

  /// No description provided for @markerTapHint.
  ///
  /// In pt, this message translates to:
  /// **'Toque para abrir os detalhes da academia'**
  String get markerTapHint;

  /// No description provided for @markerGoodMoment.
  ///
  /// In pt, this message translates to:
  /// **'Bom momento'**
  String get markerGoodMoment;

  /// No description provided for @reportThanks.
  ///
  /// In pt, this message translates to:
  /// **'Obrigado pelo relato! +5 pontos\n{gym} agora em {percent}% (confiança de {trust}%).'**
  String reportThanks(String gym, String percent, String trust);

  /// No description provided for @alertVeryHighNow.
  ///
  /// In pt, this message translates to:
  /// **'Lotação muito alta agora. Considere treinar em outro horário.'**
  String get alertVeryHighNow;

  /// No description provided for @alertBestWindow.
  ///
  /// In pt, this message translates to:
  /// **'Melhor horário previsto: por volta das {hour}h ({percent}%).'**
  String alertBestWindow(String hour, String percent);

  /// No description provided for @alertLessCrowded.
  ///
  /// In pt, this message translates to:
  /// **'{gym} está menos cheia agora ({delta} pontos a menos).'**
  String alertLessCrowded(String gym, String delta);

  /// No description provided for @alertStableFlow.
  ///
  /// In pt, this message translates to:
  /// **'Movimento estável nas próximas horas.'**
  String get alertStableFlow;

  /// No description provided for @pushChannelName.
  ///
  /// In pt, this message translates to:
  /// **'Alertas de lotação'**
  String get pushChannelName;

  /// No description provided for @pushChannelDescription.
  ///
  /// In pt, this message translates to:
  /// **'Avisos de academias tranquilas perto de você.'**
  String get pushChannelDescription;

  /// No description provided for @pushLowCrowdTitle.
  ///
  /// In pt, this message translates to:
  /// **'Academia tranquila perto de você'**
  String get pushLowCrowdTitle;

  /// No description provided for @pushLowCrowdBody.
  ///
  /// In pt, this message translates to:
  /// **'{gym} com {percent}% agora, a {distance} de você.'**
  String pushLowCrowdBody(String gym, String percent, String distance);

  /// No description provided for @gymFoundOnMap.
  ///
  /// In pt, this message translates to:
  /// **'Academia encontrada no mapa'**
  String get gymFoundOnMap;

  /// No description provided for @controlsPlaces.
  ///
  /// In pt, this message translates to:
  /// **'Escolher locais do mapa'**
  String get controlsPlaces;

  /// No description provided for @placesTitle.
  ///
  /// In pt, this message translates to:
  /// **'Locais no mapa'**
  String get placesTitle;

  /// No description provided for @placesSubtitle.
  ///
  /// In pt, this message translates to:
  /// **'Marque o que você quer ver. As academias aparecem sempre.'**
  String get placesSubtitle;

  /// No description provided for @placesShowAll.
  ///
  /// In pt, this message translates to:
  /// **'Mostrar tudo'**
  String get placesShowAll;

  /// No description provided for @placesHideAll.
  ///
  /// In pt, this message translates to:
  /// **'Ocultar tudo'**
  String get placesHideAll;

  /// No description provided for @placesTransport.
  ///
  /// In pt, this message translates to:
  /// **'Transporte (paradas de ônibus, estações)'**
  String get placesTransport;

  /// No description provided for @placesFood.
  ///
  /// In pt, this message translates to:
  /// **'Alimentação'**
  String get placesFood;

  /// No description provided for @placesShops.
  ///
  /// In pt, this message translates to:
  /// **'Comércio'**
  String get placesShops;

  /// No description provided for @placesHealth.
  ///
  /// In pt, this message translates to:
  /// **'Saúde'**
  String get placesHealth;

  /// No description provided for @placesEducation.
  ///
  /// In pt, this message translates to:
  /// **'Educação'**
  String get placesEducation;

  /// No description provided for @placesServices.
  ///
  /// In pt, this message translates to:
  /// **'Serviços (bancos, correios…)'**
  String get placesServices;

  /// No description provided for @placesLeisure.
  ///
  /// In pt, this message translates to:
  /// **'Lazer e turismo'**
  String get placesLeisure;

  /// No description provided for @placesReligion.
  ///
  /// In pt, this message translates to:
  /// **'Templos e igrejas'**
  String get placesReligion;

  /// No description provided for @placesOther.
  ///
  /// In pt, this message translates to:
  /// **'Outros'**
  String get placesOther;

  /// No description provided for @gymUnnamed.
  ///
  /// In pt, this message translates to:
  /// **'Academia'**
  String get gymUnnamed;

  /// No description provided for @routeCalculating.
  ///
  /// In pt, this message translates to:
  /// **'Calculando trajeto…'**
  String get routeCalculating;

  /// No description provided for @routeFailed.
  ///
  /// In pt, this message translates to:
  /// **'Não foi possível calcular o trajeto agora.'**
  String get routeFailed;

  /// No description provided for @routeWalking.
  ///
  /// In pt, this message translates to:
  /// **'A pé'**
  String get routeWalking;

  /// No description provided for @routeDriving.
  ///
  /// In pt, this message translates to:
  /// **'Carro'**
  String get routeDriving;

  /// No description provided for @routeOpenInGoogleMaps.
  ///
  /// In pt, this message translates to:
  /// **'Navegar no Google Maps'**
  String get routeOpenInGoogleMaps;

  /// No description provided for @amenityWeights.
  ///
  /// In pt, this message translates to:
  /// **'Musculação'**
  String get amenityWeights;

  /// No description provided for @amenityCardio.
  ///
  /// In pt, this message translates to:
  /// **'Cardio'**
  String get amenityCardio;

  /// No description provided for @amenityGroupClasses.
  ///
  /// In pt, this message translates to:
  /// **'Aulas coletivas'**
  String get amenityGroupClasses;

  /// No description provided for @amenityPool.
  ///
  /// In pt, this message translates to:
  /// **'Piscina'**
  String get amenityPool;

  /// No description provided for @routeHideCard.
  ///
  /// In pt, this message translates to:
  /// **'Ocultar cartão (o trajeto continua no mapa)'**
  String get routeHideCard;

  /// No description provided for @routeEnd.
  ///
  /// In pt, this message translates to:
  /// **'Encerrar trajeto'**
  String get routeEnd;

  /// No description provided for @routeRecalculating.
  ///
  /// In pt, this message translates to:
  /// **'Recalculando trajeto…'**
  String get routeRecalculating;

  /// No description provided for @routeArrived.
  ///
  /// In pt, this message translates to:
  /// **'Você chegou à academia.'**
  String get routeArrived;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'pt'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'pt':
      return AppLocalizationsPt();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
