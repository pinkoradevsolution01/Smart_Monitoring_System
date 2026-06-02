import 'package:flutter/material.dart';
import '../../utils/app_localizations.dart';
import '../../services/attendance_service.dart';
import '../cashier/cashier_pos.dart';
import '../cashier/price_checker_screen.dart';
import '../../models/user.dart';
import '../owner/for_delivery_screen.dart';

class SalesPromoterDashboard extends StatelessWidget {
  final User user;
  const SalesPromoterDashboard({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.t('sales_promoter'))),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // Dashboard welcome section
                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Dashboard',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Welcome, ${user.name}',
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                ),
                // Action tiles
                Expanded(
                  child: GridView.count(
                    crossAxisCount: MediaQuery.of(context).size.width > 800
                        ? 3
                        : 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    children: [
                      _ActionTile(
                        icon: Icons.access_time,
                        color: Colors.indigo,
                        title: AppLocalizations.t('attendance'),
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (_) => Dialog(
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: _AttendanceCard(user: user),
                              ),
                            ),
                          );
                        },
                      ),
                      _ActionTile(
                        icon: Icons.point_of_sale,
                        color: Colors.teal,
                        title: AppLocalizations.t('open_pos'),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CashierPOS(cashierName: user.name),
                          ),
                        ),
                      ),
                      _ActionTile(
                        icon: Icons.search,
                        color: Colors.orange,
                        title: AppLocalizations.t('price_checker'),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const PriceCheckerScreen(),
                          ),
                        ),
                      ),
                      _ActionTile(
                        icon: Icons.local_shipping,
                        color: Colors.blue,
                        title: AppLocalizations.t('for_delivery'),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ForDeliveryScreen(user: user),
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

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: color,
                child: Icon(icon, color: Colors.white, size: 28),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AttendanceCard extends StatefulWidget {
  final User user;

  const _AttendanceCard({required this.user});

  @override
  State<_AttendanceCard> createState() => _AttendanceCardState();
}

class _AttendanceCardState extends State<_AttendanceCard> {
  List<AttendanceEntry> _entries = [];
  bool _loading = true;
  String _nextLabel = 'IN';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await AttendanceService.instance.loadEntries(widget.user.id);
    final nextType = await AttendanceService.instance.nextTypeForUser(
      widget.user.id,
    );
    setState(() {
      _entries = list.reversed.toList(); // show newest first
      _nextLabel = _friendlyLabel(nextType);
      _loading = false;
    });
  }

  Future<void> _toggle() async {
    setState(() => _loading = true);
    final list = await AttendanceService.instance.toggle(widget.user.id);
    final nextType = await AttendanceService.instance.nextTypeForUser(
      widget.user.id,
    );
    setState(() {
      _entries = list.reversed.toList();
      _nextLabel = _friendlyLabel(nextType);
      _loading = false;
    });
    final last = _entries.isNotEmpty ? _entries.first : null;
    if (last != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${_friendlyLabel(last.type)} @ ${_formatTime(last.time)}',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  String _friendlyLabel(String type) {
    switch (type) {
      case 'LUNCH':
        return 'LB';
      case 'SNACK':
        return 'SB';
      case 'OUT':
        return 'OUT';
      case 'IN':
      default:
        return 'IN';
    }
  }

  String _formatTime(DateTime t) {
    return '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')} ${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:${t.second.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final next = _nextLabel;
    return SizedBox(
      width: 420,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            AppLocalizations.t('attendance'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text('${AppLocalizations.t('next')}: $next'),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            icon: const Icon(Icons.login),
            label: Text(next),
            onPressed: _loading ? null : _toggle,
          ),
          const SizedBox(height: 12),
          if (_loading) const CircularProgressIndicator(),
          if (!_loading) ...[
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 240),
              child: _entries.isEmpty
                  ? Text(AppLocalizations.t('no_records'))
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: _entries.length,
                      separatorBuilder: (context, index) =>
                          const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final e = _entries[index];
                        return ListTile(
                          dense: true,
                          leading: CircleAvatar(
                            radius: 16,
                            backgroundColor: e.type == 'IN'
                                ? Colors.green
                                : (e.type == 'OUT' ? Colors.red : Colors.amber),
                            child: Text(
                              _friendlyLabel(e.type),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                              ),
                            ),
                          ),
                          title: Text(_formatTime(e.time)),
                        );
                      },
                    ),
            ),
          ],
        ],
      ),
    );
  }
}
