import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import '../../services/admin_service.dart';
import '../../models/admin_account.dart';
import '../../utils/app_localizations.dart';

class ManageAdminAccountScreen extends StatefulWidget {
  const ManageAdminAccountScreen({super.key});

  @override
  State<ManageAdminAccountScreen> createState() =>
      _ManageAdminAccountScreenState();
}

class _ManageAdminAccountScreenState extends State<ManageAdminAccountScreen> {
  late AdminService _adminService;
  AdminAccount? _admin;

  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _contactController;
  late TextEditingController _passwordController;
  late TextEditingController _confirmController;

  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _adminService = GetIt.I<AdminService>();
    _loadAdmin();
    _adminService.addListener(_onAdminChanged);
  }

  void _loadAdmin() {
    final adminAccount = _adminService.adminAccount;
    _admin = (adminAccount.email.isEmpty && adminAccount.password.isEmpty)
        ? null
        : adminAccount;
    _initializeControllers();
    // If there's no admin account yet, start in editing mode to create one
    if (_admin == null) {
      _isEditing = true;
    }
    if (mounted) setState(() {});
  }

  void _initializeControllers() {
    _nameController = TextEditingController(text: _admin?.name ?? '');
    _emailController = TextEditingController(text: _admin?.email ?? '');
    _contactController = TextEditingController(
      text: _admin?.contactNumber ?? '',
    );
    _passwordController = TextEditingController();
    _confirmController = TextEditingController();
  }

  void _onAdminChanged() {
    if (!mounted) return;
    _loadAdmin();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _contactController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _adminService.removeListener(_onAdminChanged);
    super.dispose();
  }

  Future<void> _saveChanges() async {
    if (_nameController.text.isEmpty ||
        _emailController.text.isEmpty ||
        !_emailController.text.contains('@')) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.t('fill_required_fields'))),
      );
      return;
    }

    if (_admin != null) {
      final updated = _admin!.copyWith(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        contactNumber: _contactController.text.isNotEmpty
            ? _contactController.text.trim()
            : _admin!.contactNumber,
      );
      final success = await _adminService.updateAdminAccount(updated);
      if (!mounted) return;
      if (success) {
        setState(() => _isEditing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.t('account_updated_success')),
          ),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.t('action_failed'))),
        );
      }
    } else {
      final contact = _contactController.text.trim();
      if (contact.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.t('valid_contact_required'))),
        );
        return;
      }

      // Basic contact format guidance: require country code (starts with '+')
      if (!contact.startsWith('+') || contact.length < 10) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.t('valid_contact_required'))),
        );
        return;
      }

      if (_passwordController.text.length < 6 ||
          _passwordController.text != _confirmController.text) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.t('passwords_do_not_match'))),
        );
        return;
      }

      final success = await _adminService.createAdminAccount(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        contactNumber: contact,
      );
      if (!mounted) return;
      if (success) {
        setState(() => _isEditing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.t('account_created_success')),
          ),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.t('admin_password_conflict')),
          ),
        );
      }
    }
  }

  void _showChangePasswordDialog() {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) => _AdminChangePasswordDialog(
        adminService: _adminService,
        admin: _admin,
      ),
    );
  }

  Future<void> _deleteAdmin() async {
    if (_admin == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Admin Account'),
        content: const Text(
          'This will permanently delete the admin account. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppLocalizations.t('cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final success = await _adminService.deleteAdminAccount();
    if (!mounted) return;
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.t('account_deleted'))),
      );
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.t('action_failed'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _admin == null ? 'Create Admin Account' : 'Manage Staff (Admin)',
        ),
        actions: [
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => setState(() => _isEditing = true),
            )
          else
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                setState(() => _isEditing = false);
                _initializeControllers();
              },
            ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 48,
                        backgroundColor: Colors.blue.shade50,
                        child: Icon(Icons.person, size: 48, color: Colors.blue),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _admin?.name ?? 'No admin staff registered',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _admin?.email ?? '',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  AppLocalizations.t('account_information'),
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _nameController,
                  enabled: _isEditing,
                  decoration: InputDecoration(
                    labelText: AppLocalizations.t('full_name'),
                    prefixIcon: const Icon(Icons.person),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _emailController,
                  enabled: _isEditing,
                  decoration: InputDecoration(
                    labelText: AppLocalizations.t('email_address'),
                    prefixIcon: const Icon(Icons.email),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _contactController,
                  enabled: _isEditing,
                  decoration: InputDecoration(
                    labelText: AppLocalizations.t('account_contact_number'),
                    prefixIcon: const Icon(Icons.phone),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 12),
                if (_admin == null && _isEditing) ...[
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'Create Password',
                      prefixIcon: const Icon(Icons.lock),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _confirmController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: AppLocalizations.t('confirm_password'),
                      prefixIcon: const Icon(Icons.lock_outline),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                if (_isEditing)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _saveChanges,
                      icon: const Icon(Icons.save),
                      label: Text(AppLocalizations.t('save_changes')),
                    ),
                  ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
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
                      const SizedBox(height: 8),
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
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    border: Border.all(color: Colors.red.shade300),
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
                      const SizedBox(height: 8),
                      Text(
                        'Deleting the admin account will remove admin login access.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _deleteAdmin,
                          icon: const Icon(Icons.delete_forever),
                          label: const Text('Delete Admin Account'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: BorderSide(color: Colors.red.shade700),
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
}

class _AdminChangePasswordDialog extends StatefulWidget {
  final AdminService adminService;
  final AdminAccount? admin;

  const _AdminChangePasswordDialog({
    required this.adminService,
    required this.admin,
  });

  @override
  State<_AdminChangePasswordDialog> createState() =>
      _AdminChangePasswordDialogState();
}

class _AdminChangePasswordDialogState
    extends State<_AdminChangePasswordDialog> {
  late TextEditingController _currentController;
  late TextEditingController _newController;
  late TextEditingController _confirmController;
  bool _isLoading = false;
  bool _showCurrentPassword = false;
  bool _showNewPassword = false;
  bool _showConfirmPassword = false;

  @override
  void initState() {
    super.initState();
    _currentController = TextEditingController();
    _newController = TextEditingController();
    _confirmController = TextEditingController();
  }

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    if (widget.admin == null) return;

    // Validate current password
    if (!widget.adminService.authenticate(
      widget.admin!.email,
      _currentController.text,
    )) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.t('current_password_incorrect')),
        ),
      );
      return;
    }

    // Validate new password length
    if (_newController.text.length < 6) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.t('new_password_min_length'))),
      );
      return;
    }

    // Validate password confirmation
    if (_newController.text != _confirmController.text) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.t('passwords_do_not_match'))),
      );
      return;
    }

    setState(() => _isLoading = true);
    final success = await widget.adminService.resetPassword(
      _newController.text,
    );
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.t('password_changed_success'))),
      );
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
              controller: _currentController,
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
              controller: _newController,
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
              controller: _confirmController,
              obscureText: !_showConfirmPassword,
              decoration: InputDecoration(
                labelText: AppLocalizations.t('confirm_new_password'),
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.lock_outline),
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
          onPressed: _isLoading ? null : _changePassword,
          child: _isLoading
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
