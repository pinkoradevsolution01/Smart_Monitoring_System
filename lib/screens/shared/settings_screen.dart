import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';
import '../../utils/app_localizations.dart';
import '../../utils/locale_controller.dart';
import '../../utils/theme_controller.dart';
import '../../utils/motion_controller.dart';
import '../../utils/policy_dialogs.dart';
import '../../services/package_service.dart';
import '../../services/license_service.dart';
import '../../services/supabase_sync_service.dart';
import '../../services/backend_config.dart';
import '../../services/backend_server_resolver.dart';
import '../../models/pricing_package.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../utils/print_settings.dart';
import 'user_manual_screen.dart';
import 'activation_code_request_dialog.dart';
import 'dart:math' as math;

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late Locale _selectedLocale;
  late String _selectedThemeKey;
  late bool _selectedReduceMotion;
  final TextEditingController _backendUrlController = TextEditingController();
  String _selectedPaperSize = 'Thermal 48mm';
  bool _hasChanges = false;
  bool _isSavingBackendUrl = false;
  String? _subscriptionMode;
  DateTime? _trialExpires;
  DateTime? _subscriptionExpires; // Monthly rental expiry
  bool _isActivated = false;
  // Discount / price display
  int? _subscriptionDiscount;
  String? _subscriptionPriceDisplay;
  String? _subscriptionOriginalPriceDisplay;

  @override
  void initState() {
    super.initState();
    _selectedLocale = LocaleController.locale.value;
    _selectedThemeKey = ThemeController.themeKey.value;
    _selectedReduceMotion = MotionController.reduceMotion.value;
    _backendUrlController.text = BackendConfig.resolvedApiBaseUrl ??
        BackendConfig.apiBaseUrl;
    // Load saved default paper size and update shared notifier
    SharedPreferences.getInstance().then((prefs) {
      final saved = prefs.getString('default_receipt_paper_size');
      final savedBackendUrl = prefs.getString(
        BackendConfig.backendApiBaseUrlPrefsKey,
      );
      final savedBackendUrls = prefs.getString(
        BackendConfig.backendApiBaseUrlsPrefsKey,
      );
      final mode = prefs.getString('subscription_mode');
      final trialExpiresStr = prefs.getString('trial_expires');
      final subscriptionExpiresStr = prefs.getString('subscription_expires');
      final activated = prefs.getBool('activation_status') ?? false;
      if (mounted) {
        if (saved != null) setState(() => _selectedPaperSize = saved);
        if (savedBackendUrls != null && savedBackendUrls.isNotEmpty) {
          _backendUrlController.text = savedBackendUrls;
        } else if (savedBackendUrl != null && savedBackendUrl.isNotEmpty) {
          _backendUrlController.text = savedBackendUrl;
        }
        if (mode != null) setState(() => _subscriptionMode = mode);
        if (trialExpiresStr != null) {
          try {
            _trialExpires = DateTime.parse(trialExpiresStr);
          } catch (_) {}
        }
        if (subscriptionExpiresStr != null) {
          try {
            _subscriptionExpires = DateTime.parse(subscriptionExpiresStr);
          } catch (_) {}
        }
        // Load discount/price info if available
        final discount = prefs.getInt('subscription_discount');
        final priceDisplay = prefs.getString('subscription_price_display');
        final originalDisplay = prefs.getString(
          'subscription_original_price_display',
        );
        if (discount != null ||
            priceDisplay != null ||
            originalDisplay != null) {
          setState(() {
            _subscriptionDiscount = discount;
            _subscriptionPriceDisplay = priceDisplay;
            _subscriptionOriginalPriceDisplay = originalDisplay;
          });
        }
        setState(() => _isActivated = activated);
        PrintSettings.paperSize.value = saved ?? _selectedPaperSize;
      }
    });
  }

  void _markAsChanged() {
    if (!_hasChanges) {
      setState(() => _hasChanges = true);
    }
  }

  void _saveChanges() {
    LocaleController.setLocale(_selectedLocale);
    ThemeController.setTheme(_selectedThemeKey);
    MotionController.setReduceMotion(_selectedReduceMotion);

    setState(() => _hasChanges = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.t('settings_saved')),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _resetChanges() {
    setState(() {
      _selectedLocale = LocaleController.locale.value;
      _selectedThemeKey = ThemeController.themeKey.value;
      _selectedReduceMotion = MotionController.reduceMotion.value;
      _hasChanges = false;
    });
  }

  List<String> _parseBackendUrls(String entered) {
    return BackendServerResolver.normalizeCandidates(
      entered.split(RegExp(r'[,\n; ]+')),
    );
  }

  Future<void> _saveBackendUrl() async {
    final entered = _backendUrlController.text.trim();
    if (entered.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your backend URL'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final candidateUrls = _parseBackendUrls(entered);
    if (candidateUrls.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Enter at least one valid URL like http://152.42.185.35:3000/api',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSavingBackendUrl = true);
    try {
      final ok = await BackendServerResolver.testBaseUrls(candidateUrls);
      if (!ok) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Cannot reach any saved backend. Check the droplet IP, port 3000, and firewall.',
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      await BackendServerResolver.savePreferredBaseUrls(candidateUrls);
      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            candidateUrls.length == 1
                ? 'Backend URL saved: ${candidateUrls.first}'
                : 'Backend URLs saved: ${candidateUrls.join(', ')}',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save backend URL: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSavingBackendUrl = false);
      }
    }
  }

  // ======================== CLOUD SYNC HANDLERS ========================

  Future<void> _handleBackupToCloud(BuildContext context) async {
    final syncService = SupabaseSyncService();

    if (!syncService.isConfigured) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please activate your license first to enable cloud sync',
          ),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Backing up data to cloud...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final success = await syncService.pushAllData();
      Navigator.of(context).pop(); // Close loading dialog

      if (success) {
        final stats = syncService.getSyncSummary();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Backup completed!\n$stats'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Backup failed: ${syncService.lastError}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      Navigator.of(context).pop(); // Close loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Future<void> _handleRestoreFromCloud(BuildContext context) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore from Cloud?'),
        content: const Text(
          'This will replace all local data with data from cloud. '
          'Current local data will be overwritten. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Restore'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final syncService = SupabaseSyncService();

    if (!syncService.isConfigured) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please activate your license first to enable cloud sync',
          ),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Restoring data from cloud...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final success = await syncService.pullAllData();
      Navigator.of(context).pop(); // Close loading dialog

      if (success) {
        final stats = syncService.getSyncSummary();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Restore completed!\n$stats'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Restore failed: ${syncService.lastError}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      Navigator.of(context).pop(); // Close loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Future<void> _handleBidirectionalSync(BuildContext context) async {
    final syncService = SupabaseSyncService();

    if (!syncService.isConfigured) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please activate your license first to enable cloud sync',
          ),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Syncing data with cloud...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final success = await syncService.syncBidirectional();
      Navigator.of(context).pop(); // Close loading dialog

      if (success) {
        final stats = syncService.getSyncSummary();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Sync completed!\n$stats'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Sync failed: ${syncService.lastError}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      Navigator.of(context).pop(); // Close loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  void dispose() {
    _backendUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.t('settings')),
        actions: [
          if (_hasChanges)
            TextButton.icon(
              onPressed: _resetChanges,
              icon: const Icon(Icons.refresh, color: Colors.white),
              label: const Text('Reset', style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Package Information Section
            _buildPackageInfoCard(context),
            const SizedBox(height: 24),
            // Subscription Expiry Section (Monthly Rental)
            if (_isActivated && _subscriptionExpires != null)
              _buildSubscriptionExpiryCard(context),
            if (_isActivated && _subscriptionExpires != null)
              const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 24),

            Text(
              AppLocalizations.t('language'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            DropdownButton<Locale>(
              value: _selectedLocale,
              items: const [
                DropdownMenuItem(value: Locale('en'), child: Text('EN')),
                DropdownMenuItem(value: Locale('fil'), child: Text('FIL')),
              ],
              onChanged: (l) {
                if (l != null) {
                  setState(() => _selectedLocale = l);
                  _markAsChanged();
                }
              },
            ),

            const SizedBox(height: 24),
            Text('Motion', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            SwitchListTile(
              title: Text(AppLocalizations.t('reduce_motion')),
              value: _selectedReduceMotion,
              onChanged: (v) {
                setState(() => _selectedReduceMotion = v);
                _markAsChanged();
              },
            ),

            const SizedBox(height: 24),
            Text(
              AppLocalizations.t('theme'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Preset colors in honeycomb pattern
                _buildHoneycombGrid(context, _selectedThemeKey),
                const SizedBox(height: 24),
                // Custom color picker button
                Center(
                  child: ElevatedButton.icon(
                    onPressed: () => _showCustomColorPicker(context),
                    icon: const Icon(Icons.palette),
                    label: const Text('Custom Color Picker'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 16),
            // Printing / Paper Size Section
            Text('Printing', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text('Default Paper Size:'),
                const SizedBox(width: 12),
                DropdownButton<String>(
                  value: _selectedPaperSize,
                  items:
                      <String>[
                            'A4',
                            'Letter',
                            'Thermal 48mm',
                            'Thermal 50mm',
                            'Thermal 55mm',
                            'Thermal 58mm',
                          ]
                          .map(
                            (k) => DropdownMenuItem(value: k, child: Text(k)),
                          )
                          .toList(),
                  onChanged: (v) async {
                    if (v == null) return;
                    setState(() => _selectedPaperSize = v);
                    _markAsChanged();
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setString('default_receipt_paper_size', v);
                    // broadcast change so open previews update live
                    PrintSettings.paperSize.value = v;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Default paper size saved: $v')),
                    );
                  },
                ),
                const Spacer(),
                Text(
                  _selectedPaperSize.contains('Thermal')
                      ? 'Width: ${_selectedPaperSize.replaceAll(RegExp(r'[^0-9]'), '')} mm'
                      : '',
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildBackendConnectionCard(context),
            const SizedBox(height: 24),
            // Cloud Sync Section - Standard Package Required
            _buildCloudSyncSection(context),

            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.t('help_support'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Icon(
                Icons.menu_book,
                color: Theme.of(context).colorScheme.primary,
              ),
              title: Text(AppLocalizations.t('user_manual')),
              subtitle: const Text('Installation, setup, and troubleshooting'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const UserManualScreen()),
                );
              },
            ),
            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.t('legal'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Icon(
                Icons.privacy_tip,
                color: Theme.of(context).colorScheme.primary,
              ),
              title: Text(AppLocalizations.t('privacy_policy')),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => PolicyDialogs.showPrivacyPolicy(context),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: Icon(
                Icons.description,
                color: Theme.of(context).colorScheme.primary,
              ),
              title: Text(AppLocalizations.t('user_agreement')),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => PolicyDialogs.showUserAgreement(context),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: Icon(
                Icons.archive,
                color: Theme.of(context).colorScheme.primary,
              ),
              title: Text(AppLocalizations.t('dependency_licenses')),
              subtitle: Text(AppLocalizations.t('dependency_licenses_desc')),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => showLicensePage(
                context: context,
                applicationName: 'Smart Monitoring System',
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: Icon(
                Icons.edit,
                color: Theme.of(context).colorScheme.primary,
              ),
              title: Text(AppLocalizations.t('update_privacy_policy')),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showEditPolicyDialog(
                context,
                'custom_privacy_policy',
                AppLocalizations.t('privacy_intro_content'),
                AppLocalizations.t('privacy_policy'),
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: Icon(
                Icons.description_outlined,
                color: Theme.of(context).colorScheme.primary,
              ),
              title: Text(AppLocalizations.t('update_terms')),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showEditPolicyDialog(
                context,
                'custom_terms',
                AppLocalizations.t('agreement_acceptance_content'),
                AppLocalizations.t('user_agreement'),
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: Icon(
                Icons.credit_card,
                color: Theme.of(context).colorScheme.primary,
              ),
              title: Text(AppLocalizations.t('pci_guidance_title')),
              subtitle: Text(AppLocalizations.t('pci_guidance_summary')),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showPciGuidance(context),
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.t('about'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Icon(
                Icons.info,
                color: Theme.of(context).colorScheme.primary,
              ),
              title: Text(AppLocalizations.t('about_system')),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showAboutSystem(context),
            ),

            // Save Changes Button
            const SizedBox(height: 32),
            if (_hasChanges)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.primary,
                    width: 2,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Theme.of(context).colorScheme.primary,
                      size: 32,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'You have unsaved changes',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Click Save to apply changes across the system',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _resetChanges,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Reset'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton.icon(
                            onPressed: _saveChanges,
                            icon: const Icon(Icons.save),
                            label: const Text('Save Changes'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(
                                context,
                              ).colorScheme.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
          ],
        ),
      ),
      floatingActionButton: _hasChanges
          ? FloatingActionButton.extended(
              onPressed: _saveChanges,
              icon: const Icon(Icons.save),
              label: const Text('Save'),
              backgroundColor: Theme.of(context).colorScheme.primary,
            )
          : null,
    );
  }

  void _showAboutSystem(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.info, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(child: Text(AppLocalizations.t('about_system'))),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // System Icon
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.store,
                    size: 64,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Smart Monitoring System',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  AppLocalizations.t('system_subtitle'),
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 16),
                // Developer Info
                _buildInfoRow(
                  context,
                  Icons.person,
                  AppLocalizations.t('developed_by'),
                  'Jay-Be Gubot',
                ),
                const SizedBox(height: 16),
                _buildInfoRow(
                  context,
                  Icons.business,
                  AppLocalizations.t('brand'),
                  'Pinkora Dev',
                ),
                const SizedBox(height: 16),
                _buildInfoRow(
                  context,
                  Icons.code,
                  AppLocalizations.t('version'),
                  '1.0.0',
                ),
                const SizedBox(height: 16),
                _buildInfoRow(
                  context,
                  Icons.calendar_today,
                  AppLocalizations.t('release_date'),
                  'December 2025',
                ),
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 16),
                Text(
                  AppLocalizations.t('about_description'),
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  '© 2025 Pinkora Dev. All rights reserved.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[500],
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.t('close')),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showPciGuidance(BuildContext context) {
    final defaultText = AppLocalizations.t('pci_guidance_content') != ''
        ? AppLocalizations.t('pci_guidance_content')
        : 'If you accept card payments, use a PCI-compliant payment processor. Avoid storing card numbers, use TLS for network communication, maintain unique administrator accounts, keep devices and software updated, and perform periodic security reviews. For full compliance consult a PCI Qualified Security Assessor (QSA).';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.credit_card,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(AppLocalizations.t('pci_guidance_title'))),
          ],
        ),
        content: SingleChildScrollView(
          child: Text(
            defaultText,
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.justify,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.t('close')),
          ),
        ],
      ),
    );
  }

  void _showEditPolicyDialog(
    BuildContext context,
    String storageKey,
    String defaultText,
    String title,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(storageKey) ?? '';
    final controller = TextEditingController(
      text: stored.isNotEmpty ? stored : defaultText,
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.edit, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(child: Text(title)),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              children: [
                TextFormField(
                  controller: controller,
                  maxLines: 18,
                  decoration: InputDecoration(border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          controller.text = defaultText;
                        },
                        child: Text('Reset to Default'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          await prefs.setString(storageKey, controller.text);
                          if (mounted) Navigator.pop(context);
                          ScaffoldMessenger.of(
                            this.context,
                          ).showSnackBar(SnackBar(content: Text('Saved')));
                        },
                        child: Text('Save'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHoneycombGrid(BuildContext context, String selectedKey) {
    final entries = ThemeController.presets.entries.toList();

    // Add custom color if it exists
    final colors = <MapEntry<String, Color>>[
      ...entries.map((e) => MapEntry(e.key, e.value)),
      if (selectedKey == 'custom')
        MapEntry('custom', ThemeController.customColor.value),
    ];

    return Center(
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.center,
        children: colors.map((entry) {
          final isSelected = selectedKey == entry.key;
          return _buildHexagon(
            color: entry.value,
            isSelected: isSelected,
            label: entry.key[0].toUpperCase() + entry.key.substring(1),
            onTap: () {
              setState(() => _selectedThemeKey = entry.key);
              _markAsChanged();
            },
          );
        }).toList(),
      ),
    );
  }

  Widget _buildHexagon({
    required Color color,
    required bool isSelected,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 80,
        height: 92,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(
              size: const Size(80, 92),
              painter: HexagonPainter(color: color, isSelected: isSelected),
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isSelected)
                  Icon(
                    Icons.check_circle,
                    color: color.computeLuminance() > 0.5
                        ? Colors.black
                        : Colors.white,
                    size: 24,
                  ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: color.computeLuminance() > 0.5
                        ? Colors.black
                        : Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showCustomColorPicker(BuildContext context) {
    showDialog(context: context, builder: (ctx) => _CustomColorPickerDialog());
  }

  Widget _buildPackageInfoCard(BuildContext context) {
    final packageService = GetIt.I<PackageService>();
    final package = packageService.selectedPackage;

    if (package == null) {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
              Theme.of(context).colorScheme.primary.withValues(alpha: 0.05),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.workspace_premium,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Current Package',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        package.name,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      if (_subscriptionMode == 'free_trial')
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.blue.shade200),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.timer,
                                    size: 16,
                                    color: Colors.blue.shade700,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Free Trial',
                                    style: TextStyle(
                                      color: Colors.blue.shade700,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (_trialExpires != null)
                              Text(
                                'Expires ${_trialExpires!.toLocal().toString().split(" ").first}',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: Colors.grey[700]),
                              ),
                          ],
                        ),
                    ],
                  ),
                ),
                if (package.price != 'Custom Pricing')
                  Text(
                    package.price,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 16),
            Text(
              'Included Features:',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildFeatureChip(
                  context,
                  icon: Icons.inventory,
                  label: 'POS & Inventory',
                  isIncluded: true,
                ),
                _buildFeatureChip(
                  context,
                  icon: Icons.videocam,
                  label: 'CCTV Monitoring',
                  isIncluded: package.hasCCTV,
                ),
                _buildFeatureChip(
                  context,
                  icon: Icons.cloud,
                  label: 'Cloud Sync',
                  isIncluded: package.hasCloudSync,
                ),
                _buildFeatureChip(
                  context,
                  icon: Icons.local_shipping,
                  label: 'Supplier Management',
                  isIncluded: package.hasSupplierManagement,
                ),
                _buildFeatureChip(
                  context,
                  icon: Icons.account_balance_wallet,
                  label: 'E-Wallet Transfer',
                  isIncluded: package.hasEWallet,
                ),
                _buildFeatureChip(
                  context,
                  icon: Icons.analytics,
                  label: 'Advanced Analytics',
                  isIncluded: package.hasAdvancedAnalytics,
                ),
              ],
            ),
            if (package.maxUsers > 1) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(Icons.people, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Text(
                    'Up to ${package.maxUsers} users',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSubscriptionExpiryCard(BuildContext context) {
    if (_subscriptionExpires == null) return const SizedBox.shrink();

    final now = DateTime.now();
    final isExpired = now.isAfter(_subscriptionExpires!);
    final daysRemaining = _subscriptionExpires!.difference(now).inDays;
    final hoursRemaining = _subscriptionExpires!.difference(now).inHours;
    final minutesRemaining = _subscriptionExpires!.difference(now).inMinutes;
    final isExpiringSoon = !isExpired && daysRemaining <= 3;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isExpired
                ? [
                    Colors.red.withValues(alpha: 0.15),
                    Colors.red.withValues(alpha: 0.05),
                  ]
                : isExpiringSoon
                ? [
                    Colors.orange.withValues(alpha: 0.15),
                    Colors.orange.withValues(alpha: 0.05),
                  ]
                : [
                    Colors.green.withValues(alpha: 0.15),
                    Colors.green.withValues(alpha: 0.05),
                  ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isExpired
                        ? Colors.red
                        : isExpiringSoon
                        ? Colors.orange
                        : Colors.green,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isExpired
                        ? Icons.lock_clock
                        : isExpiringSoon
                        ? Icons.warning_amber
                        : Icons.calendar_month,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Monthly Subscription',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isExpired
                            ? 'Expired'
                            : isExpiringSoon
                            ? 'Expiring Soon'
                            : 'Active',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isExpired
                              ? Colors.red.shade700
                              : isExpiringSoon
                              ? Colors.orange.shade700
                              : Colors.green.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 16),
            // Price / discount display
            if (_subscriptionPriceDisplay != null ||
                _subscriptionDiscount != null) ...[
              Row(
                children: [
                  Icon(
                    Icons.attach_money,
                    size: 20,
                    color: isExpired
                        ? Colors.red.shade700
                        : isExpiringSoon
                        ? Colors.orange.shade700
                        : Colors.green.shade700,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Monthly Price',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            if (_subscriptionPriceDisplay != null)
                              Text(
                                _subscriptionPriceDisplay!,
                                style: Theme.of(context).textTheme.titleSmall
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                            const SizedBox(width: 8),
                            if (_subscriptionOriginalPriceDisplay != null)
                              Text(
                                _subscriptionOriginalPriceDisplay!,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      decoration: TextDecoration.lineThrough,
                                      color: Colors.grey.shade600,
                                    ),
                              ),
                            const Spacer(),
                            if (_subscriptionDiscount != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4,
                                  horizontal: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.green.shade200,
                                  ),
                                ),
                                child: Text(
                                  '-₱${_subscriptionDiscount!}',
                                  style: TextStyle(
                                    color: Colors.green.shade700,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            Row(
              children: [
                Icon(
                  Icons.schedule,
                  size: 20,
                  color: isExpired
                      ? Colors.red.shade700
                      : isExpiringSoon
                      ? Colors.orange.shade700
                      : Colors.green.shade700,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isExpired ? 'Expired On:' : 'Expires On:',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_subscriptionExpires!.toLocal().toString().split('.')[0].split(' ')[0]} at ${_subscriptionExpires!.toLocal().toString().split('.')[0].split(' ')[1]}',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (!isExpired) ...[
              Row(
                children: [
                  Icon(
                    Icons.timer,
                    size: 20,
                    color: isExpiringSoon
                        ? Colors.orange.shade700
                        : Colors.green.shade700,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      minutesRemaining < 60
                          ? '$minutesRemaining minutes remaining'
                          : hoursRemaining < 24
                          ? '$hoursRemaining hours remaining'
                          : '$daysRemaining days remaining',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: isExpiringSoon
                            ? Colors.orange.shade700
                            : Colors.green.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
            if (isExpired) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade300),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red.shade700),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Subscription expired. Renew now to restore access.',
                        style: TextStyle(
                          color: Colors.red.shade900,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () => _showRenewalDialog(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isExpired
                      ? Colors.red.shade600
                      : isExpiringSoon
                      ? Colors.orange.shade600
                      : Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
                icon: Icon(isExpired ? Icons.lock_open : Icons.payment),
                label: Text(
                  isExpired ? 'Renew Now' : 'Settle Now',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Monthly rental subscription - Activation code required for renewal',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showRenewalDialog() async {
    final packageService = GetIt.I<PackageService>();
    var package = packageService.selectedPackage;
    if (package == null) {
      final prefs = await SharedPreferences.getInstance();
      final savedPackageName = prefs.getString('subscription_package');
      for (final savedPackage in PricingPackage.packages) {
        if (savedPackage.name == savedPackageName) {
          package = savedPackage;
          break;
        }
      }
    }
    if (package == null || !mounted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to determine the current subscription package.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // Every settlement/renewal must start with a fresh activation-code
    // request, even if the user already requested or used a previous code.
    final requestSent = await showActivationCodeRequestDialog(
      context: context,
      packageName: package.name,
      packagePrice: package.price,
      requestType: 'monthly',
    );
    if (!requestSent || !mounted) return;

    final activationCodeController = TextEditingController();

    // Step 1: Show activation code input dialog
    final code = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.vpn_key, color: Colors.blue.shade700),
            const SizedBox(width: 12),
            const Expanded(child: Text('Enter Renewal Activation Code')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.refresh, color: Colors.blue.shade700),
                      const SizedBox(width: 8),
                      const Text(
                        'Monthly Renewal',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Renew your subscription:\n'
                    '1. Complete payment for next month\n'
                    '2. Get new activation code from developer\n'
                    '3. Enter code below to extend access\n'
                    '4. Valid for 1 more month',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Your request was sent. Enter the new activation code you receive to renew your subscription.',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: activationCodeController,
              decoration: InputDecoration(
                labelText: 'Renewal Activation Code',
                hintText: 'Enter new code from developer',
                prefixIcon: const Icon(Icons.vpn_key),
                border: const OutlineInputBorder(),
                helperText: 'Contact jaybe.gubot01@gmail.com for code',
              ),
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[A-Z0-9-]')),
              ],
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(null),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final inputCode = activationCodeController.text.trim();
              if (inputCode.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter activation code'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              Navigator.of(dialogContext).pop(inputCode);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Renew'),
          ),
        ],
      ),
    );

    activationCodeController.dispose();

    if (code == null || !mounted) return;

    // Step 2: Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: Center(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 24),
                  const Text(
                    'Processing renewal...',
                    style: TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Please wait',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    // Step 3: Try to activate
    try {
      final licenseService = GetIt.I<LicenseService>();
      final result = await licenseService.activate(code);

      if (!mounted) return;
      Navigator.pop(context); // Close loading

      if (result.success) {
        // Reload subscription info
        final prefs = await SharedPreferences.getInstance();
        final subExpStr = prefs.getString('subscription_expires');
        if (mounted && subExpStr != null) {
          try {
            setState(() => _subscriptionExpires = DateTime.parse(subExpStr));
          } catch (_) {}
        }

        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green.shade700),
                const SizedBox(width: 12),
                const Text('Renewal Successful!'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Your subscription has been renewed for another month!',
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.celebration,
                        color: Colors.green.shade700,
                        size: 48,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Access extended by 1 month\n(TEST MODE: 3 minutes)',
                        style: TextStyle(
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Done'),
              ),
            ],
          ),
        );
      } else {
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.error, color: Colors.red.shade700),
                const SizedBox(width: 12),
                const Text('Renewal Failed'),
              ],
            ),
            content: Text(result.message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close loading

      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.error, color: Colors.red.shade700),
              const SizedBox(width: 12),
              const Text('Error'),
            ],
          ),
          content: Text('An error occurred: $e'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildFeatureChip(
    BuildContext context, {
    required IconData icon,
    required String label,
    required bool isIncluded,
  }) {
    return Chip(
      avatar: Icon(
        isIncluded ? Icons.check_circle : Icons.cancel,
        size: 18,
        color: isIncluded ? Colors.green : Colors.grey,
      ),
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: isIncluded ? Colors.black87 : Colors.grey,
          decoration: isIncluded ? null : TextDecoration.lineThrough,
        ),
      ),
      backgroundColor: isIncluded
          ? Colors.green.withValues(alpha: 0.1)
          : Colors.grey.withValues(alpha: 0.1),
      side: BorderSide(
        color: isIncluded
            ? Colors.green.withValues(alpha: 0.3)
            : Colors.grey.withValues(alpha: 0.3),
        width: 1,
      ),
    );
  }

  Widget _buildCloudSyncSection(BuildContext context) {
    final packageService = GetIt.I<PackageService>();
    final currentPackage = packageService.selectedPackage;
    final hasCloudSyncAccess = packageService.hasCloudSyncAccess;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.cloud_sync,
              color: Theme.of(context).colorScheme.primary,
              size: 28,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Cloud Sync & Backup',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (!hasCloudSyncAccess)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange, width: 2),
            ),
            child: Column(
              children: [
                Icon(Icons.lock_outline, size: 48, color: Colors.orange[700]),
                const SizedBox(height: 12),
                Text(
                  'Cloud Sync Locked',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange[700],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'This feature is only available in Standard package and above',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.orange[700]),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Please upgrade to Standard package or above to enable Cloud Sync',
                        ),
                        duration: Duration(seconds: 3),
                      ),
                    );
                  },
                  icon: const Icon(Icons.upgrade),
                  label: const Text('Upgrade to Standard'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange[700],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                  ),
                ),
              ],
            ),
          )
        else ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green, size: 24),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Cloud Sync Enabled',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Your data is synced across devices and automatically backed up',
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 16),
                  ListTile(
                    leading: Icon(
                      Icons.cloud_download,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    title: const Text('Backup to Cloud'),
                    subtitle: const Text('Manual backup of all data'),
                    trailing: const Icon(Icons.arrow_forward),
                    onTap: () => _handleBackupToCloud(context),
                  ),
                  ListTile(
                    leading: Icon(
                      Icons.cloud_upload,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    title: const Text('Restore from Cloud'),
                    subtitle: const Text('Restore previous backup'),
                    trailing: const Icon(Icons.arrow_forward),
                    onTap: () => _handleRestoreFromCloud(context),
                  ),
                  ListTile(
                    leading: Icon(
                      Icons.sync,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    title: const Text('Auto-Sync Settings'),
                    subtitle: const Text('Sync data in real-time'),
                    trailing: const Icon(Icons.arrow_forward),
                    onTap: () => _handleBidirectionalSync(context),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.blue.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Colors.blue[700],
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Package: ${currentPackage?.name ?? 'Standard'}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue[700],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildBackendConnectionCard(BuildContext context) {
    final activeUrl = BackendConfig.resolvedApiBaseUrl ?? BackendConfig.apiBaseUrl;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.link, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Backend Connection',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Enter your droplet URL first. You can also add fallback URLs separated by commas or spaces.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _backendUrlController,
              decoration: const InputDecoration(
                labelText: 'Backend URL(s)',
                hintText: 'http://152.42.185.35:3000/api, http://192.168.x.x:3000/api',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.url,
              autocorrect: false,
              enableSuggestions: false,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isSavingBackendUrl ? null : _saveBackendUrl,
                    icon: _isSavingBackendUrl
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save),
                    label: Text(
                      _isSavingBackendUrl ? 'Saving...' : 'Save Backend URL',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Active URL: $activeUrl',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[700],
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class HexagonPainter extends CustomPainter {
  final Color color;
  final bool isSelected;

  HexagonPainter({required this.color, required this.isSelected});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = _createHexagonPath(size);
    canvas.drawPath(path, paint);

    if (isSelected) {
      final borderPaint = Paint()
        ..color = color.computeLuminance() > 0.5 ? Colors.black : Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3;
      canvas.drawPath(path, borderPaint);
    }
  }

  Path _createHexagonPath(Size size) {
    final path = Path();
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final radius = math.min(centerX, centerY) - 2;

    for (int i = 0; i < 6; i++) {
      final angle = (math.pi / 3 * i) - math.pi / 2;
      final x = centerX + radius * math.cos(angle);
      final y = centerY + radius * math.sin(angle);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(covariant HexagonPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.isSelected != isSelected;
  }
}

class _CustomColorPickerDialog extends StatefulWidget {
  @override
  State<_CustomColorPickerDialog> createState() =>
      _CustomColorPickerDialogState();
}

class _CustomColorPickerDialogState extends State<_CustomColorPickerDialog> {
  Color selectedColor = ThemeController.customColor.value;

  final List<Color> predefinedColors = [
    Colors.red,
    Colors.pink,
    Colors.purple,
    Colors.deepPurple,
    Colors.indigo,
    Colors.blue,
    Colors.lightBlue,
    Colors.cyan,
    Colors.teal,
    Colors.green,
    Colors.lightGreen,
    Colors.lime,
    Colors.yellow,
    Colors.amber,
    Colors.orange,
    Colors.deepOrange,
    Colors.brown,
    Colors.grey,
    Colors.blueGrey,
    const Color(0xFF6F4E37), // Mocha
    const Color(0xFF8B4513), // Saddle Brown
    const Color(0xFF2F4F4F), // Dark Slate Grey
    const Color(0xFF556B2F), // Dark Olive Green
    const Color(0xFF8B008B), // Dark Magenta
  ];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Choose Custom Color'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Selected color preview in hexagon
              _buildHexagon(
                color: selectedColor,
                isSelected: true,
                label: 'Selected',
                onTap: () {},
              ),
              const SizedBox(height: 24),
              // Honeycomb grid of predefined colors
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: predefinedColors.map((color) {
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        selectedColor = color;
                      });
                    },
                    child: _buildSmallHexagon(
                      color: color,
                      isSelected: selectedColor.toARGB32() == color.toARGB32(),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(AppLocalizations.t('cancel')),
        ),
        ElevatedButton(
          onPressed: () {
            ThemeController.setTheme('custom', color: selectedColor);
            Navigator.pop(context);
          },
          child: const Text('Apply'),
        ),
      ],
    );
  }

  Widget _buildHexagon({
    required Color color,
    required bool isSelected,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 80,
        height: 92,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(
              size: const Size(80, 92),
              painter: HexagonPainter(color: color, isSelected: isSelected),
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isSelected)
                  Icon(
                    Icons.check_circle,
                    color: color.computeLuminance() > 0.5
                        ? Colors.black
                        : Colors.white,
                    size: 24,
                  ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: color.computeLuminance() > 0.5
                        ? Colors.black
                        : Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSmallHexagon({required Color color, required bool isSelected}) {
    return SizedBox(
      width: 50,
      height: 58,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(50, 58),
            painter: HexagonPainter(color: color, isSelected: isSelected),
          ),
          if (isSelected)
            Icon(
              Icons.check,
              color: color.computeLuminance() > 0.5
                  ? Colors.black
                  : Colors.white,
              size: 20,
            ),
        ],
      ),
    );
  }
}
