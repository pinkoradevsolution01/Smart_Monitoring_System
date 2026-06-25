import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import '../../services/user_service.dart';
import '../../models/user.dart';
import '../../utils/app_localizations.dart';
import '../../services/backend_api_service.dart';
import '../../services/backend_config.dart';

class ManageOwnerAccountScreen extends StatefulWidget {
  const ManageOwnerAccountScreen({super.key});

  @override
  State<ManageOwnerAccountScreen> createState() =>
      _ManageOwnerAccountScreenState();
}

class _ManageOwnerAccountScreenState extends State<ManageOwnerAccountScreen> {
  late UserService _userService;
  final ApiClient _api = ApiClient();
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

      if (BackendConfig.useRestBackend) {
        try {
          final response = await _api.patchJson(
            'auth/users/${Uri.encodeComponent(_owner!.id)}',
            body: {
              'fullName': updated.name,
              'email': updated.email,
              'contactNumber': updated.pin,
              'role': updated.role.toString().split('.').last,
            },
          );
          if (response is! Map<String, dynamic> || response['success'] != true) {
            throw Exception('Failed to update owner in backend');
          }
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to save owner changes to MySQL: $e'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
      }

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
      final provisionalId = 'owner-${DateTime.now().millisecondsSinceEpoch}';
      var ownerId = provisionalId;

      if (BackendConfig.useRestBackend) {
        try {
          final registerResponse = await _api.postJson(
            'auth/google/register-owner',
            body: {
              'id': provisionalId,
              'email': _emailController.text.trim(),
              'fullName': _nameController.text.trim(),
              'contactNumber': _contactController.text.trim(),
            },
          );
          if (registerResponse is! Map<String, dynamic> ||
              registerResponse['success'] != true ||
              registerResponse['user'] is! Map) {
            throw Exception('Failed to create owner in backend');
          }

          final backendUser =
              Map<String, dynamic>.from(registerResponse['user'] as Map);
          ownerId = backendUser['id']?.toString() ?? ownerId;

          final passwordResponse = await _api.patchJson(
            'auth/users/${Uri.encodeComponent(ownerId)}/password',
            body: {'newPassword': 'owner'},
          );
          if (passwordResponse is! Map<String, dynamic> ||
              passwordResponse['success'] != true) {
            throw Exception('Failed to set owner password in backend');
          }
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to create owner in MySQL: $e'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
      }

      final user = User(
        id: ownerId,
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

  void _showChangePinDialog() {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) {
        final newPinCtrl = TextEditingController();
        final confirmPinCtrl = TextEditingController();
        bool isSaving = false;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Change Owner PIN'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: newPinCtrl,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    decoration: const InputDecoration(
                      hintText: 'New 4-digit PIN',
                    ),
                    obscureText: true,
                  ),
                  TextField(
                    controller: confirmPinCtrl,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    decoration: const InputDecoration(hintText: 'Confirm PIN'),
                    obscureText: true,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(AppLocalizations.t('cancel')),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (isSaving) return;

                    final a = newPinCtrl.text.trim();
                    final b = confirmPinCtrl.text.trim();
                    final pinPattern = RegExp(r'^\d{4}$');
                    if (!pinPattern.hasMatch(a) ||
                        !pinPattern.hasMatch(b) ||
                        a != b) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('PINs must match and be 4 digits'),
                        ),
                      );
                      return;
                    }

                    if (_owner == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('No owner account to update'),
                        ),
                      );
                      return;
                    }

                    setDialogState(() {
                      isSaving = true;
                    });

                    if (BackendConfig.useRestBackend) {
                      try {
                        final response = await _api.patchJson(
                          'auth/users/${Uri.encodeComponent(_owner!.id)}',
                          body: {
                            'fullName': _owner!.name,
                            'email': _owner!.email,
                            'contactNumber': a,
                            'role': _owner!.role.toString().split('.').last,
                          },
                        );
                        if (response is! Map<String, dynamic> ||
                            response['success'] != true) {
                          throw Exception('Failed to update PIN in backend');
                        }
                      } catch (e) {
                        if (!mounted) return;
                        setDialogState(() {
                          isSaving = false;
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Failed to save PIN changes to MySQL: $e',
                            ),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }
                    }

                    final updated = _owner!.copyWith(pin: a);
                    final success = await _userService.updateUser(updated);
                    if (!mounted) return;
                    setDialogState(() {
                      isSaving = false;
                    });
                    if (success) {
                      setState(() {
                        _owner = updated;
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            AppLocalizations.t('account_updated_success'),
                          ),
                        ),
                      );
                      Navigator.pop(ctx);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(AppLocalizations.t('action_failed')),
                        ),
                      );
                    }
                  },
                  child: isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(AppLocalizations.t('save_changes')),
                ),
              ],
            );
          },
        );
      },
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

    if (BackendConfig.useRestBackend) {
      try {
        final response = await _api.deleteJson(
          'auth/users/${Uri.encodeComponent(_owner!.id)}',
        );
        if (response is! Map<String, dynamic> || response['success'] != true) {
          throw Exception('Failed to delete owner in backend');
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete owner from MySQL: $e'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

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
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _showChangePinDialog,
                          icon: const Icon(Icons.pin),
                          label: const Text('Change PIN'),
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
  final ApiClient _api = ApiClient();
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
    if (BackendConfig.useRestBackend) {
      try {
        final response = await _api.patchJson(
          'auth/users/${Uri.encodeComponent(widget.owner!.id)}/password',
          body: {
            if (hasCurrentPassword) 'currentPassword': _currentController.text,
            'newPassword': _newController.text,
          },
        );
        if (response is! Map<String, dynamic> || response['success'] != true) {
          throw Exception('Failed to update password in backend');
        }
      } catch (e) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to change password in MySQL: $e'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    final updated = widget.owner!.copyWith(
      password: _newController.text,
      authMethod: hasCurrentPassword ? widget.owner!.authMethod : 'password',
    );
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
