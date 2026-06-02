import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import '../../services/user_service.dart';
import '../../models/user.dart';
import '../../utils/app_localizations.dart';

class ManageOwnerAccountScreen extends StatefulWidget {
  const ManageOwnerAccountScreen({super.key});

  @override
  State<ManageOwnerAccountScreen> createState() =>
      _ManageOwnerAccountScreenState();
}

class _ManageOwnerAccountScreenState extends State<ManageOwnerAccountScreen> {
  late UserService _userService;
  User? _owner;

  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _contactController;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _userService = GetIt.I<UserService>();
    _loadOwner();
    _userService.addListener(_onUsersChanged);
  }

  void _loadOwner() {
    final owners = _userService.getUsersByRole(UserRole.owner);
    _owner = owners.isNotEmpty ? owners.first : null;
    _initializeControllers();
  }

  void _initializeControllers() {
    _nameController = TextEditingController(text: _owner?.name ?? '');
    _emailController = TextEditingController(text: _owner?.email ?? '');
    _contactController = TextEditingController(text: _owner?.pin ?? '');
  }

  void _onUsersChanged() {
    if (!mounted) return;
    _loadOwner();
    setState(() {});
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _contactController.dispose();
    _userService.removeListener(_onUsersChanged);
    super.dispose();
  }

  Future<void> _saveChanges() async {
    if (_nameController.text.isEmpty ||
        _emailController.text.isEmpty ||
        !_emailController.text.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.t('fill_required_fields'))),
      );
      return;
    }

    if (_owner != null) {
      final updated = _owner!.copyWith(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        pin: _contactController.text.isNotEmpty
            ? _contactController.text.trim()
            : _owner!.pin,
      );
      final success = await _userService.updateUser(updated);
      if (!mounted) return;
      if (success) {
        setState(() => _isEditing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.t('account_updated_success')),
          ),
        );
      }
    } else {
      final id = 'owner-${DateTime.now().millisecondsSinceEpoch}';
      final user = User(
        id: id,
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        password: 'owner',
        pin: _contactController.text.trim(),
        role: UserRole.owner,
        createdAt: DateTime.now(),
        isActive: true,
      );
      final success = await _userService.addUser(user);
      if (!mounted) return;
      if (success) {
        setState(() => _isEditing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.t('account_created_success')),
          ),
        );
      }
    }
  }

  void _showChangePasswordDialog() {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) =>
          _OwnerChangePasswordDialog(userService: _userService, owner: _owner),
    );
  }

  Future<void> _deleteOwner() async {
    if (_owner == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Owner Account'),
        content: const Text(
          'This will permanently delete the owner account. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppLocalizations.t('cancel')),
          ),
          // ignore: sort_child_properties_last
          ElevatedButton(
             onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final success = await _userService.deleteUserPermanently(_owner!.id);
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
        title: const Text('Manage Owner Account'),
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
                        _owner?.name ?? 'No owner registered',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _owner?.email ?? '',
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
                        'Deleting the owner account will remove login access and related data.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _deleteOwner,
                          icon: const Icon(Icons.delete_forever),
                          label: const Text('Delete Owner Account'),
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

class _OwnerChangePasswordDialog extends StatefulWidget {
  final UserService userService;
  final User? owner;

  const _OwnerChangePasswordDialog({
    required this.userService,
    required this.owner,
  });

  @override
  State<_OwnerChangePasswordDialog> createState() =>
      _OwnerChangePasswordDialogState();
}

class _OwnerChangePasswordDialogState
    extends State<_OwnerChangePasswordDialog> {
  late TextEditingController _currentController;
  late TextEditingController _newController;
  late TextEditingController _confirmController;
  bool _isLoading = false;

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
    if (widget.owner == null) return;
    
    // If owner has no password (Google OAuth user), skip current password check
    final hasCurrentPassword = widget.owner!.password.isNotEmpty;
    
    if (hasCurrentPassword) {
      if (!widget.userService.authenticate(
        widget.owner!.email,
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
    }
    
    if (_newController.text.length < 6) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.t('new_password_min_length'))),
      );
      return;
    }
    if (_newController.text != _confirmController.text) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.t('passwords_do_not_match'))),
      );
      return;
    }

    setState(() => _isLoading = true);
    final updated = widget.owner!.copyWith(password: _newController.text);
    final success = await widget.userService.updateUser(updated);
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.t('password_changed_success'))),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.t('action_failed'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasCurrentPassword = widget.owner?.password.isNotEmpty ?? false;
    
    return AlertDialog(
      title: Text(AppLocalizations.t('change_password')),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasCurrentPassword)
              Column(
                children: [
                  TextField(
                    controller: _currentController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: AppLocalizations.t('current_password'),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              )
            else
              Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade300),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Colors.blue.shade700,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Set up your first password to login with email',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue.shade900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            TextField(
              controller: _newController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: hasCurrentPassword
                    ? AppLocalizations.t('new_password')
                    : 'Password',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _confirmController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: hasCurrentPassword
                    ? AppLocalizations.t('confirm_new_password')
                    : 'Confirm Password',
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
