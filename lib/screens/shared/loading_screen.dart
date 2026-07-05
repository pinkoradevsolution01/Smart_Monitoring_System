import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../utils/app_localizations.dart';
import '../../models/user.dart';

class LoadingScreen extends StatefulWidget {
  final Widget destination;
  final UserRole? role;
  final IconData? iconData;
  const LoadingScreen({
    super.key,
    required this.destination,
    this.role,
    this.iconData,
  });

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _rotation;
  late final Animation<double> _dot1;
  late final Animation<double> _dot2;
  late final Animation<double> _dot3;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    );

    _rotation = Tween(
      begin: 0.0,
      end: math.pi * 4,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));

    _dot1 = Tween(begin: 0.6, end: 1.15).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.0, 0.7, curve: Curves.easeInOut),
      ),
    );
    _dot2 = Tween(begin: 0.6, end: 1.15).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.15, 0.85, curve: Curves.easeInOut),
      ),
    );
    _dot3 = Tween(begin: 0.6, end: 1.15).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.3, 0.95, curve: Curves.easeInOut),
      ),
    );

    _ctrl.forward().whenComplete(() {
      if (!mounted) return;
      // replace loading with destination
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => widget.destination));
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Color _lerpColor(Color a, Color b, double t) => Color.lerp(a, b, t) ?? a;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final alt = primary.withAlpha((0.8 * 255).round());

    return Scaffold(
      body: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, child) {
          // animated background colors
          final t = Curves.easeInOut.transform(_ctrl.value);
          final c1 = _lerpColor(primary, Colors.deepPurple, (t * 0.7));
          final c2 = _lerpColor(
            alt,
            Colors.indigo,
            (0.6 + t * 0.4).clamp(0.0, 1.0),
          );

          return Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment(-0.8 + t * 1.6, -1),
                end: Alignment(0.8 - t * 1.6, 1),
                colors: [c1, c2],
              ),
            ),
            child: child,
          );
        },
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // rotating store icon with subtle scale pulse
                AnimatedBuilder(
                  animation: _ctrl,
                  builder: (context, _) {
                    final scale =
                        0.9 + 0.15 * math.sin(_ctrl.value * math.pi * 2);
                    return Transform.rotate(
                      angle: _rotation.value,
                      child: Transform.scale(
                        scale: scale,
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha((0.12 * 255).round()),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withAlpha(
                                  (0.12 * 255).round(),
                                ),
                                blurRadius: 12,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: SizedBox(
                            width: 250,
                            height: 250,
                            child: Center(
                              child: widget.iconData != null
                                  ? Icon(
                                      widget.iconData!,
                                      size: 140,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onPrimary,
                                    )
                                  : widget.role != null
                                  ? Icon(
                                      _iconForRole(widget.role!),
                                      size: 140,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onPrimary,
                                    )
                                  : Image.asset(
                                      'SMS_LOGO_NBG.png',
                                      width: 240,
                                      height: 240,
                                      fit: BoxFit.contain,
                                    ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 28),

                // bouncing dots
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ScaleTransition(scale: _dot1, child: _buildDot()),
                    const SizedBox(width: 10),
                    ScaleTransition(scale: _dot2, child: _buildDot()),
                    const SizedBox(width: 10),
                    ScaleTransition(scale: _dot3, child: _buildDot()),
                  ],
                ),

                const SizedBox(height: 20),
                Text(
                  AppLocalizations.t('loading'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                AnimatedBuilder(
                  animation: _ctrl,
                  builder: (context, _) {
                    return Opacity(
                      opacity: (_ctrl.value * 1.2).clamp(0.0, 1.0),
                      child: Text(
                        'Creative aura, built with code',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 13,
                          fontStyle: FontStyle.italic,
                          letterSpacing: 0.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDot() {
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle),
    );
  }

  IconData _iconForRole(UserRole role) {
    switch (role) {
      case UserRole.owner:
        return Icons.storefront;
      case UserRole.manager:
        return Icons.manage_accounts;
      case UserRole.salesPromoter:
        return Icons.campaign;
      case UserRole.inventoryClerk:
        return Icons.inventory_2;
      case UserRole.deliveryReceiver:
        return Icons.local_shipping;
      case UserRole.cashier:
        return Icons.point_of_sale;
      case UserRole.staff:
        return Icons.person;
    }
  }
}
