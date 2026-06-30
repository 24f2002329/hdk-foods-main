import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/widgets/error_retry.dart';
import '../models/product.dart';
import '../services/product_service.dart';
import '../../../core/widgets/hdk_preloader.dart';

const _red = Color(0xFFFF1E1E);
const _surface = Color(0xFF050505);
const _panel = Color(0xFF111111);
const _card = Color(0xFF1C1C1C);
const _stroke = Color(0xFF2A2A2A);

class ModifierGroupsManagementScreen extends StatefulWidget {
  const ModifierGroupsManagementScreen({super.key});

  @override
  State<ModifierGroupsManagementScreen> createState() =>
      _ModifierGroupsManagementScreenState();
}

class _ModifierGroupsManagementScreenState
    extends State<ModifierGroupsManagementScreen> {
  final ProductService _svc = ProductService();
  List<ModifierGroup> _groups = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _svc.getModifierGroups();
      setState(() {
        _groups = list;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _openGroupEditor({ModifierGroup? group}) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ModifierGroupEditorScreen(group: group),
      ),
    );
    if (result == true) _load();
  }

  Future<void> _deleteGroup(ModifierGroup group) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _card,
        title: const Text('Delete Modifier Group', style: TextStyle(color: Colors.white)),
        content: Text('Delete "${group.name}"? This will delete all options in this group.',
            style: const TextStyle(color: Colors.grey)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _svc.deleteModifierGroup(group.id);
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        backgroundColor: _surface,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text('Modifier Groups',
            style: GoogleFonts.poppins(
                color: Colors.white, fontWeight: FontWeight.w600)),
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh, color: _red),
              onPressed: _load),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openGroupEditor(),
        backgroundColor: _red,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _loading
          ? const Center(child: HdkPreloader())
          : _error != null
              ? ErrorRetryWidget(error: _error!, onRetry: _load)
              : _groups.isEmpty
                  ? Center(
                      child: Text('No modifier groups yet. Tap + to add.',
                          style: GoogleFonts.poppins(color: Colors.grey)))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _groups.length,
                        itemBuilder: (_, i) {
                          final g = _groups[i];
                          return Card(
                            color: _card,
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              title: Text(g.name,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600)),
                              subtitle: Text(
                                '${g.selectionType} • '
                                '${g.required ? "Required" : "Optional"} • '
                                '${g.options.length} options',
                                style: const TextStyle(color: Colors.grey, fontSize: 12),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined,
                                        color: Colors.grey, size: 20),
                                    onPressed: () => _openGroupEditor(group: g),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline,
                                        color: Colors.redAccent, size: 20),
                                    onPressed: () => _deleteGroup(g),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}

class ModifierGroupEditorScreen extends StatefulWidget {
  final ModifierGroup? group;
  const ModifierGroupEditorScreen({super.key, this.group});

  @override
  State<ModifierGroupEditorScreen> createState() =>
      _ModifierGroupEditorScreenState();
}

class _ModifierGroupEditorScreenState extends State<ModifierGroupEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final ProductService _svc = ProductService();

  late TextEditingController _name;
  late TextEditingController _description;
  late TextEditingController _minSelection;
  late TextEditingController _maxSelection;
  late TextEditingController _displayOrder;
  String _selectionType = 'SINGLE';
  bool _required = false;
  bool _saving = false;

  List<ModifierOption> _options = [];

  @override
  void initState() {
    super.initState();
    final g = widget.group;
    _name = TextEditingController(text: g?.name ?? '');
    _description = TextEditingController(text: g?.description ?? '');
    _minSelection = TextEditingController(text: '${g?.minSelection ?? 0}');
    _maxSelection = TextEditingController(text: '${g?.maxSelection ?? 1}');
    _displayOrder = TextEditingController(text: '${g?.displayOrder ?? 0}');
    final type = (g?.selectionType ?? 'SINGLE').toUpperCase();
    _selectionType = (type == 'SINGLE' || type == 'MULTIPLE') ? type : 'SINGLE';
    _required = g?.required ?? false;
    _options = g != null ? List<ModifierOption>.from(g.options) : [];
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _minSelection.dispose();
    _maxSelection.dispose();
    _displayOrder.dispose();
    super.dispose();
  }

  Future<void> _saveGroup() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final data = {
      'name': _name.text.trim(),
      'description': _description.text.trim(),
      'selection_type': _selectionType,
      'required': _required,
      'min_selection': int.tryParse(_minSelection.text) ?? 0,
      'max_selection': int.tryParse(_maxSelection.text) ?? 1,
      'display_order': int.tryParse(_displayOrder.text) ?? 0,
    };

    try {
      if (widget.group == null) {
        await _svc.createModifierGroup(data);
      } else {
        await _svc.updateModifierGroup(widget.group!.id, data);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _addOrEditOption({ModifierOption? option}) async {
    if (widget.group == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please save the modifier group first before adding options.')),
      );
      return;
    }

    final ctrlName = TextEditingController(text: option?.name ?? '');
    final ctrlPrice = TextEditingController(text: option != null ? '${option.extraPrice}' : '0.0');
    final ctrlSort = TextEditingController(text: option != null ? '${option.sortOrder}' : '0');
    bool available = option?.isAvailable ?? true;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _card,
        title: Text(option == null ? 'New Option' : 'Edit Option',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: ctrlName,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Option Name',
                  labelStyle: TextStyle(color: Colors.grey),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: _stroke)),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: ctrlPrice,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Extra Price (₹)',
                  labelStyle: TextStyle(color: Colors.grey),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: _stroke)),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: ctrlSort,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Sort Order',
                  labelStyle: TextStyle(color: Colors.grey),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: _stroke)),
                ),
              ),
              const SizedBox(height: 12),
              StatefulBuilder(
                builder: (ctx2, setDialogState) => SwitchListTile(
                  title: const Text('Available', style: TextStyle(color: Colors.white, fontSize: 14)),
                  value: available,
                  activeColor: _red,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (val) => setDialogState(() => available = val),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _red,
              minimumSize: const Size(80, 40),
            ),
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (result == true && ctrlName.text.trim().isNotEmpty) {
      final data = {
        'modifier_group': widget.group!.id,
        'name': ctrlName.text.trim(),
        'extra_price': double.tryParse(ctrlPrice.text) ?? 0.0,
        'sort_order': int.tryParse(ctrlSort.text) ?? 0,
        'is_available': available,
      };
      try {
        if (option == null) {
          await _svc.createModifierOption(data);
        } else {
          await _svc.updateModifierOption(option.id, data);
        }
        // Reload option list from server
        final updatedGroups = await _svc.getModifierGroups();
        final match = updatedGroups.firstWhere((g) => g.id == widget.group!.id);
        setState(() {
          _options = match.options;
        });
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }

  Future<void> _deleteOption(ModifierOption opt) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _card,
        title: const Text('Delete Option', style: TextStyle(color: Colors.white)),
        content: Text('Delete option "${opt.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _svc.deleteModifierOption(opt.id);
      final updatedGroups = await _svc.getModifierGroups();
      final match = updatedGroups.firstWhere((g) => g.id == widget.group!.id);
      setState(() {
        _options = match.options;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.group != null;
    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        backgroundColor: _surface,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(isEdit ? 'Edit Modifier Group' : 'Add Modifier Group',
            style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: HdkPreloader(width: 20, height: 20),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.check, color: _red),
              onPressed: _saveGroup,
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _name,
              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Group Name',
                labelStyle: const TextStyle(color: Colors.grey),
                filled: true,
                fillColor: _panel,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _description,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Description (Optional)',
                labelStyle: const TextStyle(color: Colors.grey),
                filled: true,
                fillColor: _panel,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _selectionType,
              dropdownColor: _panel,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Selection Type',
                labelStyle: const TextStyle(color: Colors.grey),
                filled: true,
                fillColor: _panel,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              items: const [
                DropdownMenuItem(value: 'SINGLE', child: Text('Single Choice')),
                DropdownMenuItem(value: 'MULTIPLE', child: Text('Multiple Choice')),
              ],
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _selectionType = val;
                  });
                }
              },
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              title: const Text('Required Selection?', style: TextStyle(color: Colors.white)),
              value: _required,
              activeColor: _red,
              tileColor: _panel,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              onChanged: (val) => setState(() => _required = val),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _minSelection,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Min Selection',
                      labelStyle: const TextStyle(color: Colors.grey),
                      filled: true,
                      fillColor: _panel,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _maxSelection,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Max Selection',
                      labelStyle: const TextStyle(color: Colors.grey),
                      filled: true,
                      fillColor: _panel,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _displayOrder,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Display Order',
                labelStyle: const TextStyle(color: Colors.grey),
                filled: true,
                fillColor: _panel,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Options',
                    style: GoogleFonts.poppins(
                        color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                if (isEdit)
                  ElevatedButton.icon(
                    onPressed: () => _addOrEditOption(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _red,
                      minimumSize: const Size(0, 36),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    icon: const Icon(Icons.add, color: Colors.white, size: 16),
                    label: const Text('Add Option', style: TextStyle(color: Colors.white)),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            if (!isEdit)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Text('Create the group first to add options.',
                      style: TextStyle(color: Colors.grey)),
                ),
              )
            else if (_options.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Text('No options added yet.', style: TextStyle(color: Colors.grey)),
                ),
              )
            else
              ..._options.map((opt) {
                return Card(
                  color: _panel,
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(opt.name, style: const TextStyle(color: Colors.white)),
                    subtitle: Text(
                      'Price: +₹${opt.extraPrice.toStringAsFixed(0)} • '
                      'Sort: ${opt.sortOrder} • '
                      '${opt.isAvailable ? "Active" : "Disabled"}',
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.grey, size: 18),
                          onPressed: () => _addOrEditOption(option: opt),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                          onPressed: () => _deleteOption(opt),
                        ),
                      ],
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}
