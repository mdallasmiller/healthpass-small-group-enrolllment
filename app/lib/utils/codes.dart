import 'dart:math';

/// Generates a short, human-friendly access code (no ambiguous characters).
String generateAccessCode([int length = 6]) {
  const chars = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  final rand = Random.secure();
  return List.generate(length, (_) => chars[rand.nextInt(chars.length)]).join();
}

/// Builds the per-employee enrollment URL from the current web origin.
String buildEnrollUrl(String origin, String groupId, String employeeId) {
  return '$origin/?g=$groupId&e=$employeeId';
}
