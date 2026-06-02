import 'dart:async';

import 'package:flutter/material.dart';

class HeaderClock extends StatefulWidget {
  const HeaderClock({super.key});

  @override
  State<HeaderClock> createState() => _HeaderClockState();
}

class _HeaderClockState extends State<HeaderClock> {
  late DateTime _now;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _two(int n) => n.toString().padLeft(2, '0');

  String _formatTime(DateTime dt) {
    final h = _two(dt.hour);
    final m = _two(dt.minute);
    final s = _two(dt.second);
    return '$h:$m:$s';
  }

  String _formatDate(DateTime dt) {
    final y = dt.year;
    final mo = _two(dt.month);
    final d = _two(dt.day);
    return '$y-$mo-$d';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          _formatTime(_now),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        Text(
          _formatDate(_now),
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
        ),
      ],
    );
  }
}
