import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/customer.dart';
import '../../services/customer_service.dart';
import '../../utils/app_localizations.dart';

class LoyaltyRewardsScreen extends StatefulWidget {
  const LoyaltyRewardsScreen({super.key});

  @override
  State<LoyaltyRewardsScreen> createState() => _LoyaltyRewardsScreenState();
}

class _LoyaltyRewardsScreenState extends State<LoyaltyRewardsScreen> {
  final CustomerService _customerService = CustomerService();
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  Customer? _selectedCustomer;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _copyBarcodeValue(String barcode) async {
    await Clipboard.setData(ClipboardData(text: barcode));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.t('barcode_copied'))),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.t('loyalty_rewards')),
        actions: [
          IconButton(
            onPressed: () => setState(() {}),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: AppLocalizations.t('search_customers'),
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Customer>>(
              future: _customerService.getCustomers(query: _query),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final customers = snapshot.data ?? <Customer>[];
                if (customers.isEmpty) {
                  return Center(
                    child: Text(AppLocalizations.t('no_customers')),
                  );
                }
                return ListView.builder(
                  itemCount: customers.length,
                  itemBuilder: (context, index) {
                    final customer = customers[index];
                    final isSelected = _selectedCustomer?.id == customer.id;
                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      elevation: isSelected ? 6 : 2,
                      child: ListTile(
                        leading: CircleAvatar(
                          child: Text(
                            customer.fullName.isNotEmpty
                                ? customer.fullName[0].toUpperCase()
                                : '?',
                          ),
                        ),
                        title: Text(customer.fullName),
                        subtitle: Text(
                          '${customer.pointsBalance} ${AppLocalizations.t('points')}',
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.qr_code_2),
                          onPressed: () =>
                              setState(() => _selectedCustomer = customer),
                        ),
                        onTap: () =>
                            setState(() => _selectedCustomer = customer),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          if (_selectedCustomer != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                border: Border(top: BorderSide(color: Colors.grey.shade300)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _selectedCustomer!.fullName,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(
                        onPressed: () =>
                            _copyBarcodeValue(_selectedCustomer!.barcodeValue),
                        icon: const Icon(Icons.copy),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(AppLocalizations.t('barcode_generated_for_customer')),
                  const SizedBox(height: 16),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      color: Colors.white,
                      child: BarcodeWidget(
                        barcode: Barcode.code128(),
                        data: _selectedCustomer!.barcodeValue,
                        width: 300,
                        height: 110,
                        drawText: true,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SelectableText(_selectedCustomer!.barcodeValue),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
