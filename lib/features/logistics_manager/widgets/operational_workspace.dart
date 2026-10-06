import 'package:flutter/material.dart';

/// A comfortable reading width with room for phone keyboards and primary actions.
class OperationalListView extends StatelessWidget {
  const OperationalListView({
    super.key,
    required this.children,
    this.padding,
    this.controller,
    this.physics,
    this.shrinkWrap = false,
  });
  final List<Widget> children;
  final EdgeInsetsGeometry? padding;
  final ScrollController? controller;
  final ScrollPhysics? physics;
  final bool shrinkWrap;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, size) {
      final gutter = size.maxWidth < 600 ? 16.0 : 32.0;
      final side = ((size.maxWidth - 1120) / 2).clamp(gutter, double.infinity);
      return ListView(
        controller: controller,
        physics: physics,
        shrinkWrap: shrinkWrap,
        padding: EdgeInsets.fromLTRB(side, 24, side, 96),
        children: children,
      );
    },
  );
}

class OperationalStep extends StatelessWidget {
  const OperationalStep(this.number, this.title, this.description, {super.key});
  final String number, title, description;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 24, bottom: 16),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(number, style: Theme.of(context).textTheme.titleMedium),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(description, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
      ],
    ),
  );
}

/// Optional inputs stay editable while the main task remains easy to scan.
class OperationalOptional extends StatelessWidget {
  const OperationalOptional({
    super.key,
    required this.title,
    required this.children,
    this.initiallyExpanded = false,
  });
  final String title;
  final List<Widget> children;
  final bool initiallyExpanded;
  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.symmetric(vertical: 12),
    child: ExpansionTile(
      maintainState: true,
      initiallyExpanded: initiallyExpanded,
      tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      leading: const Icon(Icons.tune),
      title: Text(title),
      children: children,
    ),
  );
}

/// Fields stack on phones and share a row on larger workspaces.
class OperationalFields extends StatelessWidget {
  const OperationalFields({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, size) {
      if (size.maxWidth >= 600 || children.whereType<Expanded>().length < 2) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final child in children)
            if (child is Expanded)
              child.child
            else if (child is Flexible)
              child.child
            else if (child is SizedBox && child.width != null)
              const SizedBox(height: 12)
            else
              child,
        ],
      );
    },
  );
}

String operationalCopy(BuildContext context, String english, String hindi) =>
    Localizations.localeOf(context).languageCode == 'hi' ? hindi : english;

class OperationalCardGrid extends StatelessWidget {
  const OperationalCardGrid({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, size) {
      final width =
          size.maxWidth >= 900 ? (size.maxWidth - 16) / 2 : size.maxWidth;
      return Wrap(
        spacing: 16,
        runSpacing: 16,
        children: [
          for (final child in children) SizedBox(width: width, child: child),
        ],
      );
    },
  );
}
