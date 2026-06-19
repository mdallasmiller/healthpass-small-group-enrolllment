import 'dart:math';

/// Generates a short, human-friendly access code (no ambiguous characters).
String generateAccessCode([int length = 6]) {
  const chars = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  final rand = Random.secure();
  return List.generate(length, (_) => chars[rand.nextInt(chars.length)]).join();
}

/// The branded domain the enrollment portal is served from. Invite links sent
/// over SMS/email must use this (carriers filter generic *.web.app links).
const String kEnrollBaseUrl = 'https://enrollment.joinhealthpass.com';

/// Builds the per-employee enrollment URL on the branded domain.
String buildEnrollUrl(String origin, String groupId, String employeeId) {
  return '$origin/?g=$groupId&e=$employeeId';
}
