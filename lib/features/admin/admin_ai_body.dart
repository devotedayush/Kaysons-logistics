import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import 'admin_ai_service.dart';

const _onSurface = Color(0xFF1D1B20);
const _onSurfaceVariant = Color(0xFF49454F);

class AdminAiBody extends StatefulWidget {
  const AdminAiBody({super.key});

  @override
  State<AdminAiBody> createState() => _AdminAiBodyState();
}

class _AdminAiBodyState extends State<AdminAiBody> {
  final _question = TextEditingController();
  final _variables = TextEditingController(text: '{}');
  final List<_ClawdMessage> _messages = [
    const _ClawdMessage(
      fromClawd: true,
      text:
          'I am Clawd. I read the backend ledger facts, explain risks, and store every report for audit.',
    ),
  ];

  bool _loading = true;
  bool _asking = false;
  bool _reporting = false;
  bool _detecting = false;
  ClawdDailyReport? _latestReport;
  List<ClawdPromptTemplate> _templates = const [];
  List<ClawdStoredReport> _reports = const [];
  List<ClawdAnomaly> _anomalies = const [];
  ClawdPromptTemplate? _selectedTemplate;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _question.dispose();
    _variables.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    try {
      final service = AdminAiService.instance;
      final results = await Future.wait([
        service.loadPromptTemplates(),
        service.loadReports(),
        service.loadAnomalies(),
      ]);
      if (!mounted) return;
      final templates = results[0] as List<ClawdPromptTemplate>;
      setState(() {
        _templates = templates;
        _reports = results[1] as List<ClawdStoredReport>;
        _anomalies = results[2] as List<ClawdAnomaly>;
        _selectedTemplate ??= templates.isEmpty ? null : templates.first;
      });
    } catch (e) {
      _addError('Clawd data could not load: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _ask() async {
    final question = _question.text.trim();
    if (question.isEmpty || _asking) return;
    setState(() {
      _asking = true;
      _question.clear();
      _messages.add(_ClawdMessage(fromClawd: false, text: question));
    });
    try {
      final result = await AdminAiService.instance.ask(question);
      if (!mounted) return;
      setState(() {
        _messages.add(_ClawdMessage(fromClawd: true, text: result.answer));
      });
    } catch (e) {
      _addError('Clawd is not ready: $e');
    } finally {
      if (mounted) setState(() => _asking = false);
    }
  }

  Future<void> _runReport({required bool monthly}) async {
    if (_reporting) return;
    setState(() => _reporting = true);
    try {
      final report =
          monthly
              ? await AdminAiService.instance.monthlyReport(force: true)
              : await AdminAiService.instance.dailyReport(force: true);
      if (!mounted) return;
      setState(() {
        _latestReport = report;
        _messages.add(
          _ClawdMessage(
            fromClawd: true,
            text:
                '${monthly ? 'Monthly' : 'Daily'} report ${report.reportDate.isEmpty ? '' : 'for ${report.reportDate}'} is ready.\n\n${report.summary}',
          ),
        );
      });
      await _refresh();
    } catch (e) {
      _addError(
        '${monthly ? 'Monthly' : 'Daily'} analysis could not run: $e\n\nOpenAI and service-role keys must be set as Supabase Edge Function secrets.',
      );
    } finally {
      if (mounted) setState(() => _reporting = false);
    }
  }

  Future<void> _detectAnomalies() async {
    if (_detecting) return;
    setState(() => _detecting = true);
    try {
      final result = await AdminAiService.instance.detectAnomalies();
      if (!mounted) return;
      setState(() {
        _messages.add(
          _ClawdMessage(
            fromClawd: true,
            text:
                'Anomaly scan complete. Checked ${result.scanned} signals and stored ${result.stored} review item(s).',
          ),
        );
      });
      await _refresh();
    } catch (e) {
      _addError('Anomaly scan could not run: $e');
    } finally {
      if (mounted) setState(() => _detecting = false);
    }
  }

  Future<void> _runSelectedTemplate() async {
    final template = _selectedTemplate;
    if (template == null || _asking) return;
    setState(() {
      _asking = true;
      _messages.add(_ClawdMessage(fromClawd: false, text: template.name));
    });
    try {
      final variables = parseTemplateVariables(_variables.text);
      final result = await AdminAiService.instance.runTemplate(
        templateId: template.id,
        variables: variables,
      );
      if (!mounted) return;
      setState(() {
        _messages.add(_ClawdMessage(fromClawd: true, text: result.answer));
      });
      await _refresh();
    } catch (e) {
      _addError('Saved prompt could not run: $e');
    } finally {
      if (mounted) setState(() => _asking = false);
    }
  }

  Future<void> _showPromptDialog() async {
    final name = TextEditingController();
    final category = TextEditingController(text: 'custom');
    final prompt = TextEditingController();
    final created = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Add Clawd prompt'),
            content: SizedBox(
              width: 560,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: name,
                    decoration: const InputDecoration(labelText: 'Name'),
                  ),
                  TextField(
                    controller: category,
                    decoration: const InputDecoration(labelText: 'Category'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: prompt,
                    minLines: 5,
                    maxLines: 8,
                    decoration: const InputDecoration(
                      labelText: 'Prompt',
                      hintText:
                          'Review {{route}} for sudden freight increase and possible e-way risk.',
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Save'),
              ),
            ],
          ),
    );
    if (created != true) return;
    try {
      await AdminAiService.instance.createPromptTemplate(
        name: name.text,
        category: category.text,
        templateText: prompt.text,
      );
      await _refresh();
    } catch (e) {
      _addError('Prompt could not be saved: $e');
    }
  }

  Future<void> _updateAnomaly(ClawdAnomaly anomaly, String status) async {
    try {
      await AdminAiService.instance.updateAnomalyStatus(anomaly.id, status);
      await _refresh();
    } catch (e) {
      _addError('Anomaly status could not be updated: $e');
    }
  }

  void _addError(String text) {
    if (!mounted) return;
    setState(() {
      _messages.add(_ClawdMessage(fromClawd: true, text: text, isError: true));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _Header(
          reporting: _reporting,
          detecting: _detecting,
          onDaily: () => _runReport(monthly: false),
          onMonthly: () => _runReport(monthly: true),
          onDetect: _detectAnomalies,
        ),
        if (_latestReport != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: _ReportNotice(report: _latestReport!),
          ),
        Expanded(
          child:
              _loading
                  ? const Center(child: CircularProgressIndicator())
                  : LayoutBuilder(
                    builder: (context, constraints) {
                      final narrow = constraints.maxWidth < 980;
                      final panels = _SidePanels(
                        templates: _templates,
                        selectedTemplate: _selectedTemplate,
                        variables: _variables,
                        anomalies: _anomalies,
                        reports: _reports,
                        onTemplateChanged:
                            (template) =>
                                setState(() => _selectedTemplate = template),
                        onRunTemplate: _runSelectedTemplate,
                        onAddPrompt: _showPromptDialog,
                        onUpdateAnomaly: _updateAnomaly,
                      );
                      final chat = _ChatPane(
                        messages: _messages,
                        question: _question,
                        asking: _asking,
                        onAsk: _ask,
                      );

                      if (narrow) {
                        return ListView(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                          children: [
                            SizedBox(height: 620, child: chat),
                            const SizedBox(height: 12),
                            panels,
                          ],
                        );
                      }

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(flex: 7, child: chat),
                          SizedBox(width: 390, child: panels),
                        ],
                      );
                    },
                  ),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.reporting,
    required this.detecting,
    required this.onDaily,
    required this.onMonthly,
    required this.onDetect,
  });

  final bool reporting;
  final bool detecting;
  final VoidCallback onDaily;
  final VoidCallback onMonthly;
  final VoidCallback onDetect;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Wrap(
        spacing: 12,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const Icon(Icons.psychology_alt_outlined, size: 42),
          const SizedBox(
            width: 360,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Clawd',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: _onSurface,
                  ),
                ),
                Text(
                  'Backend AI for fraud, ledger, and operations intelligence',
                  style: TextStyle(fontSize: 12, color: _onSurfaceVariant),
                ),
              ],
            ),
          ),
          OutlinedButton.icon(
            onPressed: detecting ? null : onDetect,
            icon:
                detecting
                    ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : const Icon(Icons.warning_amber_outlined),
            label: Text(detecting ? 'Scanning' : 'Scan risks'),
          ),
          FilledButton.icon(
            onPressed: reporting ? null : onDaily,
            icon: const Icon(Icons.today_outlined),
            label: const Text('Daily report'),
          ),
          FilledButton.tonalIcon(
            onPressed: reporting ? null : onMonthly,
            icon: const Icon(Icons.calendar_month_outlined),
            label: const Text('Monthly report'),
          ),
        ],
      ),
    );
  }
}

class _ChatPane extends StatelessWidget {
  const _ChatPane({
    required this.messages,
    required this.question,
    required this.asking,
    required this.onAsk,
  });

  final List<_ClawdMessage> messages;
  final TextEditingController question;
  final bool asking;
  final VoidCallback onAsk;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            itemCount: messages.length,
            itemBuilder:
                (context, index) => _MessageBubble(message: messages[index]),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: question,
                    minLines: 1,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: 'Ask about e-way risk, route costs, delays...',
                      filled: true,
                      fillColor: const Color(0xFFF8F5FB),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onSubmitted: (_) => onAsk(),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton.filled(
                  tooltip: 'Send',
                  onPressed: asking ? null : onAsk,
                  icon:
                      asking
                          ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SidePanels extends StatelessWidget {
  const _SidePanels({
    required this.templates,
    required this.selectedTemplate,
    required this.variables,
    required this.anomalies,
    required this.reports,
    required this.onTemplateChanged,
    required this.onRunTemplate,
    required this.onAddPrompt,
    required this.onUpdateAnomaly,
  });

  final List<ClawdPromptTemplate> templates;
  final ClawdPromptTemplate? selectedTemplate;
  final TextEditingController variables;
  final List<ClawdAnomaly> anomalies;
  final List<ClawdStoredReport> reports;
  final ValueChanged<ClawdPromptTemplate?> onTemplateChanged;
  final VoidCallback onRunTemplate;
  final VoidCallback onAddPrompt;
  final Future<void> Function(ClawdAnomaly anomaly, String status)
  onUpdateAnomaly;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 16),
      children: [
        _Panel(
          title: 'Saved prompts',
          action: IconButton(
            tooltip: 'Add prompt',
            onPressed: onAddPrompt,
            icon: const Icon(Icons.add),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<ClawdPromptTemplate>(
                initialValue: selectedTemplate,
                items:
                    templates
                        .map(
                          (template) => DropdownMenuItem(
                            value: template,
                            child: Text(template.name),
                          ),
                        )
                        .toList(),
                onChanged: onTemplateChanged,
                decoration: const InputDecoration(labelText: 'Prompt'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: variables,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Variables JSON',
                  hintText: '{"route":"Karnal to Delhi"}',
                ),
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: selectedTemplate == null ? null : onRunTemplate,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Run prompt'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _Panel(
          title: 'Open risk signals',
          child: Column(
            children:
                anomalies.isEmpty
                    ? const [
                      Text(
                        'No stored risk signals yet.',
                        style: TextStyle(color: _onSurfaceVariant),
                      ),
                    ]
                    : anomalies
                        .take(8)
                        .map(
                          (anomaly) => _AnomalyTile(
                            anomaly: anomaly,
                            onUpdate: onUpdateAnomaly,
                          ),
                        )
                        .toList(),
          ),
        ),
        const SizedBox(height: 12),
        _Panel(
          title: 'Report history',
          child: Column(
            children:
                reports.isEmpty
                    ? const [
                      Text(
                        'Reports will appear after Clawd runs.',
                        style: TextStyle(color: _onSurfaceVariant),
                      ),
                    ]
                    : reports.take(6).map(_ReportTile.new).toList(),
          ),
        ),
      ],
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.child, this.action});

  final String title;
  final Widget child;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE4E0E8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: _onSurface,
                  ),
                ),
              ),
              if (action != null) action!,
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _ReportNotice extends StatelessWidget {
  const _ReportNotice({required this.report});

  final ClawdDailyReport report;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF4FF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFD3DEF6)),
      ),
      child: Text(
        '${report.reportType.toUpperCase()} analysis saved for ${report.reportDate}',
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: _onSurface,
        ),
      ),
    );
  }
}

class _AnomalyTile extends StatelessWidget {
  const _AnomalyTile({required this.anomaly, required this.onUpdate});

  final ClawdAnomaly anomaly;
  final Future<void> Function(ClawdAnomaly anomaly, String status) onUpdate;

  @override
  Widget build(BuildContext context) {
    final label = anomaly.signalType.replaceAll('_', ' ');
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _Badge(
                text: anomaly.severity,
                color: _severityColor(anomaly.severity),
              ),
              _Badge(text: anomaly.status, color: const Color(0xFFE6E0E9)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: _onSurface,
            ),
          ),
          Text(
            [
              if (anomaly.companyName.isNotEmpty) anomaly.companyName,
              if (anomaly.routeKey.isNotEmpty) anomaly.routeKey,
            ].join(' · '),
            style: const TextStyle(fontSize: 12, color: _onSurfaceVariant),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            children: [
              TextButton(
                onPressed:
                    anomaly.status == 'resolved'
                        ? null
                        : () => onUpdate(anomaly, 'resolved'),
                child: const Text('Resolved'),
              ),
              TextButton(
                onPressed:
                    anomaly.status == 'false_positive'
                        ? null
                        : () => onUpdate(anomaly, 'false_positive'),
                child: const Text('False positive'),
              ),
            ],
          ),
          const Divider(height: 12),
        ],
      ),
    );
  }
}

class _ReportTile extends StatelessWidget {
  const _ReportTile(this.report);

  final ClawdStoredReport report;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${report.reportType} · ${report.periodStart} to ${report.periodEnd}',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: _onSurface,
            ),
          ),
          Text(
            'Risk score ${report.riskScore.toStringAsFixed(0)}',
            style: const TextStyle(fontSize: 12, color: _onSurfaceVariant),
          ),
          const Divider(height: 14),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Text(
          text,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final _ClawdMessage message;

  @override
  Widget build(BuildContext context) {
    final align =
        message.fromClawd ? Alignment.centerLeft : Alignment.centerRight;
    final bg =
        message.isError
            ? const Color(0xFFFFEDEA)
            : message.fromClawd
            ? const Color(0xFFF6EDFB)
            : const Color(0xFFE7F6EC);
    return Align(
      alignment: align,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 760),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
        ),
        child:
            message.fromClawd && !message.isError
                ? _MarkdownMessage(text: message.text)
                : SelectableText(
                  message.text,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.42,
                    color: _onSurface,
                  ),
                ),
      ),
    );
  }
}

class _MarkdownMessage extends StatelessWidget {
  const _MarkdownMessage({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).textTheme.bodyMedium?.copyWith(
      color: _onSurface,
      fontSize: 14,
      height: 1.42,
    );
    final headingColor = _onSurface.withValues(alpha: 0.95);

    return MarkdownBody(
      data: text,
      selectable: true,
      styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
        p: base,
        strong: base?.copyWith(fontWeight: FontWeight.w800),
        em: base?.copyWith(fontStyle: FontStyle.italic),
        h1: base?.copyWith(
          color: headingColor,
          fontSize: 20,
          fontWeight: FontWeight.w800,
          height: 1.2,
        ),
        h2: base?.copyWith(
          color: headingColor,
          fontSize: 17,
          fontWeight: FontWeight.w800,
          height: 1.25,
        ),
        h3: base?.copyWith(
          color: headingColor,
          fontSize: 15,
          fontWeight: FontWeight.w800,
          height: 1.3,
        ),
        h1Padding: const EdgeInsets.only(top: 4, bottom: 8),
        h2Padding: const EdgeInsets.only(top: 8, bottom: 6),
        h3Padding: const EdgeInsets.only(top: 6, bottom: 4),
        blockSpacing: 10,
        listIndent: 22,
        listBullet: base,
        tableHead: base?.copyWith(fontWeight: FontWeight.w800),
        tableBody: base,
        tableBorder: TableBorder.all(color: const Color(0xFFE0D7E7)),
        tableCellsPadding: const EdgeInsets.symmetric(
          horizontal: 8,
          vertical: 6,
        ),
        tableHeadCellsDecoration: const BoxDecoration(color: Color(0xFFEDE3F4)),
        blockquote: base?.copyWith(color: _onSurfaceVariant),
        blockquotePadding: const EdgeInsets.fromLTRB(12, 8, 10, 8),
        blockquoteDecoration: const BoxDecoration(
          color: Color(0xFFFDF8FF),
          border: Border(left: BorderSide(color: Color(0xFFBBA7CD), width: 4)),
        ),
        code: base?.copyWith(
          color: const Color(0xFF3B3142),
          fontFamily: 'monospace',
          fontSize: 13,
          backgroundColor: const Color(0xFFF1E9F5),
        ),
        codeblockPadding: const EdgeInsets.all(10),
        codeblockDecoration: BoxDecoration(
          color: const Color(0xFFF1E9F5),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE0D7E7)),
        ),
      ),
    );
  }
}

Color _severityColor(String severity) {
  switch (severity) {
    case 'critical':
      return const Color(0xFFFFDAD6);
    case 'high':
      return const Color(0xFFFFE0B2);
    case 'medium':
      return const Color(0xFFFFF4CE);
    default:
      return const Color(0xFFE6F4EA);
  }
}

class _ClawdMessage {
  const _ClawdMessage({
    required this.fromClawd,
    required this.text,
    this.isError = false,
  });

  final bool fromClawd;
  final String text;
  final bool isError;
}
