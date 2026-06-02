import 'dart:io';
import 'dart:math';

/// Generates valid activation codes that pass the checksum validation
/// (sum of char codes % 7 == 0)
void main() {
  final random = Random.secure();
  final codes = <String>[];
  final characters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';

  print('Generating 100 one-time activation codes...\n');

  int attempts = 0;
  while (codes.length < 100) {
    attempts++;

    // Generate random 20-character code
    final buffer = StringBuffer();
    for (int i = 0; i < 20; i++) {
      buffer.write(characters[random.nextInt(characters.length)]);
    }

    final code = buffer.toString();

    // Check if it passes the checksum (sum % 7 == 0)
    int sum = 0;
    for (int i = 0; i < code.length; i++) {
      sum += code.codeUnitAt(i);
    }

    // If checksum passes and code is unique, add it
    if (sum % 7 == 0 && !codes.contains(code)) {
      codes.add(code);
      print('${codes.length}. $code (checksum: $sum, attempts: $attempts)');
      attempts = 0; // Reset attempts counter
    }
  }

  print('\n✅ Successfully generated 100 valid activation codes!\n');

  // Save to file
  final file = File('ACTIVATION_CODES.txt');
  final buffer = StringBuffer();
  buffer.writeln('# Smart Monitoring System - One-Time Activation Codes');
  buffer.writeln('# Generated: ${DateTime.now()}');
  buffer.writeln('# Total: 100 codes');
  buffer.writeln('# Note: Each code can only be used once');
  buffer.writeln('# Format: 20-character uppercase alphanumeric');
  buffer.writeln('# Validation: Checksum (sum of char codes % 7 == 0)');
  buffer.writeln('#' * 60);
  buffer.writeln();

  for (int i = 0; i < codes.length; i++) {
    buffer.writeln('${(i + 1).toString().padLeft(3, '0')}. ${codes[i]}');
  }

  file.writeAsStringSync(buffer.toString());
  print('📄 Codes saved to: ACTIVATION_CODES.txt');
  print('🔒 Each code works one-time only (tracked in app storage)');
}
