import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaysons_logistics/features/delivery/delivery_workflow_panel.dart';
import 'package:kaysons_logistics/l10n/app_localizations.dart';

const freight = <String, dynamic>{
  'id': 'freight-1',
  'delivery_workflow_version': 1,
  'status': 'dispatched',
  'origin': 'Delhi',
  'destination_town': 'Ludhiana',
  'stop_details': [
    {'name': 'Moga'},
    {'name': 'Ludhiana'},
  ],
};

List<Map<String, dynamic>> receivers({bool reported = false}) => [
  {
    'id': 'receiver-a',
    'stop_index': 0,
    'town': 'Moga',
    'party_name': 'Alpha Stores',
    'planned_cases': 40,
    'planned_weight_mt': 1.2,
    'gr_numbers': ['GR-A'],
    'pod_review_status': 'pending',
    if (reported)
      'report': {
        'outcome': 'full',
        'recipient_name': 'Raj',
        'recipient_phone': '9876543210',
        'delivered_at': '2026-10-04T08:00:00Z',
        'submitted_at': '2026-10-04T08:30:00Z',
        'proof_paths': ['user/freight/alpha.pdf'],
      },
  },
  {
    'id': 'receiver-b',
    'stop_index': 0,
    'town': 'Moga',
    'party_name': 'Beta Stores',
    'planned_cases': 20,
    'planned_weight_mt': .6,
    'lr_numbers': ['LR-B'],
    'pod_review_status': 'pending',
    if (reported)
      'report': {
        'outcome': 'partial',
        'recipient_name': 'Simran',
        'cases_received': 18,
        'weight_received_mt': .5,
        'cases_damaged': 2,
        'discrepancy_reason': 'Two damaged cases',
        'delivered_at': '2026-10-04T09:00:00Z',
        'submitted_at': '2026-10-04T09:30:00Z',
        'proof_paths': ['user/freight/beta.jpg'],
      },
  },
  {
    'id': 'receiver-c',
    'stop_index': 1,
    'town': 'Ludhiana',
    'party_name': 'Gamma Stores',
    'pod_review_status': 'pending',
  },
];

const expenses = [
  <String, dynamic>{
    'id': 'expense-1',
    'receiver_id': 'receiver-b',
    'kind': 'labour',
    'amount': 250,
    'status': 'pending',
    'reason': 'Unloading labour',
    'submitted_at': '2026-10-04T09:40:00Z',
  },
];

Future<void> pumpPanel(
  WidgetTester tester, {
  bool office = false,
  bool readOnly = false,
  bool canEditPlan = true,
  bool canApproveExpenses = true,
  bool reported = false,
  String locale = 'en',
  Map<String, dynamic> trip = freight,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: Locale(locale),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: Scaffold(
        body: SingleChildScrollView(
          child: DeliveryWorkflowPanel(
            freight: trip,
            office: office,
            readOnly: readOnly,
            canEditPlan: canEditPlan,
            canApproveExpenses: canApproveExpenses,
            loadData: () async => [receivers(reported: reported), [], expenses],
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> revealExpense(WidgetTester tester) async {
  final tile = find.widgetWithText(ExpansionTile, 'Labour · ₹250');
  await tester.ensureVisible(tile);
  await tester.tap(tile);
  await tester.pumpAndSettle();
}

Future<void> openReport(
  WidgetTester tester, {
  String label = 'Report delivery',
}) async {
  final button = find.widgetWithText(FilledButton, label).first;
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'customers in one town keep distinct quantities references and reports',
    (tester) async {
      await pumpPanel(tester, reported: true, readOnly: true);
      expect(find.text('1. Moga · Alpha Stores'), findsOneWidget);
      expect(find.text('1. Moga · Beta Stores'), findsOneWidget);
      expect(find.text('2. Ludhiana · Gamma Stores'), findsOneWidget);
      expect(find.text('2/3 customers reported'), findsOneWidget);
      expect(find.text('0/3 PODs accepted'), findsOneWidget);
      expect(find.text('40 cases · 1.2 MT'), findsOneWidget);
      expect(find.text('20 cases · 0.6 MT'), findsOneWidget);
      expect(find.text('GR-A'), findsOneWidget);
      expect(find.text('LR-B'), findsOneWidget);
      expect(find.text('Cases not accepted'), findsOneWidget);
      expect(find.text('2'), findsWidgets);
      expect(find.text('Full delivery'), findsOneWidget);
      expect(find.text('Partial delivery'), findsOneWidget);
      expect(find.text('POD 1'), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'read-only dispatch role sees evidence but no edit submit or review controls',
    (tester) async {
      await pumpPanel(tester, office: true, readOnly: true, reported: true);
      await revealExpense(tester);
      for (final label in [
        'Edit customers & references',
        'Add journey update',
        'Report delivery',
        'Update report / upload POD',
        'Submit expense',
        'Accept POD',
        'Request correction',
        'Approve expense',
        'Reject',
      ]) {
        expect(find.text(label), findsNothing, reason: label);
      }
      expect(find.text('Unloading labour'), findsOneWidget);
      expect(find.text('Beta Stores (Moga)'), findsOneWidget);
      expect(find.text('POD 1'), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'transporter can report and claim but cannot change office references or review',
    (tester) async {
      await pumpPanel(tester);
      expect(find.text('Report delivery'), findsNWidgets(3));
      expect(find.text('Add journey update'), findsOneWidget);
      expect(find.text('Submit expense'), findsOneWidget);
      await revealExpense(tester);
      for (final label in [
        'Edit customers & references',
        'Accept POD',
        'Request correction',
        'Approve expense',
        'Reject',
      ]) {
        expect(find.text(label), findsNothing);
      }
    },
  );

  testWidgets(
    'office reviews full POD but cannot accept an unresolved shortfall',
    (tester) async {
      await pumpPanel(tester, office: true, reported: true);
      final accepts =
          tester
              .widgetList<FilledButton>(
                find.widgetWithText(FilledButton, 'Accept POD'),
              )
              .toList();
      expect(accepts, hasLength(2));
      expect(accepts[0].onPressed, isNotNull);
      expect(accepts[1].onPressed, isNull);
      final edit = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, 'Edit customers & references'),
      );
      expect(
        edit.onPressed,
        isNull,
        reason: 'Reported customer references must not be rewritten',
      );
      expect(find.text('Request correction'), findsNWidgets(2));
      expect(find.text('Report delivery'), findsNothing);
      await revealExpense(tester);
      expect(find.text('Approve expense'), findsOneWidget);
      expect(find.text('Reject'), findsOneWidget);
    },
  );

  testWidgets(
    'limited office permissions hide plan and expense approval actions',
    (tester) async {
      await pumpPanel(
        tester,
        office: true,
        canEditPlan: false,
        canApproveExpenses: false,
      );
      expect(find.text('Edit customers & references'), findsNothing);
      await revealExpense(tester);
      expect(find.text('Approve expense'), findsNothing);
      expect(find.text('Reject'), findsNothing);
    },
  );

  testWidgets(
    'delivery modal starts full and reveals discrepancy fields only when needed',
    (tester) async {
      await pumpPanel(tester);
      await openReport(tester);
      expect(find.text('Alpha Stores · Moga'), findsOneWidget);
      expect(find.text('Receiver name'), findsOneWidget);
      expect(find.text('Cases accepted'), findsNothing);
      expect(find.text('Reason for shortfall / failed attempt'), findsNothing);
      expect(find.text('Proof of delivery (image or PDF)'), findsOneWidget);
      final dropdown = find.byType(DropdownButtonFormField<String>);
      await tester.ensureVisible(dropdown);
      await tester.tap(dropdown);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Partial delivery').last);
      await tester.pumpAndSettle();
      for (final field in [
        'Cases accepted',
        'Weight accepted (MT, if known)',
        'Damaged cases (optional)',
        'Rejected cases (optional)',
        'Reason for shortfall / failed attempt',
      ]) {
        expect(find.text(field), findsOneWidget);
      }
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
      expect(find.text('Required'), findsNWidgets(3));
      await tester.ensureVisible(dropdown);
      await tester.tap(dropdown);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Full delivery').last);
      await tester.pumpAndSettle();
      expect(find.text('Cases accepted'), findsNothing);
      expect(find.text('Reason for shortfall / failed attempt'), findsNothing);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('missing route towns disable journey entry instead of crashing', (
    tester,
  ) async {
    await pumpPanel(
      tester,
      trip: {
        ...freight,
        'stop_details': [],
        'stops': [],
        'destination_town': '',
      },
    );
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Add journey update'),
    );
    expect(button.onPressed, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('transporter writes remain disabled before vehicle dispatch', (
    tester,
  ) async {
    await pumpPanel(tester, trip: {...freight, 'status': 'accepted'});
    for (final label in ['Report delivery', 'Add journey update']) {
      for (final button in tester.widgetList<FilledButton>(
        find.widgetWithText(FilledButton, label),
      )) {
        expect(button.onPressed, isNull, reason: label);
      }
    }
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'Submit expense'),
          )
          .onPressed,
      isNull,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('switching trip IDs refreshes the receiving customer data', (
    tester,
  ) async {
    var loads = 0;
    Future<void> showTrip(String id) async {
      await tester.pumpWidget(
        MaterialApp(
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Scaffold(
            body: SingleChildScrollView(
              child: DeliveryWorkflowPanel(
                freight: {...freight, 'id': id},
                readOnly: true,
                loadData: () async {
                  loads++;
                  return [
                    [
                      {
                        'id': '$id-receiver',
                        'stop_index': 0,
                        'town': 'Moga',
                        'party_name': id,
                      },
                    ],
                    [],
                    [],
                  ];
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    await showTrip('first');
    expect(find.text('1. Moga · first'), findsOneWidget);
    await showTrip('second');
    expect(loads, 2);
    expect(find.text('1. Moga · second'), findsOneWidget);
    expect(find.text('1. Moga · first'), findsNothing);
  });

  testWidgets('Hindi mobile report remains usable with larger system text', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(390, 844)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpPanel(tester, locale: 'hi');
    expect(find.text('डिलीवरी का सार'), findsOneWidget);
    expect(find.text('0/3 ग्राहकों की रिपोर्ट'), findsOneWidget);
    await openReport(tester, label: 'डिलीवरी रिपोर्ट करें');
    expect(find.text('प्राप्तकर्ता का नाम'), findsOneWidget);
    expect(find.text('स्वीकृत केस'), findsNothing);
    expect(find.text('सहेजें').hitTestable(), findsOneWidget);
    expect(find.text('रद्द करें').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('रद्द करें'));
    await tester.pumpAndSettle();
  });
}
