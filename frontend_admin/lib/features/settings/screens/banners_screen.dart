import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/config_service.dart';

const _red = Color(0xFFFF1E1E);
const _surface = Color(0xFF050505);
const _card = Color(0xFF111111);
const _stroke = Color(0xFF2A2A2A);

class BannersScreen extends StatefulWidget {
  const BannersScreen({super.key});

  @override
  State<BannersScreen> createState() => _BannersScreenState();
}

class _BannersScreenState extends State<BannersScreen> {
  final AdminConfigService _svc = AdminConfigService();
  List<Map<String, dynamic>> _banners = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await _svc.getBanners();
      if (mounted) setState(() { _banners = list.cast<Map<String, dynamic>>(); _loading = false; });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openForm({Map<String, dynamic>? banner}) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => _BannerFormScreen(banner: banner)),
    );
    if (result == true) _load();
  }

  Future<void> _delete(int id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _card,
        title: const Text('Delete Banner', style: TextStyle(color: Colors.white)),
        content: const Text('Remove this banner?', style: TextStyle(color: Colors.grey)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _svc.deleteBanner(id);
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        backgroundColor: _surface,
        title: Text('Banners', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
        actions: [IconButton(icon: const Icon(Icons.refresh, color: _red), onPressed: _load)],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(),
        backgroundColor: _red,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _red))
          : _banners.isEmpty
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.image_not_supported, color: Colors.grey, size: 64),
                  const SizedBox(height: 12),
                  Text('No banners yet', style: GoogleFonts.poppins(color: Colors.grey)),
                  const SizedBox(height: 8),
                  TextButton.icon(onPressed: () => _openForm(),
                    icon: const Icon(Icons.add, color: _red),
                    label: const Text('Add Banner', style: TextStyle(color: _red))),
                ]))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
                  itemCount: _banners.length,
                  itemBuilder: (_, i) {
                    final b = _banners[i];
                    return Card(
                      color: _card,
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        leading: b['image_url'] != null && (b['image_url'] as String).isNotEmpty
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: Image.network(b['image_url'], width: 52, height: 52,
                                    fit: BoxFit.cover, errorBuilder: (_, __, ___) =>
                                        const Icon(Icons.broken_image, color: Colors.grey)),
                              )
                            : const Icon(Icons.image, color: Colors.grey, size: 40),
                        title: Text(b['title'] ?? 'Banner', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                        subtitle: Text(b['subtitle'] ?? '', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: (b['is_active'] == true ? Colors.green : Colors.grey).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(b['is_active'] == true ? 'Active' : 'Hidden',
                                style: TextStyle(color: b['is_active'] == true ? Colors.greenAccent : Colors.grey, fontSize: 10)),
                          ),
                          IconButton(icon: const Icon(Icons.edit_outlined, color: Colors.grey, size: 18), onPressed: () => _openForm(banner: b)),
                          IconButton(icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18), onPressed: () => _delete(b['id'])),
                        ]),
                      ),
                    );
                  },
                ),
    );
  }
}

class _BannerFormScreen extends StatefulWidget {
  final Map<String, dynamic>? banner;
  const _BannerFormScreen({this.banner});

  @override
  State<_BannerFormScreen> createState() => _BannerFormScreenState();
}

class _BannerFormScreenState extends State<_BannerFormScreen> {
  final _svc = AdminConfigService();
  final _imageUrl = TextEditingController();
  final _title = TextEditingController();
  final _subtitle = TextEditingController();
  final _linkAction = TextEditingController();
  bool _isActive = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final b = widget.banner;
    if (b != null) {
      _imageUrl.text = b['image_url'] ?? '';
      _title.text = b['title'] ?? '';
      _subtitle.text = b['subtitle'] ?? '';
      _linkAction.text = b['link_action'] ?? '';
      _isActive = b['is_active'] ?? true;
    }
  }

  @override
  void dispose() {
    _imageUrl.dispose(); _title.dispose(); _subtitle.dispose(); _linkAction.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_imageUrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Image URL is required')));
      return;
    }
    setState(() => _saving = true);
    final data = {
      'image_url': _imageUrl.text.trim(),
      'title': _title.text.trim(),
      'subtitle': _subtitle.text.trim(),
      'link_action': _linkAction.text.trim(),
      'is_active': _isActive,
    };
    try {
      if (widget.banner == null) {
        await _svc.createBanner(data);
      } else {
        await _svc.updateBanner(widget.banner!['id'], data);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  InputDecoration _dec(String label) => InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.grey),
        filled: true, fillColor: _card,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _stroke)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _stroke)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _red)),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        backgroundColor: _surface,
        title: Text(widget.banner == null ? 'Add Banner' : 'Edit Banner',
            style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
        actions: [
          _saving
              ? const Padding(padding: EdgeInsets.all(16),
                  child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: _red)))
              : TextButton(onPressed: _save, child: const Text('Save', style: TextStyle(color: _red, fontWeight: FontWeight.bold))),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextFormField(controller: _imageUrl, style: const TextStyle(color: Colors.white), decoration: _dec('Image URL *')),
          const SizedBox(height: 12),
          TextFormField(controller: _title, style: const TextStyle(color: Colors.white), decoration: _dec('Title (optional)')),
          const SizedBox(height: 12),
          TextFormField(controller: _subtitle, style: const TextStyle(color: Colors.white), decoration: _dec('Subtitle (optional)')),
          const SizedBox(height: 12),
          TextFormField(controller: _linkAction, style: const TextStyle(color: Colors.white),
              decoration: _dec('Link Action').copyWith(hintText: 'e.g. menu, orders', hintStyle: const TextStyle(color: Colors.grey, fontSize: 12))),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(10), border: Border.all(color: _stroke)),
            child: Row(children: [
              const Expanded(child: Text('Active', style: TextStyle(color: Colors.white))),
              Switch(value: _isActive, onChanged: (v) => setState(() => _isActive = v), activeThumbColor: _red),
            ]),
          ),
        ],
      ),
    );
  }
}
