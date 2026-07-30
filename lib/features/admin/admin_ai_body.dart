import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import 'admin_ai_service.dart';

const _onSurface = Color(0xFF1D1B20);
const _onSurfaceVariant = Color(0xFF49454F);
const _border = Color(0xFFE4E0E8);

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
          'I am Clawd. I use the current ledger snapshot, risk queue, and reports to answer operations questions.',
    ),
  ];

  bool _loading = true;
  bool _asking = false;
  bool _reporting = false;
  bool _detecting = false;
  ClawdSnapshot? _snapshot;
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
        service.loadSnapshot(),
        service.loadPromptTemplates(),
        service.loadReports(),
        service.loadAnomalies(),
      ]);
      if (!mounted) return;
      final templates = results[1] as List<ClawdPromptTemplate>;
      setState(() {
        _snapshot = results[0] as ClawdSnapshot;
        _templates = templates;
        _reports = results[2] as List<ClawdStoredReport>;
        _anomalies = results[3] as List<ClawdAnomaly>;
        _selectedTemplate ??= templates.isEmpty ? null : templates.first;
      });
    } catch (e) {
      _addError('Clawd data could not load: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _ask([String? prompt]) async {
    final question = (prompt ?? _question.text).trim();
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
                'Risk scan complete. Checked ${result.scanned} ranked signal(s) and stored ${result.stored} review item(s).',
          ),
        );
      });
      await _refresh();
    } catch (e) {
      _addError('Risk scan could not run: $e');
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
                          'Review {{route}} for freight increase and POD risk.',
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
      _addError('Risk status could not be updated: $e');
    }
  }

  Future<void> _showExpandedChat() async {
    await showDialog<void>(
      context: context,
      builder:
          (dialogContext) => StatefulBuilder(
            builder: (context, setDialogState) {
              Future<void> ask([String? prompt]) async {
                final pending = _ask(prompt);
                setDialogState(() {});
                await pending;
                if (dialogContext.mounted) setDialogState(() {});
              }

              return Dialog.fullscreen(
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.psychology_alt_outlined, size: 30),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Clawd chat',
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  Text(
                                    'Choose a quick prompt or ask an operations question.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: _onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: 'Close expanded chat',
                              onPressed:
                                  () => Navigator.of(dialogContext).pop(),
                              icon: const Icon(Icons.close),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _QuickPrompts(onPrompt: (prompt) => ask(prompt)),
                        const SizedBox(height: 12),
                        Expanded(
                          child: _ChatPane(
                            messages: _messages,
                            question: _question,
                            asking: _asking,
                            onAsk: ask,
                            expanded: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
    );
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
                      final wide = constraints.maxWidth >= 1100;
                      final workspace = _Workspace(
                        snapshot: _snapshot,
                        messages: _messages,
                        question: _question,
                        asking: _asking,
                        anomalies: _anomalies,
                        reports: _reports,
                        templates: _templates,
                        selectedTemplate: _selectedTemplate,
                        variables: _variables,
                        onAsk: _ask,
                        onQuickPrompt: _ask,
                        onExpandChat: _showExpandedChat,
                        onUpdateAnomaly: _updateAnomaly,
                        onTemplateChanged:
                            (value) =>
                                setState(() => _selectedTemplate = value),
                        onRunTemplate: _runSelectedTemplate,
                        onAddPrompt: _showPromptDialog,
                      );
                      if (!wide) {
                        return workspace;
                      }
                      return workspace;
                    },
                  ),
        ),
      ],
    );
  }
}

class _Workspace extends StatelessWidget {
  const _Workspace({
    required this.snapshot,
    required this.messages,
    required this.question,
    required this.asking,
    required this.anomalies,
    required this.reports,
    required this.templates,
    required this.selectedTemplate,
    required this.variables,
    required this.onAsk,
    required this.onQuickPrompt,
    required this.onExpandChat,
    required this.onUpdateAnomaly,
    required this.onTemplateChanged,
    required this.onRunTemplate,
    required this.onAddPrompt,
  });

  final ClawdSnapshot? snapshot;
  final List<_ClawdMessage> messages;
  final TextEditingController question;
  final bool asking;
  final List<ClawdAnomaly> anomalies;
  final List<ClawdStoredReport> reports;
  final List<ClawdPromptTemplate> templates;
  final ClawdPromptTemplate? selectedTemplate;
  final TextEditingController variables;
  final Future<void> Function([String? prompt]) onAsk;
  final ValueChanged<String> onQuickPrompt;
  final VoidCallback onExpandChat;
  final Future<void> Function(ClawdAnomaly anomaly, String status)
  onUpdateAnomaly;
  final ValueChanged<ClawdPromptTemplate?> onTemplateChanged;
  final VoidCallback onRunTemplate;
  final VoidCallback onAddPrompt;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 1100;
        if (!wide) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            children: [
              _RiskSummary(snapshot: snapshot),
              const SizedBox(height: 12),
              _QuickPrompts(onPrompt: onQuickPrompt),
              const SizedBox(height: 12),
              SizedBox(
                height: 520,
                child: _ChatPane(
                  messages: messages,
                  question: question,
                  asking: asking,
                  onAsk: onAsk,
                  onExpand: onExpandChat,
                ),
              ),
              const SizedBox(height: 12),
              _ReviewQueue(anomalies: anomalies, onUpdate: onUpdateAnomaly),
              const SizedBox(height: 12),
              _ToolsPanel(
                templates: templates,
                selectedTemplate: selectedTemplate,
                variables: variables,
                reports: reports,
                onTemplateChanged: onTemplateChanged,
                onRunTemplate: onRunTemplate,
                onAddPrompt: onAddPrompt,
              ),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 7,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 8, 16),
                children: [
                  _RiskSummary(snapshot: snapshot),
                  const SizedBox(height: 12),
                  _QuickPrompts(onPrompt: onQuickPrompt),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 500,
                    child: _ChatPane(
                      messages: messages,
                      question: question,
                      asking: asking,
                      onAsk: onAsk,
                      onExpand: onExpandChat,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 430,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(8, 8, 16, 16),
                children: [
                  _ReviewQueue(anomalies: anomalies, onUpdate: onUpdateAnomaly),
                  const SizedBox(height: 12),
                  _ToolsPanel(
                    templates: templates,
                    selectedTemplate: selectedTemplate,
                    variables: variables,
                    reports: reports,
                    onTemplateChanged: onTemplateChanged,
                    onRunTemplate: onRunTemplate,
                    onAddPrompt: onAddPrompt,
                  ),
                ],
              ),
            ),
          ],
        );
      },
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
          const Icon(Icons.psychology_alt_outlined, size: 38),
          const SizedBox(
            width: 360,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Clawd',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: _onSurface,
                  ),
                ),
                Text(
                  'Operations analyst for freight, POD, e-way, and cost review',
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

class _RiskSummary extends StatelessWidget {
  const _RiskSummary({required this.snapshot});

  final ClawdSnapshot? snapshot;

  @override
  Widget build(BuildContext context) {
    final s = snapshot;
    return _Panel(
      title:
          s == null
              ? 'Current Risk Summary'
              : 'Current Risk Summary · ${s.periodLabel}',
      child:
          s == null
              ? const Text(
                'No snapshot loaded.',
                style: TextStyle(color: _onSurfaceVariant),
              )
              : Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _MetricPill('Dispatches', s.dispatches.toString()),
                  _MetricPill('Freight', _fmtMoney(s.freight)),
                  _MetricPill(
                    'POD pending',
                    s.podPending.toString(),
                    warning: s.podPending > 0,
                  ),
                  _MetricPill(
                    'Review value',
                    _fmtMoney(s.reviewValue),
                    warning: s.reviewValue > 0,
                  ),
                  _MetricPill(
                    'Duplicate e-way',
                    s.duplicateEwayRisks.toString(),
                    warning: s.duplicateEwayRisks > 0,
                  ),
                  _MetricPill(
                    'Route spikes',
                    s.routeCostSpikeRisks.toString(),
                    warning: s.routeCostSpikeRisks > 0,
                  ),
                  _MetricPill(
                    'Extra charges',
                    s.highExtraChargeRisks.toString(),
                    warning: s.highExtraChargeRisks > 0,
                  ),
                ],
              ),
    );
  }
}

class _QuickPrompts extends StatelessWidget {
  const _QuickPrompts({required this.onPrompt});

  final ValueChanged<String> onPrompt;

  @override
  Widget build(BuildContext context) {
    final prompts = [
      'Summarize April 2026 logistics',
      'Show POD pending by transporter',
      'Find highest freight per MT routes',
      'Check duplicate invoice and e-way risk',
      'Compare Bunge vs Cargill',
    ];
    return _Panel(
      title: 'Quick Prompts',
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children:
            prompts
                .map(
                  (prompt) => ActionChip(
                    avatar: const Icon(Icons.bolt_outlined, size: 16),
                    label: Text(prompt),
                    onPressed: () => onPrompt(prompt),
                  ),
                )
                .toList(),
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
    this.onExpand,
    this.expanded = false,
  });

  final List<_ClawdMessage> messages;
  final TextEditingController question;
  final bool asking;
  final Future<void> Function([String? prompt]) onAsk;
  final VoidCallback? onExpand;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'Ask Clawd',
      fill: expanded,
      trailing:
          onExpand == null
              ? null
              : TextButton.icon(
                onPressed: onExpand,
                icon: const Icon(Icons.open_in_full, size: 18),
                label: const Text('Expand'),
              ),
      child: Column(
        children: [
          if (expanded)
            Expanded(child: _MessageList(messages: messages))
          else
            SizedBox(height: 380, child: _MessageList(messages: messages)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: question,
                  minLines: 1,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText:
                        'Ask about POD, routes, e-way bills, or transporter costs...',
                  ),
                  onSubmitted: (_) => onAsk(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                tooltip: 'Send',
                onPressed: asking ? null : () => onAsk(),
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
        ],
      ),
    );
  }
}

class _MessageList extends StatelessWidget {
  const _MessageList({required this.messages});

  final List<_ClawdMessage> messages;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: messages.length,
      itemBuilder: (context, index) => _MessageBubble(message: messages[index]),
    );
  }
}

class _ReviewQueue extends StatelessWidget {
  const _ReviewQueue({required this.anomalies, required this.onUpdate});

  final List<ClawdAnomaly> anomalies;
  final Future<void> Function(ClawdAnomaly anomaly, String status) onUpdate;

  @override
  Widget build(BuildContext context) {
    final open = anomalies.where((a) => a.status == 'open').take(8).toList();
    return _Panel(
      title: 'Open Review Queue',
      child:
          open.isEmpty
              ? const Text(
                'No stored review items yet. Run Scan risks.',
                style: TextStyle(color: _onSurfaceVariant),
              )
              : Column(
                children:
                    open
                        .map(
                          (anomaly) => _AnomalyTile(
                            anomaly: anomaly,
                            onUpdate: onUpdate,
                          ),
                        )
                        .toList(),
              ),
    );
  }
}

class _ToolsPanel extends StatelessWidget {
  const _ToolsPanel({
    required this.templates,
    required this.selectedTemplate,
    required this.variables,
    required this.reports,
    required this.onTemplateChanged,
    required this.onRunTemplate,
    required this.onAddPrompt,
  });

  final List<ClawdPromptTemplate> templates;
  final ClawdPromptTemplate? selectedTemplate;
  final TextEditingController variables;
  final List<ClawdStoredReport> reports;
  final ValueChanged<ClawdPromptTemplate?> onTemplateChanged;
  final VoidCallback onRunTemplate;
  final VoidCallback onAddPrompt;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'Reports & Saved Prompts',
      trailing: IconButton(
        tooltip: 'Add prompt',
        onPressed: onAddPrompt,
        icon: const Icon(Icons.add),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<ClawdPromptTemplate>(
            value: selectedTemplate,
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
            decoration: const InputDecoration(labelText: 'Saved prompt'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: variables,
            minLines: 2,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Variables JSON',
              hintText: '{"route":"Ludhiana to Amritsar"}',
            ),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: selectedTemplate == null ? null : onRunTemplate,
            icon: const Icon(Icons.play_arrow),
            label: const Text('Run prompt'),
          ),
          const Divider(height: 24),
          if (reports.isEmpty)
            const Text(
              'Reports will appear after Clawd runs.',
              style: TextStyle(color: _onSurfaceVariant),
            )
          else
            ...reports.take(5).map(_ReportTile.new),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.title,
    required this.child,
    this.trailing,
    this.fill = false,
  });

  final String title;
  final Widget child;
  final Widget? trailing;
  final bool fill;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _border),
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
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: _onSurface,
                  ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 10),
          if (fill) Expanded(child: child) else child,
        ],
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  const _MetricPill(this.label, this.value, {this.warning = false});

  final String label;
  final String value;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: warning ? const Color(0xFFFFF7E8) : const Color(0xFFF7F2FA),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: warning ? const Color(0xFFE9C46A) : _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: _onSurface,
            ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, color: _onSurfaceVariant),
          ),
        ],
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
              _Badge(
                text:
                    'priority ${anomaly.businessPriorityScore.toStringAsFixed(0)}',
                color: const Color(0xFFEFF4FF),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
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
                onPressed: () => onUpdate(anomaly, 'resolved'),
                child: const Text('Resolved'),
              ),
              TextButton(
                onPressed: () => onUpdate(anomaly, 'false_positive'),
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

class _ReportNotice extends StatelessWidget {
  const _ReportNotice({required this.report});

  final ClawdDailyReport report;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF4FF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFD3DEF6)),
      ),
      child: Text(
        '${report.reportType.toUpperCase()} analysis saved for ${report.reportDate}',
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: _onSurface,
        ),
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
              fontWeight: FontWeight.w800,
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
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
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
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
        ),
        child:
            message.fromClawd && !message.isError
                ? MarkdownBody(
                  data: message.text,
                  selectable: true,
                  styleSheet: MarkdownStyleSheet.fromTheme(
                    Theme.of(context),
                  ).copyWith(
                    p: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontSize: 14,
                      height: 1.42,
                    ),
                    h2: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                    h3: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                    listIndent: 22,
                  ),
                )
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

String _fmtMoney(double value) {
  if (value >= 10000000) return '₹${(value / 10000000).toStringAsFixed(2)} Cr';
  if (value >= 100000) return '₹${(value / 100000).toStringAsFixed(2)} L';
  if (value >= 1000) return '₹${(value / 1000).toStringAsFixed(1)}K';
  return '₹${value.toStringAsFixed(0)}';
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
