part of 'gym_map_page.dart';

extension _GymMapPageAccount on _GymMapPageState {
  Future<void> _openPrivacyPolicy() async {
    const backendUrl = String.fromEnvironment('PLAN_BACKEND_BASE_URL');
    final configuredBackend = Uri.tryParse(backendUrl);
    final uri =
        _planSubscriptionService?.privacyPolicyUri ??
        (configuredBackend?.hasAuthority == true
            ? configuredBackend!.resolve('/privacy')
            : null);
    if (uri == null) {
      _showMapSnack(_t.accountPrivacyOpenFailed);
      return;
    }
    try {
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
    } catch (_) {
      // Show a readable failure if a browser is unavailable.
    }
    if (mounted) _showMapSnack(_t.accountPrivacyOpenFailed);
  }

  Future<void> _deleteAccount(BuildContext sheetContext) async {
    final service = _planSubscriptionService;
    if (service == null || !service.hasAuthSession || _isPlanAuthBusy) return;
    final password = TextEditingController();
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder:
            (dialogContext) => AlertDialog(
              title: Text(_t.accountDeleteTitle),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_t.accountDeleteWarning),
                    TextButton(
                      onPressed:
                          () => launchUrl(
                            Uri.parse(
                              'https://play.google.com/store/account/subscriptions',
                            ),
                            mode: LaunchMode.externalApplication,
                          ),
                      child: Text(_t.accountManageSubscriptions),
                    ),
                    if (!service.isAnonymousSession)
                      TextField(
                        controller: password,
                        obscureText: true,
                        autocorrect: false,
                        enableSuggestions: false,
                        decoration: InputDecoration(
                          labelText: _t.authPasswordLabel,
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: Text(_t.actionCancel),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: Text(_t.accountDeleteTitle),
                ),
              ],
            ),
      );
      if (confirmed != true || !mounted) return;
      _planSyncTimer?.cancel();
      _setStateIfMapVisible(() {
        _isPlanAuthBusy = true;
      });
      try {
        await service.deleteAccount(password: password.text);
        _crowdReportRemoteService?.refreshAuthFromStorage();
        if (!mounted) return;
        widget.onActivePlanChanged?.call(AppPlanTier.free);
        // Recreate the screen to discard all in-memory data from the old account.
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute<void>(builder: (_) => const AccountDeletedPage()),
          (_) => false,
        );
      } catch (error) {
        if (mounted) _showMapSnack(_formatAuthFailure(error));
        _startPlanSyncTimer();
      } finally {
        if (mounted) {
          _setStateIfMapVisible(() {
            _isPlanAuthBusy = false;
          });
        }
      }
    } finally {
      password.dispose();
    }
  }
}

class AccountDeletedPage extends StatelessWidget {
  const AccountDeletedPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(_t.accountDeleteTitle)),
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_t.accountDeletedMessage, textAlign: TextAlign.center),
            const SizedBox(height: 20),
            FilledButton(
              onPressed:
                  () => Navigator.of(
                    context,
                  ).pushNamedAndRemoveUntil('/', (_) => false),
              child: Text(_t.accountContinue),
            ),
          ],
        ),
      ),
    ),
  );
}
