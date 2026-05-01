import 'package:flutter/material.dart';

import '../../core/supabase/supabase_bootstrap.dart';

class _UserRow {
  _UserRow({
    required this.id,
    required this.name,
    required this.role,
    required this.status,
    required this.permissions,
  });
  final String id;
  String name;
  String role;
  String status;
  Set<String> permissions;
}

const _roleLabels = {
  'transporter': 'Transporter',
  'logistics_manager': 'Logistics Manager',
  'admin': 'Admin',
};

const _allPermissions = [
  ('edit_freight', 'Edit Freight'),
  ('view_analytics', 'View Analytics'),
  ('finalise_booking', 'Finalise Booking'),
  ('view_only', 'View Only'),
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
  String? _error;
  final List<_UserRow> _users = [];

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
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
              'id, full_name, business_name, email, role, status, permissions')
          .order('created_at', ascending: false);
      _users
        ..clear()
        ..addAll((rows as List).map((r) {
          final perms = (r['permissions'] as List?)?.cast<String>() ?? const [];
          final name = (r['full_name'] ??
                  r['business_name'] ??
                  r['email'] ??
                  'Unnamed')
              .toString();
          return _UserRow(
            id: r['id'] as String,
            name: name,
            role: (r['role'] ?? 'transporter') as String,
            status: (r['status'] ?? 'pending') as String,
            permissions: perms.toSet(),
          );
        }));
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _updatePermissions(_UserRow u) async {
    try {
      await supabase
          .from('profiles')
          .update({'permissions': u.permissions.toList()}).eq('id', u.id);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Update failed: $e')),
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
        SnackBar(content: Text('Update failed: $e')),
      );
    }
  }

  Future<void> _removeUser(_UserRow u) async {
    try {
      await supabase.from('profiles').delete().eq('id', u.id);
      setState(() => _users.remove(u));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Delete failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final approved = _users.where((u) => u.status == 'approved').toList();
    final pending = _users.where((u) => u.status == 'pending').toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              const Expanded(
                child: Text('User management',
                    style: TextStyle(
                        fontSize: 24, fontWeight: FontWeight.w500)),
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _loading ? null : _load,
              ),
            ],
          ),
        ),
        TabBar(
          controller: _tab,
          tabs: [
            Tab(text: 'Users (${approved.length})'),
            Tab(text: 'Pending (${pending.length})'),
          ],
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text('Error: $_error',
                            style: const TextStyle(color: Colors.red)),
                      ),
                    )
                  : TabBarView(
                      controller: _tab,
                      children: [
                        _buildList(approved, pending: false),
                        _buildList(pending, pending: true),
                      ],
                    ),
        ),
      ],
    );
  }

  Widget _buildList(List<_UserRow> users, {required bool pending}) {
    if (users.isEmpty) {
      return const Center(
        child: Text('No users', style: TextStyle(color: Color(0xFF49454F))),
      );
    }
    return ListView.separated(
      itemCount: users.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, i) => _userTile(users[i], pending: pending),
    );
  }

  Widget _userTile(_UserRow u, {required bool pending}) {
    return ExpansionTile(
      leading: const CircleAvatar(
        backgroundColor: Color(0xFFEADDFF),
        child: Icon(Icons.person, color: Color(0xFF4F378A)),
      ),
      title: Text(u.name),
      subtitle: Text(_roleLabels[u.role] ?? u.role),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Wrap(
            spacing: 8,
            children: _allPermissions.map((p) {
              final selected = u.permissions.contains(p.$1);
              return FilterChip(
                label: Text(p.$2),
                selected: selected,
                onSelected: (v) async {
                  setState(() {
                    if (v) {
                      u.permissions.add(p.$1);
                    } else {
                      u.permissions.remove(p.$1);
                    }
                  });
                  await _updatePermissions(u);
                },
              );
            }).toList(),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (pending) ...[
                TextButton.icon(
                  onPressed: () => _setStatus(u, 'approved'),
                  icon: const Icon(Icons.check, color: Color(0xFF2E7D32)),
                  label: const Text('Approve',
                      style: TextStyle(color: Color(0xFF2E7D32))),
                ),
                TextButton.icon(
                  onPressed: () => _setStatus(u, 'rejected'),
                  icon: const Icon(Icons.close, color: Color(0xFFB3261E)),
                  label: const Text('Reject',
                      style: TextStyle(color: Color(0xFFB3261E))),
                ),
              ] else
                const SizedBox.shrink(),
              TextButton.icon(
                onPressed: () => _removeUser(u),
                icon: const Icon(Icons.delete_outline, color: Color(0xFFB3261E)),
                label: const Text('Remove',
                    style: TextStyle(color: Color(0xFFB3261E))),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
