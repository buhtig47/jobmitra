// lib/screens/alerts_screen.dart
import 'package:flutter/material.dart';
import '../utils/constants.dart';
import '../models/job_model.dart';
import '../services/api_service.dart';

class AlertsScreen extends StatefulWidget {
  final ApiService api;
  const AlertsScreen({super.key, required this.api});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  List<AlertRule> _rules = [];
  bool _loading = true;

  static const _categories = [
    '', 'railway', 'banking', 'ssc', 'teaching', 'police',
    'defence', 'upsc', 'anganwadi', 'psu', 'medical',
    'research', 'engineering', 'postal', 'admin', 'it_tech',
  ];

  static const _states = [
    '', 'Andhra Pradesh', 'Arunachal Pradesh', 'Assam', 'Bihar',
    'Chhattisgarh', 'Goa', 'Gujarat', 'Haryana', 'Himachal Pradesh',
    'Jharkhand', 'Karnataka', 'Kerala', 'Madhya Pradesh', 'Maharashtra',
    'Manipur', 'Meghalaya', 'Mizoram', 'Nagaland', 'Odisha', 'Punjab',
    'Rajasthan', 'Sikkim', 'Tamil Nadu', 'Telangana', 'Tripura',
    'Uttar Pradesh', 'Uttarakhand', 'West Bengal', 'Delhi', 'All India',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final rules = await widget.api.getAlertRules();
    if (mounted) setState(() { _rules = rules; _loading = false; });
  }

  Future<void> _save() => widget.api.saveAlertRules(_rules);

  Future<void> _toggle(int idx) async {
    setState(() {
      _rules[idx] = _rules[idx].copyWith(isActive: !_rules[idx].isActive);
    });
    await _save();
  }

  Future<void> _delete(int idx) async {
    setState(() => _rules.removeAt(idx));
    await _save();
  }

  void _showAddSheet([AlertRule? existing, int? editIdx]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddAlertSheet(
        existing: existing,
        categories: _categories,
        states: _states,
        onSave: (rule) async {
          setState(() {
            if (editIdx != null) {
              _rules[editIdx] = rule;
            } else {
              _rules.insert(0, rule);
            }
          });
          await _save();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // Header
          SliverToBoxAdapter(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF1A6B3C), Color(0xFF0D4A28)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 12, 20, 24),
                  child: Row(children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                      onPressed: () => Navigator.pop(context),
                      padding: EdgeInsets.zero,
                    ),
                    const SizedBox(width: 4),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('🔔 Job Alerts', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 3),
                      Text('Naye matching jobs pe instant notification',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 13)),
                    ])),
                    // Add button
                    GestureDetector(
                      onTap: () => _showAddSheet(),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.add_rounded, color: Colors.white, size: 18),
                          SizedBox(width: 4),
                          Text('Add', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                        ]),
                      ),
                    ),
                  ]),
                ),
              ),
            ),
          ),

          if (_loading)
            const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
          else if (_rules.isEmpty)
            SliverFillRemaining(child: _EmptyState(onAdd: () => _showAddSheet()))
          else
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) => _AlertTile(
                    rule: _rules[i],
                    onToggle: () => _toggle(i),
                    onDelete: () => _delete(i),
                    onEdit: () => _showAddSheet(_rules[i], i),
                  ),
                  childCount: _rules.length,
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: _rules.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _showAddSheet(),
              backgroundColor: AppColors.primary,
              icon: const Icon(Icons.add_rounded, color: Colors.white),
              label: const Text('New Alert', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            ),
    );
  }
}

// ── Alert tile ──────────────────────────────────────────────
class _AlertTile extends StatelessWidget {
  final AlertRule    rule;
  final VoidCallback onToggle, onDelete, onEdit;
  const _AlertTile({required this.rule, required this.onToggle, required this.onDelete, required this.onEdit});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: rule.isActive
          ? AppColors.primary.withValues(alpha: 0.2)
          : Colors.grey.withValues(alpha: 0.2)),
      boxShadow: [BoxShadow(
        color: (rule.isActive ? AppColors.primary : Colors.grey).withValues(alpha: 0.07),
        blurRadius: 8, offset: const Offset(0, 3),
      )],
    ),
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: Container(
        width: 44, height: 44,
        decoration: BoxDecoration(
          color: (rule.isActive ? AppColors.primary : Colors.grey).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(child: Icon(Icons.notifications_rounded,
            color: rule.isActive ? AppColors.primary : Colors.grey[400], size: 22)),
      ),
      title: Text(rule.label,
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14,
              color: rule.isActive ? AppColors.textPrimary : Colors.grey[400])),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 3),
        child: Wrap(spacing: 6, runSpacing: 4, children: [
          if (rule.keyword.isNotEmpty)  _chip('🔍 ${rule.keyword}'),
          if (rule.state.isNotEmpty)    _chip('📍 ${rule.state}'),
          if (rule.category.isNotEmpty) _chip('📂 ${rule.category}'),
          if (rule.freeOnly)            _chip('💸 Free only'),
        ]),
      ),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        Switch(value: rule.isActive, onChanged: (_) => onToggle(),
            activeColor: AppColors.primary, materialTapTargetSize: MaterialTapTargetSize.shrinkWrap),
        PopupMenuButton<String>(
          icon: Icon(Icons.more_vert_rounded, color: Colors.grey[400], size: 20),
          onSelected: (v) {
            if (v == 'edit') onEdit();
            if (v == 'delete') onDelete();
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'edit', child: Row(children: [
              Icon(Icons.edit_rounded, size: 16), SizedBox(width: 8), Text('Edit'),
            ])),
            const PopupMenuItem(value: 'delete', child: Row(children: [
              Icon(Icons.delete_rounded, size: 16, color: Colors.red), SizedBox(width: 8),
              Text('Delete', style: TextStyle(color: Colors.red)),
            ])),
          ],
        ),
      ]),
    ),
  );

  Widget _chip(String t) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
    child: Text(t, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
  );
}

// ── Add/Edit alert bottom sheet ─────────────────────────────
class _AddAlertSheet extends StatefulWidget {
  final AlertRule?        existing;
  final List<String>      categories;
  final List<String>      states;
  final Function(AlertRule) onSave;
  const _AddAlertSheet({this.existing, required this.categories, required this.states, required this.onSave});

  @override
  State<_AddAlertSheet> createState() => _AddAlertSheetState();
}

class _AddAlertSheetState extends State<_AddAlertSheet> {
  late final TextEditingController _kw;
  String _state    = '';
  String _category = '';
  bool   _freeOnly = false;

  static const _catLabels = {
    '': 'Any Category',
    'railway': '🚂 Railway', 'banking': '🏦 Banking', 'ssc': '📋 SSC',
    'teaching': '📚 Teaching', 'police': '👮 Police', 'defence': '⭐ Defence',
    'upsc': '🏛️ UPSC', 'anganwadi': '🌸 Anganwadi', 'psu': '🏭 PSU',
    'medical': '🏥 Medical', 'research': '🔬 Research', 'engineering': '⚙️ Engineering',
    'postal': '📮 Postal', 'admin': '🗂️ Admin', 'it_tech': '💻 IT/Tech',
  };

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _kw       = TextEditingController(text: e?.keyword ?? '');
    _state    = e?.state    ?? '';
    _category = e?.category ?? '';
    _freeOnly = e?.freeOnly ?? false;
  }

  @override
  void dispose() { _kw.dispose(); super.dispose(); }

  void _save() {
    final rule = AlertRule(
      id:       widget.existing?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      keyword:  _kw.text.trim(),
      state:    _state,
      category: _category,
      freeOnly: _freeOnly,
      isActive: widget.existing?.isActive ?? true,
    );
    if (rule.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Kuch toh filter set karo!'),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    widget.onSave(rule);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Handle
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),
          Text(isEdit ? 'Alert Edit Karo' : 'Naya Alert',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
          const SizedBox(height: 4),
          Text('Jab koi matching job aaye, notification milegi',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          const SizedBox(height: 20),

          // Keyword
          const Text('🔍 Keyword (optional)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 6),
          TextField(
            controller: _kw,
            decoration: InputDecoration(
              hintText: 'e.g. UPSC, constable, teacher...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
          const SizedBox(height: 16),

          // State
          const Text('📍 State (optional)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            value: _state,
            decoration: InputDecoration(
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
            items: widget.states.map((s) => DropdownMenuItem(
              value: s,
              child: Text(s.isEmpty ? 'Any State' : s),
            )).toList(),
            onChanged: (v) => setState(() => _state = v ?? ''),
          ),
          const SizedBox(height: 16),

          // Category
          const Text('📂 Category (optional)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            value: _category,
            decoration: InputDecoration(
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
            items: widget.categories.map((c) => DropdownMenuItem(
              value: c,
              child: Text(_catLabels[c] ?? c),
            )).toList(),
            onChanged: (v) => setState(() => _category = v ?? ''),
          ),
          const SizedBox(height: 16),

          // Free only toggle
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(children: [
              const Icon(Icons.money_off_rounded, color: AppColors.primary, size: 20),
              const SizedBox(width: 10),
              const Expanded(child: Text('Free jobs only (no application fee)',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
              Switch(value: _freeOnly, onChanged: (v) => setState(() => _freeOnly = v),
                  activeColor: AppColors.primary),
            ]),
          ),
          const SizedBox(height: 24),

          // Save button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: Text(isEdit ? 'Update Alert' : 'Alert Save Karo',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Empty state ─────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(40),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('🔕', style: TextStyle(fontSize: 56)),
        const SizedBox(height: 16),
        const Text('Koi Alert Set Nahi Hai',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
        const SizedBox(height: 8),
        Text('Apni pasand ke jobs ka alert set karo\naur automatically notification milegi',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.5)),
        const SizedBox(height: 28),
        ElevatedButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Pehla Alert Banao', style: TextStyle(fontWeight: FontWeight.w700)),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ]),
    ),
  );
}
