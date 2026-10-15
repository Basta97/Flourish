import 'dart:convert';
import 'package:cryptography/cryptography.dart';

/// Hex SHA-256 of [text]; used to recognise the same import or message twice.
Future<String> fingerprint(String text) async => (await Sha256().hash(
  utf8.encode(text),
)).bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
