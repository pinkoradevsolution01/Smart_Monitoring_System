import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

class SignaturePad extends StatefulWidget {
  final double width;
  final double height;
  final ValueChanged<String>? onSignatureChanged;

  const SignaturePad({
    super.key,
    this.width = 300,
    this.height = 200,
    this.onSignatureChanged,
  });

  @override
  State<SignaturePad> createState() => SignaturePadState();
}

class SignaturePadState extends State<SignaturePad> {
  final List<Offset?> _points = [];
  final GlobalKey _signatureKey = GlobalKey();
  bool _isDrawing = false;

  void clear() {
    setState(() {
      _points.clear();
    });
    widget.onSignatureChanged?.call('');
  }

  Future<String> getSignatureAsBase64() async {
    if (_points.isEmpty) return '';

    try {
      RenderRepaintBoundary boundary =
          _signatureKey.currentContext!.findRenderObject()
              as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      if (byteData != null) {
        Uint8List pngBytes = byteData.buffer.asUint8List();
        return base64Encode(pngBytes);
      }
    } catch (e) {
      debugPrint('Error capturing signature: $e');
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(8),
        color: Colors.white,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: RepaintBoundary(
          key: _signatureKey,
          child: MouseRegion(
            cursor: SystemMouseCursors.precise,
            child: Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: (event) {
                debugPrint('Pointer down at: ${event.localPosition}');
                setState(() {
                  _isDrawing = true;
                  _points.add(event.localPosition);
                });
              },
              onPointerMove: (event) {
                if (_isDrawing) {
                  debugPrint('Drawing at: ${event.localPosition}');
                  setState(() {
                    _points.add(event.localPosition);
                  });
                  widget.onSignatureChanged?.call('drawing');
                }
              },
              onPointerUp: (event) {
                debugPrint('Pointer up - Total points: ${_points.length}');
                setState(() {
                  _isDrawing = false;
                  _points.add(null);
                });
              },
              onPointerCancel: (event) {
                setState(() {
                  _isDrawing = false;
                  _points.add(null);
                });
              },
              child: CustomPaint(
                painter: SignaturePainter(points: _points),
                child: Container(
                  width: widget.width,
                  height: widget.height,
                  color: Colors.transparent,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SignaturePainter extends CustomPainter {
  final List<Offset?> points;

  SignaturePainter({required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    debugPrint('SignaturePainter.paint called with ${points.length} points');

    final paint = Paint()
      ..color = Colors.black
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 4.0
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < points.length - 1; i++) {
      if (points[i] != null && points[i + 1] != null) {
        debugPrint('Drawing line from ${points[i]} to ${points[i + 1]}');
        canvas.drawLine(points[i]!, points[i + 1]!, paint);
      }
    }
  }

  @override
  bool shouldRepaint(SignaturePainter oldDelegate) {
    return true; // Always repaint to ensure updates
  }
}
