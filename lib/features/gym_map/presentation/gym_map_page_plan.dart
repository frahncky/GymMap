part of 'gym_map_page.dart';

extension _GymMapPagePlan on _GymMapPageState {
  String _tierToPlanKey(AppPlanTier tier) => tier.name;

  AppPlanTier _tierFromPlanKey(String planKey) {
    for (final tier in AppPlanTier.values) {
      if (tier.name == planKey) {
        return tier;
      }
    }
    return AppPlanTier.free;
  }

  String _formatDateTimeLabel(DateTime dateUtc) {
    return DateFormat.yMd(_t.localeName).add_Hm().format(dateUtc.toLocal());
  }

  String _activePlanStatusLabel() {
    if (_activePlan == AppPlanTier.free || _activePlanExpiresAtUtc == null) {
      return _t.planFreeActive;
    }
    return _t.planValidUntil(_formatDateTimeLabel(_activePlanExpiresAtUtc!));
  }

  void _maybeWarnPlanNearExpiry(AppPlanTier plan, DateTime? expiresAtUtc) {
    if (plan == AppPlanTier.free || expiresAtUtc == null) {
      _lastPlanExpiryWarningKey = null;
      return;
    }
    final now = DateTime.now().toUtc();
    final remaining = expiresAtUtc.difference(now);
    if (remaining <= Duration.zero || remaining > const Duration(days: 3)) {
      return;
    }
    final warningKey = '${plan.name}:${expiresAtUtc.millisecondsSinceEpoch}';
    if (_lastPlanExpiryWarningKey == warningKey) {
      return;
    }
    _lastPlanExpiryWarningKey = warningKey;
    final days = remaining.inDays;
    final hours = remaining.inHours;
    final planLabel = kPlanCatalog[plan]!.label;
    final windowLabel =
        days >= 1
            ? _t.durationDays(days)
            : hours >= 1
            ? _t.durationHours(hours)
            : _t.durationUnderOneHour;
    _showMapSnack(_t.planExpiresSoon(planLabel, windowLabel));
  }

  String _planAuthStatusLabel() {
    final service = _planSubscriptionService;
    if (service == null) {
      return _t.authInitializing;
    }
    if (service.isProductionMode && !service.hasRemoteBackend) {
      return _t.authProductionNoBackend;
    }
    if (!service.hasRemoteBackend) {
      return _t.authNoBackend;
    }
    if (service.isProductionMode && !service.hasAuthSession) {
      return _t.authProductionNeedsSession;
    }
    if (service.isAnonymousSession) {
      return _t.authAnonymousAccount;
    }
    if (service.hasAuthSession) {
      return _t.authSessionActive(service.username ?? service.userId);
    }
    return _t.authNotSignedIn;
  }

  Future<void> _initializePlayStoreBilling() async {
    try {
      final isAvailable = await _inAppPurchase.isAvailable();
      if (!mounted) {
        return;
      }
      _setStateIfMapVisible(() {
        _isPlayStoreAvailable = isAvailable;
      });
      if (!isAvailable) {
        return;
      }
      _purchaseStreamSubscription?.cancel();
      _purchaseStreamSubscription = _inAppPurchase.purchaseStream.listen(
        (purchases) {
          unawaited(_handlePlayPurchaseUpdates(purchases));
        },
        onError: (Object error, StackTrace stackTrace) {
          if (!mounted) {
            return;
          }
          _showMapSnack(_t.playListenFailed);
        },
      );
      await _loadPlayProducts(forceRefresh: true);
    } catch (_) {
      if (!mounted) {
        return;
      }
      _setStateIfMapVisible(() {
        _isPlayStoreAvailable = false;
      });
    }
  }

  Future<void> _loadPlayProducts({bool forceRefresh = false}) async {
    if (!_isPlayStoreAvailable) {
      return;
    }
    if (_isLoadingPlayProducts && !forceRefresh) {
      return;
    }
    if (mounted) {
      _setStateIfMapVisible(() {
        _isLoadingPlayProducts = true;
      });
    }
    try {
      final response = await _inAppPurchase.queryProductDetails(
        _GymMapPageState._planProductIds.values.toSet(),
      );
      if (!mounted) {
        return;
      }
      _setStateIfMapVisible(() {
        _playProducts = response.productDetails;
      });
      if (response.error != null) {
        _showMapSnack(_t.playLoadProductsFailed);
      } else if (response.notFoundIDs.isNotEmpty) {
        _showMapSnack(_t.playProductsNotFound);
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showMapSnack(_t.playLoadProductsError);
    } finally {
      if (mounted) {
        _setStateIfMapVisible(() {
          _isLoadingPlayProducts = false;
        });
      }
    }
  }

  String _formatAuthFailure(Object error) {
    final raw = '$error'.trim();
    final normalized =
        raw.startsWith('Bad state: ')
            ? raw.substring('Bad state: '.length).trim()
            : raw;
    if (normalized.startsWith('rate_limited')) {
      final retryAfter = _retryAfterSecondsFromRateLimitError(normalized);
      if (retryAfter != null) {
        return _t.authTooManyAttemptsWait(_formatRetryAfterLabel(retryAfter));
      }
      return _t.authTooManyAttempts;
    }
    switch (normalized) {
      case 'invalid_credentials':
        return _t.authInvalidCredentials;
      case 'missing_credentials':
        return _t.authMissingCredentials;
      case 'invalid_username':
        return _t.authInvalidUsername;
      case 'username_taken':
        return _t.authUsernameTaken;
      case 'invalid_password_length':
        return _t.authPasswordTooShort;
      case 'already_registered':
        return _t.authAlreadyRegistered;
      case 'unauthorized':
        return _t.authUnauthorized;
      case '':
        return _t.authFailed;
      default:
        return normalized;
    }
  }

  String _metricErrorCode(Object error) {
    final raw = '$error'.trim();
    final normalized =
        raw.startsWith('Bad state: ')
            ? raw.substring('Bad state: '.length).trim()
            : raw;
    return normalized.isEmpty ? 'unknown' : normalized;
  }

  int? _retryAfterSecondsFromRateLimitError(String normalized) {
    final separator = normalized.indexOf(':');
    if (separator < 0 || separator + 1 >= normalized.length) {
      return null;
    }
    final parsed = int.tryParse(normalized.substring(separator + 1).trim());
    if (parsed == null || parsed <= 0) {
      return null;
    }
    return parsed;
  }

  String _formatRetryAfterLabel(int seconds) {
    if (seconds >= 60) {
      final minutes = (seconds / 60).ceil();
      return '$minutes min';
    }
    return '$seconds s';
  }

  String _formatBillingFailure(Object error) {
    final raw = '$error'.trim();
    final normalized =
        raw.startsWith('Bad state: ')
            ? raw.substring('Bad state: '.length).trim()
            : raw;
    if (normalized.startsWith('rate_limited')) {
      final retryAfter = _retryAfterSecondsFromRateLimitError(normalized);
      if (retryAfter != null) {
        return _t.billingRateLimitedWait(_formatRetryAfterLabel(retryAfter));
      }
      return _t.billingRateLimited;
    }
    switch (normalized) {
      case 'backend_required_in_production':
        return _t.billingProductionNeedsBackend;
      case 'backend_required_for_play_billing':
        return _t.billingPlayNeedsBackend;
      case 'user_identity_required_in_production':
        return _t.billingProductionNeedsUser;
      case 'play_store_unavailable':
        return _t.playUnavailable;
      case 'play_product_not_found':
        return _t.billingProductNotFound;
      case 'play_checkout_not_started':
        return _t.billingCheckoutNotStarted;
      case 'play_product_id_missing':
        return _t.billingProductMissing;
      case 'play_purchase_token_missing':
        return _t.billingTokenMissing;
      case 'play_purchase_not_active':
        return _t.billingPurchaseNotActive;
      case 'play_purchase_not_found':
        return _t.billingPurchaseNotFound;
      case 'play_product_mismatch':
        return _t.billingProductMismatch;
      case 'play_package_mismatch':
        return _t.billingPackageMismatch;
      case 'play_api_unauthorized':
        return _t.billingPlayUnauthorized;
      case 'play_validation_unavailable':
      case 'play_api_unavailable':
        return _t.billingValidationUnavailable;
      case 'payment_pending_webhook':
        return _t.billingPendingWebhook;
      case 'pix_provider_unavailable':
        return _t.billingPixUnavailable;
      case 'invalid_webhook_signature':
        return _t.billingInvalidWebhook;
      case 'unauthorized':
      case 'forbidden':
        return _t.billingSessionExpiredOrForbidden;
      default:
        if (normalized == 'Backend HTTP 401') {
          return _t.billingSessionExpired;
        }
        if (normalized == 'Backend HTTP 429') {
          return _t.billingRateLimited;
        }
        if (normalized.isEmpty) {
          return _t.billingGenericFailure;
        }
        return normalized;
    }
  }

  Future<void> _initializePlanSubscription() async {
    try {
      final service = await PlanSubscriptionService.create();
      await _ensurePlanSession(service);
      final snapshot = await service.loadActiveSubscription();
      final nextPlan = _tierFromPlanKey(snapshot.activePlanKey);
      if (!mounted) {
        return;
      }
      _setStateIfMapVisible(() {
        _planSubscriptionService = service;
        _activePlan = nextPlan;
        _activePlanExpiresAtUtc = snapshot.expiresAt;
        _isLoadingPlanSubscription = false;
      });
      widget.onActivePlanChanged?.call(nextPlan);
      _enforcePlanCoverageAfterTierChange();
      _maybeWarnPlanNearExpiry(_activePlan, _activePlanExpiresAtUtc);
      _startPlanSyncTimer();
    } catch (_) {
      if (!mounted) {
        return;
      }
      _setStateIfMapVisible(() {
        _isLoadingPlanSubscription = false;
      });
    }
  }

  /// Cria ou renova a conta anônima do aparelho para que os recursos que
  /// dependem do backend (lotação, assinatura) funcionem sem login manual.
  Future<void> _ensurePlanSession(PlanSubscriptionService service) async {
    final hadSession = service.hasAuthSession;
    final previousUserId = service.userId;
    try {
      await service.ensureSession();
    } catch (_) {
      // Sem backend disponível o app segue com o cache local.
      return;
    }
    if (!hadSession || previousUserId != service.userId) {
      _crowdReportRemoteService?.refreshAuthFromStorage();
      // O saldo pedido antes da sessão existir volta "não autorizado".
      unawaited(_refreshRewards());
    }
  }

  void _startPlanSyncTimer() {
    _planSyncTimer?.cancel();
    _planSyncTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      unawaited(_syncPlanFromStorage(showExpiryNotice: false));
    });
  }

  Future<void> _syncPlanFromStorage({required bool showExpiryNotice}) async {
    final service = _planSubscriptionService;
    if (service == null) {
      return;
    }

    await _ensurePlanSession(service);
    final previousPlan = _activePlan;
    final snapshot = await service.loadActiveSubscription();
    if (!mounted) {
      return;
    }

    final nextPlan = _tierFromPlanKey(snapshot.activePlanKey);
    final nextExpiresAt = snapshot.expiresAt;
    final hasExpiryChanged =
        (nextExpiresAt?.millisecondsSinceEpoch ?? 0) !=
        (_activePlanExpiresAtUtc?.millisecondsSinceEpoch ?? 0);
    final hasPlanChanged = nextPlan != _activePlan;
    if (!hasPlanChanged && !hasExpiryChanged) {
      return;
    }

    _setStateIfMapVisible(() {
      _activePlan = nextPlan;
      _activePlanExpiresAtUtc = nextExpiresAt;
    });
    if (hasPlanChanged) {
      widget.onActivePlanChanged?.call(nextPlan);
      _enforcePlanCoverageAfterTierChange();
    }
    _maybeWarnPlanNearExpiry(nextPlan, nextExpiresAt);

    if (showExpiryNotice &&
        previousPlan != AppPlanTier.free &&
        nextPlan == AppPlanTier.free) {
      _showMapSnack(_t.planExpiredBackToFree);
    }
  }

  Future<void> _activateFreePlan() async {
    final service = _planSubscriptionService;
    if (service == null) {
      _showMapSnack(_t.subscriptionInitializing);
      return;
    }
    await service.downgradeToFree();
    await _syncPlanFromStorage(showExpiryNotice: false);
    _showMapSnack(_t.planFreeActivated);
  }

  Future<void> _startPlanLoginFlow(
    BuildContext sheetContext, {
    bool register = false,
  }) async {
    final service = _planSubscriptionService;
    if (service == null) {
      _showMapSnack(_t.subscriptionInitializing);
      return;
    }
    if (!service.hasRemoteBackend) {
      _showMapSnack(_t.authNoBackendForLogin);
      return;
    }

    final userController = TextEditingController(
      text: register || service.isAnonymousSession ? '' : service.userId,
    );
    final passwordController = TextEditingController();
    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          var isSubmitting = false;
          var hidePassword = true;
          String? errorMessage;
          return StatefulBuilder(
            builder: (context, setDialogState) {
              Future<void> submitLogin() async {
                final userId = userController.text.trim();
                final password = passwordController.text;
                if (userId.isEmpty || password.isEmpty) {
                  setDialogState(() {
                    errorMessage = _t.authMissingCredentials;
                  });
                  return;
                }

                setDialogState(() {
                  errorMessage = null;
                  isSubmitting = true;
                });
                if (mounted) {
                  _setStateIfMapVisible(() {
                    _isPlanAuthBusy = true;
                  });
                }
                try {
                  final session =
                      register
                          ? await service.register(
                            username: userId,
                            password: password,
                          )
                          : await service.signIn(
                            userId: userId,
                            password: password,
                          );
                  await _syncPlanFromStorage(showExpiryNotice: false);
                  _crowdReportRemoteService?.refreshAuthFromStorage();
                  unawaited(_syncCrowdReportsForCurrentContext());
                  if (!mounted) {
                    return;
                  }
                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop();
                  }
                  if (sheetContext.mounted) {
                    Navigator.of(sheetContext).pop();
                  }
                  _showMapSnack(
                    register
                        ? _t.authAccountCreated(
                          service.username ?? session.userId,
                        )
                        : _t.authSignedIn(service.username ?? session.userId),
                  );
                } catch (error) {
                  if (dialogContext.mounted) {
                    setDialogState(() {
                      errorMessage = _formatAuthFailure(error);
                    });
                  }
                } finally {
                  if (mounted) {
                    _setStateIfMapVisible(() {
                      _isPlanAuthBusy = false;
                    });
                  }
                  if (dialogContext.mounted) {
                    setDialogState(() {
                      isSubmitting = false;
                    });
                  }
                }
              }

              return AlertDialog(
                title: Text(
                  register ? _t.authCreateAccount : _t.authSignInMonthly,
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: userController,
                      enabled: !isSubmitting,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: _t.authUsernameLabel,
                        hintText: 'user-001',
                        helperText: register ? _t.authUsernameHelper : null,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: passwordController,
                      enabled: !isSubmitting,
                      obscureText: hidePassword,
                      onSubmitted: (_) {
                        unawaited(submitLogin());
                      },
                      decoration: InputDecoration(
                        labelText: _t.authPasswordLabel,
                        helperText: register ? _t.authPasswordHelper : null,
                        suffixIcon: IconButton(
                          onPressed:
                              isSubmitting
                                  ? null
                                  : () {
                                    setDialogState(() {
                                      hidePassword = !hidePassword;
                                    });
                                  },
                          icon: Icon(
                            hidePassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                        ),
                      ),
                    ),
                    if (errorMessage != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        errorMessage!,
                        style: const TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed:
                        isSubmitting
                            ? null
                            : () {
                              Navigator.of(dialogContext).pop();
                            },
                    child: Text(_t.actionCancel),
                  ),
                  FilledButton.icon(
                    onPressed:
                        isSubmitting
                            ? null
                            : () {
                              unawaited(submitLogin());
                            },
                    icon:
                        isSubmitting
                            ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : Icon(register ? Icons.person_add : Icons.login),
                    label: Text(
                      register
                          ? (isSubmitting
                              ? _t.authCreating
                              : _t.authCreateAccount)
                          : (isSubmitting ? _t.authSigningIn : _t.authSignIn),
                    ),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      userController.dispose();
      passwordController.dispose();
    }
  }

  Future<void> _logoutPlanSession(BuildContext sheetContext) async {
    final service = _planSubscriptionService;
    if (service == null) {
      _showMapSnack(_t.subscriptionInitializing);
      return;
    }
    if (!service.hasAuthSession || service.isAnonymousSession) {
      _showMapSnack(_t.authNoSession);
      return;
    }
    if (_isPlanAuthBusy) {
      return;
    }

    _setStateIfMapVisible(() {
      _isPlanAuthBusy = true;
    });
    try {
      await service.signOut();
      // _syncPlanFromStorage volta para a conta anônima do aparelho.
      await _syncPlanFromStorage(showExpiryNotice: false);
      _crowdReportRemoteService?.refreshAuthFromStorage();
      unawaited(_syncCrowdReportsForCurrentContext());
      if (sheetContext.mounted) {
        Navigator.of(sheetContext).pop();
      }
      _showMapSnack(_t.authSignedOut);
    } catch (_) {
      _showMapSnack(_t.authSignOutFailed);
    } finally {
      if (mounted) {
        _setStateIfMapVisible(() {
          _isPlanAuthBusy = false;
        });
      }
    }
  }

  void _onPlanPicked(AppPlanTier selectedTier, BuildContext sheetContext) {
    unawaited(
      _metrics.trackEvent(
        'plan_select',
        params: <String, Object?>{
          'source': 'paywall',
          'currentPlan': _tierToPlanKey(_activePlan),
          'selectedPlan': _tierToPlanKey(selectedTier),
        },
      ),
    );
    Navigator.of(sheetContext).pop();
    if (selectedTier == AppPlanTier.free) {
      unawaited(_activateFreePlan());
      return;
    }
    unawaited(_startStoreCheckout(selectedTier));
  }

  Future<void> _startStoreCheckout(AppPlanTier tier) async {
    final planKey = _tierToPlanKey(tier);
    final service = _planSubscriptionService;
    if (service == null) {
      unawaited(
        _metrics.trackEvent(
          'checkout_start',
          params: <String, Object?>{
            'plan': planKey,
            'result': 'failed',
            'reason': 'service_unavailable',
          },
        ),
      );
      _showMapSnack(_t.subscriptionInitializing);
      return;
    }
    if (_isStartingStoreCheckout) {
      unawaited(
        _metrics.trackEvent(
          'checkout_start',
          params: <String, Object?>{
            'plan': planKey,
            'result': 'failed',
            'reason': 'checkout_in_progress',
          },
        ),
      );
      return;
    }
    if (!_isPlayStoreAvailable) {
      unawaited(
        _metrics.trackEvent(
          'checkout_start',
          params: <String, Object?>{
            'plan': planKey,
            'result': 'failed',
            'reason': 'play_store_unavailable',
          },
        ),
      );
      _showMapSnack(
        _formatBillingFailure(StateError('play_store_unavailable')),
      );
      return;
    }
    final productId = _GymMapPageState._planProductIds[tier];
    if (productId == null || productId.trim().isEmpty) {
      unawaited(
        _metrics.trackEvent(
          'checkout_start',
          params: <String, Object?>{
            'plan': planKey,
            'result': 'failed',
            'reason': 'play_product_id_missing',
          },
        ),
      );
      _showMapSnack(
        _formatBillingFailure(StateError('play_product_id_missing')),
      );
      return;
    }

    ProductDetails? product;
    for (final item in _playProducts) {
      if (item.id == productId) {
        product = item;
        break;
      }
    }
    if (product == null) {
      await _loadPlayProducts(forceRefresh: true);
      for (final item in _playProducts) {
        if (item.id == productId) {
          product = item;
          break;
        }
      }
    }
    if (product == null) {
      unawaited(
        _metrics.trackEvent(
          'checkout_start',
          params: <String, Object?>{
            'plan': planKey,
            'result': 'failed',
            'reason': 'play_product_not_found',
          },
        ),
      );
      _showMapSnack(
        _formatBillingFailure(StateError('play_product_not_found')),
      );
      return;
    }

    _setStateIfMapVisible(() {
      _isStartingStoreCheckout = true;
    });

    try {
      if (service.isProductionMode && !service.hasRemoteBackend) {
        throw StateError('backend_required_in_production');
      }
      if (service.isProductionMode && !service.hasAuthSession) {
        throw StateError('user_identity_required_in_production');
      }
      final started = await _inAppPurchase.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: product),
      );
      if (!started) {
        throw StateError('play_checkout_not_started');
      }
      unawaited(
        _metrics.trackEvent(
          'checkout_start',
          params: <String, Object?>{
            'plan': planKey,
            'productId': product.id,
            'result': 'started',
          },
        ),
      );
      if (!mounted) {
        return;
      }
      _showMapSnack(_t.playFinishPayment);
    } catch (error) {
      unawaited(
        _metrics.trackEvent(
          'checkout_start',
          params: <String, Object?>{
            'plan': planKey,
            'productId': product.id,
            'result': 'failed',
            'reason': _metricErrorCode(error),
          },
        ),
      );
      _showMapSnack(_formatBillingFailure(error));
    } finally {
      if (mounted) {
        _setStateIfMapVisible(() {
          _isStartingStoreCheckout = false;
        });
      }
    }
  }

  Future<void> _handlePlayPurchaseUpdates(
    List<PurchaseDetails> purchases,
  ) async {
    for (final purchase in purchases) {
      if (!mounted) {
        return;
      }
      switch (purchase.status) {
        case PurchaseStatus.pending:
          continue;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          await _processPlayPurchase(purchase);
          continue;
        case PurchaseStatus.error:
          final errorMessage = purchase.error?.message.trim();
          unawaited(
            _metrics.trackEvent(
              'purchase_fail',
              params: <String, Object?>{
                'status': 'error',
                'productId': purchase.productID.trim(),
                'reason': _metricErrorCode(errorMessage ?? 'purchase_error'),
              },
            ),
          );
          if (errorMessage != null && errorMessage.isNotEmpty) {
            _showMapSnack(errorMessage);
          } else {
            _showMapSnack(_t.playPurchaseFailed);
          }
          continue;
        case PurchaseStatus.canceled:
          unawaited(
            _metrics.trackEvent(
              'purchase_cancel',
              params: <String, Object?>{'productId': purchase.productID.trim()},
            ),
          );
          _showMapSnack(_t.playPaymentCanceled);
          continue;
      }
    }
  }

  Future<void> _processPlayPurchase(PurchaseDetails purchase) async {
    final service = _planSubscriptionService;
    if (service == null) {
      unawaited(
        _metrics.trackEvent(
          'purchase_fail',
          params: <String, Object?>{
            'productId': purchase.productID.trim(),
            'reason': 'service_unavailable',
          },
        ),
      );
      _showMapSnack(_t.subscriptionInitializing);
      return;
    }
    final token = purchase.verificationData.serverVerificationData.trim();
    final productId = purchase.productID.trim();
    if (token.isEmpty) {
      unawaited(
        _metrics.trackEvent(
          'purchase_fail',
          params: <String, Object?>{
            'productId': productId,
            'reason': 'play_purchase_token_missing',
          },
        ),
      );
      _showMapSnack(
        _formatBillingFailure(StateError('play_purchase_token_missing')),
      );
      return;
    }
    final tier = _tierFromProductId(productId);
    if (tier == null) {
      unawaited(
        _metrics.trackEvent(
          'purchase_fail',
          params: <String, Object?>{
            'productId': productId,
            'reason': 'play_product_not_found',
          },
        ),
      );
      _showMapSnack(_t.playUnknownProduct);
      return;
    }
    final processingKey = '${purchase.purchaseID ?? 'no-id'}|$productId|$token';
    if (_processingPlayPurchases.contains(processingKey)) {
      return;
    }
    _processingPlayPurchases.add(processingKey);
    try {
      final snapshot = await service.confirmPlayStorePurchase(
        planKey: _tierToPlanKey(tier),
        productId: productId,
        purchaseToken: token,
        purchaseId: purchase.purchaseID,
      );
      await _syncActivePlanFromSnapshot(snapshot);
      if (!mounted) {
        return;
      }
      await _completePlayPurchaseIfNeeded(purchase);
      unawaited(
        _metrics.trackEvent(
          'purchase_success',
          params: <String, Object?>{
            'plan': _tierToPlanKey(tier),
            'productId': productId,
            'status': purchase.status.name,
          },
        ),
      );
      final notificationKey = '$productId|$token';
      if (_markPurchaseSuccessNotified(notificationKey)) {
        unawaited(_showPlanActivationSuccessDialog(tier));
      } else {
        _showMapSnack(_t.planActivatedSuccess(kPlanCatalog[tier]!.label));
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      unawaited(
        _metrics.trackEvent(
          'purchase_fail',
          params: <String, Object?>{
            'plan': _tierToPlanKey(tier),
            'productId': productId,
            'reason': _metricErrorCode(error),
          },
        ),
      );
      _showMapSnack(_formatBillingFailure(error));
    } finally {
      _processingPlayPurchases.remove(processingKey);
    }
  }

  Future<void> _completePlayPurchaseIfNeeded(PurchaseDetails purchase) async {
    if (!purchase.pendingCompletePurchase) {
      return;
    }
    try {
      await _inAppPurchase.completePurchase(purchase);
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showMapSnack(_t.playFinalizeFailed);
    }
  }

  AppPlanTier? _tierFromProductId(String productId) {
    for (final entry in _GymMapPageState._planProductIds.entries) {
      if (entry.value == productId) {
        return entry.key;
      }
    }
    return null;
  }

  Future<void> _syncActivePlanFromSnapshot(SubscriptionState snapshot) async {
    if (!mounted) {
      return;
    }
    final nextPlan = _tierFromPlanKey(snapshot.activePlanKey);
    _setStateIfMapVisible(() {
      _activePlan = nextPlan;
      _activePlanExpiresAtUtc = snapshot.expiresAt;
    });
    widget.onActivePlanChanged?.call(nextPlan);
    _enforcePlanCoverageAfterTierChange();
  }

  PlanInfo get _activePlanInfo => kPlanCatalog[_activePlan]!;

  bool get _isFreePlan => _activePlan == AppPlanTier.free;
  bool get _hasHistoryInsights =>
      _activePlan == AppPlanTier.smart ||
      _activePlan == AppPlanTier.pro ||
      _activePlan == AppPlanTier.elite;
  bool get _hasProInsights =>
      _activePlan == AppPlanTier.pro || _activePlan == AppPlanTier.elite;
  bool get _hasEliteInsights => _activePlan == AppPlanTier.elite;
  bool get _hasNationwideCoverage => _activePlan == AppPlanTier.elite;

  int _planTierWeight(AppPlanTier tier) {
    switch (tier) {
      case AppPlanTier.free:
        return 0;
      case AppPlanTier.smart:
        return 1;
      case AppPlanTier.pro:
        return 2;
      case AppPlanTier.elite:
        return 3;
    }
  }

  ProductDetails? _playProductForTier(AppPlanTier tier) {
    final productId = _GymMapPageState._planProductIds[tier];
    if (productId == null || productId.trim().isEmpty) {
      return null;
    }
    for (final product in _playProducts) {
      if (product.id == productId) {
        return product;
      }
    }
    return null;
  }

  String _planPriceLabel(AppPlanTier tier) {
    if (tier == AppPlanTier.free) {
      return _t.priceFreeMonthly;
    }
    final playProduct = _playProductForTier(tier);
    if (playProduct != null) {
      final price = playProduct.price.trim();
      if (price.isNotEmpty) {
        return _t.pricePerMonth(price);
      }
    }
    return kPlanCatalog[tier]!.monthlyPrice;
  }

  String _planActionLabel(AppPlanTier tier, AppPlanTier current) {
    if (tier == current) {
      return _t.planCurrent;
    }
    if (tier == AppPlanTier.free) {
      return current == AppPlanTier.free
          ? _t.planContinueFree
          : _t.planBackToFree;
    }
    if (_planTierWeight(tier) > _planTierWeight(current)) {
      return current == AppPlanTier.free ? _t.planSubscribe : _t.planUpgrade;
    }
    return _t.planChange;
  }

  Color _planAccentColor(AppPlanTier tier) {
    return PlanThemePalette.colorFor(tier);
  }

  Color _planOnAccentColor(AppPlanTier tier) {
    return PlanThemePalette.onColorFor(tier);
  }

  IconData _planIcon(AppPlanTier tier) {
    switch (tier) {
      case AppPlanTier.free:
        return Icons.lock_open_rounded;
      case AppPlanTier.smart:
        return Icons.bolt_rounded;
      case AppPlanTier.pro:
        return Icons.rocket_launch_rounded;
      case AppPlanTier.elite:
        return Icons.workspace_premium_rounded;
    }
  }

  String? _paywallPromoLabel() {
    final message = _GymMapPageState._paywallPromoMessage.trim();
    if (message.isEmpty) {
      return null;
    }
    final deadline = _GymMapPageState._paywallPromoDeadline.trim();
    if (deadline.isEmpty) {
      return message;
    }
    return _t.promoUntil(message, deadline);
  }

  List<String> _planCardHighlights(AppPlanTier tier) {
    final currentInsights = kPlanCatalog[tier]!.insights;
    switch (tier) {
      case AppPlanTier.free:
        return currentInsights.take(2).toList(growable: false);
      case AppPlanTier.smart:
        final freeInsights = kPlanCatalog[AppPlanTier.free]!.insights.toSet();
        final unique = currentInsights
            .where((feature) => !freeInsights.contains(feature))
            .toList(growable: false);
        final source = unique.isEmpty ? currentInsights : unique;
        return source.take(3).toList(growable: false);
      case AppPlanTier.pro:
        return currentInsights.take(4).toList(growable: false);
      case AppPlanTier.elite:
        final proInsights = kPlanCatalog[AppPlanTier.pro]!.insights.toSet();
        final eliteOnly = currentInsights
            .where((feature) => !proInsights.contains(feature))
            .toList(growable: true);
        if (eliteOnly.length < 4) {
          eliteOnly.add(_t.planIncludesPro);
        }
        return eliteOnly.take(4).toList(growable: false);
    }
  }

  Widget _buildPlanOfferCard({
    required BuildContext sheetContext,
    required AppPlanTier tier,
    required AppPlanTier current,
    required bool isRecommended,
  }) {
    final plan = kPlanCatalog[tier]!;
    final cardHighlights = _planCardHighlights(tier);
    final accentColor = _planAccentColor(tier);
    final onAccentColor = _planOnAccentColor(tier);
    final isCurrent = tier == current;
    final isActionEnabled =
        !_isLoadingPlanSubscription && !_isStartingStoreCheckout && !isCurrent;
    final isPrimaryTrialCta =
        current == AppPlanTier.free && tier == AppPlanTier.pro;
    final actionLabel =
        isPrimaryTrialCta
            ? _t.planStartFreeTrial
            : _planActionLabel(tier, current);
    final fullPriceLabel = _planPriceLabel(tier);
    final periodSeparatorIndex = fullPriceLabel.indexOf('/');
    final priceMain =
        periodSeparatorIndex > 0
            ? fullPriceLabel.substring(0, periodSeparatorIndex)
            : fullPriceLabel;
    final pricePeriod =
        periodSeparatorIndex > 0
            ? fullPriceLabel.substring(periodSeparatorIndex)
            : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: withUiOpacity(accentColor, isRecommended ? 0.48 : 0.26),
          width: isRecommended ? 1.6 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: withUiOpacity(accentColor, 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(_planIcon(tier), size: 16, color: accentColor),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  plan.label,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    color: accentColor,
                  ),
                ),
              ),
              if (isRecommended)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: withUiOpacity(accentColor, 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    _t.planMostPopular,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: accentColor,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text.rich(
            TextSpan(
              text: priceMain,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: GymMapColors.textStrong,
              ),
              children: [
                if (pricePeriod.isNotEmpty)
                  TextSpan(
                    text: ' $pricePeriod',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: GymMapColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          ...cardHighlights.map(
            (feature) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.check_circle, size: 14, color: accentColor),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      feature,
                      style: const TextStyle(
                        color: GymMapColors.textStrong,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child:
                isCurrent
                    ? OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        foregroundColor: accentColor,
                        side: BorderSide(
                          color: withUiOpacity(accentColor, 0.42),
                        ),
                      ),
                      onPressed: null,
                      icon: const Icon(Icons.check_circle_outline),
                      label: Text(actionLabel),
                    )
                    : ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        backgroundColor: accentColor,
                        foregroundColor: onAccentColor,
                      ),
                      onPressed:
                          isActionEnabled
                              ? () {
                                _onPlanPicked(tier, sheetContext);
                              }
                              : null,
                      icon:
                          _isStartingStoreCheckout && tier != AppPlanTier.free
                              ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                              : Icon(
                                tier == AppPlanTier.free
                                    ? Icons.arrow_back
                                    : Icons.rocket_launch,
                              ),
                      label: Text(actionLabel),
                    ),
          ),
          if (isPrimaryTrialCta) ...[
            const SizedBox(height: 4),
            Text(
              _t.planInstantAccess,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: GymMapColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPlanComparisonMatrix() {
    const unavailableColor = Color(0xFFD64B4B);
    final rows = <({String feature, Set<AppPlanTier> available})>[
      (
        feature: _t.planFeatureLiveOccupancy,
        available: {
          AppPlanTier.free,
          AppPlanTier.smart,
          AppPlanTier.pro,
          AppPlanTier.elite,
        },
      ),
      (
        feature: _t.planFeatureHistory,
        available: {AppPlanTier.smart, AppPlanTier.pro, AppPlanTier.elite},
      ),
      (
        feature: _t.planFeaturePeakCompare,
        available: {AppPlanTier.pro, AppPlanTier.elite},
      ),
      (feature: _t.planFeatureForecast, available: {AppPlanTier.elite}),
      (feature: _t.planFeatureNationwide, available: {AppPlanTier.elite}),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: withUiOpacity(_planAccentColor(_activePlan), 0.12),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final totalWidth =
              constraints.maxWidth.isFinite ? constraints.maxWidth : 340.0;
          final tierCount = AppPlanTier.values.length;
          const minTierWidth = 44.0;
          const maxTierWidth = 58.0;
          const minFeatureWidth = 108.0;
          const maxFeatureWidth = 136.0;

          var tierWidth =
              ((totalWidth - minFeatureWidth) / tierCount)
                  .clamp(minTierWidth, maxTierWidth)
                  .toDouble();
          var featureWidth = totalWidth - (tierWidth * tierCount);
          featureWidth = featureWidth.clamp(minFeatureWidth, maxFeatureWidth);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _t.planQuickComparison,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: GymMapColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  SizedBox(width: featureWidth),
                  for (final tier in AppPlanTier.values)
                    SizedBox(
                      width: tierWidth,
                      child: Builder(
                        builder: (_) {
                          final accentColor = _planAccentColor(tier);
                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 1),
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              color: withUiOpacity(accentColor, 0.10),
                            ),
                            child: Center(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  kPlanCatalog[tier]!.label,
                                  maxLines: 1,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 10,
                                    color: accentColor,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              ...rows.map((row) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      SizedBox(
                        width: featureWidth,
                        child: Text(
                          row.feature,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            color: GymMapColors.textStrong,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      for (final tier in AppPlanTier.values)
                        SizedBox(
                          width: tierWidth,
                          child: Center(
                            child: Semantics(
                              label:
                                  row.available.contains(tier)
                                      ? _t.planAvailableIn(
                                        kPlanCatalog[tier]!.label,
                                      )
                                      : _t.planUnavailableIn(
                                        kPlanCatalog[tier]!.label,
                                      ),
                              child: Icon(
                                row.available.contains(tier)
                                    ? Icons.check_circle_rounded
                                    : Icons.cancel_rounded,
                                size: 17,
                                color:
                                    row.available.contains(tier)
                                        ? GymMapColors.occupancyLow
                                        : unavailableColor,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 6),
              Wrap(
                spacing: 12,
                runSpacing: 6,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_circle_rounded,
                        size: 14,
                        color: GymMapColors.occupancyLow,
                      ),
                      SizedBox(width: 4),
                      Text(
                        _t.planAvailable,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: GymMapColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.cancel_rounded,
                        size: 14,
                        color: unavailableColor,
                      ),
                      SizedBox(width: 4),
                      Text(
                        _t.planUnavailable,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: GymMapColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  void _openPlanSettings() {
    unawaited(_syncPlanFromStorage(showExpiryNotice: true));
    unawaited(
      _metrics.trackEvent(
        'paywall_open',
        params: <String, Object?>{
          'source': 'map_header',
          'currentPlan': _tierToPlanKey(_activePlan),
        },
      ),
    );
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) {
        final current = _activePlan;
        final service = _planSubscriptionService;
        final hasRemoteBackend = service?.hasRemoteBackend ?? false;
        final hasAuthSession = service?.hasAuthSession ?? false;
        final isAnonymousSession = service?.isAnonymousSession ?? false;
        final promoLabel = _paywallPromoLabel();
        const recommendedTier = AppPlanTier.pro;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _t.paywallTitle,
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _t.paywallSubtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: GymMapColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (promoLabel != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: withUiOpacity(const Color(0xFFFFA500), 0.16),
                        border: Border.all(
                          color: withUiOpacity(const Color(0xFFFFA500), 0.46),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.local_offer_outlined,
                            size: 16,
                            color: Color(0xFF8B5A00),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              promoLabel,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF6A4300),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                  ],
                  Text(
                    _isLoadingPlanSubscription
                        ? _t.subscriptionLoading
                        : _activePlanStatusLabel(),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: GymMapColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _planAuthStatusLabel(),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: GymMapColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed:
                              (!hasRemoteBackend ||
                                      _isLoadingPlanSubscription ||
                                      _isPlanAuthBusy)
                                  ? null
                                  : () {
                                    unawaited(_startPlanLoginFlow(context));
                                  },
                          icon:
                              _isPlanAuthBusy
                                  ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                  : const Icon(Icons.login),
                          label: Text(_t.authSignIn),
                        ),
                      ),
                      if (isAnonymousSession) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton.tonalIcon(
                            onPressed:
                                _isLoadingPlanSubscription || _isPlanAuthBusy
                                    ? null
                                    : () {
                                      unawaited(
                                        _startPlanLoginFlow(
                                          context,
                                          register: true,
                                        ),
                                      );
                                    },
                            icon: const Icon(Icons.person_add),
                            label: Text(_t.authCreateAccount),
                          ),
                        ),
                      ],
                      if (hasAuthSession && !isAnonymousSession) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextButton.icon(
                            onPressed:
                                _isPlanAuthBusy
                                    ? null
                                    : () {
                                      unawaited(_logoutPlanSession(context));
                                    },
                            icon: const Icon(Icons.logout),
                            label: Text(_t.authSignOut),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...AppPlanTier.values.map((tier) {
                    return _buildPlanOfferCard(
                      sheetContext: context,
                      tier: tier,
                      current: current,
                      isRecommended: tier == recommendedTier,
                    );
                  }),
                  const SizedBox(height: 4),
                  _buildPlanComparisonMatrix(),
                  const SizedBox(height: 10),
                  if (current == AppPlanTier.free) ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                        ),
                        onPressed:
                            _isLoadingPlanSubscription ||
                                    _isStartingStoreCheckout
                                ? null
                                : () {
                                  _onPlanPicked(recommendedTier, context);
                                },
                        icon:
                            _isStartingStoreCheckout
                                ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                                : const Icon(Icons.rocket_launch),
                        label: Text(_t.planStartFreeTrial),
                      ),
                    ),
                    const SizedBox(height: 6),
                  ],
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: Text(
                        current == AppPlanTier.free
                            ? _t.planContinueWithFree
                            : _t.actionClose,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
