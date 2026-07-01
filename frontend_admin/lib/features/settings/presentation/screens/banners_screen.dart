import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../services/config_service.dart';
import 'package:hdk_core/hdk_core.dart';

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
    try {
      final list = await _svc.getBanners();
      if (mounted) setState(() { _banners = list.cast<Map<String, dynamic>>(); _loading = false; });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
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
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _card,
        title: const Text('Delete Banner', style: TextStyle(color: Colors.white)),
        content: const Text('Remove this banner?', style: TextStyle(color: Colors.grey)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: _red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await _svc.deleteBanner(id);
        _load();
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        backgroundColor: _surface,
        title: Text('Banners', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
        actions: [
          IconButton(icon: const Icon(Icons.add, color: _red), onPressed: () => _openForm()),
        ],
      ),
      body: _loading
          ? const Center(child: HdkPreloader())
          : _banners.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('No banners yet', style: GoogleFonts.poppins(color: Colors.grey)),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () => _openForm(),
                        icon: const Icon(Icons.add, color: _red),
                        label: const Text('Add Banner', style: TextStyle(color: _red)),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _banners.length,
                  itemBuilder: (context, i) {
                    final b = _banners[i];
                    return Card(
                      color: _card,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: _stroke)),
                      child: ListTile(
                        leading: b['image_url'] != null && (b['image_url'] as String).isNotEmpty
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: Image.network(b['image_url'], width: 60, height: 40, fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) => const Icon(Icons.image, color: Colors.grey)),
                              )
                            : const Icon(Icons.image, color: Colors.grey),
                        title: Text(b['title'] ?? 'Banner', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                        subtitle: Text(b['subtitle'] ?? '', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(icon: const Icon(Icons.edit_outlined, color: Colors.grey, size: 18), onPressed: () => _openForm(banner: b)),
                            IconButton(icon: const Icon(Icons.delete_outline, color: _red, size: 18), onPressed: () => _delete(b['id'])),
                          ],
                        ),
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

  File? _pickedImageFile;
  final _picker = ImagePicker();
  bool _uploadingImage = false;

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

  Future<void> _pickImage(ImageSource source) async {
    try {
      final xfile = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1024,
      );
      if (xfile == null) return;
      setState(() {
        _pickedImageFile = File(xfile.path);
        _imageUrl.clear();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not pick image: $e')));
      }
    }
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: _card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.camera_alt, color: _red),
            title: const Text('Camera', style: TextStyle(color: Colors.white)),
            onTap: () { Navigator.pop(context); _pickImage(ImageSource.camera); },
          ),
          ListTile(
            leading: const Icon(Icons.photo_library, color: _red),
            title: const Text('Gallery', style: TextStyle(color: Colors.white)),
            onTap: () { Navigator.pop(context); _pickImage(ImageSource.gallery); },
          ),
          if (_pickedImageFile != null || _imageUrl.text.isNotEmpty)
            ListTile(
              leading: const Icon(Icons.clear, color: Colors.grey),
              title: const Text('Remove image', style: TextStyle(color: Colors.grey)),
              onTap: () {
                setState(() { _pickedImageFile = null; _imageUrl.clear(); });
                Navigator.pop(context);
              },
            ),
        ]),
      ),
    );
  }

  Future<void> _save() async {
    if (_imageUrl.text.trim().isEmpty && _pickedImageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Image is required')));
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
      Map<String, dynamic> saved;
      if (widget.banner == null) {
        saved = await _svc.createBanner(data);
      } else {
        await _svc.updateBanner(widget.banner!['id'], data);
        saved = widget.banner!;
      }

      // Upload banner image file if one was picked
      if (_pickedImageFile != null) {
        setState(() { _uploadingImage = true; });
        final bannerId = saved['id'];
        if (bannerId != null) {
          await _svc.uploadBannerImage(bannerId, _pickedImageFile!);
        }
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() { _saving = false; _uploadingImage = false; });
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
          _saving || _uploadingImage
              ? const Padding(padding: EdgeInsets.all(16),
                  child: Center(
                    child: HdkPreloader(width: 20, height: 20),
                  ))
              : TextButton(onPressed: _save, child: const Text('Save', style: TextStyle(color: _red, fontWeight: FontWeight.bold))),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Banner Image',
            style: GoogleFonts.poppins(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          if (_pickedImageFile != null || _imageUrl.text.trim().isNotEmpty) ...[
            GestureDetector(
              onTap: _showImageSourceDialog,
              child: Container(
                height: 140,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _stroke),
                  image: DecorationImage(
                    image: _pickedImageFile != null
                        ? FileImage(_pickedImageFile!) as ImageProvider
                        : NetworkImage(_imageUrl.text.trim()),
                    fit: BoxFit.cover,
                  ),
                ),
                child: Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.edit, color: Colors.white, size: 16),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          Row(children: [
            Expanded(
              child: TextFormField(
                controller: _imageUrl,
                style: const TextStyle(color: Colors.white),
                decoration: _dec(_pickedImageFile != null ? 'Picked from device (will upload)' : 'Image URL *'),
                readOnly: _pickedImageFile != null,
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 54,
              child: OutlinedButton.icon(
                onPressed: _showImageSourceDialog,
                icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
                label: const Text('Upload'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _red,
                  side: const BorderSide(color: _red),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ]),
          if (_uploadingImage)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: LinearProgressIndicator(color: _red),
            ),
          const SizedBox(height: 16),
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
