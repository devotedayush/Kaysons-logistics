import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:kaysons_logistics/features/admin/admin_ai_service.dart';

void main() {
  test('repairs compact AI markdown tables before rendering', () {
    final response = ClawdResponse.fromData({
      'answer':
          'Highest routes: | Rank | Route | Freight per MT | POD pending | '
          '|---:|---|---:|---:| | 1 | Ludhiana to Jammu | 2316.72 | 0 | '
          '| 2 | Ludhiana to Pathankot | 1803.46 | 3 | Check the bills.',
    });

    expect(
      response.answer,
      contains(
        'Highest routes:\n| Rank | Route | Freight per MT | POD pending |\n'
        '|---:|---|---:|---:|\n'
        '| 1 | Ludhiana to Jammu | 2316.72 | 0 |\n'
        '| 2 | Ludhiana to Pathankot | 1803.46 | 3 |\n'
        'Check the bills.',
      ),
    );
  });

  test('keeps empty table cells in their original row', () {
    final response = ClawdResponse.fromData({
      'answer':
          '| Rank | Route | MT | POD pending | |---:|---|---:|---:| '
          '| 1 | Ludhiana to Jammu | | 3 |',
    });

    expect(
      response.answer,
      '| Rank | Route | MT | POD pending |\n'
      '|---:|---|---:|---:|\n'
      '| 1 | Ludhiana to Jammu | | 3 |',
    );
  });

  testWidgets('normalized AI output renders as a markdown table', (
    tester,
  ) async {
    final response = ClawdResponse.fromData({
      'answer':
          'Highest routes: | Rank | Route | Freight per MT | Dispatches | MT | POD pending | '
          '|---:|---|---:|---:|---:|---:| '
          '| 1 | Ludhiana to Jammu | 2316.72 | 4 | 32.805 | 0 | '
          '| 2 | Ludhiana to Pathankot | 1803.46 | 22 | 97.623 | 7 |',
    });

    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: MarkdownBody(data: response.answer))),
    );

    expect(find.byType(Table), findsOneWidget);
    expect(find.text('Rank'), findsOneWidget);
    expect(find.text('Ludhiana to Jammu'), findsOneWidget);
    expect(find.text('Ludhiana to Pathankot'), findsOneWidget);
  });

  test('formats a JSON-encoded monthly report as readable markdown', () {
    final report = ClawdDailyReport.fromData({
      'report': {
        'period_end': '2026-04-30',
        'summary': jsonEncode({
          'summary':
              '### Monthly Clawd Operations Report\n\nOverall: Documentation delays are elevated.',
          'risk_level': 'critical',
          'risk_score': 88,
          'business_impact':
              '- Cashflow risk from 164 shipments.\n- Margin risk on costly routes.',
          'evidence_summary':
              '### E-way risk\n\n- Two duplicate e-way bills need review.',
          'recommended_actions': [
            'Collect pending PODs.',
            'Validate high-cost routes.',
          ],
          'follow_up_questions': ['Which PODs are oldest?'],
        }),
      },
    });

    expect(report.summary, contains('### Monthly Clawd Operations Report'));
    expect(report.summary, contains('**Critical risk · 88/100**'));
    expect(report.summary, contains('## Business impact'));
    expect(report.summary, contains('## Recommended actions'));
    expect(report.summary, contains('- Collect pending PODs.'));
    expect(report.summary, isNot(contains('{"summary"')));
    expect(report.summary, isNot(contains(r'\n')));
  });
}
