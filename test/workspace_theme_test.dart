import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaysons_logistics/core/theme/app_theme.dart';

void main() {
  testWidgets('status and filter labels contrast against light chip surfaces', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: Wrap(
            children: [
              const Chip(label: Text('POD pending')),
              ChoiceChip(
                label: const Text('Selected'),
                selected: true,
                onSelected: (_) {},
              ),
              ChoiceChip(
                label: const Text('Available'),
                selected: false,
                onSelected: (_) {},
              ),
            ],
          ),
        ),
      ),
    );
    for (final label in ['POD pending', 'Selected', 'Available']) {
      final color =
          DefaultTextStyle.of(tester.element(find.text(label))).style.color!;
      expect(color.computeLuminance(), lessThan(.15), reason: label);
    }
    expect(tester.takeException(), isNull);
  });
}
