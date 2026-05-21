import 'package:flutter/material.dart';

import '../../core/supabase/supabase_bootstrap.dart';

class LmDispatchTeamBody extends StatefulWidget {
  const LmDispatchTeamBody({super.key});

  @override
  State<LmDispatchTeamBody> createState() => _LmDispatchTeamBodyState();
}

class _LmDispatchTeamBodyState extends State<LmDispatchTeamBody> {
  final _search = TextEditingController();
  final List<_DispatchUser> _team = [];
  final List<_DispatchUser> _candidates = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final uid = supabase.auth.currentUser?.id;
      if (uid == null) throw StateError('Not signed in');
      final rows = await supabase
          .from('profiles')
          .select(
            'id, full_name, business_name, email, role, status, manager_id',
          )
          .order('created_at', ascending: false);
      final users =
          (rows as List)
              .map((row) => _DispatchUser.fromMap(row as Map<String, dynamic>))
              .where((user) => user.id != uid && user.role != 'admin')
              .toList();
      _team
        ..clear()
        ..addAll(
          users.where(
            (user) => user.role == 'dispatch_manager' && user.managerId == uid,
          ),
        );
      _candidates
        ..clear()
        ..addAll(users.where((user) => user.role == 'transporter'));
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _assign(_DispatchUser user) async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return;
    try {
      await supabase
          .from('profiles')
          .update({
            'role': 'dispatch_manager',
            'manager_id': uid,
            'status': 'approved',
          })
          .eq('id', user.id);
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${user.name} is now in your dispatch team.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not assign user: $e')));
    }
  }

  Future<void> _remove(_DispatchUser user) async {
    try {
      await supabase
          .from('profiles')
          .update({'role': 'transporter', 'manager_id': null})
          .eq('id', user.id);
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${user.name} was removed from dispatch.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not remove user: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Error: $_error',
            style: const TextStyle(color: Colors.red),
          ),
        ),
      );
    }

    final query = _search.text.trim().toLowerCase();
    final filtered =
        query.isEmpty
            ? _candidates
            : _candidates
                .where(
                  (user) =>
                      user.name.toLowerCase().contains(query) ||
                      user.email.toLowerCase().contains(query),
                )
                .toList();

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Dispatch team',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Assign registered users to track your accepted deliveries.',
                      style: TextStyle(color: Color(0xFF6B6176)),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Refresh',
                onPressed: _load,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _SectionHeader(
            icon: Icons.assignment_ind_outlined,
            title: 'Your dispatch managers',
            count: _team.length,
          ),
          const SizedBox(height: 8),
          if (_team.isEmpty)
            const _EmptyState(
              icon: Icons.person_add_alt_outlined,
              text: 'No dispatch managers assigned yet.',
            )
          else
            ..._team.map(
              (user) => _UserTile(
                user: user,
                actionIcon: Icons.person_remove_outlined,
                actionLabel: 'Remove',
                actionColor: const Color(0xFFB3261E),
                onAction: () => _remove(user),
              ),
            ),
          const SizedBox(height: 24),
          _SectionHeader(
            icon: Icons.group_add_outlined,
            title: 'Available registered users',
            count: filtered.length,
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: 'Search by name or email',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          if (filtered.isEmpty)
            const _EmptyState(
              icon: Icons.search_off_outlined,
              text: 'No transporter users available to assign.',
            )
          else
            ...filtered.map(
              (user) => _UserTile(
                user: user,
                actionIcon: Icons.person_add_alt_outlined,
                actionLabel: 'Add',
                actionColor: const Color(0xFF2E7D32),
                onAction: () => _assign(user),
              ),
            ),
        ],
      ),
    );
  }
}

class _DispatchUser {
  const _DispatchUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.status,
    this.managerId,
  });

  final String id;
  final String name;
  final String email;
  final String role;
  final String status;
  final String? managerId;

  factory _DispatchUser.fromMap(Map<String, dynamic> row) {
    final email = (row['email'] ?? '').toString();
    final name =
        (row['full_name'] ?? row['business_name'] ?? email.ifEmpty('Unnamed'))
            .toString();
    return _DispatchUser(
      id: row['id'] as String,
      name: name,
      email: email,
      role: (row['role'] ?? 'transporter').toString(),
      status: (row['status'] ?? 'pending').toString(),
      managerId: row['manager_id'] as String?,
    );
  }
}

extension on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.count,
  });

  final IconData icon;
  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF4F378A)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          ),
        ),
        Chip(label: Text('$count')),
      ],
    );
  }
}

class _UserTile extends StatelessWidget {
  const _UserTile({
    required this.user,
    required this.actionIcon,
    required this.actionLabel,
    required this.actionColor,
    required this.onAction,
  });

  final _DispatchUser user;
  final IconData actionIcon;
  final String actionLabel;
  final Color actionColor;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Color(0xFFE9E1F1)),
      ),
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: Color(0xFFEADDFF),
          child: Icon(Icons.person_outline, color: Color(0xFF4F378A)),
        ),
        title: Text(user.name),
        subtitle: Text('${user.email} · ${_statusLabel(user.status)}'),
        trailing: TextButton.icon(
          onPressed: onAction,
          icon: Icon(actionIcon, color: actionColor),
          label: Text(actionLabel, style: TextStyle(color: actionColor)),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F5FB),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE9E1F1)),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF6B6176)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text, style: const TextStyle(color: Color(0xFF6B6176))),
          ),
        ],
      ),
    );
  }
}

String _statusLabel(String status) {
  if (status == 'approved') return 'Approved';
  if (status == 'rejected') return 'Rejected';
  return 'Pending';
}
