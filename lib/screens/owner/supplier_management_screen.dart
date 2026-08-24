// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import '../../models/supplier.dart';
import '../../models/restock_record.dart';
import '../../models/purchase_order.dart';
import '../../models/product.dart';
import '../../models/damage_report.dart';
import '../../services/database_service.dart';
import '../../services/purchase_order_pdf_service.dart';
import '../../services/damage_return_pdf_service.dart';
import '../../utils/app_localizations.dart';
import '../../widgets/signature_pad.dart';

class SupplierManagementScreen extends StatefulWidget {
  final int? initialTab;
  final bool? autoCreateOrder;
  final Product? preselectedProduct;

  const SupplierManagementScreen({
    super.key,
    this.initialTab,
    this.autoCreateOrder,
    this.preselectedProduct,
  });

  @override
  State<SupplierManagementScreen> createState() =>
      _SupplierManagementScreenState();
}

class _SupplierManagementScreenState extends State<SupplierManagementScreen>
    with SingleTickerProviderStateMixin {
  final DatabaseService db = DatabaseService();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _restockSearchController =
      TextEditingController();
  final TextEditingController _orderSearchController = TextEditingController();
  final TextEditingController _damageSearchController = TextEditingController();
  late TabController _tabController;
  List<Supplier> _suppliers = [];
  List<RestockRecord> _restockRecords = [];
  List<PurchaseOrder> _purchaseOrders = [];
  List<DamageReport> _damageReports = [];
  String _query = '';
  String _restockQuery = '';
  String _orderQuery = '';
  String _damageQuery = '';
  String _orderStatusFilter = 'all';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 4,
      vsync: this,
      initialIndex: widget.initialTab ?? 0,
    );
    _tabController.addListener(() {
      setState(() {}); // Rebuild to update FAB
    });
    _loadData().then((_) {
      // Auto-open create order dialog if requested
      if (widget.autoCreateOrder == true && widget.preselectedProduct != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _showCreateOrderDialog(
              preselectedProduct: widget.preselectedProduct,
            );
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _restockSearchController.dispose();
    _orderSearchController.dispose();
    _damageSearchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final suppliers = await db.getAllSuppliers();
      final records = await db.getAllRestockRecords();
      final orders = await db.getAllPurchaseOrders();

      // Sync damage reports from restock records (for old data)
      await _syncDamageReportsFromRestockRecords(records);

      final damageReports = await db.getAllDamageReports();
      if (mounted) {
        setState(() {
          _suppliers = suppliers;
          _restockRecords = records;
          _purchaseOrders = orders;
          _damageReports = damageReports;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppLocalizations.t('error')}: $e')),
        );
      }
    }
  }

  /// Sync damage reports from restock records (for historical data before damage report feature)
  Future<void> _syncDamageReportsFromRestockRecords(
    List<RestockRecord> records,
  ) async {
    try {
      // Get all existing damage reports
      final existingReports = await db.getAllDamageReports();
      final existingReportKeys = <String>{};

      // Create a key set of existing reports (productId + date combination)
      for (var report in existingReports) {
        final key =
            '${report.productId}_${report.reportDate.toIso8601String().split('T')[0]}';
        existingReportKeys.add(key);
      }

      // Find restock records with damage that don't have damage reports
      for (var record in records) {
        if (record.damageQuantity > 0) {
          final dateKey =
              '${record.productId}_${record.restockDate.toIso8601String().split('T')[0]}';

          // Check if a damage report already exists for this record
          if (!existingReportKeys.contains(dateKey)) {
            // Get product to get the buying price
            final product = await db.getProductById(record.productId);
            final unitPrice = product?.buyingPrice ?? 0.0;

            // Create damage report from restock record
            final damageReport = DamageReport(
              productId: record.productId,
              productName: record.productName,
              quantity: record.damageQuantity,
              unitPrice: unitPrice,
              totalValue: unitPrice * record.damageQuantity,
              reason: record.damageReason.isNotEmpty
                  ? '${record.referencedBy} - ${record.damageReason}'
                  : record.referencedBy,
              reportedBy: 'Owner',
              reportDate: record.restockDate,
            );

            await db.insertDamageReport(damageReport);
          }
        }
      }
    } catch (e) {
      // Silent fail - don't interrupt the loading process
      debugPrint('Error syncing damage reports: $e');
    }
  }

  List<Supplier> _getFilteredSuppliers() {
    if (_query.isEmpty) return _suppliers;
    return _suppliers
        .where(
          (s) =>
              s.name.toLowerCase().contains(_query.toLowerCase()) ||
              s.contactPerson.toLowerCase().contains(_query.toLowerCase()) ||
              s.phone.contains(_query),
        )
        .toList();
  }

  List<RestockRecord> _getFilteredRestockRecords() {
    if (_restockQuery.isEmpty) return _restockRecords;
    return _restockRecords
        .where(
          (r) =>
              r.deliveryReceiptNo.toLowerCase().contains(
                _restockQuery.toLowerCase(),
              ) ||
              r.productName.toLowerCase().contains(
                _restockQuery.toLowerCase(),
              ) ||
              (r.supplierName?.toLowerCase().contains(
                    _restockQuery.toLowerCase(),
                  ) ??
                  false),
        )
        .toList();
  }

  List<PurchaseOrder> _getFilteredPurchaseOrders() {
    var filtered = _purchaseOrders;

    // Apply status filter
    if (_orderStatusFilter != 'all') {
      filtered = filtered.where((o) => o.status == _orderStatusFilter).toList();
    }

    // Apply search filter
    if (_orderQuery.isNotEmpty) {
      filtered = filtered
          .where(
            (o) =>
                o.orderNumber.toLowerCase().contains(
                  _orderQuery.toLowerCase(),
                ) ||
                o.supplierName.toLowerCase().contains(
                  _orderQuery.toLowerCase(),
                ),
          )
          .toList();
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        title: Text(
          AppLocalizations.t('supplier_management'),
          style: const TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: [
            Tab(
              icon: const Icon(Icons.business),
              text: AppLocalizations.t('suppliers'),
            ),
            Tab(
              icon: const Icon(Icons.history),
              text: AppLocalizations.t('restock_history'),
            ),
            Tab(
              icon: const Icon(Icons.shopping_cart),
              text: AppLocalizations.t('purchase_orders'),
            ),
            Tab(
              icon: const Icon(Icons.warning),
              text: AppLocalizations.t('damage_reports'),
            ),
          ],
        ),
      ),
      floatingActionButton: _buildFloatingActionButton(),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildSuppliersTab(),
          _buildRestockHistoryTab(),
          _buildPurchaseOrdersTab(),
          _buildDamageReportsTab(),
        ],
      ),
    );
  }

  Widget _buildSuppliersTab() {
    final filtered = _getFilteredSuppliers();

    return LayoutBuilder(
      builder: (context, constraints) {
        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 1000,
              maxHeight: constraints.maxHeight,
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      labelText: AppLocalizations.t('search'),
                      prefixIcon: const Icon(Icons.search),
                      border: const OutlineInputBorder(),
                      suffixIcon: _query.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _query = '');
                              },
                            )
                          : null,
                    ),
                    onChanged: (value) => setState(() => _query = value),
                  ),
                ),
                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : filtered.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.business_outlined,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _query.isEmpty
                                    ? AppLocalizations.t('no_suppliers')
                                    : AppLocalizations.t('no_results_found'),
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: filtered.length,
                          padding: const EdgeInsets.all(8),
                          itemBuilder: (context, index) {
                            final supplier = filtered[index];
                            return Card(
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: supplier.isActive
                                      ? Colors.green
                                      : Colors.grey,
                                  child: Text(
                                    supplier.name[0].toUpperCase(),
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ),
                                title: Text(
                                  supplier.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${AppLocalizations.t('contact')}: ${supplier.contactPerson}',
                                    ),
                                    Text(
                                      '${AppLocalizations.t('phone')}: ${supplier.phone}',
                                    ),
                                    if (supplier.email.isNotEmpty)
                                      Text(
                                        '${AppLocalizations.t('email')}: ${supplier.email}',
                                      ),
                                  ],
                                ),
                                trailing: PopupMenuButton(
                                  itemBuilder: (context) => [
                                    PopupMenuItem(
                                      child: Row(
                                        children: [
                                          const Icon(Icons.edit),
                                          const SizedBox(width: 8),
                                          Text(AppLocalizations.t('edit')),
                                        ],
                                      ),
                                      onTap: () => Future.delayed(
                                        Duration.zero,
                                        () => _showEditSupplierDialog(supplier),
                                      ),
                                    ),
                                    PopupMenuItem(
                                      child: Row(
                                        children: [
                                          const Icon(Icons.info),
                                          const SizedBox(width: 8),
                                          Text(
                                            AppLocalizations.t('view_details'),
                                          ),
                                        ],
                                      ),
                                      onTap: () => Future.delayed(
                                        Duration.zero,
                                        () => _showSupplierDetails(supplier),
                                      ),
                                    ),
                                    PopupMenuItem(
                                      child: Row(
                                        children: [
                                          Icon(
                                            supplier.isActive
                                                ? Icons.block
                                                : Icons.check_circle,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            supplier.isActive
                                                ? AppLocalizations.t(
                                                    'deactivate',
                                                  )
                                                : AppLocalizations.t(
                                                    'activate',
                                                  ),
                                          ),
                                        ],
                                      ),
                                      onTap: () =>
                                          _toggleSupplierStatus(supplier),
                                    ),
                                    PopupMenuItem(
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.delete,
                                            color: Colors.red,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            AppLocalizations.t('delete'),
                                            style: const TextStyle(
                                              color: Colors.red,
                                            ),
                                          ),
                                        ],
                                      ),
                                      onTap: () =>
                                          _confirmDeleteSupplier(supplier),
                                    ),
                                  ],
                                ),
                                isThreeLine: true,
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRestockHistoryTab() {
    final filtered = _getFilteredRestockRecords();

    return LayoutBuilder(
      builder: (context, constraints) {
        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 1000,
              maxHeight: constraints.maxHeight,
            ),
            child: Column(
              children: [
                // Search bar
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: TextField(
                    controller: _restockSearchController,
                    decoration: InputDecoration(
                      hintText:
                          '${AppLocalizations.t('search')} ${AppLocalizations.t('receipt_no')}, ${AppLocalizations.t('product')}, ${AppLocalizations.t('supplier')}',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _restockQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _restockSearchController.clear();
                                setState(() => _restockQuery = '');
                              },
                            )
                          : null,
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (v) => setState(() => _restockQuery = v),
                  ),
                ),
                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : filtered.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.history,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _restockQuery.isEmpty
                                    ? AppLocalizations.t('no_restock_records')
                                    : AppLocalizations.t('no_results_found'),
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: filtered.length,
                          padding: const EdgeInsets.all(8),
                          itemBuilder: (context, index) {
                            final record = filtered[index];
                            return Card(
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Theme.of(
                                    context,
                                  ).colorScheme.primary,
                                  child: const Icon(
                                    Icons.add_shopping_cart,
                                    color: Colors.white,
                                  ),
                                ),
                                title: Text(
                                  record.productName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${AppLocalizations.t('quantity')}: ${record.quantity}',
                                    ),
                                    if (record.supplierName != null)
                                      Text(
                                        '${AppLocalizations.t('supplier')}: ${record.supplierName}',
                                      ),
                                    if (record.deliveryReceiptNo.isNotEmpty)
                                      Text(
                                        '${AppLocalizations.t('receipt_no')}: ${record.deliveryReceiptNo}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    if (record.damageQuantity > 0)
                                      Text(
                                        '${AppLocalizations.t('damaged')}: ${record.damageQuantity}',
                                        style: const TextStyle(
                                          color: Colors.red,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    Text(
                                      '${AppLocalizations.t('by')}: ${record.referencedBy}',
                                    ),
                                    Text(
                                      _formatDate(record.restockDate),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                                trailing:
                                    record.notes.isNotEmpty ||
                                        record.damageReason.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.info_outline),
                                        onPressed: () =>
                                            _showRestockDetails(record),
                                      )
                                    : null,
                                isThreeLine: true,
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showAddSupplierDialog() {
    final nameController = TextEditingController();
    final contactController = TextEditingController();
    final phoneController = TextEditingController();
    final emailController = TextEditingController();
    final addressController = TextEditingController();
    final notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.t('add_supplier')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: '${AppLocalizations.t('supplier_name')} *',
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: contactController,
                decoration: InputDecoration(
                  labelText: '${AppLocalizations.t('contact_person')} *',
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneController,
                decoration: InputDecoration(
                  labelText: '${AppLocalizations.t('phone')} *',
                  border: const OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emailController,
                decoration: InputDecoration(
                  labelText: AppLocalizations.t('email'),
                  border: const OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: addressController,
                decoration: InputDecoration(
                  labelText: AppLocalizations.t('address'),
                  border: const OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesController,
                decoration: InputDecoration(
                  labelText: AppLocalizations.t('notes'),
                  border: const OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppLocalizations.t('cancel')),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isEmpty ||
                  contactController.text.isEmpty ||
                  phoneController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      AppLocalizations.t('please_fill_required_fields'),
                    ),
                  ),
                );
                return;
              }

              final supplier = Supplier(
                name: nameController.text,
                contactPerson: contactController.text,
                phone: phoneController.text,
                email: emailController.text,
                address: addressController.text,
                notes: notesController.text,
              );

              await db.insertSupplier(supplier);
              await _loadData();

              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(AppLocalizations.t('supplier_added'))),
              );
            },
            child: Text(AppLocalizations.t('add')),
          ),
        ],
      ),
    );
  }

  void _showEditSupplierDialog(Supplier supplier) {
    final nameController = TextEditingController(text: supplier.name);
    final contactController = TextEditingController(
      text: supplier.contactPerson,
    );
    final phoneController = TextEditingController(text: supplier.phone);
    final emailController = TextEditingController(text: supplier.email);
    final addressController = TextEditingController(text: supplier.address);
    final notesController = TextEditingController(text: supplier.notes);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.t('edit_supplier')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: '${AppLocalizations.t('supplier_name')} *',
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: contactController,
                decoration: InputDecoration(
                  labelText: '${AppLocalizations.t('contact_person')} *',
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneController,
                decoration: InputDecoration(
                  labelText: '${AppLocalizations.t('phone')} *',
                  border: const OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emailController,
                decoration: InputDecoration(
                  labelText: AppLocalizations.t('email'),
                  border: const OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: addressController,
                decoration: InputDecoration(
                  labelText: AppLocalizations.t('address'),
                  border: const OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesController,
                decoration: InputDecoration(
                  labelText: AppLocalizations.t('notes'),
                  border: const OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppLocalizations.t('cancel')),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isEmpty ||
                  contactController.text.isEmpty ||
                  phoneController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      AppLocalizations.t('please_fill_required_fields'),
                    ),
                  ),
                );
                return;
              }

              final updated = supplier.copyWith(
                name: nameController.text,
                contactPerson: contactController.text,
                phone: phoneController.text,
                email: emailController.text,
                address: addressController.text,
                notes: notesController.text,
              );

              await db.updateSupplier(updated);
              await _loadData();

              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(AppLocalizations.t('supplier_updated'))),
              );
            },
            child: Text(AppLocalizations.t('save')),
          ),
        ],
      ),
    );
  }

  void _showSupplierDetails(Supplier supplier) async {
    final records = await db.getRestockRecordsBySupplierId(supplier.id!);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(supplier.name),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _detailRow(
                AppLocalizations.t('contact_person'),
                supplier.contactPerson,
              ),
              _detailRow(AppLocalizations.t('phone'), supplier.phone),
              if (supplier.email.isNotEmpty)
                _detailRow(AppLocalizations.t('email'), supplier.email),
              if (supplier.address.isNotEmpty)
                _detailRow(AppLocalizations.t('address'), supplier.address),
              if (supplier.notes.isNotEmpty)
                _detailRow(AppLocalizations.t('notes'), supplier.notes),
              _detailRow(
                AppLocalizations.t('status'),
                supplier.isActive
                    ? AppLocalizations.t('active')
                    : AppLocalizations.t('inactive'),
              ),
              _detailRow(
                AppLocalizations.t('created_at'),
                _formatDate(supplier.createdAt),
              ),
              const Divider(height: 24),
              Text(
                AppLocalizations.t('restock_history'),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              if (records.isEmpty)
                Text(
                  AppLocalizations.t('no_restock_records'),
                  style: const TextStyle(color: Colors.grey),
                )
              else
                ...records.map(
                  (r) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      '• ${r.productName} (${r.quantity}) - ${_formatDate(r.restockDate)}',
                    ),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppLocalizations.t('close')),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Future<void> _toggleSupplierStatus(Supplier supplier) async {
    final updated = supplier.copyWith(isActive: !supplier.isActive);
    await db.updateSupplier(updated);
    await _loadData();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          updated.isActive
              ? AppLocalizations.t('supplier_activated')
              : AppLocalizations.t('supplier_deactivated'),
        ),
      ),
    );
  }

  void _confirmDeleteSupplier(Supplier supplier) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.t('confirm_delete')),
        content: Text(
          AppLocalizations.t(
            'delete_supplier_confirm',
          ).replaceAll('{name}', supplier.name),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppLocalizations.t('cancel')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              await db.deleteSupplier(supplier.id!);
              await _loadData();
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(AppLocalizations.t('supplier_deleted'))),
              );
            },
            child: Text(AppLocalizations.t('delete')),
          ),
        ],
      ),
    );
  }

  void _showRestockDetails(RestockRecord record) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.t('restock_details')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (record.deliveryReceiptNo.isNotEmpty) ...[
                Text(
                  AppLocalizations.t('receipt_no'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(record.deliveryReceiptNo),
                const SizedBox(height: 8),
              ],
              if (record.notes.isNotEmpty) ...[
                Text(
                  AppLocalizations.t('notes'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(record.notes),
                const SizedBox(height: 8),
              ],
              if (record.damageQuantity > 0) ...[
                const Divider(),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.warning, color: Colors.red, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      AppLocalizations.t('damage_info'),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${AppLocalizations.t('quantity_damaged')}: ${record.damageQuantity}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                if (record.damageReason.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    '${AppLocalizations.t('reason')}: ${record.damageReason}',
                  ),
                ],
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppLocalizations.t('close')),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  Widget? _buildFloatingActionButton() {
    switch (_tabController.index) {
      case 0: // Suppliers tab
        return FloatingActionButton.extended(
          onPressed: _showAddSupplierDialog,
          icon: const Icon(Icons.add),
          label: Text(AppLocalizations.t('add_supplier')),
        );
      case 2: // Purchase Orders tab
        return FloatingActionButton.extended(
          onPressed: _showCreateOrderDialog,
          icon: const Icon(Icons.shopping_cart),
          label: Text(AppLocalizations.t('create_order')),
        );
      case 1: // Restock History tab
      case 3: // Damage Reports tab
      default:
        return null; // No FAB on restock history and damage reports
    }
  }

  // ======================== DAMAGE REPORTS TAB ========================

  List<DamageReport> _getFilteredDamageReports() {
    if (_damageQuery.isEmpty) return _damageReports;
    return _damageReports
        .where(
          (r) =>
              r.productName.toLowerCase().contains(
                _damageQuery.toLowerCase(),
              ) ||
              r.reason.toLowerCase().contains(_damageQuery.toLowerCase()) ||
              r.reportedBy.toLowerCase().contains(_damageQuery.toLowerCase()),
        )
        .toList();
  }

  Widget _buildDamageReportsTab() {
    final filtered = _getFilteredDamageReports();

    return LayoutBuilder(
      builder: (context, constraints) {
        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 1000,
              maxHeight: constraints.maxHeight,
            ),
            child: Column(
              children: [
                // Search bar
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: TextField(
                    controller: _damageSearchController,
                    decoration: InputDecoration(
                      labelText: AppLocalizations.t('search'),
                      hintText:
                          '${AppLocalizations.t('product')}, ${AppLocalizations.t('reason')}...',
                      prefixIcon: const Icon(Icons.search),
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (v) => setState(() => _damageQuery = v),
                  ),
                ),
                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : filtered.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.warning_amber,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                AppLocalizations.t('no_damage_reports'),
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: filtered.length,
                          padding: const EdgeInsets.all(8),
                          itemBuilder: (context, index) {
                            final report = filtered[index];
                            return _buildDamageReportCard(report);
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDamageReportCard(DamageReport report) {
    final bool isReturned = report.returnStatus == 'returned';
    final bool isPaid = report.paymentStatus == 'paid';
    final bool isStoreDamage = !isReturned && !isPaid;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isPaid
              ? Colors.blue.withValues(alpha: 0.2)
              : isReturned
              ? Colors.green.withValues(alpha: 0.2)
              : Colors.orange.withValues(alpha: 0.2),
          child: Icon(
            isPaid
                ? Icons.payment
                : isReturned
                ? Icons.check_circle
                : Icons.warning,
            color: isPaid
                ? Colors.blue
                : isReturned
                ? Colors.green
                : Colors.orange,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                report.productName,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            if (isPaid)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  AppLocalizations.t('store_damage_paid'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            else if (isReturned)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  AppLocalizations.t('returned'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${AppLocalizations.t('quantity_damaged')}: ${report.quantity}',
            ),
            Text(
              '${AppLocalizations.t('total_value')}: ₱${report.totalValue.toStringAsFixed(2)}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
            Text(
              '${AppLocalizations.t('reported_by')}: ${report.reportedBy}',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            Text(
              _formatDate(report.reportDate),
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            if (isReturned && report.returnDate != null)
              Text(
                '${AppLocalizations.t('return_date')}: ${_formatDate(report.returnDate!)}',
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
            if (isPaid && report.paymentDate != null)
              Text(
                '${AppLocalizations.t('payment_date')}: ${_formatDate(report.paymentDate!)}',
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.blue,
                  fontWeight: FontWeight.bold,
                ),
              ),
            if (isPaid &&
                report.responsiblePerson != null &&
                report.responsiblePerson!.isNotEmpty)
              Text(
                '${AppLocalizations.t('responsible_person')}: ${report.responsiblePerson}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
        trailing: PopupMenuButton(
          itemBuilder: (context) => [
            PopupMenuItem(
              child: Row(
                children: [
                  const Icon(Icons.info_outline),
                  const SizedBox(width: 8),
                  Text(AppLocalizations.t('view_details')),
                ],
              ),
              onTap: () => Future.delayed(
                Duration.zero,
                () => _showDamageReportDetails(report),
              ),
            ),
            if (isStoreDamage)
              PopupMenuItem(
                child: Row(
                  children: [
                    const Icon(Icons.assignment_return, color: Colors.orange),
                    const SizedBox(width: 8),
                    Text(AppLocalizations.t('return_to_supplier')),
                  ],
                ),
                onTap: () {
                  // Use WidgetsBinding to ensure we're outside the popup menu context
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      _showReturnApprovalDialog(report);
                    }
                  });
                },
              ),
            if (isPaid)
              PopupMenuItem(
                enabled: false,
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.grey[400]),
                    const SizedBox(width: 8),
                    Text(
                      AppLocalizations.t('already_paid'),
                      style: TextStyle(color: Colors.grey[400]),
                    ),
                  ],
                ),
              ),
            if (isReturned)
              PopupMenuItem(
                child: Row(
                  children: [
                    const Icon(Icons.picture_as_pdf, color: Colors.red),
                    const SizedBox(width: 8),
                    Text(AppLocalizations.t('export_return_pdf')),
                  ],
                ),
                onTap: () {
                  // Use WidgetsBinding to ensure we're outside the popup menu context
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      _exportReturnPdf(report);
                    }
                  });
                },
              ),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }

  void _showDamageReportDetails(DamageReport report) {
    final bool isReturned = report.returnStatus == 'returned';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(
              isReturned ? Icons.check_circle : Icons.warning,
              color: isReturned ? Colors.green : Colors.orange,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                report.productName,
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow(
                AppLocalizations.t('quantity_damaged'),
                report.quantity.toString(),
              ),
              _buildDetailRow(
                AppLocalizations.t('unit_price'),
                '₱${report.unitPrice.toStringAsFixed(2)}',
              ),
              _buildDetailRow(
                AppLocalizations.t('total_value'),
                '₱${report.totalValue.toStringAsFixed(2)}',
              ),
              _buildDetailRow(
                AppLocalizations.t('reported_by'),
                report.reportedBy,
              ),
              _buildDetailRow(
                AppLocalizations.t('date'),
                _formatDate(report.reportDate),
              ),
              const Divider(height: 24),

              // Return Status Section
              if (isReturned) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green, width: 2),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.check_circle,
                            color: Colors.green,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            AppLocalizations.t('returned').toUpperCase(),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _buildDetailRow(
                        AppLocalizations.t('return_date'),
                        _formatDate(report.returnDate!),
                      ),
                      _buildDetailRow(
                        AppLocalizations.t('approved_by'),
                        report.returnApprovedBy ?? 'N/A',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              Text(
                AppLocalizations.t('reason'),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  report.reason,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
        ),
        actions: [
          if (isReturned)
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(ctx);
                _exportReturnPdf(report);
              },
              icon: const Icon(Icons.picture_as_pdf),
              label: Text(AppLocalizations.t('export_pdf')),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppLocalizations.t('close')),
          ),
        ],
      ),
    );
  }

  // ======================== PURCHASE ORDERS TAB ========================

  Widget _buildPurchaseOrdersTab() {
    final filtered = _getFilteredPurchaseOrders();

    return LayoutBuilder(
      builder: (context, constraints) {
        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 1000,
              maxHeight: constraints.maxHeight,
            ),
            child: Column(
              children: [
                // Search and filter bar
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    children: [
                      TextField(
                        controller: _orderSearchController,
                        decoration: InputDecoration(
                          hintText:
                              '${AppLocalizations.t('search')} ${AppLocalizations.t('order_number')}, ${AppLocalizations.t('supplier')}',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _orderQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    _orderSearchController.clear();
                                    setState(() => _orderQuery = '');
                                  },
                                )
                              : null,
                          border: const OutlineInputBorder(),
                        ),
                        onChanged: (v) => setState(() => _orderQuery = v),
                      ),
                      const SizedBox(height: 8),
                      // Status filter chips
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            FilterChip(
                              label: Text(AppLocalizations.t('all_items')),
                              selected: _orderStatusFilter == 'all',
                              onSelected: (selected) {
                                setState(() => _orderStatusFilter = 'all');
                              },
                            ),
                            const SizedBox(width: 8),
                            FilterChip(
                              avatar: const Icon(
                                Icons.pending,
                                size: 18,
                                color: Colors.orange,
                              ),
                              label: Text(AppLocalizations.t('pending')),
                              selected: _orderStatusFilter == 'pending',
                              onSelected: (selected) {
                                setState(() => _orderStatusFilter = 'pending');
                              },
                            ),
                            const SizedBox(width: 8),
                            FilterChip(
                              avatar: const Icon(
                                Icons.check_circle,
                                size: 18,
                                color: Colors.green,
                              ),
                              label: Text(AppLocalizations.t('approved')),
                              selected: _orderStatusFilter == 'approved',
                              onSelected: (selected) {
                                setState(() => _orderStatusFilter = 'approved');
                              },
                            ),
                            const SizedBox(width: 8),
                            FilterChip(
                              avatar: const Icon(
                                Icons.done_all,
                                size: 18,
                                color: Colors.blue,
                              ),
                              label: Text(AppLocalizations.t('completed')),
                              selected: _orderStatusFilter == 'completed',
                              onSelected: (selected) {
                                setState(
                                  () => _orderStatusFilter = 'completed',
                                );
                              },
                            ),
                            const SizedBox(width: 8),
                            FilterChip(
                              avatar: const Icon(
                                Icons.inventory,
                                size: 18,
                                color: Colors.purple,
                              ),
                              label: Text(AppLocalizations.t('received')),
                              selected: _orderStatusFilter == 'received',
                              onSelected: (selected) {
                                setState(() => _orderStatusFilter = 'received');
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : filtered.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.shopping_cart,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _orderQuery.isEmpty &&
                                        _orderStatusFilter == 'all'
                                    ? AppLocalizations.t('no_orders')
                                    : AppLocalizations.t('no_results_found'),
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: filtered.length,
                          padding: const EdgeInsets.all(8),
                          itemBuilder: (context, index) {
                            final order = filtered[index];
                            return _buildOrderCard(order);
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildOrderCard(PurchaseOrder order) {
    final statusColor = _getOrderStatusColor(order.status);
    final statusIcon = _getOrderStatusIcon(order.status);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: statusColor.withValues(alpha: 0.2),
          child: Icon(statusIcon, color: statusColor),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                order.orderNumber,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                AppLocalizations.t(order.status),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${AppLocalizations.t('supplier')}: ${order.supplierName}'),
            Text(
              '${AppLocalizations.t('order_date')}: ${_formatOrderDate(order.orderDate)}',
            ),
            Text(
              '${AppLocalizations.t('total_value')}: ₱${order.totalAmount.toStringAsFixed(2)}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
          ],
        ),
        trailing: PopupMenuButton(
          itemBuilder: (context) => [
            PopupMenuItem(
              child: Row(
                children: [
                  const Icon(Icons.info),
                  const SizedBox(width: 8),
                  Text(AppLocalizations.t('view_details')),
                ],
              ),
              onTap: () =>
                  Future.delayed(Duration.zero, () => _showOrderDetails(order)),
            ),
            if (order.status == 'pending')
              PopupMenuItem(
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green),
                    const SizedBox(width: 8),
                    Text(AppLocalizations.t('approve_order')),
                  ],
                ),
                onTap: () => Future.delayed(
                  Duration.zero,
                  () => _showApproveOrderDialog(order),
                ),
              ),
            if (order.status == 'approved')
              PopupMenuItem(
                child: Row(
                  children: [
                    const Icon(Icons.done_all, color: Colors.blue),
                    const SizedBox(width: 8),
                    Text(AppLocalizations.t('mark_completed')),
                  ],
                ),
                onTap: () => _markOrderCompleted(order.id!),
              ),
            if (order.status == 'completed')
              PopupMenuItem(
                child: Row(
                  children: [
                    const Icon(Icons.inventory, color: Colors.purple),
                    const SizedBox(width: 8),
                    Text(AppLocalizations.t('restock')),
                  ],
                ),
                onTap: () => Future.delayed(
                  Duration.zero,
                  () => _showRestockOrderDialog(order),
                ),
              ),
            PopupMenuItem(
              child: Row(
                children: [
                  const Icon(Icons.picture_as_pdf, color: Colors.red),
                  const SizedBox(width: 8),
                  Text(AppLocalizations.t('export_pdf')),
                ],
              ),
              onTap: () => _exportOrderPdf(order),
            ),
            if (order.status == 'pending')
              PopupMenuItem(
                child: Row(
                  children: [
                    const Icon(Icons.delete, color: Colors.red),
                    const SizedBox(width: 8),
                    Text(AppLocalizations.t('delete')),
                  ],
                ),
                onTap: () => _confirmDeleteOrder(order),
              ),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }

  Color _getOrderStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'approved':
        return Colors.green;
      case 'completed':
        return Colors.blue;
      case 'received':
        return Colors.purple;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getOrderStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Icons.pending;
      case 'approved':
        return Icons.check_circle;
      case 'completed':
        return Icons.done_all;
      case 'received':
        return Icons.inventory;
      case 'cancelled':
        return Icons.cancel;
      default:
        return Icons.shopping_cart;
    }
  }

  String _formatOrderDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }

  void _showCreateOrderDialog({Product? preselectedProduct}) async {
    if (_suppliers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.t('no_suppliers')),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final products = await db.getAllProducts();
    if (products.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.t('no_products')),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    Supplier? selectedSupplier;
    DateTime? expectedDelivery;
    final notesController = TextEditingController();
    final List<PurchaseOrderItem> orderItems = [];

    // If a product was preselected, add it to the order items
    if (preselectedProduct != null) {
      final preselectedItem = PurchaseOrderItem(
        orderId: 0,
        productId: preselectedProduct.id!,
        productName: preselectedProduct.name,
        quantity: preselectedProduct.reorderLevel > 0
            ? preselectedProduct.reorderLevel
            : 10,
        unitPrice: preselectedProduct.buyingPrice,
        totalPrice:
            (preselectedProduct.reorderLevel > 0
                ? preselectedProduct.reorderLevel
                : 10) *
            preselectedProduct.buyingPrice,
      );
      orderItems.add(preselectedItem);
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final total = orderItems.fold<double>(
            0,
            (sum, item) => sum + item.totalPrice,
          );

          return AlertDialog(
            title: Text(AppLocalizations.t('create_order')),
            content: SizedBox(
              width: 500,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (preselectedProduct != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: Colors.blue.shade700,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                '${AppLocalizations.t('order_from_supplier')}: ${preselectedProduct.name}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue.shade900,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    DropdownButtonFormField<Supplier>(
                      initialValue: selectedSupplier,
                      decoration: InputDecoration(
                        labelText: '${AppLocalizations.t('supplier')} *',
                        border: const OutlineInputBorder(),
                      ),
                      items: _suppliers
                          .where((s) => s.isActive)
                          .map(
                            (s) =>
                                DropdownMenuItem(value: s, child: Text(s.name)),
                          )
                          .toList(),
                      onChanged: (value) {
                        setDialogState(() => selectedSupplier = value);
                      },
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      title: Text(AppLocalizations.t('expected_delivery')),
                      subtitle: Text(
                        expectedDelivery != null
                            ? _formatOrderDate(expectedDelivery!)
                            : AppLocalizations.t('optional'),
                      ),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now().add(
                            const Duration(days: 7),
                          ),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(
                            const Duration(days: 365),
                          ),
                        );
                        if (date != null) {
                          setDialogState(() => expectedDelivery = date);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: notesController,
                      decoration: InputDecoration(
                        labelText:
                            '${AppLocalizations.t('notes')} (${AppLocalizations.t('optional')})',
                        border: const OutlineInputBorder(),
                      ),
                      maxLines: 2,
                    ),
                    const Divider(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          AppLocalizations.t('add_products'),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_circle),
                          color: Theme.of(context).colorScheme.primary,
                          onPressed: () => _showAddProductDialog(
                            context,
                            products,
                            orderItems,
                            setDialogState,
                          ),
                        ),
                      ],
                    ),
                    if (orderItems.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            AppLocalizations.t('no_items'),
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ),
                      )
                    else
                      ...orderItems.asMap().entries.map((entry) {
                        final index = entry.key;
                        final item = entry.value;
                        return Card(
                          child: ListTile(
                            title: Text(item.productName),
                            subtitle: Text(
                              '${AppLocalizations.t('quantity')}: ${item.quantity} × ₱${item.unitPrice.toStringAsFixed(2)}',
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '₱${item.totalPrice.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete,
                                    color: Colors.red,
                                  ),
                                  onPressed: () {
                                    setDialogState(() {
                                      orderItems.removeAt(index);
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    if (orderItems.isNotEmpty) ...[
                      const Divider(),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              AppLocalizations.t('total_value'),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '₱${total.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(AppLocalizations.t('cancel')),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (selectedSupplier == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(AppLocalizations.t('select_supplier')),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  if (orderItems.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(AppLocalizations.t('at_least_one_item')),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  final orderNumber = db.generateOrderNumber();
                  final order = PurchaseOrder(
                    orderNumber: orderNumber,
                    supplierId: selectedSupplier!.id!,
                    supplierName: selectedSupplier!.name,
                    orderDate: DateTime.now(),
                    expectedDeliveryDate: expectedDelivery,
                    status: 'pending',
                    items: orderItems,
                    totalAmount: total,
                    notes: notesController.text,
                  );

                  await db.insertPurchaseOrder(order);
                  await _loadData();

                  if (mounted) {
                    Navigator.pop(ctx);
                    // Return true if this was an auto-created order from inventory
                    if (preselectedProduct != null) {
                      Navigator.pop(context, true);
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(AppLocalizations.t('order_created')),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                },
                child: Text(AppLocalizations.t('create_order')),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showAddProductDialog(
    BuildContext parentContext,
    List<Product> products,
    List<PurchaseOrderItem> orderItems,
    StateSetter updateParent,
  ) {
    Product? selectedProduct;
    final qtyController = TextEditingController();
    final priceController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(AppLocalizations.t('add_item')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<Product>(
                initialValue: selectedProduct,
                decoration: InputDecoration(
                  labelText: AppLocalizations.t('select_product'),
                  border: const OutlineInputBorder(),
                ),
                items: products.map((p) {
                  final isOutOfStock = p.quantity == 0;
                  final isLowStock = p.lowStock && p.quantity > 0;

                  final stockText =
                      '${AppLocalizations.t('stock')}: ${p.quantity}';
                  final stockColor = isOutOfStock
                      ? Colors.red
                      : isLowStock
                      ? Colors.orange
                      : Colors.grey[600];

                  return DropdownMenuItem(
                    value: p,
                    child: Text.rich(
                      TextSpan(
                        children: [
                          WidgetSpan(
                            alignment: PlaceholderAlignment.middle,
                            child: Icon(
                              isOutOfStock
                                  ? Icons.remove_circle
                                  : isLowStock
                                  ? Icons.warning_amber
                                  : Icons.check_circle,
                              color: isOutOfStock
                                  ? Colors.red
                                  : isLowStock
                                  ? Colors.orange
                                  : Colors.green,
                              size: 18,
                            ),
                          ),
                          const TextSpan(text: '  '),
                          TextSpan(
                            text: p.name,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          TextSpan(
                            text: ' ($stockText)',
                            style: TextStyle(
                              fontSize: 12,
                              color: stockColor,
                              fontWeight: isOutOfStock || isLowStock
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    selectedProduct = value;
                    if (value != null) {
                      priceController.text = value.buyingPrice.toString();
                    }
                  });
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: qtyController,
                decoration: InputDecoration(
                  labelText: AppLocalizations.t('quantity'),
                  border: const OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: priceController,
                decoration: InputDecoration(
                  labelText: AppLocalizations.t('unit_price'),
                  prefixText: '₱',
                  border: const OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(AppLocalizations.t('cancel')),
            ),
            ElevatedButton(
              onPressed: () {
                if (selectedProduct == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(AppLocalizations.t('select_product')),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                final qty = int.tryParse(qtyController.text);
                final price = double.tryParse(priceController.text);

                if (qty == null || qty <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(AppLocalizations.t('enter_quantity')),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                if (price == null || price <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(AppLocalizations.t('enter_unit_price')),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                final item = PurchaseOrderItem(
                  orderId: 0,
                  productId: selectedProduct!.id!,
                  productName: selectedProduct!.name,
                  quantity: qty,
                  unitPrice: price,
                  totalPrice: qty * price,
                );

                updateParent(() {
                  orderItems.add(item);
                });

                Navigator.pop(ctx);
              },
              child: Text(AppLocalizations.t('add_item')),
            ),
          ],
        ),
      ),
    );
  }

  void _showOrderDetails(PurchaseOrder order) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(order.orderNumber),
        content: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow(
                  AppLocalizations.t('supplier'),
                  order.supplierName,
                ),
                _buildDetailRow(
                  AppLocalizations.t('order_date'),
                  _formatOrderDate(order.orderDate),
                ),
                if (order.expectedDeliveryDate != null)
                  _buildDetailRow(
                    AppLocalizations.t('expected_delivery'),
                    _formatOrderDate(order.expectedDeliveryDate!),
                  ),
                _buildDetailRow(
                  AppLocalizations.t('order_status'),
                  AppLocalizations.t(order.status),
                ),
                if (order.approvedBy != null) ...[
                  _buildDetailRow(
                    AppLocalizations.t('approved_by'),
                    order.approvedBy!,
                  ),
                  if (order.approvalDate != null)
                    _buildDetailRow(
                      AppLocalizations.t('approved_on'),
                      _formatDate(order.approvalDate!),
                    ),
                ],
                if (order.notes.isNotEmpty) ...[
                  const Divider(),
                  Text(
                    AppLocalizations.t('notes'),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(order.notes),
                ],
                const Divider(),
                Text(
                  AppLocalizations.t('products'),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                ...order.items.map(
                  (item) => Card(
                    child: ListTile(
                      title: Text(item.productName),
                      subtitle: Text(
                        '${item.quantity} × ₱${item.unitPrice.toStringAsFixed(2)}',
                      ),
                      trailing: Text(
                        '₱${item.totalPrice.toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
                const Divider(),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        AppLocalizations.t('total_value'),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '₱${order.totalAmount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          if (order.status == 'pending')
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _showApproveOrderDialog(order);
              },
              child: Text(AppLocalizations.t('approve_order')),
            ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _exportOrderPdf(order);
            },
            child: Text(AppLocalizations.t('export_pdf')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppLocalizations.t('close')),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('$label:', style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(value),
        ],
      ),
    );
  }

  void _showApproveOrderDialog(PurchaseOrder order) {
    final signatureKey = GlobalKey<SignaturePadState>();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(AppLocalizations.t('approve_order')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${AppLocalizations.t('order_number')}: ${order.orderNumber}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Text(AppLocalizations.t('approval_signature')),
              const SizedBox(height: 8),
              SignaturePad(key: signatureKey, width: 300, height: 150),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () {
                  signatureKey.currentState?.clear();
                },
                icon: const Icon(Icons.clear),
                label: Text(AppLocalizations.t('clear_signature')),
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
                final signature = await signatureKey.currentState
                    ?.getSignatureAsBase64();
                if (signature == null || signature.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(AppLocalizations.t('signature_required')),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                await db.approvePurchaseOrder(order.id!, 'Owner', signature);
                await _loadData();

                if (mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(AppLocalizations.t('order_approved')),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
              child: Text(AppLocalizations.t('approve_order')),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportOrderPdf(PurchaseOrder order) async {
    try {
      final supplier = await db.getSupplierById(order.supplierId);
      if (supplier != null) {
        await PurchaseOrderPdfService.generateAndPrintPdf(order, supplier);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${AppLocalizations.t('error')}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showReturnApprovalDialog(DamageReport report) {
    final signatureKey = GlobalKey<SignaturePadState>();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(AppLocalizations.t('return_approval')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.t('return_to_supplier'),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${AppLocalizations.t('product')}: ${report.productName}',
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${AppLocalizations.t('quantity')}: ${report.quantity}',
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${AppLocalizations.t('total_value')}: ₱${report.totalValue.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  AppLocalizations.t('approval_signature'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                SignaturePad(key: signatureKey, width: 300, height: 150),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () {
                    signatureKey.currentState?.clear();
                  },
                  icon: const Icon(Icons.clear),
                  label: Text(AppLocalizations.t('clear_signature')),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(AppLocalizations.t('cancel')),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                final signature = await signatureKey.currentState
                    ?.getSignatureAsBase64();
                if (signature == null || signature.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(AppLocalizations.t('signature_required')),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                // Check if report has an ID
                if (report.id == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Error: Report ID is missing'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                try {
                  await db.updateDamageReportReturn(
                    reportId: report.id!,
                    approvedBy: 'Owner',
                    signature: signature,
                  );

                  if (mounted) {
                    Navigator.pop(ctx);

                    // Reload data
                    await _loadData();

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(AppLocalizations.t('return_approved')),
                        backgroundColor: Colors.green,
                      ),
                    );

                    // Get updated report and export PDF
                    final updatedReport = await db.getDamageReportById(
                      report.id!,
                    );
                    if (updatedReport != null) {
                      await _exportReturnPdf(updatedReport);
                    }
                  }
                } catch (e) {
                  debugPrint('Error approving return: $e');
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('${AppLocalizations.t('error')}: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: Text(AppLocalizations.t('approve_return')),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportReturnPdf(DamageReport report) async {
    try {
      await DamageReturnPdfService.generateAndPrintPdf(report);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${AppLocalizations.t('error')}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showRestockOrderDialog(PurchaseOrder order) {
    final deliveryReceiptController = TextEditingController();
    final Map<int, TextEditingController> quantityControllers = {};
    final Map<int, TextEditingController> damageControllers = {};
    final Map<int, TextEditingController> damageReasonControllers = {};
    final Map<int, TextEditingController> serialNumberControllers = {};

    // Initialize controllers for each item
    for (var item in order.items) {
      quantityControllers[item.productId] = TextEditingController(
        text: item.quantity.toString(),
      );
      damageControllers[item.productId] = TextEditingController(text: '0');
      damageReasonControllers[item.productId] = TextEditingController();
      serialNumberControllers[item.productId] = TextEditingController();
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.t('restock_items')),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${AppLocalizations.t('order_number')}: ${order.orderNumber}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: deliveryReceiptController,
                  decoration: InputDecoration(
                    labelText: AppLocalizations.t('delivery_receipt'),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const Divider(height: 32),
                Text(
                  AppLocalizations.t('products'),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                ...order.items.map((item) {
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.productName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${AppLocalizations.t('ordered')}: ${item.quantity}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller:
                                      quantityControllers[item.productId],
                                  decoration: InputDecoration(
                                    labelText: AppLocalizations.t('received'),
                                    isDense: true,
                                    border: const OutlineInputBorder(),
                                  ),
                                  keyboardType: TextInputType.number,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: damageControllers[item.productId],
                                  decoration: InputDecoration(
                                    labelText: AppLocalizations.t('damaged'),
                                    isDense: true,
                                    border: const OutlineInputBorder(),
                                  ),
                                  keyboardType: TextInputType.number,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: damageReasonControllers[item.productId],
                            decoration: InputDecoration(
                              labelText:
                                  '${AppLocalizations.t('damage_reason')} (${AppLocalizations.t('optional')})',
                              isDense: true,
                              border: const OutlineInputBorder(),
                            ),
                            maxLines: 2,
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: serialNumberControllers[item.productId],
                            decoration: InputDecoration(
                              labelText:
                                  '${AppLocalizations.t('serial_number')} (${AppLocalizations.t('optional')})',
                              isDense: true,
                              border: const OutlineInputBorder(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              for (var controller in quantityControllers.values) {
                controller.dispose();
              }
              for (var controller in damageControllers.values) {
                controller.dispose();
              }
              for (var controller in damageReasonControllers.values) {
                controller.dispose();
              }
              for (var controller in serialNumberControllers.values) {
                controller.dispose();
              }
              deliveryReceiptController.dispose();
              Navigator.pop(ctx);
            },
            child: Text(AppLocalizations.t('cancel')),
          ),
          ElevatedButton(
            onPressed: () async {
              final deliveryReceipt = deliveryReceiptController.text.trim();
              if (deliveryReceipt.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      AppLocalizations.t('delivery_receipt_required'),
                    ),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              // Restock each product
              for (var item in order.items) {
                final receivedQty =
                    int.tryParse(quantityControllers[item.productId]!.text) ??
                    0;
                final damageQty =
                    int.tryParse(damageControllers[item.productId]!.text) ?? 0;
                final damageReason = damageReasonControllers[item.productId]!
                    .text
                    .trim();
                final serialNumber = serialNumberControllers[item.productId]!
                    .text
                    .trim();

                if (receivedQty > 0) {
                  // Create restock record with damage info
                  final damageNote = damageQty > 0
                      ? 'Restocked from purchase order ($damageQty damaged items excluded${serialNumber.isNotEmpty ? ', SN: $serialNumber' : ''})'
                      : 'Restocked from purchase order';

                  final record = RestockRecord(
                    productId: item.productId,
                    productName: item.productName,
                    quantity: receivedQty,
                    damageQuantity: damageQty,
                    damageReason: damageReason.isNotEmpty
                        ? '$damageReason${serialNumber.isNotEmpty ? ' (SN: $serialNumber)' : ''}'
                        : serialNumber.isNotEmpty
                        ? 'SN: $serialNumber'
                        : '',
                    deliveryReceiptNo: deliveryReceipt,
                    supplierId: order.supplierId,
                    supplierName: order.supplierName,
                    referencedBy: 'Purchase Order ${order.orderNumber}',
                    notes: damageNote,
                    restockDate: DateTime.now(),
                  );
                  await db.insertRestockRecord(record);

                  // If there are damaged items, create a damage report
                  if (damageQty > 0) {
                    final damageReportReason = damageReason.isNotEmpty
                        ? '${AppLocalizations.t('purchase_order')}: ${order.orderNumber} - $damageReason${serialNumber.isNotEmpty ? ' (SN: $serialNumber)' : ''}'
                        : '${AppLocalizations.t('purchase_order')}: ${order.orderNumber}${serialNumber.isNotEmpty ? ' (SN: $serialNumber)' : ''}';

                    final damageReport = DamageReport(
                      productId: item.productId,
                      productName: item.productName,
                      quantity: damageQty,
                      unitPrice: item.unitPrice,
                      totalValue: item.unitPrice * damageQty,
                      reason: damageReportReason,
                      reportedBy: 'Owner',
                      reportDate: DateTime.now(),
                    );
                    await db.insertDamageReport(damageReport);
                  }

                  // Update product stock: add only good items (received - damaged)
                  final goodItems = receivedQty - damageQty;
                  if (goodItems > 0) {
                    final product = await db.getProductById(item.productId);
                    if (product != null) {
                      final updatedProduct = product.copyWith(
                        quantity: product.quantity + goodItems,
                        buyingPrice: item.unitPrice,
                      );
                      await db.updateProduct(updatedProduct);
                    }
                  }
                }
              }

              // Mark order as received
              await db.updatePurchaseOrderStatus(order.id!, 'received');
              await _loadData();

              // Cleanup
              for (var controller in quantityControllers.values) {
                controller.dispose();
              }
              for (var controller in damageControllers.values) {
                controller.dispose();
              }
              for (var controller in damageReasonControllers.values) {
                controller.dispose();
              }
              deliveryReceiptController.dispose();

              if (mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(AppLocalizations.t('restock_success')),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            child: Text(AppLocalizations.t('restock')),
          ),
        ],
      ),
    );
  }

  Future<void> _markOrderCompleted(int orderId) async {
    await db.updatePurchaseOrderStatus(orderId, 'completed');
    await _loadData();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.t('order_updated')),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _confirmDeleteOrder(PurchaseOrder order) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.t('confirm')),
        content: Text(AppLocalizations.t('delete_order_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppLocalizations.t('cancel')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await db.deletePurchaseOrder(order.id!);
              await _loadData();
              if (mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(AppLocalizations.t('order_deleted'))),
                );
              }
            },
            child: Text(AppLocalizations.t('delete')),
          ),
        ],
      ),
    );
  }
}
