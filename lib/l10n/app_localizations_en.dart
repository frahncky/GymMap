// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get settingsLanguageTitle => 'Language';

  @override
  String get settingsLanguageSystem => 'Device language';

  @override
  String get settingsLanguagePortuguese => 'Português';

  @override
  String get settingsLanguageEnglish => 'English';

  @override
  String get planFreeActive => 'Free plan active';

  @override
  String planValidUntil(String date) {
    return 'Valid until $date';
  }

  @override
  String durationDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days',
      one: '1 day',
    );
    return '$_temp0';
  }

  @override
  String durationHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hours',
      one: '1 hour',
    );
    return '$_temp0';
  }

  @override
  String get durationUnderOneHour => 'less than 1 hour';

  @override
  String planExpiresSoon(String plan, String window) {
    return 'Your $plan plan expires in $window. Renewal is manual only, whenever you decide.';
  }

  @override
  String get authInitializing => 'Authentication is still starting';

  @override
  String get authProductionNoBackend =>
      'Production mode active without a remote backend configured';

  @override
  String get authNoBackend => 'Remote backend not configured in the app';

  @override
  String get authProductionNeedsSession =>
      'Production mode requires a signed-in session';

  @override
  String get authAnonymousAccount =>
      'Anonymous account on this device. Create an account so you don\'t lose your subscription when you switch phones.';

  @override
  String authSessionActive(String user) {
    return 'Signed in as $user';
  }

  @override
  String get authNotSignedIn => 'Not signed in';

  @override
  String get playLoadingProducts => 'Google Play: loading products...';

  @override
  String get playUnavailable => 'Google Play is unavailable on this device.';

  @override
  String get playProductsMissing =>
      'Google Play: one or more products not found yet.';

  @override
  String get playReady => 'Google Play ready for checkout.';

  @override
  String get playListenFailed => 'Couldn\'t listen to Google Play purchases.';

  @override
  String get playLoadProductsFailed => 'Couldn\'t load Google Play products.';

  @override
  String playProductsNotFound(String ids) {
    return 'Products not found on Google Play: $ids';
  }

  @override
  String get playLoadProductsError => 'Failed to load Google Play products.';

  @override
  String authTooManyAttemptsWait(String wait) {
    return 'Too many sign-in attempts. Wait $wait.';
  }

  @override
  String get authTooManyAttempts =>
      'Too many sign-in attempts. Wait a moment and try again.';

  @override
  String get authInvalidCredentials => 'Invalid username or password.';

  @override
  String get authMissingCredentials => 'Enter your username and password.';

  @override
  String get authInvalidUsername =>
      'Username must have 3 to 32 characters: lowercase letters, numbers, dot, hyphen or underscore.';

  @override
  String get authUsernameTaken => 'This username is already taken.';

  @override
  String get authPasswordTooShort =>
      'The password must have at least 8 characters.';

  @override
  String get authAlreadyRegistered =>
      'This session already belongs to a registered account.';

  @override
  String get authUnauthorized => 'Session not authorized.';

  @override
  String get authFailed => 'Authentication failed';

  @override
  String billingRateLimitedWait(String wait) {
    return 'Attempt limit reached. Wait $wait.';
  }

  @override
  String get billingRateLimited =>
      'Attempt limit reached. Wait a moment and try again.';

  @override
  String get billingProductionNeedsBackend =>
      'Production mode requires a remote backend.';

  @override
  String get billingPlayNeedsBackend =>
      'Google Play checkout requires a remote backend.';

  @override
  String get billingProductionNeedsUser =>
      'Production mode requires a signed-in user.';

  @override
  String get billingProductNotFound =>
      'Subscription product not found on Google Play.';

  @override
  String get billingCheckoutNotStarted =>
      'Couldn\'t start Google Play checkout.';

  @override
  String get billingProductMissing => 'Subscription product not provided.';

  @override
  String get billingTokenMissing => 'Purchase token missing. Try again.';

  @override
  String get billingPurchaseNotActive =>
      'Purchase is not active on Google Play yet.';

  @override
  String get billingPurchaseNotFound => 'Purchase not found on Google Play.';

  @override
  String get billingProductMismatch =>
      'The purchased product doesn\'t match the selected plan.';

  @override
  String get billingPackageMismatch => 'Purchase linked to another app.';

  @override
  String get billingPlayUnauthorized =>
      'Backend isn\'t allowed to validate Google Play. Check the credentials.';

  @override
  String get billingValidationUnavailable =>
      'Couldn\'t validate the Google Play purchase right now.';

  @override
  String get billingPendingWebhook =>
      'Payment not confirmed by the webhook yet. Wait a few seconds and try again.';

  @override
  String get billingPixUnavailable =>
      'Pix gateway unavailable right now. Try again shortly.';

  @override
  String get billingInvalidWebhook =>
      'Invalid payment webhook. Contact support.';

  @override
  String get billingSessionExpiredOrForbidden =>
      'Session expired or not allowed. Sign in again.';

  @override
  String get billingSessionExpired => 'Session expired. Sign in again.';

  @override
  String get billingGenericFailure =>
      'Couldn\'t process the subscription right now.';

  @override
  String get planExpiredBackToFree =>
      'Subscription expired. The app is back on the free plan.';

  @override
  String get subscriptionInitializing =>
      'Subscription is still starting. Try again.';

  @override
  String get planFreeActivated => 'Free plan activated.';

  @override
  String get authNoBackendForLogin =>
      'Remote backend not configured for sign-in.';

  @override
  String authAccountCreated(String user) {
    return 'Account created for $user.';
  }

  @override
  String authSignedIn(String user) {
    return 'Signed in as $user.';
  }

  @override
  String get authCreateAccount => 'Create account';

  @override
  String get authSignInMonthly => 'Sign in to the monthly plan';

  @override
  String get authUsernameLabel => 'Username';

  @override
  String get authUsernameHelper =>
      '3 to 32 characters: a-z, 0-9, dot, hyphen or _';

  @override
  String get authPasswordLabel => 'Password';

  @override
  String get authPasswordHelper => 'At least 8 characters';

  @override
  String get actionCancel => 'Cancel';

  @override
  String get authCreating => 'Creating...';

  @override
  String get authSigningIn => 'Signing in...';

  @override
  String get authSignIn => 'Sign in';

  @override
  String get authNoSession => 'There\'s no signed-in session.';

  @override
  String get authSignedOut => 'Signed out.';

  @override
  String get authSignOutFailed => 'Couldn\'t sign out right now.';

  @override
  String get playFinishPayment =>
      'Complete the payment on Google Play to activate the plan.';

  @override
  String get playPurchaseFailed =>
      'Failed to process the Google Play purchase.';

  @override
  String get playPaymentCanceled => 'Payment canceled on Google Play.';

  @override
  String playUnknownProduct(String id) {
    return 'Unknown Google Play product: $id';
  }

  @override
  String planActivatedSuccess(String plan) {
    return '$plan subscription activated successfully.';
  }

  @override
  String get playFinalizeFailed =>
      'Purchase validated, but it couldn\'t be finalized on Google Play.';

  @override
  String get priceFreeMonthly => 'R\$ 0/month';

  @override
  String pricePerMonth(String price) {
    return '$price/month';
  }

  @override
  String get planCurrent => 'Current plan';

  @override
  String get planContinueFree => 'Continue free';

  @override
  String get planBackToFree => 'Back to free';

  @override
  String get planSubscribe => 'Subscribe';

  @override
  String get planUpgrade => 'Upgrade';

  @override
  String get planChange => 'Change plan';

  @override
  String promoUntil(String message, String deadline) {
    return '$message • until $deadline';
  }

  @override
  String get planIncludesPro => 'Includes everything in Pro';

  @override
  String get planStartFreeTrial => 'Start free trial';

  @override
  String get planMostPopular => 'MOST POPULAR';

  @override
  String get planInstantAccess => 'Instant access, cancel anytime.';

  @override
  String get planFeatureLiveOccupancy => 'Live occupancy';

  @override
  String get planFeatureHistory => '24h history';

  @override
  String get planFeaturePeakCompare => 'Peaks and comparison';

  @override
  String get planFeatureForecast => 'Forecast and alerts';

  @override
  String get planFeatureNationwide => 'Nationwide coverage';

  @override
  String get planQuickComparison => 'Quick comparison';

  @override
  String planAvailableIn(String plan) {
    return 'Available on the $plan plan';
  }

  @override
  String planUnavailableIn(String plan) {
    return 'Not available on the $plan plan';
  }

  @override
  String get planAvailable => 'Available';

  @override
  String get planUnavailable => 'Not available';

  @override
  String get paywallTitle => 'Get the most out of GymMap';

  @override
  String get paywallSubtitle =>
      'Pick the right plan for occupancy, forecasts and comparisons.';

  @override
  String get paywallSocialProof => '10,000+ active premium users';

  @override
  String get paywallRating => 'Average rating 4.8/5 in verified reviews.';

  @override
  String get subscriptionLoading => 'Loading subscription...';

  @override
  String get authSignOut => 'Sign out';

  @override
  String get planContinueWithFree => 'Continue with the free plan';

  @override
  String get actionClose => 'Close';

  @override
  String get planNameFree => 'Free';

  @override
  String get planNameSmart => 'Essential';

  @override
  String get insightCurrentOccupancy => 'Current occupancy';

  @override
  String get insightHistory24h => 'Last 24h history';

  @override
  String get insightPeakHours => 'Peak hours by day';

  @override
  String get insightCompareGyms => 'Gym comparison';

  @override
  String get insightForecast => 'Occupancy forecast for the next hours';

  @override
  String get insightNationwide => 'Coverage anywhere in the country';

  @override
  String get insightAlerts => 'Personalized alerts';

  @override
  String get communityYourRegion => 'Your region';

  @override
  String get communityRegionUnavailable => 'Region unavailable';

  @override
  String distanceMetersFromYou(String meters) {
    return '$meters m from you';
  }

  @override
  String distanceKmFromYou(String km) {
    return '$km km from you';
  }

  @override
  String get communityPhotoCaptionRecent =>
      'Recent photo from someone who trained here.';

  @override
  String get communityPhotoCaptionRecord =>
      'Recent community record at this gym.';

  @override
  String get distanceUnknown => 'Distance not available';

  @override
  String timeAgoMinutes(String count) {
    return '$count min ago';
  }

  @override
  String timeAgoHours(String count) {
    return '$count h ago';
  }

  @override
  String timeAgoDays(String count) {
    return '$count d ago';
  }

  @override
  String get occupancyLevelLow => 'Low';

  @override
  String get occupancyLevelModerate => 'Moderate';

  @override
  String get occupancyLevelHigh => 'High';

  @override
  String get communityAnonymousUser => 'Anonymous user';

  @override
  String get communityYou => 'You';

  @override
  String communityThanksValidation(String points) {
    return 'Thanks for validating! +$points community points.';
  }

  @override
  String get communityTitle => 'Community';

  @override
  String get communityLoadingReports => 'Loading reports from your region...';

  @override
  String get communityNoReportsYet =>
      'There are no recent reports from gyms in your region yet.';

  @override
  String get communityRecentRegionReports =>
      'Recent reports from gyms in your region.';

  @override
  String get communityFeedDescription =>
      'Feed of recent reports with collaborative validation.';

  @override
  String get communityTopContributors => 'Top contributors this week';

  @override
  String communityYourPosition(String rank) {
    return 'Your position: $rank';
  }

  @override
  String communityRegion(String region) {
    return 'Region: $region';
  }

  @override
  String get communityNotEnoughRanking => 'Not enough ranking data yet.';

  @override
  String get communityEnableLocationRanking =>
      'Turn on location to load the real ranking.';

  @override
  String get communityRealDataWeek => 'Real data from the last 7 days';

  @override
  String communityPointsShort(String points) {
    return '$points pts';
  }

  @override
  String communityYourPoints(String points) {
    return 'Your points: $points';
  }

  @override
  String get communityPointsPerValidation => '+2 per validation';

  @override
  String get communityContributeOnMap => 'Contribute on the map';

  @override
  String get communityRecentRegionTitle => 'Recent reports in your region';

  @override
  String get communityRecentTitle => 'Recent reports';

  @override
  String get communityRefreshReports => 'Refresh reports';

  @override
  String get communityEmptyRegion =>
      'No recent reports in your region right now. Open the map and contribute to show up here.';

  @override
  String get communityEnableLocationReports =>
      'Turn on your location to see recent reports from your region.';

  @override
  String get communityPhotoByCommunity => 'Photo sent by the community.';

  @override
  String communityConfirm(String count) {
    return 'Confirm ($count)';
  }

  @override
  String communityDisagree(String count) {
    return 'Disagree ($count)';
  }

  @override
  String get profileDefaultName => 'GymMap user';

  @override
  String get profileSavePreferenceFailed =>
      'Couldn\'t save this preference right now.';

  @override
  String get profileLoadPhotoFailed => 'Couldn\'t load the photo.';

  @override
  String get profilePickPhotoFailed => 'Couldn\'t pick the photo.';

  @override
  String get profileNameRequired => 'Enter a name for your profile.';

  @override
  String get profileSaveFailed => 'Couldn\'t save the profile.';

  @override
  String get profileEdit => 'Edit profile';

  @override
  String get profileChangePhoto => 'Change photo';

  @override
  String get profileRemovePhoto => 'Remove';

  @override
  String get profileNameLabel => 'Name';

  @override
  String get profileNameHint => 'How you want to appear';

  @override
  String get actionSave => 'Save';

  @override
  String get profileUpdated => 'Profile updated.';

  @override
  String get profileTitle => 'Profile';

  @override
  String profileCurrentPlan(String plan) {
    return 'Current plan: $plan';
  }

  @override
  String get profileVisible => 'Public profile';

  @override
  String get profilePrivate => 'Private profile';

  @override
  String get actionOpenMap => 'Open map';

  @override
  String get profilePublicTitle => 'Allow public view';

  @override
  String get profilePublicSubtitle =>
      'Lets your name and photo appear in the community.';

  @override
  String get profilePushTitle => 'Push notifications';

  @override
  String get profilePushSubtitle => 'Get occupancy alerts and updates.';

  @override
  String get profileLocationAlertsTitle => 'Location alerts';

  @override
  String get profileLocationAlertsSubtitle =>
      'Let me know when a gym near me has low occupancy.';

  @override
  String get profileHapticsTitle => 'Haptic feedback';

  @override
  String get profileHapticsSubtitle => 'Vibrate on important actions.';

  @override
  String get profileDataSaverTitle => 'Data saver mode';

  @override
  String get profileDataSaverSubtitle => 'Reduce background updates.';

  @override
  String get favoritesDefaultName => 'Favorite gym';

  @override
  String get favoritesLoadFailed => 'Couldn\'t load your favorites.';

  @override
  String get actionRetry => 'Try again';

  @override
  String get favoritesTitle => 'Favorites';

  @override
  String get favoritesEmpty => 'You haven\'t saved any favorite gyms yet.';

  @override
  String favoritesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count saved gyms.',
      one: '1 saved gym.',
    );
    return '$_temp0';
  }

  @override
  String get favoritesHint =>
      'Use the heart icon on the gym panel to save your favorites.';

  @override
  String get favoritesViewMap => 'View map';

  @override
  String get navMap => 'Map';

  @override
  String get navFavorites => 'Favorites';

  @override
  String get navCommunity => 'Community';

  @override
  String get navProfile => 'Profile';

  @override
  String headerCommunityPointsLabel(String points) {
    return 'Community points: $points';
  }

  @override
  String get headerCommunityPointsHint => 'Tap to open the weekly ranking';

  @override
  String get headerOpenRanking => 'Open community ranking';

  @override
  String get headerPlanSettings => 'Plan settings';

  @override
  String get headerPlanSettingsHint => 'Tap to open subscription options';

  @override
  String get searchFieldLabel => 'Search field';

  @override
  String get searchFieldHint => 'Type a gym, neighborhood or city';

  @override
  String get searchPlaceholder => 'Search gym, neighborhood or city';

  @override
  String get searchLocationTooltip => 'Search location';

  @override
  String get searchClearTooltip => 'Clear search';

  @override
  String filterSemanticsLabel(String filter) {
    return 'Filter $filter';
  }

  @override
  String get filterTapToRemove => 'Tap again to remove the filter';

  @override
  String get filterTapToApply => 'Tap to apply the filter';

  @override
  String get emptyZoomIn => 'Zoom in on the map to load gyms automatically.';

  @override
  String get emptyNoFilterMatch => 'No gyms match the active filters.';

  @override
  String get emptyNoSearchResults => 'No results found for your search.';

  @override
  String get emptyNoNearbyGyms => 'No gyms registered near your location.';

  @override
  String get filterClearAll => 'Clear filters';

  @override
  String get adLabel => 'Ad: upgrade to remove ads.';

  @override
  String get tutorialTitle => 'Quick map tips';

  @override
  String get tutorialSearch => 'Use search for a gym, neighborhood or city.';

  @override
  String get tutorialFilters => 'Turn on the toggles to filter results.';

  @override
  String get tutorialPin => 'Tap a pin to open details and send a report.';

  @override
  String get tutorialGotIt => 'Got it';

  @override
  String get tutorialShowNearest => 'Show nearest';

  @override
  String get tutorialSkip => 'Skip tutorial';

  @override
  String get panelFavoriteGym => 'Favorite gym';

  @override
  String get panelAddGymToFavorites => 'Add gym to favorites';

  @override
  String get panelToggleFavoriteHint => 'Tap to toggle favorite';

  @override
  String get panelRemoveFavorite => 'Remove from favorites';

  @override
  String get panelAddFavorite => 'Add to favorites';

  @override
  String get gymClosed => 'Closed';

  @override
  String panelStatus(String status) {
    return 'Status: $status';
  }

  @override
  String get panelClosedNotice =>
      'Gym closed now. Occupancy hidden on the map.';

  @override
  String panelReportsSummary(String total, String recent) {
    return '$total total reports | $recent recent reports';
  }

  @override
  String panelLastReport(String time) {
    return 'Last report: $time';
  }

  @override
  String get panelViewRoute => 'Directions';

  @override
  String get panelUpdateOccupancy => 'Update this gym\'s occupancy';

  @override
  String get panelSendingReport => 'Sending report...';

  @override
  String get panelContribute => 'Contribute';

  @override
  String get panelContributeClosed =>
      'Occupancy reports are only available while the gym is open.';

  @override
  String get chartPeak => 'Peak';

  @override
  String get chartAverage => 'Average';

  @override
  String get panelPeakOfDay => 'Peak of the day';

  @override
  String get panelReference => 'reference';

  @override
  String get panelForecast => 'Forecast for the next hours';

  @override
  String reportBlockedWait(String minutes) {
    return 'Sending temporarily blocked. Wait $minutes min before a new report.';
  }

  @override
  String get subscriptionActivated => 'Subscription activated!';

  @override
  String planUnlocked(String plan) {
    return '$plan plan unlocked successfully.';
  }

  @override
  String get actionContinue => 'Continue';

  @override
  String get communityCurrentLocation => 'Your current location';

  @override
  String get communityCurrentRegion => 'Current region';

  @override
  String get communityNoRanking => 'no ranking';

  @override
  String get communityTop10 => 'Top 10 contributors this week';

  @override
  String communityCurrentPosition(String rank, String points) {
    return 'Your current position: $rank  .  $points pts';
  }

  @override
  String get communityRankingUpdating => 'Updating ranking...';

  @override
  String get communityRankingRealInfo =>
      'Real points from the last 7 days. Each valid report adds +5 points.';

  @override
  String get communityRankingInfo =>
      'Each valid report adds +5 points. Keep contributing to climb the ranking.';

  @override
  String get communityRankingEmpty =>
      'There aren\'t enough points in this region yet.';

  @override
  String get locationNotificationTitle => 'GymMap location active';

  @override
  String get locationNotificationText =>
      'GymMap is updating your location in the background.';

  @override
  String get locationEnableGps => 'Turn on GPS to center on your location.';

  @override
  String get locationNoPermission =>
      'No location permission. You can turn it on later in settings.';

  @override
  String get locationDeniedForever =>
      'Location permission permanently denied. Change it in the device settings.';

  @override
  String get locationDenied => 'Location permission denied.';

  @override
  String get locationTimeout =>
      'Timed out getting your location. Try again shortly.';

  @override
  String get locationUnavailable => 'Couldn\'t get your location right now.';

  @override
  String get locationPromptTitle => 'Allow location?';

  @override
  String get locationPromptBody =>
      'With location on, GymMap finds nearby gyms automatically and calculates distance in real time.';

  @override
  String get locationPromptLater => 'Not now';

  @override
  String get locationPromptAllow => 'Allow';

  @override
  String get controlsNorthLabel => 'Reorient map to north';

  @override
  String get controlsNorthHint =>
      'Tap to reset the orientation to zero degrees';

  @override
  String get controlsNorthTooltip => 'Reorient to north';

  @override
  String get controlsMyLocationLabel => 'Center on my location';

  @override
  String get controlsMyLocationHint =>
      'Tap to move the map to your current position';

  @override
  String get controlsMyLocationTooltip => 'My location';

  @override
  String get controlsUpdatingGymsLabel => 'Updating gyms on the map';

  @override
  String get controlsUpdatingGyms => 'Updating gyms...';

  @override
  String get controlsYourLocation => 'Your location on the map';

  @override
  String get coverageEnableLocation =>
      'Turn on location to see gyms in your region on your current plan.';

  @override
  String get coverageEliteOnly =>
      'Other regions are exclusive to the Elite plan.';

  @override
  String get filterOpenNow => 'Open now';

  @override
  String get filterLowCrowd => 'Low occupancy';

  @override
  String get filterClasses => 'Classes';

  @override
  String get filterCardio => 'Cardio';

  @override
  String get filterPool => 'With pool';

  @override
  String get filterFavorites => 'Favorites';

  @override
  String hoursOpenUntil(String time) {
    return 'Open until $time';
  }

  @override
  String hoursOpensAt(String time) {
    return 'Opens at $time';
  }

  @override
  String hoursOpensTomorrow(String time) {
    return 'Opens tomorrow at $time';
  }

  @override
  String hoursToday(String open, String close) {
    return 'Today: $open - $close';
  }

  @override
  String get mapDisabledInTest => 'Map disabled in test mode';

  @override
  String get mapLocatingYou => 'Locating you...';

  @override
  String get mapUnavailableRetry => 'Map unavailable. Try again';

  @override
  String get mapLoading => 'Loading map...';

  @override
  String get mapOpenGoogleMapsFailed => 'Couldn\'t open Google Maps right now.';

  @override
  String favoriteAdded(String gym) {
    return '$gym added to favorites.';
  }

  @override
  String favoriteRemoved(String gym) {
    return '$gym removed from favorites.';
  }

  @override
  String get tutorialNoGymToHighlight =>
      'No gym available to highlight right now.';

  @override
  String get searchFailed => 'Couldn\'t search this location right now.';

  @override
  String get searchNotFound =>
      'Place not found. Try a neighborhood, city or address.';

  @override
  String get searchParseFailed => 'Couldn\'t understand this location.';

  @override
  String get searchTimeout => 'Timed out searching this location.';

  @override
  String get searchError => 'Couldn\'t search this location.';

  @override
  String get occupancyLevelVeryHigh => 'Very high';

  @override
  String get timeNoInfo => 'no information';

  @override
  String get timeNow => 'now';

  @override
  String timeMinutesAgo(String count) {
    return '$count min ago';
  }

  @override
  String timeHoursAgo(String count) {
    return '$count h ago';
  }

  @override
  String markerOccupancySemantics(String percent) {
    return '$percent percent occupancy';
  }

  @override
  String get markerClosedNow => 'closed now';

  @override
  String get markerFavoriteSuffix => ', favorite';

  @override
  String get markerTapHint => 'Tap to open the gym details';

  @override
  String get markerGoodMoment => 'Good time';

  @override
  String reportThanks(String gym, String percent, String trust) {
    return 'Thanks for contributing! +5 points\n$gym updated to $percent% (conf. $trust%).';
  }

  @override
  String get alertVeryHighNow =>
      'Very high occupancy right now. Consider training at another time.';

  @override
  String alertBestWindow(String hour, String percent) {
    return 'Best expected window around ${hour}h ($percent%).';
  }

  @override
  String alertLessCrowded(String gym, String delta) {
    return '$gym is $delta pp less crowded right now.';
  }

  @override
  String get alertStableFlow => 'Steady flow over the next hours for this gym.';

  @override
  String get pushChannelName => 'Contextual alerts';

  @override
  String get pushChannelDescription =>
      'Alerts when a nearby gym has low occupancy.';

  @override
  String get pushLowCrowdTitle => 'Low-occupancy gym nearby';

  @override
  String pushLowCrowdBody(String gym, String percent, String distance) {
    return '$gym at $percent% now, $distance from you.';
  }

  @override
  String get gymFoundOnMap => 'Gym found on the map';

  @override
  String get controlsPlaces => 'Choose map places';

  @override
  String get placesTitle => 'Places on the map';

  @override
  String get placesSubtitle =>
      'Check what you want to see. Gyms are always shown.';

  @override
  String get placesShowAll => 'Show all';

  @override
  String get placesHideAll => 'Hide all';

  @override
  String get placesTransport => 'Transport (bus stops, stations)';

  @override
  String get placesFood => 'Food and drink';

  @override
  String get placesShops => 'Shops';

  @override
  String get placesHealth => 'Health';

  @override
  String get placesEducation => 'Education';

  @override
  String get placesServices => 'Services (banks, post offices...)';

  @override
  String get placesLeisure => 'Leisure and tourism';

  @override
  String get placesReligion => 'Places of worship';

  @override
  String get placesOther => 'Other';

  @override
  String get gymUnnamed => 'Gym';

  @override
  String get routeCalculating => 'Calculating route...';

  @override
  String get routeFailed => 'Couldn\'t calculate the route right now.';

  @override
  String get routeWalking => 'Walk';

  @override
  String get routeDriving => 'Car';

  @override
  String get routeOpenInGoogleMaps => 'Navigate in Google Maps';

  @override
  String get amenityWeights => 'Weight training';

  @override
  String get amenityCardio => 'Cardio';

  @override
  String get amenityGroupClasses => 'Group classes';

  @override
  String get amenityPool => 'Pool';

  @override
  String get routeHideCard => 'Hide card (the route stays on the map)';

  @override
  String get routeEnd => 'End route';

  @override
  String get routeRecalculating => 'Recalculating route...';

  @override
  String get routeArrived => 'You\'ve arrived at the gym.';
}
