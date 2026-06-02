// ignore_for_file: avoid_print
import 'dart:math';

/// Quick script to generate test activation codes that pass offline validation
/// Run: dart run scripts/generate_test_codes.dart
void main() {
  print('=== Test Activation Code Generator ===\n');
  print('Generating codes that pass offline validation (sum % 7 == 0)\n');

  // Show hardcoded test codes first
  print('HARDCODED TEST CODES (Always Valid):');
  print('  1. TEST1234567890ABCDEF');
  print('  2. DEV20240209TESTCODE1');
  print('  3. ABCDEFGHIJ0123456789');
  print('\nThese codes are hardcoded and will always work.\n');

  print('GENERATED CODES (Checksum Valid):');

  // Generate 5 test codes
  for (int i = 1; i <= 5; i++) {
    final code = generateValidCode();
    print('Code $i: $code');
    print('  Formatted: ${formatCode(code)}');
    print('  Checksum: ${getChecksum(code)} (sum % 7 = 0) ✓\n');
  }
}

String generateValidCode() {
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  final random = Random();
  String code;
  int attempts = 0;

  do {
    code = '';
    for (int i = 0; i < 24; i++) {
      code += chars[random.nextInt(chars.length)];
    }
    attempts++;
  } while (!validateChecksum(code) && attempts < 1000);

  return code;
}

bool validateChecksum(String code) {
  int sum = 0;
  for (int i = 0; i < code.length; i++) {
    sum += code.codeUnitAt(i);
  }
  return sum % 7 == 0;
}

int getChecksum(String code) {
  int sum = 0;
  for (int i = 0; i < code.length; i++) {
    sum += code.codeUnitAt(i);
  }
  return sum;
}

String formatCode(String code) {
  if (code.length < 20) return code;

  // Format as XXXX-XXXX-XXXX-XXXX-XXXX
  final buffer = StringBuffer();
  for (int i = 0; i < code.length; i++) {
    if (i > 0 && i % 4 == 0) {
      buffer.write('-');
    }
    buffer.write(code[i]);
  }
  return buffer.toString();
}
