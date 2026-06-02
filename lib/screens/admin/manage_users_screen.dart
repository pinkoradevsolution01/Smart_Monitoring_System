import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import '../../models/user.dart';
import '../../services/user_service.dart';
import '../../services/package_service.dart';
import '../../utils/app_localizations.dart';

class ManageUsers extends StatefulWidget {
  const ManageUsers({super.key});

  @override
  State<ManageUsers> createState() => _ManageUsersState();
}

class _ManageUsersState extends State<ManageUsers> {
  late UserService _userService;
  late PackageService _packageService;

  @override
  void initState() {
    super.initState();
    _userService = GetIt.I<UserService>();
    _packageService = GetIt.I<PackageService>();
    _userService.addListener(_onUsersChanged);
  }

  void _onUsersChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _userService.removeListener(_onUsersChanged);
    super.dispose();
  }

  void _showAddUserDialog() {
    // Check if user limit is reached (exclude owner from count)
    final currentUserCount = _userService.activeUsers
        .where((u) => u.role != UserRole.owner)
        .length;
    final maxUsers = _packageService.selectedPackage?.maxUsers ?? 999;

    if (currentUserCount >= maxUsers) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'User limit reached! Your ${_packageService.selectedPackage?.name ?? "current"} package allows only $maxUsers user${maxUsers > 1 ? "s" : ""}.',
          ),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 3),
          action: SnackBarAction(
            label: 'Dismiss',
            textColor: Colors.white,
            onPressed: () {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
            },
          ),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (_) => _UserFormDialog(
        title: 'Add New User',
        onSave: (user) async {
          final success = await _userService.addUser(user);
          if (!mounted) return;
          if (success) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('User added successfully')),
            );
            Navigator.pop(context);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Email already in use')),
            );
          }
        },
      ),
    );
  }

  void _showEditUserDialog(User user) {
    showDialog(
      context: context,
      builder: (_) => _UserFormDialog(
        title: 'Edit User',
        initialUser: user,
        onSave: (updatedUser) async {
          final success = await _userService.updateUser(updatedUser);
          if (!mounted) return;
          if (success) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('User updated successfully')),
            );
            Navigator.pop(context);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Email already in use')),
            );
          }
        },
      ),
    );
  }

  void _showDeleteConfirm(User user) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Deactivate User'),
        content: Text('Are you sure you want to deactivate ${user.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.t('cancel')),
          ),
          TextButton(
            onPressed: () async {
              await _userService.removeUser(user.id);
              if (!mounted) return;
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('User deactivated')));
              Navigator.pop(context);
            },
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.t('manage_users_title')),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add User',
            onPressed: _showAddUserDialog,
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 12.0,
            ),
            child: Builder(
              builder: (context) {
                final users = _userService.activeUsers
                    .where((u) => u.role != UserRole.owner)
                    .toList();

                if (users.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: 80,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 16),
                        const Text('No users yet'),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _showAddUserDialog,
                          icon: const Icon(Icons.add),
                          label: const Text('Add User'),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final user = users[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 4,
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: user.role == UserRole.owner
                              ? Colors.blue
                              : user.role == UserRole.manager
                              ? Colors.indigo
                              : user.role == UserRole.salesPromoter
                              ? Colors.orange
                              : user.role == UserRole.inventoryClerk
                              ? Colors.purple
                              : user.role == UserRole.deliveryReceiver
                              ? Colors.brown
                              : user.role == UserRole.cashier
                              ? Colors.green
                              : Colors.grey,
                          child: Icon(
                            user.role == UserRole.owner
                                ? Icons.admin_panel_settings
                                : user.role == UserRole.manager
                                ? Icons.work
                                : user.role == UserRole.salesPromoter
                                ? Icons.campaign
                                : user.role == UserRole.inventoryClerk
                                ? Icons.inventory
                                : user.role == UserRole.deliveryReceiver
                                ? Icons.local_shipping
                                : user.role == UserRole.cashier
                                ? Icons.shopping_cart
                                : Icons.more_horiz,
                            color: Colors.white,
                          ),
                        ),
                        title: Text(user.name),
                        subtitle: Text(
                          '${user.role == UserRole.owner
                              ? AppLocalizations.t('owner')
                              : user.role == UserRole.manager
                              ? AppLocalizations.t('manager')
                              : user.role == UserRole.salesPromoter
                              ? AppLocalizations.t('sales_promoter')
                              : user.role == UserRole.inventoryClerk
                              ? AppLocalizations.t('inventory_clerk')
                              : user.role == UserRole.deliveryReceiver
                              ? AppLocalizations.t('delivery_receiver')
                              : user.role == UserRole.cashier
                              ? AppLocalizations.t('cashier_role')
                              : AppLocalizations.t('other_role')} • ${user.email}',
                        ),
                        trailing: PopupMenuButton(
                          itemBuilder: (_) => [
                            PopupMenuItem(
                              child: Text(AppLocalizations.t('edit')),
                              onTap: () => Future.delayed(
                                const Duration(milliseconds: 300),
                                () => _showEditUserDialog(user),
                              ),
                            ),
                            PopupMenuItem(
                              child: Text(
                                AppLocalizations.t('deactivate'),
                                style: TextStyle(color: Colors.red),
                              ),
                              onTap: () => Future.delayed(
                                const Duration(milliseconds: 300),
                                () => _showDeleteConfirm(user),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _UserFormDialog extends StatefulWidget {
  final String title;
  final User? initialUser;
  final Function(User) onSave;

  const _UserFormDialog({
    required this.title,
    this.initialUser,
    required this.onSave,
  });

  @override
  State<_UserFormDialog> createState() => _UserFormDialogState();
}

class _UserFormDialogState extends State<_UserFormDialog> {
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _passwordController;
  late TextEditingController _pinController;
  UserRole _selectedRole = UserRole.cashier;
  bool _showPassword = false;
  bool _showPin = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialUser != null) {
      _nameController = TextEditingController(text: widget.initialUser!.name);
      _emailController = TextEditingController(text: widget.initialUser!.email);
      _passwordController = TextEditingController(
        text: widget.initialUser!.password,
      );
      _pinController = TextEditingController(
        text: widget.initialUser!.pin ?? '',
      );
      _selectedRole = widget.initialUser!.role;
    } else {
      _nameController = TextEditingController();
      _emailController = TextEditingController();
      _passwordController = TextEditingController();
      _pinController = TextEditingController();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  bool _isValidForm() {
    return _nameController.text.isNotEmpty &&
        _emailController.text.isNotEmpty &&
        _emailController.text.contains('@') &&
        _passwordController.text.isNotEmpty &&
        _passwordController.text.length >= 6;
  }

  void _save() {
    if (!_isValidForm()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please fill all fields correctly (password min 6 chars, valid email)',
          ),
        ),
      );
      return;
    }

    final id =
        widget.initialUser?.id ??
        'user-${DateTime.now().millisecondsSinceEpoch}';
    final user = User(
      id: id,
      name: _nameController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text,
      pin: _pinController.text.isNotEmpty ? _pinController.text : null,
      role: _selectedRole,
      createdAt: widget.initialUser?.createdAt ?? DateTime.now(),
      isActive: true,
    );

    widget.onSave(user);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _passwordController,
                obscureText: !_showPassword,
                decoration: InputDecoration(
                  labelText: 'Password (min 6 chars)',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _showPassword ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () =>
                        setState(() => _showPassword = !_showPassword),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _pinController,
                obscureText: !_showPin,
                decoration: InputDecoration(
                  labelText: 'PIN (optional)',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.security),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _showPin ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () => setState(() => _showPin = !_showPin),
                  ),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<UserRole>(
                initialValue: _selectedRole,
                decoration: const InputDecoration(
                  labelText: 'Role',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.security_rounded),
                ),
                items: [
                  DropdownMenuItem(
                    value: UserRole.manager,
                    child: Row(
                      children: [
                        Icon(Icons.work, color: Colors.indigo),
                        const SizedBox(width: 8),
                        Text(AppLocalizations.t('manager')),
                      ],
                    ),
                  ),
                  DropdownMenuItem(
                    value: UserRole.salesPromoter,
                    child: Row(
                      children: [
                        Icon(Icons.campaign, color: Colors.orange),
                        const SizedBox(width: 8),
                        Text(AppLocalizations.t('sales_promoter')),
                      ],
                    ),
                  ),
                  DropdownMenuItem(
                    value: UserRole.inventoryClerk,
                    child: Row(
                      children: [
                        Icon(Icons.inventory, color: Colors.purple),
                        const SizedBox(width: 8),
                        Text(AppLocalizations.t('inventory_clerk')),
                      ],
                    ),
                  ),
                  DropdownMenuItem(
                    value: UserRole.deliveryReceiver,
                    child: Row(
                      children: [
                        Icon(Icons.local_shipping, color: Colors.brown),
                        const SizedBox(width: 8),
                        Text(AppLocalizations.t('delivery_receiver')),
                      ],
                    ),
                  ),
                  DropdownMenuItem(
                    value: UserRole.cashier,
                    child: Row(
                      children: [
                        Icon(Icons.shopping_cart, color: Colors.green),
                        const SizedBox(width: 8),
                        Text(AppLocalizations.t('cashier_role')),
                      ],
                    ),
                  ),
                  DropdownMenuItem(
                    value: UserRole.staff,
                    child: Row(
                      children: [
                        Icon(Icons.more_horiz, color: Colors.grey),
                        const SizedBox(width: 8),
                        Text(AppLocalizations.t('other_role')),
                      ],
                    ),
                  ),
                ],
                onChanged: (role) {
                  if (role != null) {
                    setState(() => _selectedRole = role);
                  }
                },
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
          onPressed: _isValidForm() ? _save : null,
          child: Text(
            widget.initialUser == null ? AppLocalizations.t('add') : 'Update',
          ),
        ),
      ],
    );
  }
}
