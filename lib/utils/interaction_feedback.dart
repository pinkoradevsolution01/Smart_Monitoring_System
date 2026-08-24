import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

import 'motion_controller.dart';

/// Consistent, subtle feedback for intentional actions.
/// A short WAV click is generated in memory, which is more reliable than the
/// operating system's optional click-sound setting on Windows and Android.
class InteractionFeedback {
  static final AudioPlayer _player = AudioPlayer();
  static final Uint8List _tapSound = _createClickWav();

  static void tap() {
    if (MotionController.reduceMotion.value) return;
    _play(.22);
    HapticFeedback.selectionClick();
  }

  static void cartAdded() {
    if (MotionController.reduceMotion.value) return;
    _play(.32);
    HapticFeedback.mediumImpact();
  }

  static void _play(double volume) {
    unawaited(
      _player
          .play(BytesSource(_tapSound, mimeType: 'audio/wav'), volume: volume)
          .catchError((_) {
            // Sound feedback must never block or break a business action.
          }),
    );
  }

  static Uint8List _createClickWav() {
    const sampleRate = 22050;
    const durationMilliseconds = 62;
    final sampleCount = sampleRate * durationMilliseconds ~/ 1000;
    final bytes = ByteData(44 + sampleCount * 2);

    void writeAscii(int offset, String value) {
      for (var index = 0; index < value.length; index++) {
        bytes.setUint8(offset + index, value.codeUnitAt(index));
      }
    }

    writeAscii(0, 'RIFF');
    bytes.setUint32(4, 36 + sampleCount * 2, Endian.little);
    writeAscii(8, 'WAVEfmt ');
    bytes.setUint32(16, 16, Endian.little);
    bytes.setUint16(20, 1, Endian.little);
    bytes.setUint16(22, 1, Endian.little);
    bytes.setUint32(24, sampleRate, Endian.little);
    bytes.setUint32(28, sampleRate * 2, Endian.little);
    bytes.setUint16(32, 2, Endian.little);
    bytes.setUint16(34, 16, Endian.little);
    writeAscii(36, 'data');
    bytes.setUint32(40, sampleCount * 2, Endian.little);

    for (var index = 0; index < sampleCount; index++) {
      final progress = index / sampleCount;
      final envelope = math.pow(1 - progress, 4).toDouble();
      final frequency = 880 - (progress * 240);
      final sample = math.sin(2 * math.pi * frequency * index / sampleRate) *
          envelope *
          0.72;
      bytes.setInt16(44 + index * 2, (sample * 32767).round(), Endian.little);
    }
    return bytes.buffer.asUint8List();
  }
}
