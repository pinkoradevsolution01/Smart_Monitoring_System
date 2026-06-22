import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import '../../services/google_auth_service.dart';
import '../../services/developer_service.dart';
import '../shared/developer_auth_screen.dart';

class DeveloperAccountScreen extends StatefulWidget {
  const DeveloperAccountScreen({super.key});

  @override
  State<DeveloperAccountScreen> createState() => _DeveloperAccountScreenState();
}

class _DeveloperAccountScreenState extends State<DeveloperAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _showCurrentPassword = false;
  bool _showConfirmPassword = false;
  bool _isLoading = false;

  // Email from authenticated user (read-only)
  String _authenticatedEmail = '';

  @override
  void initState() {
    super.initState();
    _loadDeveloperInfo();
  }

  Future<void> _showChangePasswordDialog() async {
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    bool showCurrent = false;
    bool showNew = false;
    bool showConfirm = false;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: const Text('Change System Password'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: currentCtrl,
                obscureText: !showCurrent,
                decoration: InputDecoration(
                  labelText: 'Current Password (leave blank if none)',
                  suffixIcon: IconButton(
                    icon: Icon(
                      showCurrent ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () =>
                        setStateDialog(() => showCurrent = !showCurrent),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: newCtrl,
                obscureText: !showNew,
                decoration: InputDecoration(
                  labelText: 'New Password',
                  suffixIcon: IconButton(
                    icon: Icon(
                      showNew ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () => setStateDialog(() => showNew = !showNew),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: confirmCtrl,
                obscureText: !showConfirm,
                decoration: InputDecoration(
                  labelText: 'Confirm Password',
                  suffixIcon: IconButton(
                    icon: Icon(
                      showConfirm ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () =>
                        setStateDialog(() => showConfirm = !showConfirm),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final devService = GetIt.I.get<DeveloperService>();
                final account = devService.account;

                // If a stored password exists, require current to match
                if ((account?.authMethod ?? 'password') == 'password' &&
                    account != null &&
                    currentCtrl.text.isNotEmpty &&
                    !await devService.authenticate(account.email, currentCtrl.text)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Current password is incorrect'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                if (newCtrl.text.isEmpty || confirmCtrl.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Please enter and confirm the new password',
                      ),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                if (newCtrl.text != confirmCtrl.text) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Passwords do not match'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                await devService.updateDeveloperAccount(
                  username: account?.displayName ?? 'Developer',
                  password: newCtrl.text,
                  authMethod: 'password',
                );
                Navigator.pop(context, true);
              },
              child: const Text('Change'),
            ),
          ],
        ),
      ),
    );

    if (result == true && mounted) {
      // Refresh the in-page Create Password field to show the new system password
      final devService = GetIt.I.get<DeveloperService>();
      final updated = devService.account?.authMethod == 'password'
          ? 'Updated on server'
          : 'Google account';
      setState(() {
        _currentPasswordController.text = updated;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ System developer password updated'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _currentPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadDeveloperInfo() async {
    final devService = GetIt.I.get<DeveloperService>();
    await devService.refreshDeveloperAccount();

    // Try to get email from backend-authenticated Google user first
    final user = GoogleAuthService().currentUser;
    final String emailToDisplay;

    if (user != null && user['email'] != null) {
      emailToDisplay = user['email'].toString();
    } else {
      emailToDisplay = devService.account?.email ?? 'dev@smartmonitoring.com';
    }

    setState(() {
      _nameController.text = devService.account?.displayName ?? 'Developer';
      _authenticatedEmail = emailToDisplay;
      _currentPasswordController.clear();
    });
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final devService = GetIt.I.get<DeveloperService>();
      final currentAccount = devService.account;

      if (_currentPasswordController.text.isNotEmpty &&
          _currentPasswordController.text != _confirmPasswordController.text) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Passwords do not match'),
              backgroundColor: Colors.red,
            ),
          );
        }
        setState(() => _isLoading = false);
        return;
      }

      await devService.updateDeveloperAccount(
        username: _nameController.text,
        email: _authenticatedEmail,
        password: _currentPasswordController.text.isNotEmpty
            ? _currentPasswordController.text
            : null,
        authMethod: _currentPasswordController.text.isNotEmpty
            ? 'password'
            : (currentAccount?.authMethod ?? 'password'),
        googleSub: currentAccount?.googleSub,
        avatarUrl: currentAccount?.avatarUrl,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Account information updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving changes: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _resetToDefaults() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 8),
            Text('Reset to Defaults'),
          ],
        ),
        content: const Text(
          'This will reset your developer account to default credentials.\n\n'
          'Default email: dev@smartmonitoring.com\n'
          'Default password: developer123\n\n'
          'Are you sure?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final devService = GetIt.I.get<DeveloperService>();
    await devService.updateDeveloperAccount(
      username: 'Developer',
      email: 'dev@smartmonitoring.com',
      password: 'developer123',
      authMethod: 'password',
    );

    _loadDeveloperInfo();
    _currentPasswordController.clear();
    _confirmPasswordController.clear();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Account reset to defaults'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.red),
            SizedBox(width: 8),
            Text('Delete Developer Account'),
          ],
        ),
        content: const Text(
          'This will permanently delete your developer account credentials.\n\n'
          'You will need to set up a new developer account to access the dashboard again.\n\n'
          'Are you sure?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete Account'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final devService = GetIt.I.get<DeveloperService>();
      await devService.updateDeveloperAccount(
        username: 'Developer',
        email: 'dev@smartmonitoring.com',
        password: 'developer123',
        authMethod: 'password',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Developer account deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );

        // Navigate back to registration screen
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const DeveloperAuthScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting account: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('👤 Manage Developer Account'),
        backgroundColor: Colors.grey[900],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.grey[900]!, Colors.grey[800]!],
          ),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                // Header Card
                Card(
                  color: Colors.grey[850],
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.indigo,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.indigo.withValues(alpha: 0.3),
                                blurRadius: 20,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.code,
                            size: 48,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Developer Account',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Manage your developer credentials and information',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[400],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Account Information Form
                Card(
                  color: Colors.grey[850],
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Basic Information',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Name Field
                          TextFormField(
                            controller: _nameController,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              labelText: 'Name',
                              labelStyle: TextStyle(color: Colors.grey[400]),
                              prefixIcon: const Icon(
                                Icons.person,
                                color: Colors.grey,
                              ),
                              border: const OutlineInputBorder(),
                              enabledBorder: OutlineInputBorder(
                                borderSide: BorderSide(
                                  color: Colors.grey[700]!,
                                ),
                              ),
                              focusedBorder: const OutlineInputBorder(
                                borderSide: BorderSide(color: Colors.indigo),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter a name';
                              }
                              return null;
                            },
                          ),

                          const SizedBox(height: 16),

                          // Email Field (Read-only - from authenticated account)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 16,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey[700]!),
                              borderRadius: BorderRadius.circular(4),
                              color: Colors.grey[800],
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.email, color: Colors.grey),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Email (Developer Account)',
                                        style: TextStyle(
                                          color: Colors.grey[400],
                                          fontSize: 12,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _authenticatedEmail,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  Icons.verified_user,
                                  color: Colors.green[400],
                                  size: 20,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Change Password Section
                Card(
                  color: Colors.grey[850],
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Create / Change Password',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Leave blank to keep current password',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[500],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Create Password (or enter current when changing)
                        TextFormField(
                          controller: _currentPasswordController,
                          style: const TextStyle(color: Colors.white),
                          obscureText: !_showCurrentPassword,
                          decoration: InputDecoration(
                            labelText: 'Create Password',
                            labelStyle: TextStyle(color: Colors.grey[400]),
                            prefixIcon: const Icon(
                              Icons.lock,
                              color: Colors.grey,
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _showCurrentPassword
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                                color: Colors.grey,
                              ),
                              onPressed: () {
                                setState(() {
                                  _showCurrentPassword = !_showCurrentPassword;
                                });
                              },
                            ),
                            border: const OutlineInputBorder(),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.grey[700]!),
                            ),
                            focusedBorder: const OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.indigo),
                            ),
                          ),
                          validator: (value) {
                            // If user entered a new password, require this field when a stored password exists
                            return null;
                          },
                        ),

                        const SizedBox(height: 16),

                        const SizedBox(height: 16),

                        // Confirm Password
                        TextFormField(
                          controller: _confirmPasswordController,
                          style: const TextStyle(color: Colors.white),
                          obscureText: !_showConfirmPassword,
                          decoration: InputDecoration(
                            labelText: 'Confirm Password',
                            labelStyle: TextStyle(color: Colors.grey[400]),
                            prefixIcon: const Icon(
                              Icons.lock_outline,
                              color: Colors.grey,
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _showConfirmPassword
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                                color: Colors.grey,
                              ),
                              onPressed: () {
                                setState(() {
                                  _showConfirmPassword = !_showConfirmPassword;
                                });
                              },
                            ),
                            border: const OutlineInputBorder(),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.grey[700]!),
                            ),
                            focusedBorder: const OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.indigo),
                            ),
                          ),
                          validator: (value) {
                            // If creating a password (no stored password), confirm must match Create Password
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isLoading ? null : _resetToDefaults,
                        icon: const Icon(Icons.restore),
                        label: const Text('Reset to Defaults'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.orange,
                          side: const BorderSide(color: Colors.orange),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _saveChanges,
                        icon: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : const Icon(Icons.save),
                        label: const Text('Save Changes'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigo,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Change System Password (applies across app and icon flows)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _showChangePasswordDialog,
                    icon: const Icon(Icons.key),
                    label: const Text('Change System Password'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Info Card
                Card(
                  color: Colors.indigo.withValues(alpha: 0.2),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, color: Colors.lightBlue),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Your developer password is required to access the developer dashboard from login or package screens.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[300],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Delete Account Button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _isLoading ? null : _deleteAccount,
                    icon: const Icon(Icons.delete_forever),
                    label: const Text('Delete Developer Account'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
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
