@TestOn('chrome')
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthpass_enroll/models/employee.dart';
import 'package:healthpass_enroll/models/group.dart';
import 'package:healthpass_enroll/screens/enroll_portal.dart';

Group _testGroup() => Group.empty().copyWith(
      name: 'Test Co',
      ichraEnabled: true,
      offeredLevels: ['1000', '2500'], // $4K NOT offered
      medicalRates: {
        for (final l in kCoopLevels)
          l: const TierRates(employeeOnly: 300, spouseChild: 500, family: 700),
      },
      dental: const DentalConfig(
        enabled: true,
        option: DentalOption.coop2500,
        rates: Tier4Rates(employeeOnly: 35, spouse: 70, child: 75, family: 100),
      ),
      details: const GroupDetails(
        healthDescription: '## Health\nSome copy.',
        healthVideoUrl: 'https://youtu.be/abc12345678',
        preventiveDescription: '## Preventive',
      ),
    );

void main() {
  testWidgets('Demographics page renders the new fields', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: EnrollPortal(
        group: _testGroup(),
        employee: Employee(firstName: 'Sarah', lastName: 'Connor', email: 's@t.com'),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Demographic information'), findsOneWidget);
    expect(find.text('Sex'), findsOneWidget);
    expect(find.text('Male'), findsOneWidget);
    expect(find.text('Female'), findsOneWidget);
    expect(find.text('Address'), findsOneWidget);
    expect(find.text('Line two (optional)'), findsOneWidget);
    expect(find.text('Zip code'), findsOneWidget);
    // New tobacco copy + security cue
    expect(find.textContaining('vapes, chew, and smoked marijuana'), findsOneWidget);
    expect(find.textContaining('encrypted'), findsOneWidget);
  });

  testWidgets('Continue blocks on missing required fields (validation runs)',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: EnrollPortal(
        group: _testGroup(),
        employee: Employee(firstName: 'Sarah', lastName: 'Connor', email: 's@t.com'),
      ),
    ));
    await tester.pumpAndSettle();

    // DOB/SSN/address empty -> tapping Continue must NOT advance.
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    // Still on Demographics; validation messages visible.
    expect(find.text('Demographic information'), findsOneWidget);
    expect(find.text('Required'), findsWidgets);
  });

  testWidgets('Full flow: fill demographics -> Coverage shows offered levels + Read More/Watch Video',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: EnrollPortal(
        group: _testGroup(),
        employee: Employee(firstName: 'Sarah', lastName: 'Connor', email: 's@t.com'),
      ),
    ));
    await tester.pumpAndSettle();

    Future<void> fill(String label, String value) async {
      // The label is a sibling of the field inside the same LabeledField.
      await tester.enterText(
          find.descendant(of: _labeled(label), matching: find.byType(TextFormField)),
          value);
    }

    await fill('Date of birth', '03/15/1985');
    await fill('Social Security Number', '111223333');
    await fill('Address', '500 Pine St');
    await fill('City', 'Salem');
    await fill('State', 'OR');
    await fill('Zip code', '97301');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    // Now on Coverage.
    expect(find.text('Health coverage'), findsOneWidget);
    expect(find.text('Read More'), findsWidgets);
    expect(find.text('Watch Video'), findsWidgets);
    // Choose the cooperative plan to reveal deductible levels.
    await tester.tap(find.text('Preventive + Cooperative Bundle'));
    await tester.pumpAndSettle();
    // Offered levels only: $1K and $2.5K present, $4K absent.
    expect(find.text('\$1K'), findsOneWidget);
    expect(find.text('\$2.5K'), findsOneWidget);
    expect(find.text('\$4K'), findsNothing);
  });
}

/// Finds the LabeledField (a Column) that contains [label].
Finder _labeled(String label) => find.ancestor(
      of: find.text(label),
      matching: find.byWidgetPredicate((w) => w is Column),
    ).first;
