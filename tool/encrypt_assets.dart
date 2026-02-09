/// Encrypts markdown files with AES-256-CBC using a passphrase.
///
/// Usage:
///   dart tool/encrypt_assets.dart <passphrase>
///
/// Reads:  mhs-001.en.md, mhs-001.hr.md
/// Writes: assets/mhs-001.en.enc, assets/mhs-001.hr.enc
///
/// Format of .enc files: base64( IV[16] + ciphertext[...] )
/// Plaintext is prefixed with "MHS_OK:" for decryption verification.
library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;

const _marker = 'MHS_OK:';

void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln('Usage: dart tool/encrypt_assets.dart <passphrase>');
    exit(1);
  }

  final passphrase = args.join(' ');
  final keyBytes = sha256.convert(utf8.encode(passphrase)).bytes;
  final key = enc.Key.fromBase64(base64.encode(keyBytes));
  final iv = enc.IV.fromSecureRandom(16);
  final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));

  const files = ['mhs-001.en.md', 'mhs-001.hr.md'];

  for (final file in files) {
    final source = File(file);
    if (!source.existsSync()) {
      stderr.writeln('ERROR: $file not found');
      exit(1);
    }

    final plaintext = '$_marker${source.readAsStringSync()}';
    final encrypted = encrypter.encrypt(plaintext, iv: iv);

    // Store IV + ciphertext as base64
    final combined = <int>[...iv.bytes, ...encrypted.bytes];
    final outName = file.replaceAll('.md', '.enc');
    File('assets/$outName').writeAsStringSync(base64.encode(combined));

    stdout.writeln('✓ $file → assets/$outName (${combined.length} bytes encrypted)');
  }

  stdout.writeln('\nDone. Passphrase SHA-256: ${sha256.convert(utf8.encode(passphrase))}');
}
