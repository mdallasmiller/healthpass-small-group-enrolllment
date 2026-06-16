import 'dart:convert';
import 'package:csv/csv.dart';
import '../models/employee.dart';
import 'codes.dart';

/// Parses a simple Enrollment Roster CSV: First Name, Last Name, Email, Phone.
/// A header row is auto-detected and skipped (email must look like an address).
List<Employee> parseRosterCsv(List<int> bytes) {
  final text = utf8.decode(bytes, allowMalformed: true);
  final rows =
      const CsvToListConverter(eol: '\n', shouldParseNumbers: false).convert(text);
  final out = <Employee>[];
  for (final row in rows) {
    if (row.length < 3) continue;
    final first = row[0].toString().trim();
    final last = row[1].toString().trim();
    final email = row[2].toString().trim();
    final phone = row.length > 3 ? row[3].toString().trim() : '';
    if (!email.contains('@') || !email.contains('.')) continue; // skips header
    if (first.isEmpty && last.isEmpty) continue;
    out.add(Employee(
      firstName: first,
      lastName: last,
      email: email,
      phone: phone,
      accessCode: generateAccessCode(),
    ));
  }
  return out;
}

/// Parses a rich Enrollment Census CSV (BenefitZone-style) into employees,
/// mapping columns by header name. Marks benefit-class "ineligible" rows.
List<Employee> parseCensusCsv(List<int> bytes) {
  final text = utf8.decode(bytes, allowMalformed: true);
  final rows =
      const CsvToListConverter(eol: '\n', shouldParseNumbers: false).convert(text);
  if (rows.isEmpty) return [];
  final header = rows.first.map((c) => c.toString().trim().toLowerCase()).toList();
  int col(List<String> aliases) {
    for (var i = 0; i < header.length; i++) {
      for (final a in aliases) {
        if (header[i] == a || header[i].contains(a)) return i;
      }
    }
    return -1;
  }

  final cSsn = col(['ssn', 'social']);
  final cFirst = col(['first name', 'first']);
  final cMiddle = col(['middle']);
  final cLast = col(['last name', 'last']);
  final cDob = col(['birthdate', 'date of birth', 'dob', 'birth']);
  final cGender = col(['gender', 'sex']);
  final cHire = col(['date of hire', 'hire']);
  final cTobacco = col(['tobacco']);
  final cMobile = col(['mobile']);
  final cHome = col(['home phone']);
  final cPhone = col(['phone']);
  final cEmail = col(['email']);
  final cAddr = col(['address']);
  final cCity = col(['city']);
  final cState = col(['state']);
  final cZip = col(['zip']);
  final cJob = col(['job']);
  final cBenefit = col(['benefit class']);
  final cEmp = col(['employment status', 'employee status', 'pt or ft', 'full-time']);

  String at(List row, int i) =>
      (i >= 0 && i < row.length) ? row[i].toString().trim() : '';

  final out = <Employee>[];
  for (var r = 1; r < rows.length; r++) {
    final row = rows[r];
    final first = at(row, cFirst);
    final last = at(row, cLast);
    if (first.isEmpty && last.isEmpty) continue;
    final benefit = at(row, cBenefit);
    final bl = benefit.toLowerCase();
    final eligible = !(bl.contains('not eligible') || bl.contains('ineligible'));
    final mobile = at(row, cMobile);
    out.add(Employee(
      firstName: first,
      middleName: at(row, cMiddle),
      lastName: last,
      email: at(row, cEmail),
      phone: mobile.isNotEmpty ? mobile : at(row, cPhone),
      accessCode: generateAccessCode(),
      ssn: at(row, cSsn),
      dob: at(row, cDob),
      gender: at(row, cGender),
      dateOfHire: at(row, cHire),
      tobacco: at(row, cTobacco),
      mobilePhone: mobile,
      homePhone: at(row, cHome),
      addressLine1: at(row, cAddr),
      city: at(row, cCity),
      state: at(row, cState),
      zip: at(row, cZip),
      jobTitle: at(row, cJob),
      benefitClass: benefit,
      employmentStatus: at(row, cEmp),
      eligible: eligible,
    ));
  }
  return out;
}
