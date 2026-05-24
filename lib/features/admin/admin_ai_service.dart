import 'dart:convert';

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

  Future<ClawdDailyReport> monthlyReport({bool force = false}) async {
    final response = await supabase.functions.invoke(
      'clawd-admin-ai',
      body: {'action': 'monthly_report', 'force': force},
    );
    return ClawdDailyReport.fromData(response.data);
  }

  Future<ClawdDetectionResult> detectAnomalies() async {
    final response = await supabase.functions.invoke(
      'clawd-admin-ai',
      body: {'action': 'detect_anomalies'},
    );
    return ClawdDetectionResult.fromData(response.data);
  }

  Future<ClawdResponse> runTemplate({
    required String templateId,
    Map<String, dynamic> variables = const {},
  }) async {
    final response = await supabase.functions.invoke(
      'clawd-admin-ai',
      body: {
        'action': 'template_run',
        'template_id': templateId,
        'variables': variables,
      },
    );
    return ClawdResponse.fromData(response.data);
  }

  Future<List<ClawdPromptTemplate>> loadPromptTemplates() async {
    final rows = await supabase
        .from('ai_prompt_templates')
        .select()
        .order('category')
        .order('name');
    return (rows as List)
        .map(
          (row) => ClawdPromptTemplate.fromMap(Map<String, dynamic>.from(row)),
        )
        .toList();
  }

  Future<void> createPromptTemplate({
    required String name,
    required String category,
    required String templateText,
  }) async {
    await supabase.from('ai_prompt_templates').insert({
      'name': name.trim(),
      'category': category.trim().isEmpty ? 'custom' : category.trim(),
      'template_text': templateText.trim(),
    });
  }

  Future<List<ClawdStoredReport>> loadReports() async {
    final rows = await supabase
        .from('ai_reports')
        .select()
        .order('period_end', ascending: false)
        .limit(12);
    return (rows as List)
        .map((row) => ClawdStoredReport.fromMap(Map<String, dynamic>.from(row)))
        .toList();
  }

  Future<List<ClawdAnomaly>> loadAnomalies() async {
    final rows = await supabase
        .from('ai_anomaly_events')
        .select()
        .order('detected_at', ascending: false)
        .limit(40);
    return (rows as List)
        .map((row) => ClawdAnomaly.fromMap(Map<String, dynamic>.from(row)))
        .toList();
  }

  Future<void> updateAnomalyStatus(String id, String status) async {
    await supabase
        .from('ai_anomaly_events')
        .update({
          'status': status,
          if (status != 'open') 'resolved_at': DateTime.now().toIso8601String(),
        })
        .eq('id', id);
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
      answer: _PlainEnglishAiText.clean(
        (map['answer'] ?? map['report']?['summary'] ?? '').toString(),
      ),
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
  String get reportDate =>
      (report['report_date'] ?? report['period_end'] ?? '').toString();
  String get reportType => (report['report_type'] ?? 'daily').toString();

  factory ClawdDailyReport.fromData(dynamic data) {
    final map = Map<String, dynamic>.from(data as Map);
    return ClawdDailyReport(
      report: Map<String, dynamic>.from(map['report'] as Map? ?? const {}),
      metrics: Map<String, dynamic>.from(map['metrics'] as Map? ?? const {}),
    );
  }
}

class ClawdDetectionResult {
  const ClawdDetectionResult({
    required this.scanned,
    required this.stored,
    required this.events,
  });

  final int scanned;
  final int stored;
  final List<dynamic> events;

  factory ClawdDetectionResult.fromData(dynamic data) {
    final map = Map<String, dynamic>.from(data as Map);
    return ClawdDetectionResult(
      scanned: (map['scanned'] as num?)?.toInt() ?? 0,
      stored: (map['stored'] as num?)?.toInt() ?? 0,
      events: (map['events'] as List?) ?? const [],
    );
  }
}

class ClawdPromptTemplate {
  const ClawdPromptTemplate({
    required this.id,
    required this.name,
    required this.category,
    required this.templateText,
  });

  final String id;
  final String name;
  final String category;
  final String templateText;

  factory ClawdPromptTemplate.fromMap(Map<String, dynamic> map) {
    return ClawdPromptTemplate(
      id: (map['id'] ?? '').toString(),
      name: (map['name'] ?? '').toString(),
      category: (map['category'] ?? 'custom').toString(),
      templateText: (map['template_text'] ?? '').toString(),
    );
  }
}

class ClawdStoredReport {
  const ClawdStoredReport({
    required this.id,
    required this.reportType,
    required this.periodStart,
    required this.periodEnd,
    required this.summary,
    required this.riskScore,
    required this.recommendations,
  });

  final String id;
  final String reportType;
  final String periodStart;
  final String periodEnd;
  final String summary;
  final double riskScore;
  final List<dynamic> recommendations;

  factory ClawdStoredReport.fromMap(Map<String, dynamic> map) {
    return ClawdStoredReport(
      id: (map['id'] ?? '').toString(),
      reportType: (map['report_type'] ?? '').toString(),
      periodStart: (map['period_start'] ?? '').toString(),
      periodEnd: (map['period_end'] ?? '').toString(),
      summary: _PlainEnglishAiText.clean((map['summary'] ?? '').toString()),
      riskScore: (map['risk_score'] as num?)?.toDouble() ?? 0,
      recommendations: (map['recommendations'] as List?) ?? const [],
    );
  }
}

class ClawdAnomaly {
  const ClawdAnomaly({
    required this.id,
    required this.signalType,
    required this.severity,
    required this.entityType,
    required this.status,
    required this.companyName,
    required this.routeKey,
    required this.evidence,
    required this.metrics,
    required this.createdAt,
  });

  final String id;
  final String signalType;
  final String severity;
  final String entityType;
  final String status;
  final String companyName;
  final String routeKey;
  final Map<String, dynamic> evidence;
  final Map<String, dynamic> metrics;
  final String createdAt;

  factory ClawdAnomaly.fromMap(Map<String, dynamic> map) {
    return ClawdAnomaly(
      id: (map['id'] ?? '').toString(),
      signalType: (map['signal_type'] ?? '').toString(),
      severity: (map['severity'] ?? 'medium').toString(),
      entityType: (map['entity_type'] ?? '').toString(),
      status: (map['status'] ?? 'open').toString(),
      companyName: (map['company_name'] ?? '').toString(),
      routeKey: (map['route_key'] ?? '').toString(),
      evidence: Map<String, dynamic>.from(map['evidence'] as Map? ?? const {}),
      metrics: Map<String, dynamic>.from(map['metrics'] as Map? ?? const {}),
      createdAt: (map['detected_at'] ?? '').toString(),
    );
  }
}

Map<String, dynamic> parseTemplateVariables(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return {};
  final decoded = jsonDecode(trimmed);
  if (decoded is Map) return Map<String, dynamic>.from(decoded);
  throw const FormatException('Variables must be a JSON object.');
}

class _PlainEnglishAiText {
  const _PlainEnglishAiText._();

  static final _technicalPatterns = <RegExp>[
    RegExp(
      r"\b(?:admin_alerts|profiles|freights|bids|metrics|metadata|vehicles|drivers|invoices|delivery_stages|ai_runs|ai_reports|ai_anomaly_events|clawd_[a-z_]+)(?:\.[a-z_]+)+\s*=\s*(?:"
      r'"[^"]*"'
      r"|'[^']*'|[^\s,)]+)",
      caseSensitive: false,
    ),
    RegExp(
      r'\b(?:admin_alerts|profiles|freights|bids|metrics|metadata|vehicles|drivers|invoices|delivery_stages|ai_runs|ai_reports|ai_anomaly_events|clawd_[a-z_]+)(?:\.[a-z_]+)+\b',
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
      r'\([^)]*(?:admin_alerts|profiles|freights|bids|metrics|metadata|winner_profile_id|delivery_stages|ai_runs|ai_reports|ai_anomaly_events|clawd_[a-z_]+)[^)]*\)',
      caseSensitive: false,
    ),
    RegExp(
      r'\b(?:admin_alerts|profiles|freights|bids|metrics|metadata|vehicles|drivers|invoices|delivery_stages|ai_runs|ai_reports|ai_anomaly_events|clawd_[a-z_]+)\b',
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
      'pod_late_flag': 'late POD',
      'pod_missing_overdue_flag': 'overdue missing POD',
      'pod_delay_days': 'POD delay days',
      'pod_submitted_at': 'POD submission time',
      'proof_or_ack_delay': 'proof or acknowledgement delay',
      'duplicate_eway': 'duplicate e-way bill',
      'eway_mismatch': 'e-way bill mismatch',
      'route_cost_spike': 'route cost spike',
      'high_extra_charge': 'high extra charge',
      'ack_pending_days': 'acknowledgement pending days',
      'bill_to_dispatch_delay_days': 'bill-to-dispatch delay days',
      'pod_missing_flag': 'missing POD',
      'last_location_age_hours': 'stale location update',
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
            .replaceAll(RegExp(r'\btables?\b', caseSensitive: false), 'records')
            .replaceAll(RegExp(r'\bviews?\b', caseSensitive: false), 'reports')
            .replaceAll(RegExp(r'\bJSON\b', caseSensitive: false), 'details')
            .replaceAll(RegExp(r'\bSQL\b', caseSensitive: false), 'backend checks')
            .replaceAll(
              RegExp(r'\bUUIDs?\b', caseSensitive: false),
              'record IDs',
            )
            .replaceAll(
              RegExp(
                r'\b(?:payment is blocked|payment blocked|blocked payment|payment has been blocked|payment was blocked)\b',
                caseSensitive: false,
              ),
              'payment needs manual review',
            )
            .replaceAll(
              RegExp(
                r'\b(?:Is )?payment needs manual review\?\s*No\.?\s*',
                caseSensitive: false,
              ),
              '',
            )
            .replaceAll(
              RegExp(
                r'\bNothing here says payment needs manual review\.?\s*',
                caseSensitive: false,
              ),
              'No automatic payment stop is applied. ',
            )
            .replaceAll(
              RegExp(
                r"(?:#{1,6}\s*)?[—-]?\s*\bthere(?:'s| is) no indication that payment needs manual review\.?\s*",
                caseSensitive: false,
              ),
              'No automatic payment stop is applied. ',
            )
            .replaceAll(
              RegExp(
                r'\bIs payment needs manual review\?\s*',
                caseSensitive: false,
              ),
              '',
            )
            .replaceAll(
              RegExp(
                r"\bthere(?:'s| is) no indication that payment is (?:automatically )?blocked\.?\s*",
                caseSensitive: false,
              ),
              'No automatic payment stop is applied. ',
            )
            .replaceAll(
              RegExp(
                r'\b(?:blocked|held|cannot be cleared|should not be cleared) for payment\b',
                caseSensitive: false,
              ),
              'marked for review before payment release',
            )
            .replaceAll(
              RegExp(r'\bblocked\b', caseSensitive: false),
              'on automatic stop',
            )
            .replaceAll(
              RegExp(
                r'\bautomatic payment stop is applied in v1\b',
                caseSensitive: false,
              ),
              'No automatic payment stop is applied right now',
            )
            .replaceAll(
              RegExp(
                r'[—-]\s*there is no automatic payment stop in v1',
                caseSensitive: false,
              ),
              'No automatic payment stop is applied right now',
            )
            .replaceAll(
              RegExp(
                r'\bautomatic payment stop in v1\b',
                caseSensitive: false,
              ),
              'automatic payment stop right now',
            )
            .replaceAll(RegExp(r'\s+([,.;:])'), r'$1')
            .replaceAll(RegExp(r'[ \t]{2,}'), ' ')
            .replaceAll(RegExp(r'\n{3,}'), '\n\n')
            .trim();

    return text;
  }
}
