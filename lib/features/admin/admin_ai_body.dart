import 'dart:convert';
import 'package:flutter/material.dart';
import '../../core/widgets/workspace_widgets.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import 'admin_ai_service.dart';

const _onSurface = Color(0xFF1D1B20);
const _onSurfaceVariant = Color(0xFF49454F);
const _border = Color(0xFFE4E0E8);

String _copy(BuildContext context, String english, String hindi) =>
    context.mounted && Localizations.localeOf(context).languageCode == 'hi'
        ? hindi
        : english;

class AdminAiBody extends StatefulWidget {
  const AdminAiBody({super.key});

  @override
  State<AdminAiBody> createState() => _AdminAiBodyState();
}

class _AdminAiBodyState extends State<AdminAiBody> {
  final _question = TextEditingController();
  final _variables = TextEditingController(text: '{}');
  final List<_ClawdMessage> _messages = [];
  String? _welcomeLanguage;

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
  void didChangeDependencies() {
    super.didChangeDependencies();
    final language = Localizations.localeOf(context).languageCode;
    if (_welcomeLanguage == language) return;
    final welcome = _ClawdMessage(
      fromClawd: true,
      text: _copy(
        context,
        'I am Clawd. I use the current ledger snapshot, risk queue, and reports to answer operations questions.',
        'मैं Clawd हूँ। आपके परिचालन सवालों का जवाब देने के लिए मौजूदा लेजर, जोखिम सूची और रिपोर्ट देखता हूँ।',
      ),
    );
    if (_messages.isEmpty) {
      _messages.add(welcome);
    } else {
      _messages[0] = welcome;
    }
    _welcomeLanguage = language;
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
      if (!mounted) return;
      _addError(
        '${_copy(context, 'Clawd data could not load', 'Clawd का डेटा लोड नहीं हुआ')}: $e',
      );
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
      final result = await AdminAiService.instance.ask(
        question,
        language: Localizations.localeOf(context).languageCode,
      );
      if (!mounted) return;
      setState(() {
        _messages.add(_ClawdMessage(fromClawd: true, text: result.answer));
      });
    } catch (e) {
      if (!mounted) return;
      _addError(
        '${_copy(context, 'Clawd is not ready', 'Clawd अभी उपलब्ध नहीं है')}: $e',
      );
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
            text: _copy(
              context,
              '${monthly ? 'Monthly' : 'Daily'} report ${report.reportDate.isEmpty ? '' : 'for ${report.reportDate}'} is ready.\n\n${report.summary}',
              '${monthly ? 'मासिक' : 'दैनिक'} रिपोर्ट ${report.reportDate.isEmpty ? '' : '${report.reportDate} के लिए'} तैयार है।\n\n${report.summary}',
            ),
          ),
        );
      });
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      _addError(
        _copy(
          context,
          '${monthly ? 'Monthly' : 'Daily'} analysis could not run: $e\n\nOpenAI and service-role keys must be set as Supabase Edge Function secrets.',
          '${monthly ? 'मासिक' : 'दैनिक'} विश्लेषण नहीं चल सका: $e',
        ),
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
            text: _copy(
              context,
              'Risk scan complete. Checked ${result.scanned} ranked signal(s) and stored ${result.stored} review item(s).',
              'जोखिम जाँच पूरी हुई। ${result.scanned} संकेत देखे और ${result.stored} समीक्षा आइटम सहेजे।',
            ),
          ),
        );
      });
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      _addError(
        '${_copy(context, 'Risk scan could not run', 'जोखिम जाँच नहीं चल सकी')}: $e',
      );
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
        language: Localizations.localeOf(context).languageCode,
      );
      if (!mounted) return;
      setState(() {
        _messages.add(_ClawdMessage(fromClawd: true, text: result.answer));
      });
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      _addError(
        '${_copy(context, 'Saved prompt could not run', 'सहेजा गया प्रश्न नहीं चल सका')}: $e',
      );
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
            scrollable: true,
            title: Text(
              _copy(
                context,
                'Save a reusable question',
                'दोबारा उपयोग करने वाला सवाल सहेजें',
              ),
            ),
            content: SizedBox(
              width: 560,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GuidanceCard(
                    title: _copy(
                      context,
                      'Give the question a clear name',
                      'सवाल को आसान नाम दें',
                    ),
                    message: _copy(
                      context,
                      'For example: Monthly freight review. Write the question as you would ask a colleague. Use {{route}} only when the route should be filled in each time.',
                      'जैसे: मासिक भाड़े की समीक्षा। सवाल ऐसे लिखें जैसे किसी सहकर्मी से पूछते हैं। हर बार मार्ग भरने के लिए ही {{route}} का उपयोग करें।',
                    ),
                    icon: Icons.bookmark_add_outlined,
                  ),
                  const SizedBox(height: 16),

                  TextField(
                    controller: name,
                    decoration: InputDecoration(
                      labelText: _copy(context, 'Name', 'नाम'),
                    ),
                  ),
                  TextField(
                    controller: category,
                    decoration: InputDecoration(
                      labelText: _copy(context, 'Category', 'श्रेणी'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: prompt,
                    minLines: 5,
                    maxLines: 8,
                    decoration: InputDecoration(
                      labelText: _copy(context, 'Prompt', 'प्रश्न'),
                      hintText: _copy(
                        context,
                        'Review {{route}} for freight increase and POD risk.',
                        '{{route}} पर भाड़ा वृद्धि और POD जोखिम की समीक्षा करें।',
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(_copy(context, 'Cancel', 'रद्द करें')),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(_copy(context, 'Save', 'सहेजें')),
              ),
            ],
          ),
    );
    if (created != true || !mounted) return;
    try {
      await AdminAiService.instance.createPromptTemplate(
        name: name.text,
        category: category.text,
        templateText: prompt.text,
      );
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      _addError(
        '${_copy(context, 'Prompt could not be saved', 'प्रश्न सहेजा नहीं जा सका')}: $e',
      );
    }
  }

  Future<void> _updateAnomaly(ClawdAnomaly anomaly, String status) async {
    try {
      await AdminAiService.instance.updateAnomalyStatus(anomaly.id, status);
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      _addError(
        '${_copy(context, 'Risk status could not be updated', 'जोखिम की स्थिति नहीं बदली जा सकी')}: $e',
      );
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
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _copy(context, 'Clawd chat', 'Clawd चैट'),
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  Text(
                                    _copy(
                                      context,
                                      'Choose a quick prompt or ask an operations question.',
                                      'तुरंत प्रश्न चुनें या परिचालन के बारे में पूछें।',
                                    ),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: _onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: _copy(
                                context,
                                'Close expanded chat',
                                'बड़ी चैट बंद करें',
                              ),
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
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text(
                  _copy(
                    context,
                    'Saved reports and advanced tools',
                    'सहेजी रिपोर्ट और अतिरिक्त उपकरण',
                  ),
                ),
                children: [
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
          WorkspaceHeader(
            title: _copy(
              context,
              'Ask your operations assistant',
              'अपने परिचालन सहायक से पूछें',
            ),
            description: _copy(
              context,
              'Ask a question in everyday language. Clawd checks your ledger and explains delivery proof, freight costs and records that need review.',
              'आसान भाषा में सवाल पूछें। Clawd लेजर देखकर डिलीवरी प्रमाण, भाड़े और समीक्षा वाले रिकॉर्ड समझाता है।',
            ),
            icon: Icons.auto_awesome_outlined,
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
            label: Text(
              detecting
                  ? _copy(context, 'Scanning', 'जाँच जारी है')
                  : _copy(context, 'Scan risks', 'जोखिम जाँचें'),
            ),
          ),
          FilledButton.icon(
            onPressed: reporting ? null : onDaily,
            icon: const Icon(Icons.today_outlined),
            label: Text(_copy(context, 'Daily report', 'दैनिक रिपोर्ट')),
          ),
          FilledButton.tonalIcon(
            onPressed: reporting ? null : onMonthly,
            icon: const Icon(Icons.calendar_month_outlined),
            label: Text(_copy(context, 'Monthly report', 'मासिक रिपोर्ट')),
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
              ? _copy(context, 'Current Risk Summary', 'मौजूदा जोखिम सारांश')
              : '${_copy(context, 'Current Risk Summary', 'मौजूदा जोखिम सारांश')} · ${s.periodLabel}',
      child:
          s == null
              ? Text(
                _copy(context, 'No snapshot loaded.', 'सारांश लोड नहीं हुआ।'),
                style: const TextStyle(color: _onSurfaceVariant),
              )
              : Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _MetricPill(
                    _copy(context, 'Dispatches', 'डिस्पैच'),
                    s.dispatches.toString(),
                  ),
                  _MetricPill(
                    _copy(context, 'Freight', 'भाड़ा'),
                    _fmtMoney(s.freight),
                  ),
                  _MetricPill(
                    _copy(context, 'POD pending', 'POD लंबित'),
                    s.podPending.toString(),
                    warning: s.podPending > 0,
                  ),
                  _MetricPill(
                    _copy(context, 'Review value', 'समीक्षा राशि'),
                    _fmtMoney(s.reviewValue),
                    warning: s.reviewValue > 0,
                  ),
                  _MetricPill(
                    _copy(context, 'Duplicate e-way', 'डुप्लिकेट ई-वे'),
                    s.duplicateEwayRisks.toString(),
                    warning: s.duplicateEwayRisks > 0,
                  ),
                  _MetricPill(
                    _copy(context, 'Route spikes', 'मार्ग लागत वृद्धि'),
                    s.routeCostSpikeRisks.toString(),
                    warning: s.routeCostSpikeRisks > 0,
                  ),
                  _MetricPill(
                    _copy(context, 'Extra charges', 'अतिरिक्त शुल्क'),
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
      _copy(
        context,
        'What needs my attention today?',
        'आज किन कामों पर ध्यान देना है?',
      ),
      _copy(
        context,
        'Show POD pending by transporter',
        'ट्रांसपोर्टर के अनुसार लंबित POD दिखाएँ',
      ),
      _copy(
        context,
        'Find highest freight per MT routes',
        'प्रति MT सबसे महंगे मार्ग बताएँ',
      ),
      _copy(
        context,
        'Check duplicate invoice and e-way risk',
        'डुप्लिकेट इनवॉइस और ई-वे जोखिम जाँचें',
      ),
      _copy(
        context,
        'Explain this month’s freight costs',
        'इस महीने के भाड़े का खर्च समझाएँ',
      ),
    ];
    return _Panel(
      title: _copy(
        context,
        'Choose a question to get started',
        'शुरुआत के लिए सवाल चुनें',
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children:
            prompts
                .map(
                  (prompt) => ActionChip(
                    avatar: const Icon(Icons.bolt_outlined, size: 16),
                    label: Text(prompt, softWrap: true),
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
      title: _copy(context, 'Ask Clawd', 'Clawd से पूछें'),
      fill: true,
      trailing:
          onExpand == null
              ? null
              : TextButton.icon(
                onPressed: onExpand,
                icon: const Icon(Icons.open_in_full, size: 18),
                label: Text(_copy(context, 'Expand', 'बड़ा करें')),
              ),
      child: Column(
        children: [
          Expanded(child: _MessageList(messages: messages)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: question,
                  minLines: 1,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: _copy(
                      context,
                      'Ask about POD, routes, e-way bills, or transporter costs...',
                      'POD, मार्ग, ई-वे बिल या ट्रांसपोर्टर लागत के बारे में पूछें...',
                    ),
                  ),
                  onSubmitted: (_) => onAsk(),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                label: Text(_copy(context, 'Ask', 'पूछें')),
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
      title: _copy(context, 'Open Review Queue', 'खुली समीक्षा सूची'),
      child:
          open.isEmpty
              ? Text(
                _copy(
                  context,
                  'No stored review items yet. Run Scan risks.',
                  'अभी कोई समीक्षा आइटम नहीं है। जोखिम जाँच चलाएँ।',
                ),
                style: const TextStyle(color: _onSurfaceVariant),
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
      title: _copy(
        context,
        'Reports & Saved Prompts',
        'रिपोर्ट और सहेजे गए प्रश्न',
      ),
      trailing: IconButton(
        tooltip: _copy(context, 'Add prompt', 'प्रश्न जोड़ें'),
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
            decoration: InputDecoration(
              labelText: _copy(context, 'Saved prompt', 'सहेजा गया प्रश्न'),
            ),
          ),
          const SizedBox(height: 8),
          if (selectedTemplate != null)
            SavedQuestionInputs(
              key: ValueKey(selectedTemplate!.id),
              template: selectedTemplate!,
              variables: variables,
            ),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text(
              _copy(
                context,
                'Advanced question settings',
                'सवाल की अतिरिक्त सेटिंग',
              ),
            ),
            children: [
              TextField(
                controller: variables,
                minLines: 2,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: _copy(
                    context,
                    'Saved question inputs (JSON)',
                    'सहेजे सवाल की जानकारी (JSON)',
                  ),
                  hintText: '{"route":"Ludhiana to Amritsar"}',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: selectedTemplate == null ? null : onRunTemplate,
            icon: const Icon(Icons.play_arrow),
            label: Text(_copy(context, 'Run prompt', 'प्रश्न चलाएँ')),
          ),
          const Divider(height: 24),
          if (reports.isEmpty)
            Text(
              _copy(
                context,
                'Reports will appear after Clawd runs.',
                'Clawd चलने के बाद रिपोर्ट यहाँ दिखेंगी।',
              ),
              style: const TextStyle(color: _onSurfaceVariant),
            )
          else
            ...reports.take(5).map(_ReportTile.new),
        ],
      ),
    );
  }
}

/// Ordinary named fields feed the existing template-variable contract.
class SavedQuestionInputs extends StatefulWidget {
  const SavedQuestionInputs({
    super.key,
    required this.template,
    required this.variables,
  });
  final ClawdPromptTemplate template;
  final TextEditingController variables;
  @override
  State<SavedQuestionInputs> createState() => _SavedQuestionInputsState();
}

class _SavedQuestionInputsState extends State<SavedQuestionInputs> {
  late final Map<String, dynamic> _values;
  late final List<String> _fields;
  @override
  void initState() {
    super.initState();
    try {
      _values = parseTemplateVariables(widget.variables.text);
    } catch (_) {
      _values = {};
    }
    _fields =
        RegExp(r'\{\{\s*([a-zA-Z_][a-zA-Z0-9_]*)\s*\}\}')
            .allMatches(widget.template.templateText)
            .map((match) => match.group(1)!)
            .toSet()
            .toList();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (_fields.isNotEmpty)
        Text(
          _copy(
            context,
            'Details for this saved question',
            'इस सहेजे सवाल की जानकारी',
          ),
        ),
      for (final field in _fields)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: TextFormField(
            initialValue: (_values[field] ?? '').toString(),
            decoration: InputDecoration(
              labelText: switch (field) {
                'route' => _copy(context, 'Route', 'मार्ग'),
                'month' => _copy(context, 'Month', 'महीना'),
                'company' => _copy(context, 'Company', 'कंपनी'),
                'transporter' => _copy(context, 'Transporter', 'ट्रांसपोर्टर'),
                _ => field.replaceAll('_', ' '),
              },
            ),
            onChanged: (value) {
              _values[field] = value;
              widget.variables.text = jsonEncode(_values);
            },
          ),
        ),
    ],
  );
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
    final label =
        Localizations.localeOf(context).languageCode == 'hi'
            ? switch (anomaly.signalType) {
              'eway_mismatch' => 'ई-वे विवरण में अंतर',
              'duplicate_eway' => 'डुप्लिकेट ई-वे बिल जोखिम',
              'route_cost_spike' => 'मार्ग लागत में वृद्धि',
              'high_extra_charge' => 'अधिक अतिरिक्त शुल्क',
              'proof_or_ack_delay' => 'प्रमाण या पावती में देरी',
              _ => anomaly.signalType.replaceAll('_', ' '),
            }
            : anomaly.signalType.replaceAll('_', ' ');
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
                text:
                    Localizations.localeOf(context).languageCode == 'hi'
                        ? switch (anomaly.severity) {
                          'critical' => 'अति गंभीर',
                          'high' => 'उच्च',
                          'medium' => 'मध्यम',
                          _ => 'निम्न',
                        }
                        : anomaly.severity,
                color: _severityColor(anomaly.severity),
              ),
              _Badge(
                text:
                    '${_copy(context, 'priority', 'प्राथमिकता')} ${anomaly.businessPriorityScore.toStringAsFixed(0)}',
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
                child: Text(_copy(context, 'Resolved', 'सुलझा')),
              ),
              TextButton(
                onPressed: () => onUpdate(anomaly, 'false_positive'),
                child: Text(_copy(context, 'False positive', 'गलत संकेत')),
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
        _copy(
          context,
          '${report.reportType.toUpperCase()} analysis saved for ${report.reportDate}',
          '${report.reportType == 'monthly' ? 'मासिक' : 'दैनिक'} विश्लेषण ${report.reportDate} के लिए सहेजा गया',
        ),
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
            _copy(
              context,
              '${report.reportType} · ${report.periodStart} to ${report.periodEnd}',
              '${report.reportType == 'monthly' ? 'मासिक' : 'दैनिक'} · ${report.periodStart} से ${report.periodEnd}',
            ),
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: _onSurface,
            ),
          ),
          Text(
            '${_copy(context, 'Risk score', 'जोखिम स्कोर')} ${report.riskScore.toStringAsFixed(0)}',
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
