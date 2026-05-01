import '../../core/supabase/supabase_bootstrap.dart';

class AdminAiService {
  AdminAiService._();
  static final instance = AdminAiService._();

  Future<ClawdResponse> ask(String question) async {
    final response = await supabase.functions.invoke(
      'clawd-admin-ai',
      body: {'action': 'chat', 'question': question},
    );
    return ClawdResponse.fromData(response.data);
  }

  Future<ClawdDailyReport> dailyReport({bool force = false}) async {
    final response = await supabase.functions.invoke(
      'clawd-admin-ai',
      body: {'action': 'daily_report', 'force': force},
    );
    return ClawdDailyReport.fromData(response.data);
  }
}

class ClawdResponse {
  const ClawdResponse({
    required this.answer,
    required this.metrics,
    required this.anomalies,
  });

  final String answer;
  final Map<String, dynamic> metrics;
  final List<dynamic> anomalies;

  factory ClawdResponse.fromData(dynamic data) {
    final map = Map<String, dynamic>.from(data as Map);
    return ClawdResponse(
      answer: _PlainEnglishAiText.clean((map['answer'] ?? '').toString()),
      metrics: Map<String, dynamic>.from(map['metrics'] as Map? ?? const {}),
      anomalies: (map['anomalies'] as List?) ?? const [],
    );
  }
}

class ClawdDailyReport {
  const ClawdDailyReport({required this.report, required this.metrics});

  final Map<String, dynamic> report;
  final Map<String, dynamic> metrics;

  String get summary =>
      _PlainEnglishAiText.clean((report['summary'] ?? '').toString());
  List<dynamic> get anomalies => (report['anomalies'] as List?) ?? const [];
  String get reportDate => (report['report_date'] ?? '').toString();

  factory ClawdDailyReport.fromData(dynamic data) {
    final map = Map<String, dynamic>.from(data as Map);
    return ClawdDailyReport(
      report: Map<String, dynamic>.from(map['report'] as Map? ?? const {}),
      metrics: Map<String, dynamic>.from(map['metrics'] as Map? ?? const {}),
    );
  }
}

class _PlainEnglishAiText {
  const _PlainEnglishAiText._();

  static final _technicalPatterns = <RegExp>[
    RegExp(
      r"\b(?:admin_alerts|profiles|freights|bids|metrics|metadata|vehicles|drivers|invoices|delivery_stages)(?:\.[a-z_]+)+\s*=\s*(?:"
      r'"[^"]*"'
      r"|'[^']*'|[^\s,)]+)",
      caseSensitive: false,
    ),
    RegExp(
      r'\b(?:admin_alerts|profiles|freights|bids|metrics|metadata|vehicles|drivers|invoices|delivery_stages)(?:\.[a-z_]+)+\b',
      caseSensitive: false,
    ),
    RegExp(
      r'\b(?:Freight|Bid|Alert)\s+[0-9a-f]{6,}(?:[-\w]*|\.\.\.)\b',
      caseSensitive: false,
    ),
    RegExp(
      r'\b[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\b',
      caseSensitive: false,
    ),
    RegExp(r'\b[0-9a-f]{7,}\.\.\.', caseSensitive: false),
    RegExp(
      r'\([^)]*(?:admin_alerts|profiles|freights|bids|metrics|metadata|winner_profile_id|delivery_stages)[^)]*\)',
      caseSensitive: false,
    ),
  ];

  static String clean(String raw) {
    var text = raw;
    final replacements = <String, String>{
      'internal_calling_bid': 'expected freight amount',
      'winner_profile_id': 'winning transporter',
      'rc_number': 'RC details',
      'lorry_insurance_number': 'insurance details',
      'vehicle_number': 'vehicle number',
      'driver_name': 'driver name',
      'driver_phone': 'driver phone',
      'status="open"': 'open',
      'status="won"': 'won',
      'status="active"': 'active',
      'status="dispatched"': 'dispatched',
      'status="awarded"': 'awarded',
      'amount=': 'amount ',
      'null': 'missing',
    };

    for (final entry in replacements.entries) {
      text = text.replaceAll(entry.key, entry.value);
    }
    for (final pattern in _technicalPatterns) {
      text = text.replaceAll(pattern, 'this item');
    }

    text =
        text
            .replaceAll(RegExp(r'\brows?\b', caseSensitive: false), 'records')
            .replaceAll(
              RegExp(r'\bcolumns?\b', caseSensitive: false),
              'details',
            )
            .replaceAll(RegExp(r'\bfields?\b', caseSensitive: false), 'details')
            .replaceAll(RegExp(r'\btable\b', caseSensitive: false), 'records')
            .replaceAll(
              RegExp(r'\bUUIDs?\b', caseSensitive: false),
              'record IDs',
            )
            .replaceAll(RegExp(r'\s+([,.;:])'), r'$1')
            .replaceAll(RegExp(r'[ \t]{2,}'), ' ')
            .replaceAll(RegExp(r'\n{3,}'), '\n\n')
            .trim();

    return text;
  }
}
