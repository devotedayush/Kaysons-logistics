import 'package:flutter/material.dart';
import '../../core/widgets/workspace_widgets.dart';
import 'widgets/office_widgets.dart';
import 'package:go_router/go_router.dart';

import '../../core/supabase/freights_repo.dart';
import '../../core/widgets/date_window_bar.dart';
import '../../l10n/app_localizations.dart';

class AdminBidsBody extends StatefulWidget {
  const AdminBidsBody({super.key});

  @override
  State<AdminBidsBody> createState() => _AdminBidsBodyState();
}

class _AdminBidsBodyState extends State<AdminBidsBody> {
  int _rangeDays = 30;
  String _search = '';
  String _status = 'all';
  DateTime? _customStart;
  DateTime? _customEnd;

  Future<void> _pickStart() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      initialDate:
          _customStart ?? DateTime.now().subtract(const Duration(days: 7)),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _customStart = picked;
      _customEnd ??= picked;
    });
  }

  Future<void> _pickEnd() async {
    final base = _customEnd ?? _customStart ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate:
          _customStart ?? DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      initialDate: base,
    );
    if (picked == null || !mounted) return;
    setState(() => _customEnd = picked);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: WorkspaceHeader(
            title: l.adminAllBids,
            description: officeCopy(
              context,
              'Find a load, check its bidding status and open it to review offers or delivery.',
              'माल खोजें, बोली की स्थिति देखें और प्रस्ताव या डिलीवरी की समीक्षा करें।',
            ),
            icon: Icons.local_shipping_outlined,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: TextField(
            onChanged: (value) => setState(() => _search = value),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              labelText: officeCopy(
                context,
                'Search route or load',
                'मार्ग या माल खोजें',
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final entry
                  in {
                    'all': l.adminAll,
                    'open': l.adminOpen,
                    'closed': l.adminClosed,
                    'completed': l.adminCompleted,
                  }.entries)
                ChoiceChip(
                  label: Text(entry.value),
                  selected: _status == entry.key,
                  onSelected: (_) => setState(() => _status = entry.key),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: DateWindowBar(
            rangeDays: _rangeDays,
            customStart: _customStart,
            customEnd: _customEnd,
            onSelectRange:
                (days) => setState(() {
                  _rangeDays = days;
                  _customStart = null;
                  _customEnd = null;
                }),
            onPickStart: _pickStart,
            onPickEnd: _pickEnd,
            onClearCustom:
                () => setState(() {
                  _customStart = null;
                  _customEnd = null;
                }),
          ),
        ),
        Expanded(
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: FreightsRepo.instance.streamOperationalFreights(),
            builder: (context, snap) {
              if (snap.hasError) {
                return WorkspaceEmptyState(
                  title: officeCopy(
                    context,
                    'Loads could not be loaded',
                    'माल की सूची लोड नहीं हुई',
                  ),
                  message: officeCopy(
                    context,
                    'Check your connection and open this page again.',
                    'कनेक्शन जाँचें और पृष्ठ फिर खोलें।',
                  ),
                  icon: Icons.cloud_off_outlined,
                );
              }
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final freights =
                  snap.data!
                      .where(
                        (row) => withinDateWindow(
                          DateTime.tryParse(
                            (row['created_at'] ?? '').toString(),
                          ),
                          rangeDays: _rangeDays,
                          customStart: _customStart,
                          customEnd: _customEnd,
                        ),
                      )
                      .where((row) {
                        final view = freightView(row);
                        final status = view['status'];
                        final bucket =
                            status == 'completed'
                                ? 'completed'
                                : status == 'bidding' &&
                                    (view['minsLeft'] as int) > 0
                                ? 'open'
                                : 'closed';
                        return (_status == 'all' || _status == bucket) &&
                            '${view['route']} ${view['id']}'
                                .toLowerCase()
                                .contains(_search.toLowerCase());
                      })
                      .toList();
              if (freights.isEmpty) {
                return WorkspaceEmptyState(
                  title: l.adminNoBids,
                  message: officeCopy(
                    context,
                    'Try another route, status or date range.',
                    'दूसरा मार्ग, स्थिति या तारीख की अवधि चुनें।',
                  ),
                  icon: Icons.local_shipping_outlined,
                );
              }
              if (MediaQuery.sizeOf(context).width >= 1000) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: DataTable(
                    columnSpacing: 28,
                    dataRowMinHeight: 64,
                    dataRowMaxHeight: 80,
                    columns: [
                      DataColumn(label: Text(l.adminRoute)),
                      DataColumn(label: Text(l.adminCases)),
                      const DataColumn(label: Text('MT')),
                      DataColumn(label: Text(l.adminStatus)),
                      DataColumn(
                        label: Text(
                          officeCopy(context, 'Next action', 'अगला काम'),
                        ),
                      ),
                    ],
                    rows:
                        freights.map((row) {
                          final v = freightView(row);
                          return DataRow(
                            cells: [
                              DataCell(Text(v['route'].toString())),
                              DataCell(Text(v['cases'].toString())),
                              DataCell(Text(v['weight_kg'].toString())),
                              DataCell(
                                StatusBadge(
                                  label: _bidStatusLabel(
                                    v['status'] as String,
                                    v['minsLeft'] as int,
                                    l,
                                  ),
                                  tone:
                                      v['status'] == 'bidding'
                                          ? WorkspaceTone.info
                                          : WorkspaceTone.success,
                                ),
                              ),
                              DataCell(
                                OutlinedButton(
                                  onPressed:
                                      () =>
                                          context.push('/admin/bid/${v['id']}'),
                                  child: Text(
                                    officeCopy(
                                      context,
                                      'Review load',
                                      'माल देखें',
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                  ),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                itemCount: freights.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final v = freightView(freights[i]);
                  return _tile(context, v);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _tile(BuildContext context, Map<String, dynamic> v) {
    final l = AppLocalizations.of(context)!;
    final status = v['status'] as String;
    return OfficeRecordCard(
      title: v['route'] as String,
      status: StatusBadge(
        label: _bidStatusLabel(status, v['minsLeft'] as int, l),
        tone: status == 'bidding' ? WorkspaceTone.info : WorkspaceTone.success,
      ),
      values: {l.adminCases: '${v['cases']}', 'MT': '${v['weight_kg']}'},
      actions: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () => context.push('/admin/bid/${v['id']}'),
          icon: const Icon(Icons.arrow_forward),
          label: Text(
            officeCopy(
              context,
              'Review load and offers',
              'माल और प्रस्ताव देखें',
            ),
          ),
        ),
      ),
    );
  }

  String _bidStatusLabel(String status, int minsLeft, AppLocalizations l) {
    if (status == 'completed') return l.adminCompleted;
    if (status == 'bidding' && minsLeft > 0) return l.adminOpen;
    return l.adminClosed;
  }
}
