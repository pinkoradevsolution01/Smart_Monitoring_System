import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/code_request_service.dart';

/// Shows the same activation-code request form used during package setup.
/// Returns true when the request was submitted successfully.
Future<bool> showActivationCodeRequestDialog({
  required BuildContext context,
  required String packageName,
  required String packagePrice,
  required String requestType,
}) async {
  final data = await showDialog<_ActivationRequestData>(
    context: context,
    builder: (_) => _ActivationRequestDialog(
      packageName: packageName,
      packagePrice: packagePrice,
    ),
  );

  if (data == null || !context.mounted) return false;

  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const PopScope(
      canPop: false,
      child: Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 24),
                Text('Sending request to developer...'),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  final success = await CodeRequestService().requestActivationCode(
    packageName: packageName,
    packagePrice: packagePrice,
    requestType: requestType,
    businessName: data.businessName,
    contactEmail: data.contactEmail,
    contactPhone: data.contactPhone,
    additionalNotes: data.additionalNotes,
  );

  if (!context.mounted) return success;
  Navigator.of(context).pop();
  await showDialog<void>(
    context: context,
    builder: (_) => AlertDialog(
      title: Row(
        children: [
          Icon(
            success ? Icons.check_circle : Icons.error,
            color: success ? Colors.green : Colors.red,
          ),
          const SizedBox(width: 12),
          Text(success ? 'Request Sent!' : 'Request Failed'),
        ],
      ),
      content: Text(
        success
            ? 'Your activation code request has been sent to the developer.\n\n'
                'You will receive the activation code via email at:\n${data.contactEmail}'
            : 'Failed to send request. Please check your internet connection and try again.',
      ),
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('OK'),
        ),
      ],
    ),
  );
  return success;
}

class _ActivationRequestData {
  final String businessName;
  final String contactEmail;
  final String contactPhone;
  final String additionalNotes;

  const _ActivationRequestData({
    required this.businessName,
    required this.contactEmail,
    required this.contactPhone,
    required this.additionalNotes,
  });
}

class _ActivationRequestDialog extends StatefulWidget {
  final String packageName;
  final String packagePrice;

  const _ActivationRequestDialog({
    required this.packageName,
    required this.packagePrice,
  });

  @override
  State<_ActivationRequestDialog> createState() =>
      _ActivationRequestDialogState();
}

class _ActivationRequestDialogState extends State<_ActivationRequestDialog> {
  final _businessName = TextEditingController();
  final _contactEmail = TextEditingController();
  final _contactPhone = TextEditingController();
  final _notes = TextEditingController();

  @override
  void dispose() {
    _businessName.dispose();
    _contactEmail.dispose();
    _contactPhone.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _submit() {
    if (_businessName.text.trim().isEmpty ||
        _contactEmail.text.trim().isEmpty ||
        _contactPhone.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Business name, contact email, and contact phone are required',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    Navigator.of(context).pop(
      _ActivationRequestData(
        businessName: _businessName.text.trim(),
        contactEmail: _contactEmail.text.trim(),
        contactPhone: _contactPhone.text.trim(),
        additionalNotes: _notes.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Request Activation Code'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Complete this form to request a new activation code from the developer.',
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Package: ${widget.packageName}\nPrice: ${widget.packagePrice}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _businessName,
              decoration: const InputDecoration(
                labelText: 'Business Name *',
                prefixIcon: Icon(Icons.store),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _contactEmail,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Contact Email *',
                prefixIcon: Icon(Icons.email),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _contactPhone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Contact Phone *',
                prefixIcon: Icon(Icons.phone),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notes,
              maxLines: 3,
              inputFormatters: [LengthLimitingTextInputFormatter(500)],
              decoration: const InputDecoration(
                labelText: 'Additional Notes (optional)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.send),
          label: const Text('Submit Request'),
        ),
      ],
    );
  }
}
