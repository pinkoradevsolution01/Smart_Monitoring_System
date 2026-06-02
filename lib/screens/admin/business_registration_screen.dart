import 'package:flutter/material.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import '../../services/business_info_service.dart';
import '../../models/business_info.dart';
import '../../utils/app_localizations.dart';

class BusinessRegistrationScreen extends StatefulWidget {
  const BusinessRegistrationScreen({super.key});

  @override
  State<BusinessRegistrationScreen> createState() =>
      _BusinessRegistrationScreenState();
}

class _BusinessRegistrationScreenState
    extends State<BusinessRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _storeNameController = TextEditingController();
  final _businessTypeController = TextEditingController();
  final _storeAddressController = TextEditingController();
  final _businessInfoService = BusinessInfoService();

  String? _logoPath;
  bool _isLoading = false;

  final List<String> _businessTypes = [
    'Retail Store',
    'Grocery',
    'Convenience Store',
    'Pharmacy',
    'Restaurant',
    'Cafe',
    'Boutique',
    'Electronics Shop',
    'Hardware Store',
    'Department Store',
    'Shoe Store',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _loadExistingInfo();
  }

  void _loadExistingInfo() {
    final info = _businessInfoService.businessInfo;
    if (info != null) {
      _storeNameController.text = info.storeName;
      _businessTypeController.text = info.businessType;
      _storeAddressController.text = info.storeAddress ?? '';
      _logoPath = info.logoPath;
    }
  }

  @override
  void dispose() {
    _storeNameController.dispose();
    _businessTypeController.dispose();
    _storeAddressController.dispose();
    super.dispose();
  }

  Future<void> _pickLogo() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          _logoPath = result.files.single.path;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error picking logo: $e')));
      }
    }
  }

  Future<void> _saveBusinessInfo() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final info = BusinessInfo(
      storeName: _storeNameController.text.trim(),
      businessType: _businessTypeController.text.trim(),
      storeAddress: _storeAddressController.text.trim().isEmpty
          ? null
          : _storeAddressController.text.trim(),
      logoPath: _logoPath,
    );

    final success = await _businessInfoService.saveBusinessInfo(info);

    setState(() {
      _isLoading = false;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? AppLocalizations.t('business_info_saved')
                : AppLocalizations.t('business_info_save_failed'),
          ),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );

      if (success) {
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.t('business_registration')),
        actions: [
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header Section
                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          Icon(
                            Icons.store,
                            size: 64,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            AppLocalizations.t('business_registration_title'),
                            style: Theme.of(context).textTheme.headlineSmall,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            AppLocalizations.t(
                              'business_registration_subtitle',
                            ),
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: Colors.grey[600]),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Store Logo Section
                  Text(
                    AppLocalizations.t('store_logo'),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    elevation: 2,
                    child: InkWell(
                      onTap: _pickLogo,
                      child: Container(
                        height: 200,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Colors.grey[300]!,
                            width: 2,
                            style: BorderStyle.solid,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: _logoPath != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.file(
                                  File(_logoPath!),
                                  fit: BoxFit.contain,
                                ),
                              )
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.add_photo_alternate,
                                    size: 64,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    AppLocalizations.t('tap_to_upload_logo'),
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    AppLocalizations.t('optional'),
                                    style: TextStyle(
                                      color: Colors.grey[500],
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Store Name
                  Text(
                    AppLocalizations.t('store_name_label'),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _storeNameController,
                    decoration: InputDecoration(
                      hintText: AppLocalizations.t('store_name_hint'),
                      prefixIcon: const Icon(Icons.storefront),
                      border: const OutlineInputBorder(),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return AppLocalizations.t('store_name_required');
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  // Business Type
                  Text(
                    AppLocalizations.t('business_type_label'),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue:
                        _businessTypes.contains(_businessTypeController.text)
                        ? _businessTypeController.text
                        : null,
                    decoration: InputDecoration(
                      hintText: AppLocalizations.t('select_business_type'),
                      prefixIcon: const Icon(Icons.business),
                      border: const OutlineInputBorder(),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                    items: _businessTypes.map((type) {
                      return DropdownMenuItem(value: type, child: Text(type));
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        _businessTypeController.text = value;
                      }
                    },
                    validator: (value) {
                      if (_businessTypeController.text.trim().isEmpty) {
                        return AppLocalizations.t('business_type_required');
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  // Store Address (Optional)
                  Row(
                    children: [
                      Text(
                        AppLocalizations.t('store_address_label'),
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          AppLocalizations.t('optional'),
                          style: const TextStyle(fontSize: 10),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _storeAddressController,
                    decoration: InputDecoration(
                      hintText: AppLocalizations.t('store_address_hint'),
                      prefixIcon: const Icon(Icons.location_on),
                      border: const OutlineInputBorder(),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 32),

                  // Save Button
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _saveBusinessInfo,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : const Icon(Icons.save),
                    label: Text(
                      _isLoading
                          ? AppLocalizations.t('saving')
                          : AppLocalizations.t('save_business_info'),
                      style: const TextStyle(fontSize: 16),
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ],
              ), // Column
            ), // Form
          ), // SingleChildScrollView
        ), // ConstrainedBox
      ), // Center
    ); // Scaffold
  }
}
