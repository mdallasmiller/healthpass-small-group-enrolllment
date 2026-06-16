import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthpass_enroll/models/group.dart';
import 'package:healthpass_enroll/utils/pricing.dart';
import 'package:healthpass_enroll/utils/reports.dart';
import 'package:healthpass_enroll/utils/roster_import.dart';

void main() {
  group('CSV imports', () {
    test('parseRosterCsv: First/Last/Email/Phone, header skipped', () {
      const csv = 'First Name,Last Name,Email,Phone\n'
          'Jane,Doe,jane@test.com,5035551234\n'
          'John,Smith,john@test.com,\n';
      final emps = parseRosterCsv(utf8.encode(csv));
      expect(emps.length, 2); // header row skipped (no @ in "Email")
      expect(emps[0].firstName, 'Jane');
      expect(emps[0].phone, '5035551234');
      expect(emps[1].lastName, 'Smith');
    });

    test('parseRosterCsv: skips rows without a valid email', () {
      const csv = 'First Name,Last Name,Email,Phone\n'
          'NoEmail,Person,not-an-email,123\n'
          'Real,Person,real@test.com,123\n';
      final emps = parseRosterCsv(utf8.encode(csv));
      expect(emps.length, 1);
      expect(emps.single.firstName, 'Real');
    });

    test('parseCensusCsv: full BenefitZone mapping + eligible', () {
      const csv =
          'SSN,First Name,Middle Name,Last Name,Birthdate,Gender,Date of Hire,'
          'Tobacco Use Y/N,Mobile Phone #,Home Phone #,Email,Address,City,State,'
          'Zip Code,Job Titles,Benefit Class,Employment Status (PT or FT)\n'
          '111-22-3333,Sarah,J,Connor,03/15/1985,Female,01/10/2020,No,5035551234,,'
          'sarah@test.com,500 Pine St,Salem,OR,97301,Manager,Eligible,Full-Time\n';
      final emps = parseCensusCsv(utf8.encode(csv));
      expect(emps.length, 1);
      final s = emps.single;
      expect(s.firstName, 'Sarah');
      expect(s.middleName, 'J');
      expect(s.lastName, 'Connor');
      expect(s.ssn, '111-22-3333');
      expect(s.dob, '03/15/1985');
      expect(s.gender, 'Female');
      expect(s.dateOfHire, '01/10/2020');
      expect(s.tobacco, 'No');
      expect(s.mobilePhone, '5035551234');
      expect(s.email, 'sarah@test.com');
      expect(s.addressLine1, '500 Pine St');
      expect(s.city, 'Salem');
      expect(s.state, 'OR');
      expect(s.zip, '97301');
      expect(s.employmentStatus, 'Full-Time');
      expect(s.eligible, isTrue);
    });

    test('parseCensusCsv: Ineligible benefit class -> eligible=false', () {
      const csv =
          'SSN,First Name,Middle Name,Last Name,Birthdate,Gender,Date of Hire,'
          'Tobacco Use Y/N,Mobile Phone #,Home Phone #,Email,Address,City,State,'
          'Zip Code,Job Titles,Benefit Class,Employment Status (PT or FT)\n'
          '222-33-4444,Mike,,Smith,07/20/1978,Male,02/01/2019,Yes,5035555678,,'
          'mike@test.com,12 Oak Ave,Salem,OR,97302,Tech,Ineligible,Part-Time\n';
      final m = parseCensusCsv(utf8.encode(csv)).single;
      expect(m.eligible, isFalse);
      expect(m.employmentStatus, 'Part-Time');
      expect(m.tobacco, 'Yes');
    });

    test('parseCensusCsv: header mapping is order-independent', () {
      const csv = 'Email,Last Name,First Name,SSN,DOB\n'
          'z@test.com,Zed,Amy,999-88-7777,12/01/1990\n';
      final e = parseCensusCsv(utf8.encode(csv)).single;
      expect(e.firstName, 'Amy');
      expect(e.lastName, 'Zed');
      expect(e.ssn, '999-88-7777');
      expect(e.dob, '12/01/1990');
    });
  });

  group('Age + tier helpers', () {
    test('ageFromDob parses MM/DD/YYYY', () {
      expect(ageFromDob('03/15/1985', asOf: DateTime(2026, 6, 16)), 41);
      expect(ageFromDob('06/16/2000', asOf: DateTime(2026, 6, 16)), 26);
      expect(ageFromDob('bad'), isNull);
    });
    test('ageBandFor buckets correctly', () {
      expect(ageBandFor(25), '18-29');
      expect(ageBandFor(41), '40-49');
      expect(ageBandFor(70), '60-64');
    });
    test('determineTier4 maps dependents', () {
      expect(determineTier4(false, 0), Tier4.employeeOnly);
      expect(determineTier4(true, 0), Tier4.spouse);
      expect(determineTier4(false, 2), Tier4.child);
      expect(determineTier4(true, 1), Tier4.family);
    });
  });

  group('Defined contribution pricing', () {
    final g = Group.empty().copyWith(
      contributionMode: ContributionMode.definedContribution,
      definedContribution: DefinedContribution.standard(),
    );
    test('standard table loaded (40-49 / 2500 / EO = 290)', () {
      expect(definedContributionGross(g, 41, Tier4.employeeOnly, '2500'), 290);
    });
    test('employer contribution (\$159) subtracted', () {
      // 290 - 159 = 131
      expect(definedContributionDeduction(g, 41, Tier4.employeeOnly, '2500'), 131);
    });
    test('never goes below 0', () {
      final cheap = Group.empty().copyWith(
        definedContribution: const DefinedContribution(
          employerContribution: 9999,
          rates: {
            '18-29': {'2500': Tier4Rates(employeeOnly: 100)},
          },
        ),
      );
      expect(definedContributionDeduction(cheap, 25, Tier4.employeeOnly, '2500'), 0);
    });
  });

  group('Dental contribution modes', () {
    final voluntary = Group.empty().copyWith(
      dental: const DentalConfig(
        enabled: true,
        option: DentalOption.coop2500,
        rates: Tier4Rates(employeeOnly: 35, spouse: 70, child: 75, family: 100),
      ),
    );
    test('Voluntary: employee pays the tier rate', () {
      expect(dentalMonthly(voluntary, Tier4.employeeOnly), 35);
      expect(dentalMonthly(voluntary, Tier4.family), 100);
    });
    test('Company Contribution subtracts from tier rate', () {
      final company = voluntary.copyWith(
        dental: voluntary.dental.copyWith(
          contributionMode: DentalContributionMode.companyContribution,
          companyContribution: 20,
        ),
      );
      expect(dentalMonthly(company, Tier4.employeeOnly), 15); // 35 - 20
      expect(dentalMonthly(company, Tier4.family), 80); // 100 - 20
    });
    test('plan name for export', () {
      expect(voluntary.dental.planName, 'Coop Dental 2500');
      expect(
          voluntary.dental.copyWith(option: DentalOption.coop1500).planName,
          'Coop Dental 1500');
    });
    test('disabled dental costs 0', () {
      final off = voluntary.copyWith(dental: voluntary.dental.copyWith(enabled: false));
      expect(dentalMonthly(off, Tier4.family), 0);
    });
  });

  group('Pay-period conversion', () {
    test('bi-weekly from monthly', () {
      final g = Group.empty().copyWith(payFrequency: PayFrequency.biWeekly);
      expect(perPayPeriod(g, 650).toStringAsFixed(2), '300.00'); // 650*12/26
    });
  });

  group('Deduction report matches template', () {
    final enrollment = {
      'employee': {
        'employmentStatus': 'Full-Time',
        'eligible': true,
        'mobilePhone': '5035551234',
        'email': 'jane@test.com',
      },
      'data': {
        'personal': {
          'firstName': 'Jane', 'lastName': 'Doe', 'dob': '03/15/1985',
          'ssn': '111-22-3333', 'sex': 'Female', 'tobaccoUser': false,
          'addressLine1': '1 Pine St', 'city': 'Salem', 'state': 'OR', 'zip': '97301',
        },
        'dependents': {'spouse': null, 'children': []},
        'medical': {
          'plan': 'preventiveCooperative', 'level': '2500', 'tier': 'employeeOnly',
          'monthly': 300, 'tobaccoSurcharge': 0,
        },
        'dental': {
          'enrolled': true, 'tier': 'employeeOnly',
          'planName': 'Coop Dental 2500', 'monthly': 353,
        },
        'tobaccoSurcharge': {'total': 0, 'payer': 'company'},
        'ichra': {'interested': false},
        'acknowledgements': {'tobacco': true, 'preEx': true},
        'totals': {'monthly': 653, 'perPayPeriod': 301.38, 'payFrequency': 'biWeekly'},
      },
    };

    test('columns, money format and labels', () {
      final rows = deductionRows([enrollment]);
      expect(rows.length, 1);
      final r = rows.first;
      expect(r[0], 'Jane Doe');
      expect(r[1], 'Bundle (Preventive + Co-op)');
      expect(r[2], 'Employee Only');
      expect(r[3], '\$300.00'); // money $X.00
      expect(r[4], '-'); // no surcharge -> dash
      expect(r[5], 'Coop Dental 2500');
      expect(r[6], 'Employee Only');
      expect(r[7], '\$353.00');
      expect(r[8], '\$653.00');
      expect(r[9], 'Bi-weekly (26)'); // pay frequency with count
    });

    test('CSV has the template header', () {
      final csv = deductionCsv([enrollment]);
      expect(csv.startsWith(
          'Employee,Medical Plan,Medical Plan - Tier,Medical Plan - Monthly Employee Cost'),
          isTrue);
    });
  });

  group('Census export matches elections template', () {
    final ineligible = {
      'employee': {'employmentStatus': 'Part-Time', 'eligible': false, 'email': 'm@t.com'},
      'data': {
        'personal': {
          'firstName': 'Mike', 'lastName': 'Smith', 'ssn': '222-33-4444',
          'dob': '07/20/1978', 'sex': 'Male', 'tobaccoUser': true,
        },
        'dependents': {'spouse': null, 'children': []},
        'medical': {'plan': 'preventiveOnly', 'tier': 'employeeOnly'},
        'dental': {'enrolled': false},
        'ichra': {'interested': false},
        'acknowledgements': {},
        'totals': {},
        'tobaccoSurcharge': {},
      },
    };
    test('employee row: group, hours, status, sex', () {
      final rows = censusRows('Test Co', [ineligible]);
      final r = rows.first;
      expect(r[0], 'Test Co');
      expect(r[4], 'Employee'); // relationship
      expect(r[5], 'Part-Time'); // hours
      expect(r[6], 'Not Eligible'); // status from eligible=false
      expect(r[9], 'Male'); // sex
      expect(r[10], 'Yes'); // tobacco
    });
    test('CSV header has the elections columns', () {
      final csv = censusCsv('Test Co', [ineligible]);
      expect(csv.startsWith('Group Name,First Name,Middle Name,Last Name,Relationship,Hours,Status,SSN,DOB,Sex,Tobacco'),
          isTrue);
    });
  });
}
