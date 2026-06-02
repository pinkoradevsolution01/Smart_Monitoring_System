import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import '../../services/admin_service.dart';
import '../../utils/app_localizations.dart';

class ManageAdminAccountScreen extends StatefulWidget {
  const ManageAdminAccountScreen({super.key});

  @override
  State<ManageAdminAccountScreen> createState() =>
      _ManageAdminAccountScreenState();
}

class _ManageAdminAccountScreenState extends State<ManageAdminAccountScreen> {
  late AdminService _adminService;
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _contactController;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _adminService = GetIt.I<AdminService>();
    _initializeControllers();
    _adminService.addListener(_onAdminChanged);
  }

  void _initializeControllers() {
    _nameController = TextEditingController(
      text: _adminService.adminAccount.name,
    );
    _emailController = TextEditingController(
      text: _adminService.adminAccount.email,
    );
    _contactController = TextEditingController(
      text: _adminService.adminAccount.contactNumber ?? '',
    );
  }

  void _onAdminChanged() {
    if (mounted) {
      _initializeControllers();
      setState(() {});
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _contactController.dispose();
    _adminService.removeListener(_onAdminChanged);
    super.dispose();
  }

  void _saveChanges() {
    if (_nameController.text.isEmpty ||
        _emailController.text.isEmpty ||
        !_emailController.text.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.t('fill_required_fields'))),
      );
      return;
    }

    final updated = _adminService.adminAccount.copyWith(
      name: _nameController.text.trim(),
      email: _emailController.text.trim(),
      contactNumber: _contactController.text.isNotEmpty
          ? _contactController.text.trim()
          : null,
    );

    _adminService.updateAdminAccount(updated).then((success) {
      if (!mounted) return;
      if (success) {
        setState(() => _isEditing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.t('account_updated_success')),
          ),
        );
      }
    });
  }

  void _showChangePasswordDialog() {
    showDialog(
      context: context,
      builder: (_) => _ChangePasswordDialog(
        adminService: _adminService,
        onPasswordChanged: () {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(AppLocalizations.t('password_changed_success')),
              ),
            );
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final admin = _adminService.adminAccount;
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.t('manage_admin_account')),
        actions: [
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => setState(() => _isEditing = true),
              tooltip: AppLocalizations.t('edit'),
            )
          else
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                setState(() => _isEditing = false);
                _initializeControllers();
              },
              tooltip: AppLocalizations.t('cancel'),
            ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Admin Avatar and Status
                Center(
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.blue.shade100,
                        child: Icon(
                          Icons.admin_panel_settings,
                          size: 50,
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        admin.name,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        admin.email,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      if (admin.lastModified != null)
                        Text(
                          AppLocalizations.t('last_updated_date').replaceAll(
                            '{date}',
                            _formatDate(admin.lastModified!),
                          ),
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall?.copyWith(color: Colors.grey),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Account Information Section
                Text(
                  AppLocalizations.t('account_information'),
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),

                // Name Field
                TextField(
                  controller: _nameController,
                  enabled: _isEditing,
                  decoration: InputDecoration(
                    labelText: AppLocalizations.t('full_name'),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    prefixIcon: const Icon(Icons.person),
                    filled: true,
                    fillColor: _isEditing ? Colors.white : Colors.grey.shade50,
                  ),
                ),
                const SizedBox(height: 16),

                // Email Field
                TextField(
                  controller: _emailController,
                  enabled: _isEditing,
                  decoration: InputDecoration(
                    labelText: AppLocalizations.t('email_address'),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    prefixIcon: const Icon(Icons.email),
                    filled: true,
                    fillColor: _isEditing ? Colors.white : Colors.grey.shade50,
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),

                // Contact Number Field
                TextField(
                  controller: _contactController,
                  enabled: _isEditing,
                  decoration: InputDecoration(
                    labelText: AppLocalizations.t('account_contact_number'),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    prefixIcon: const Icon(Icons.phone),
                    hintText: AppLocalizations.t('contact_hint'),
                    filled: true,
                    fillColor: _isEditing ? Colors.white : Colors.grey.shade50,
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 24),

                // Save Button (visible when editing)
                if (_isEditing)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _saveChanges,
                      icon: const Icon(Icons.save),
                      label: Text(AppLocalizations.t('save_changes')),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                if (_isEditing) const SizedBox(height: 12),

                // Change Password Section
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    border: Border.all(color: Colors.amber.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.security, color: Colors.amber.shade700),
                          const SizedBox(width: 8),
                          Text(
                            AppLocalizations.t('security'),
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        AppLocalizations.t('security_message'),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _showChangePasswordDialog,
                          icon: const Icon(Icons.lock_open),
                          label: Text(AppLocalizations.t('change_password')),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amber.shade700,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Account Stats
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    border: Border.all(color: Colors.blue.shade200),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                AppLocalizations.t('account_created'),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              Text(
                                _formatDate(admin.createdAt),
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                AppLocalizations.t('last_updated'),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              Text(
                                admin.lastModified != null
                                    ? _formatDate(admin.lastModified!)
                                    : AppLocalizations.t('never'),
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Danger Zone - Delete Account
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    border: Border.all(color: Colors.red.shade300, width: 2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.warning_amber, color: Colors.red.shade700),
                          const SizedBox(width: 8),
                          Text(
                            'Danger Zone',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red.shade700,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Deleting your admin account will permanently remove all account data and credentials. This action cannot be undone. You will need to create a new admin account to access the system.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _showDeleteAccountDialog,
                          icon: const Icon(Icons.delete_forever),
                          label: const Text('Delete Admin Account'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red.shade700,
                            side: BorderSide(
                              color: Colors.red.shade700,
                              width: 2,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
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
      ),
    );
  }

  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber, color: Colors.red.shade700),
            const SizedBox(width: 8),
            const Text('Delete Admin Account'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Are you absolutely sure you want to delete your admin account?',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text('This action will:'),
            const SizedBox(height: 8),
            const Text('• Permanently delete all admin credentials'),
            const Text('• Remove all saved account information'),
            const Text('• Log you out of the system'),
            const Text('• Require creating a new admin account'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                '⚠️ This action cannot be undone!',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              _confirmDeleteAccount();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
            ),
            child: const Text('Yes, Delete Account'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteAccount() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Final Confirmation'),
        content: const Text('Type "DELETE" to confirm account deletion:'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    // Show text field dialog for confirmation
    final TextEditingController confirmController = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Final Confirmation'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Type "DELETE" to confirm account deletion:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: confirmController,
              decoration: const InputDecoration(
                hintText: 'Type DELETE here',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              confirmController.dispose();
              Navigator.pop(dialogContext);
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (confirmController.text.trim() == 'DELETE') {
                Navigator.pop(dialogContext);
                confirmController.dispose();
                await _deleteAccount();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please type DELETE to confirm'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
            ),
            child: const Text('Confirm Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAccount() async {
    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Deleting admin account...'),
              ],
            ),
          ),
        ),
      ),
    );

    // Delete account
    final success = await _adminService.deleteAdminAccount();

    if (!mounted) return;

    Navigator.pop(context); // Close loading dialog

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Admin account deleted successfully'),
          backgroundColor: Colors.green,
        ),
      );

      // Navigate back to login screen
      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to delete account. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}

class _ChangePasswordDialog extends StatefulWidget {
  final AdminService adminService;
  final VoidCallback onPasswordChanged;

  const _ChangePasswordDialog({
    required this.adminService,
    required this.onPasswordChanged,
  });

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  late TextEditingController _currentPasswordController;
  late TextEditingController _newPasswordController;
  late TextEditingController _confirmPasswordController;
  bool _showCurrentPassword = false;
  bool _showNewPassword = false;
  bool _showConfirmPassword = false;
  bool _isVerifyingCurrent = false;

  @override
  void initState() {
    super.initState();
    _currentPasswordController = TextEditingController();
    _newPasswordController = TextEditingController();
    _confirmPasswordController = TextEditingController();
  }

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    // Validate current password
    if (!widget.adminService.authenticate(
      widget.adminService.adminAccount.email,
      _currentPasswordController.text,
    )) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.t('current_password_incorrect')),
        ),
      );
      return;
    }

    // Validate new password
    if (_newPasswordController.text.length < 6) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.t('new_password_min_length'))),
      );
      return;
    }

    // Validate password confirmation
    if (_newPasswordController.text != _confirmPasswordController.text) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.t('passwords_do_not_match'))),
      );
      return;
    }

    // Reset password
    setState(() => _isVerifyingCurrent = true);
    final success = await widget.adminService.resetPassword(
      _newPasswordController.text,
    );
    if (!mounted) return;
    setState(() => _isVerifyingCurrent = false);

    if (success) {
      widget.onPasswordChanged();
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.t('admin_password_conflict'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(AppLocalizations.t('change_password')),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _currentPasswordController,
              obscureText: !_showCurrentPassword,
              decoration: InputDecoration(
                labelText: AppLocalizations.t('current_password'),
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.lock),
                suffixIcon: IconButton(
                  icon: Icon(
                    _showCurrentPassword
                        ? Icons.visibility
                        : Icons.visibility_off,
                  ),
                  onPressed: () => setState(
                    () => _showCurrentPassword = !_showCurrentPassword,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _newPasswordController,
              obscureText: !_showNewPassword,
              decoration: InputDecoration(
                labelText: AppLocalizations.t('new_password'),
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.lock),
                suffixIcon: IconButton(
                  icon: Icon(
                    _showNewPassword ? Icons.visibility : Icons.visibility_off,
                  ),
                  onPressed: () =>
                      setState(() => _showNewPassword = !_showNewPassword),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _confirmPasswordController,
              obscureText: !_showConfirmPassword,
              decoration: InputDecoration(
                labelText: AppLocalizations.t('confirm_new_password'),
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.lock),
                suffixIcon: IconButton(
                  icon: Icon(
                    _showConfirmPassword
                        ? Icons.visibility
                        : Icons.visibility_off,
                  ),
                  onPressed: () => setState(
                    () => _showConfirmPassword = !_showConfirmPassword,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(AppLocalizations.t('cancel')),
        ),
        ElevatedButton(
          onPressed: _isVerifyingCurrent ? null : _changePassword,
          child: _isVerifyingCurrent
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(AppLocalizations.t('update_password')),
        ),
      ],
    );
  }
}
