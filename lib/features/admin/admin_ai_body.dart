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
  final List<_ClawdMessage> _messages = [
    const _ClawdMessage(
      fromClawd: true,
      text:
          'I am Clawd. Ask about bids, vehicles, transporters, invoices, alerts, pricing spreads, or route anomalies.',
    ),
  ];
  bool _asking = false;
  bool _reporting = false;
  ClawdDailyReport? _dailyReport;

  @override
  void dispose() {
    _question.dispose();
    super.dispose();
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
      if (!mounted) return;
      setState(() {
        _messages.add(
          _ClawdMessage(
            fromClawd: true,
            text:
                'Clawd is not ready: $e\n\nCheck that the Edge Function secrets are set server-side.',
            isError: true,
          ),
        );
      });
    } finally {
      if (mounted) setState(() => _asking = false);
    }
  }

  Future<void> _runDailyReport({bool force = false}) async {
    if (_reporting) return;
    setState(() => _reporting = true);
    try {
      final report = await AdminAiService.instance.dailyReport(force: force);
      if (!mounted) return;
      setState(() {
        _dailyReport = report;
        _messages.add(
          _ClawdMessage(
            fromClawd: true,
            text:
                'Daily report ${report.reportDate.isEmpty ? '' : 'for ${report.reportDate}'} is ready.\n\n${report.summary}',
          ),
        );
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.add(
          _ClawdMessage(
            fromClawd: true,
            text:
                'Daily analysis could not run: $e\n\nThe OpenAI key and service-role key must be configured as Supabase Edge Function secrets.',
            isError: true,
          ),
        );
      });
    } finally {
      if (mounted) setState(() => _reporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8DEF8),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.psychology_alt_outlined),
              ),
              const SizedBox(width: 12),
              const Expanded(
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
                      'Admin AI analyst with database-wide operational context',
                      style: TextStyle(fontSize: 12, color: _onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed:
                    _reporting ? null : () => _runDailyReport(force: true),
                icon:
                    _reporting
                        ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : const Icon(Icons.today_outlined),
                label: Text(_reporting ? 'Analyzing' : 'Daily analysis'),
              ),
            ],
          ),
        ),
        if (_dailyReport != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: _DailyReportCard(report: _dailyReport!),
          ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            itemCount: _messages.length,
            itemBuilder:
                (context, index) => _MessageBubble(message: _messages[index]),
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
                    controller: _question,
                    minLines: 1,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: 'Ask Clawd about anomalies or performance...',
                      filled: true,
                      fillColor: const Color(0xFFF8F5FB),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onSubmitted: (_) => _ask(),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton.filled(
                  tooltip: 'Send',
                  onPressed: _asking ? null : _ask,
                  icon:
                      _asking
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

class _DailyReportCard extends StatelessWidget {
  const _DailyReportCard({required this.report});

  final ClawdDailyReport report;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF4FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD3DEF6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            report.reportDate.isEmpty
                ? 'Daily analysis'
                : 'Daily analysis · ${report.reportDate}',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: _onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${report.anomalies.length} anomaly signal(s) detected',
            style: const TextStyle(fontSize: 12, color: _onSurfaceVariant),
          ),
        ],
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
          borderRadius: BorderRadius.circular(16),
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
