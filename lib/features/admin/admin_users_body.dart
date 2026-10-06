import 'package:flutter/material.dart';
import '../../core/widgets/workspace_widgets.dart';
import 'widgets/office_widgets.dart';

import '../../core/supabase/supabase_bootstrap.dart';
import '../../l10n/app_localizations.dart';

class _UserRow {
  _UserRow({
    required this.id,
    required this.name,
    required this.role,
    required this.status,
    this.managerId,
    this.phone = '',
    this.email = '',
  });
  final String id;
  String name;
  String role;
  String status;
  String? managerId;
  final String phone, email;
}

String _roleLabel(AppLocalizations l, String role) => switch (role) {
  'transporter' => l.transporter,
  'logistics_manager' => l.logisticsManager,
  'dispatch_manager' => l.dispatchManager,
  'accountant' => l.accountant,
  'admin' => l.adminRoleAdmin,
  _ => role,
};

const _roleOptions = [
  'transporter',
  'logistics_manager',
  'dispatch_manager',
  'accountant',
  'admin',
];

class AdminUsersBody extends StatefulWidget {
  const AdminUsersBody({super.key});

  @override
  State<AdminUsersBody> createState() => _AdminUsersBodyState();
}

class _AdminUsersBodyState extends State<AdminUsersBody>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  bool _loading = true;
  String _search = '';
  String? _error;
  final List<_UserRow> _users = [];
  final Map<String, String> _logisticsManagers = {};

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, initialIndex: 1, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await supabase
          .from('profiles')
          .select(
            'id, full_name, business_name, email, phone, role, status, manager_id',
          )
          .order('created_at', ascending: false);
      _users
        ..clear()
        ..addAll(
          (rows as List).map((r) {
            final name =
                (r['full_name'] ?? r['business_name'] ?? r['email'] ?? '')
                    .toString();
            return _UserRow(
              id: r['id'] as String,
              name: name,
              role: (r['role'] ?? 'transporter') as String,
              status: (r['status'] ?? 'pending') as String,
              managerId: r['manager_id'] as String?,
              phone: (r['phone'] ?? '').toString(),
              email: (r['email'] ?? '').toString(),
            );
          }),
        );
      _logisticsManagers
        ..clear()
        ..addEntries(
          _users
              .where((u) => u.role == 'logistics_manager')
              .map((u) => MapEntry(u.id, u.name)),
        );
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _setRole(_UserRow u, String role) async {
    if (role == u.role) return;
    if (role == 'dispatch_manager' && _logisticsManagers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.adminManagerFirst),
        ),
      );
      return;
    }
    final managerId =
        role == 'dispatch_manager'
            ? (u.managerId ?? _logisticsManagers.keys.first)
            : null;
    try {
      await supabase
          .from('profiles')
          .update({'role': role, 'manager_id': managerId})
          .eq('id', u.id);
      setState(() {
        u.role = role;
        u.managerId = managerId;
        _logisticsManagers
          ..clear()
          ..addEntries(
            _users
                .where((user) => user.role == 'logistics_manager')
                .map((user) => MapEntry(user.id, user.name)),
          );
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${AppLocalizations.of(context)!.adminRoleUpdateFailed}: $e',
          ),
        ),
      );
    }
  }

  Future<void> _setManager(_UserRow u, String? managerId) async {
    if (u.role != 'dispatch_manager' || managerId == null) return;
    try {
      await supabase
          .from('profiles')
          .update({'manager_id': managerId})
          .eq('id', u.id);
      setState(() => u.managerId = managerId);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${AppLocalizations.of(context)!.adminManagerUpdateFailed}: $e',
          ),
        ),
      );
    }
  }

  Future<void> _setStatus(_UserRow u, String status) async {
    try {
      await supabase.from('profiles').update({'status': status}).eq('id', u.id);
      setState(() => u.status = status);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${AppLocalizations.of(context)!.adminUpdateFailed}: $e',
          ),
        ),
      );
    }
  }

  Future<void> _removeUser(_UserRow u) async {
    final remove = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(
              officeCopy(
                context,
                'Remove this access profile?',
                'यह एक्सेस प्रोफ़ाइल हटाएँ?',
              ),
            ),
            content: Text(
              officeCopy(
                context,
                '${u.name} will lose this access profile. Their sign-in account is kept. Use Reject when you only want to block access.',
                '${u.name} की एक्सेस प्रोफ़ाइल हट जाएगी। लॉगिन खाता रहेगा। केवल एक्सेस रोकने के लिए अस्वीकार करें।',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(
                  officeCopy(context, 'Keep profile', 'प्रोफ़ाइल रखें'),
                ),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(
                  officeCopy(context, 'Remove profile', 'प्रोफ़ाइल हटाएँ'),
                ),
              ),
            ],
          ),
    );
    if (remove != true || !mounted) return;
    try {
      await supabase.from('profiles').delete().eq('id', u.id);
      setState(() => _users.remove(u));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${AppLocalizations.of(context)!.adminDeleteFailed}: $e',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final matching = _users.where(
      (u) => '${u.name} ${_roleLabel(l, u.role)}'.toLowerCase().contains(
        _search.toLowerCase(),
      ),
    );
    final approved = matching.where((u) => u.status == 'approved').toList();
    final pending = matching.where((u) => u.status == 'pending').toList();
    final rejected = matching.where((u) => u.status == 'rejected').toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: WorkspaceHeader(
            title: l.adminUserManagement,
            description: officeCopy(
              context,
              'Review new registrations first. Choose the job role and reporting manager before approving access.',
              'पहले नए पंजीकरण देखें। स्वीकृति से पहले काम की भूमिका और रिपोर्टिंग प्रबंधक चुनें।',
            ),
            icon: Icons.people_outline,
            action: OutlinedButton.icon(
              onPressed: _loading ? null : _load,
              icon: const Icon(Icons.refresh),
              label: Text(l.adminRefresh),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: TextField(
            onChanged: (value) => setState(() => _search = value),
            decoration: InputDecoration(
              labelText: officeCopy(
                context,
                'Find a person or role',
                'व्यक्ति या भूमिका खोजें',
              ),
              prefixIcon: const Icon(Icons.search),
            ),
          ),
        ),
        TabBar(
          controller: _tab,
          tabs: [
            Tab(text: '${l.users} (${approved.length})'),
            Tab(text: '${l.adminPending} (${pending.length})'),
            Tab(
              text:
                  '${officeCopy(context, 'Rejected', 'अस्वीकृत')} (${rejected.length})',
            ),
          ],
        ),
        Expanded(
          child:
              _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                  ? WorkspaceEmptyState(
                    title: officeCopy(
                      context,
                      'Accounts could not be loaded',
                      'खाते लोड नहीं हुए',
                    ),
                    message: officeCopy(
                      context,
                      'Check your connection and retry before reviewing access.',
                      'खातों की समीक्षा से पहले कनेक्शन जाँचें और फिर प्रयास करें।',
                    ),
                    icon: Icons.cloud_off_outlined,
                    action: OutlinedButton(
                      onPressed: _load,
                      child: Text(l.adminRetry),
                    ),
                  )
                  : TabBarView(
                    controller: _tab,
                    children: [
                      _buildList(approved, pending: false),
                      _buildList(pending, pending: true),
                      _buildList(rejected, pending: false),
                    ],
                  ),
        ),
      ],
    );
  }

  Widget _buildList(List<_UserRow> users, {required bool pending}) {
    final l = AppLocalizations.of(context)!;
    if (users.isEmpty) {
      return WorkspaceEmptyState(
        title: l.adminNoUsers,
        message: officeCopy(
          context,
          'Try another name or choose another status tab.',
          'दूसरा नाम खोजें या स्थिति का दूसरा टैब चुनें।',
        ),
        icon: Icons.person_search_outlined,
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 900) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: constraints.maxWidth - 32,
              child: DataTable(
                columnSpacing: 24,
                dataRowMinHeight: 68,
                dataRowMaxHeight: 80,
                columns: [
                  DataColumn(
                    label: Text(officeCopy(context, 'Person', 'व्यक्ति')),
                  ),
                  DataColumn(label: Text(l.adminRole)),
                  DataColumn(label: Text(l.adminReportsTo)),
                  DataColumn(label: Text(l.adminStatus)),
                  DataColumn(
                    label: Text(officeCopy(context, 'Review', 'समीक्षा')),
                  ),
                ],
                rows:
                    users
                        .map(
                          (u) => DataRow(
                            cells: [
                              DataCell(
                                Text(u.name.isEmpty ? l.adminUnnamed : u.name),
                              ),
                              DataCell(Text(_roleLabel(l, u.role))),
                              DataCell(
                                Text(_logisticsManagers[u.managerId] ?? '—'),
                              ),
                              DataCell(
                                StatusBadge(
                                  label:
                                      u.status == 'pending'
                                          ? l.adminPending
                                          : u.status == 'approved'
                                          ? officeCopy(
                                            context,
                                            'Approved',
                                            'स्वीकृत',
                                          )
                                          : officeCopy(
                                            context,
                                            'Rejected',
                                            'अस्वीकृत',
                                          ),
                                  tone:
                                      pending
                                          ? WorkspaceTone.warning
                                          : u.status == 'approved'
                                          ? WorkspaceTone.success
                                          : WorkspaceTone.danger,
                                ),
                              ),
                              DataCell(
                                OutlinedButton.icon(
                                  onPressed:
                                      () => _reviewUser(u, pending: pending),
                                  icon: const Icon(
                                    Icons.manage_accounts_outlined,
                                  ),
                                  label: Text(
                                    officeCopy(
                                      context,
                                      'Review account',
                                      'खाता देखें',
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                        .toList(),
              ),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: users.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder:
              (_, i) => Card(child: _userTile(users[i], pending: pending)),
        );
      },
    );
  }

  void _reviewUser(_UserRow user, {required bool pending}) {
    showDialog<void>(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setDialogState) => Dialog(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: 660,
                      maxHeight: 700,
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Align(
                            alignment: Alignment.centerRight,
                            child: IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(Icons.close),
                            ),
                          ),
                          _userTile(
                            user,
                            pending: pending,
                            expanded: true,
                            onChanged: () {
                              if (context.mounted) setDialogState(() {});
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
          ),
    );
  }

  Widget _userTile(
    _UserRow u, {
    required bool pending,
    bool expanded = false,
    VoidCallback? onChanged,
  }) {
    final l = AppLocalizations.of(context)!;
    return ExpansionTile(
      initiallyExpanded: expanded,
      leading: const CircleAvatar(
        backgroundColor: Color(0xFFEADDFF),
        child: Icon(Icons.person, color: Color(0xFF4F378A)),
      ),
      title: Text(u.name.isEmpty ? l.adminUnnamed : u.name),
      trailing: StatusBadge(
        label:
            u.status == 'pending'
                ? l.adminPending
                : u.status == 'approved'
                ? officeCopy(context, 'Approved', 'स्वीकृत')
                : officeCopy(context, 'Rejected', 'अस्वीकृत'),
        tone:
            pending
                ? WorkspaceTone.warning
                : u.status == 'approved'
                ? WorkspaceTone.success
                : WorkspaceTone.danger,
      ),
      subtitle: Text(
        u.role == 'dispatch_manager' && u.managerId != null
            ? '${_roleLabel(l, u.role)} · ${_logisticsManagers[u.managerId] ?? l.adminNoManager}'
            : _roleLabel(l, u.role),
      ),
      children: [
        if (u.phone.isNotEmpty || u.email.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: OfficeRecordCard(
              title: officeCopy(
                context,
                'Registration contact details',
                'पंजीकरण की संपर्क जानकारी',
              ),
              values: {
                if (u.phone.isNotEmpty)
                  officeCopy(context, 'Phone', 'फोन'): u.phone,
                if (u.email.isNotEmpty)
                  officeCopy(context, 'Contact email', 'संपर्क ईमेल'): u.email,
              },
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final narrow = constraints.maxWidth < 560;
              final roleField = DropdownButtonFormField<String>(
                initialValue: u.role,
                decoration: InputDecoration(
                  labelText: l.adminRole,
                  border: const OutlineInputBorder(),
                ),
                items:
                    _roleOptions
                        .map(
                          (role) => DropdownMenuItem(
                            value: role,
                            child: Text(_roleLabel(l, role)),
                          ),
                        )
                        .toList(),
                onChanged: (role) {
                  if (role != null) {
                    _setRole(u, role).then((_) => onChanged?.call());
                  }
                },
              );
              final managerField = DropdownButtonFormField<String>(
                initialValue:
                    _logisticsManagers.containsKey(u.managerId)
                        ? u.managerId
                        : null,
                decoration: InputDecoration(
                  labelText: l.adminReportsTo,
                  border: const OutlineInputBorder(),
                ),
                items:
                    _logisticsManagers.entries
                        .map(
                          (entry) => DropdownMenuItem(
                            value: entry.key,
                            child: Text(entry.value),
                          ),
                        )
                        .toList(),
                onChanged:
                    u.role == 'dispatch_manager'
                        ? (managerId) => _setManager(
                          u,
                          managerId,
                        ).then((_) => onChanged?.call())
                        : null,
              );
              if (narrow) {
                return Column(
                  children: [
                    roleField,
                    if (u.role == 'dispatch_manager') ...[
                      const SizedBox(height: 10),
                      managerField,
                    ],
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: roleField),
                  if (u.role == 'dispatch_manager') ...[
                    const SizedBox(width: 10),
                    Expanded(child: managerField),
                  ],
                ],
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              l.adminAccessHelp,
              style: const TextStyle(color: Color(0xFF49454F), fontSize: 12),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              if (pending) ...[
                FilledButton.icon(
                  onPressed:
                      () => _setStatus(
                        u,
                        'approved',
                      ).then((_) => onChanged?.call()),
                  icon: const Icon(Icons.check, color: Color(0xFF2E7D32)),
                  label: Text(
                    l.adminApprove,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                TextButton.icon(
                  onPressed:
                      () => _setStatus(
                        u,
                        'rejected',
                      ).then((_) => onChanged?.call()),
                  icon: const Icon(Icons.close, color: Color(0xFFB3261E)),
                  label: Text(
                    l.adminReject,
                    style: const TextStyle(color: Color(0xFFB3261E)),
                  ),
                ),
              ] else
                const SizedBox.shrink(),
              TextButton.icon(
                onPressed: () => _removeUser(u),
                icon: const Icon(
                  Icons.delete_outline,
                  color: Color(0xFFB3261E),
                ),
                label: Text(
                  l.adminRemove,
                  style: const TextStyle(color: Color(0xFFB3261E)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
