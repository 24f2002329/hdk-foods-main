import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';

import '../../data/repositories/config_service.dart';
import 'package:hdk_core/hdk_core.dart';

const _red = Color(0xFFFF1E1E);
const _surface = Color(0xFF050505);
const _card = Color(0xFF111111);
const _stroke = Color(0xFF2A2A2A);

class StoreManagementScreen extends StatefulWidget {
  const StoreManagementScreen({super.key});

  @override
  State<StoreManagementScreen> createState() => _StoreManagementScreenState();
}

class _StoreManagementScreenState extends State<StoreManagementScreen> {
  final AdminConfigService _svc = AdminConfigService();
  bool _loading = true;
  bool _saving = false;
  String? _error;

  // Store Hours & Status
  final _closedMsg = TextEditingController();
  final _scheduledClosedMsg = TextEditingController();
  bool _isStoreOpen = true;
  TimeOfDay _openTime = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _closeTime = const TimeOfDay(hour: 22, minute: 0);
  DateTime? _scheduledStart;
  DateTime? _scheduledEnd;

  // Kitchen Location
  final _kitchenName = TextEditingController();
  final _kitchenLat = TextEditingController();
  final _kitchenLng = TextEditingController();
  final _kitchenPhone = TextEditingController();
  GoogleMapController? _mapController;
  static const double _defaultLat = 25.9233;
  static const double _defaultLng = 73.6646;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _closedMsg.dispose();
    _scheduledClosedMsg.dispose();
    _kitchenName.dispose();
    _kitchenLat.dispose();
    _kitchenLng.dispose();
    _kitchenPhone.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _svc.getConfig();
      if (mounted) {
        setState(() {
          _closedMsg.text = data['store_closed_msg'] ?? '';
          _isStoreOpen = data['is_store_open'] ?? true;
          final ot = (data['store_open_time'] as String? ?? '08:00:00').split(
            ':',
          );
          final ct = (data['store_close_time'] as String? ?? '22:00:00').split(
            ':',
          );
          _openTime = TimeOfDay(
            hour: int.parse(ot[0]),
            minute: int.parse(ot[1]),
          );
          _closeTime = TimeOfDay(
            hour: int.parse(ct[0]),
            minute: int.parse(ct[1]),
          );

          _scheduledClosedMsg.text = data['scheduled_closed_msg'] ?? '';
          _scheduledStart = data['scheduled_close_start'] != null
              ? DateTime.parse(data['scheduled_close_start']).toLocal()
              : null;
          _scheduledEnd = data['scheduled_close_end'] != null
              ? DateTime.parse(data['scheduled_close_end']).toLocal()
              : null;

          _kitchenName.text = data['kitchen_name'] ?? 'HDK Foods Kitchen';
          _kitchenLat.text = (data['kitchen_latitude'] ?? _defaultLat)
              .toString();
          _kitchenLng.text = (data['kitchen_longitude'] ?? _defaultLng)
              .toString();
          _kitchenPhone.text = data['kitchen_phone'] ?? '+918875775282';

          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await _svc.updateConfig({
        'store_closed_msg': _closedMsg.text.trim(),
        'is_store_open': _isStoreOpen,
        'store_open_time':
            '${_openTime.hour.toString().padLeft(2, '0')}:${_openTime.minute.toString().padLeft(2, '0')}:00',
        'store_close_time':
            '${_closeTime.hour.toString().padLeft(2, '0')}:${_closeTime.minute.toString().padLeft(2, '0')}:00',
        'scheduled_closed_msg': _scheduledClosedMsg.text.trim(),
        'scheduled_close_start': _scheduledStart?.toUtc().toIso8601String(),
        'scheduled_close_end': _scheduledEnd?.toUtc().toIso8601String(),
        'kitchen_name': _kitchenName.text.trim(),
        'kitchen_latitude': _kitchenLat.text.trim(),
        'kitchen_longitude': _kitchenLng.text.trim(),
        'kitchen_phone': _kitchenPhone.text.trim(),
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Store settings saved ✅')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  double get _parsedLat => double.tryParse(_kitchenLat.text) ?? _defaultLat;
  double get _parsedLng => double.tryParse(_kitchenLng.text) ?? _defaultLng;

  void _onMapTap(LatLng pos) {
    setState(() {
      _kitchenLat.text = pos.latitude.toStringAsFixed(7);
      _kitchenLng.text = pos.longitude.toStringAsFixed(7);
    });
    _mapController?.animateCamera(CameraUpdate.newLatLng(pos));
  }

  void _recenterMap() {
    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(LatLng(_parsedLat, _parsedLng), 15),
    );
  }

  Future<void> _pickTime(bool isOpen) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isOpen ? _openTime : _closeTime,
    );
    if (picked != null) {
      setState(() => isOpen ? _openTime = picked : _closeTime = picked);
    }
  }

  Future<DateTime?> _pickDateTime(
    BuildContext context,
    DateTime? initial,
  ) async {
    final date = await showDatePicker(
      context: context,
      initialDate: initial ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null) return null;

    if (!context.mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial ?? DateTime.now()),
    );
    if (time == null) return null;

    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        backgroundColor: _surface,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          'Store Management',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          _saving
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: HdkPreloader(width: 20, height: 20)),
                )
              : TextButton(
                  onPressed: _save,
                  child: const Text(
                    'Save',
                    style: TextStyle(color: _red, fontWeight: FontWeight.bold),
                  ),
                ),
        ],
      ),
      body: _loading
          ? const Center(child: HdkPreloader())
          : _error != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_error!, style: const TextStyle(color: Colors.grey)),
                  TextButton(
                    onPressed: _load,
                    child: const Text('Retry', style: TextStyle(color: _red)),
                  ),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Store status
                _sectionHeader('Store Status'),
                _toggleTile(
                  'Store Open',
                  _isStoreOpen,
                  (v) => setState(() => _isStoreOpen = v),
                ),
                const SizedBox(height: 12),
                _timeTile('Open Time', _openTime, () => _pickTime(true)),
                const SizedBox(height: 8),
                _timeTile('Close Time', _closeTime, () => _pickTime(false)),
                const SizedBox(height: 12),
                _inputField(
                  'Closed Message',
                  _closedMsg,
                  hint: 'e.g. We\'re closed. Back at 10 AM!',
                ),
                const SizedBox(height: 24),

                // Scheduled closure
                _sectionHeader('Scheduled Kitchen Closure'),
                Text(
                  'Set a date & time range to temporarily close the kitchen for holidays or maintenance.',
                  style: GoogleFonts.poppins(color: Colors.grey, fontSize: 11),
                ),
                const SizedBox(height: 12),
                _dateTimeTile(
                  'Closure Start Time',
                  _scheduledStart,
                  () async {
                    final picked = await _pickDateTime(
                      context,
                      _scheduledStart,
                    );
                    if (picked != null) {
                      setState(() => _scheduledStart = picked);
                    }
                  },
                  onClear: _scheduledStart != null
                      ? () => setState(() => _scheduledStart = null)
                      : null,
                ),
                const SizedBox(height: 8),
                _dateTimeTile(
                  'Closure End Time',
                  _scheduledEnd,
                  () async {
                    final picked = await _pickDateTime(context, _scheduledEnd);
                    if (picked != null) {
                      setState(() => _scheduledEnd = picked);
                    }
                  },
                  onClear: _scheduledEnd != null
                      ? () => setState(() => _scheduledEnd = null)
                      : null,
                ),
                const SizedBox(height: 12),
                _inputField(
                  'Scheduled Closed Message',
                  _scheduledClosedMsg,
                  hint:
                      'e.g. Closed for scheduled maintenance. Back on Tuesday at 9 AM!',
                ),
                const SizedBox(height: 32),

                // Kitchen Location
                _sectionHeader('Kitchen Location (Map Pin)'),
                Text(
                  'Set your kitchen\'s location on the map. Customers use this to track deliveries and get directions.',
                  style: GoogleFonts.poppins(color: Colors.grey, fontSize: 11),
                ),
                const SizedBox(height: 12),
                _inputField(
                  'Kitchen Display Name',
                  _kitchenName,
                  hint: 'e.g. HDK Foods Kitchen',
                  maxLines: 1,
                ),
                const SizedBox(height: 10),
                _inputField(
                  'Kitchen Phone Number',
                  _kitchenPhone,
                  hint: 'e.g. +918875775282',
                  maxLines: 1,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _inputField(
                        'Latitude',
                        _kitchenLat,
                        hint: 'e.g. 25.9233',
                        maxLines: 1,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                          signed: true,
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _inputField(
                        'Longitude',
                        _kitchenLng,
                        hint: 'e.g. 73.6646',
                        maxLines: 1,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                          signed: true,
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Map preview
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    height: 220,
                    decoration: BoxDecoration(
                      border: Border.all(color: _stroke),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Stack(
                      children: [
                        GoogleMap(
                          initialCameraPosition: CameraPosition(
                            target: LatLng(_parsedLat, _parsedLng),
                            zoom: 15,
                          ),
                          onMapCreated: (c) => _mapController = c,
                          onTap: _onMapTap,
                          markers: {
                            Marker(
                              markerId: const MarkerId('kitchen'),
                              position: LatLng(_parsedLat, _parsedLng),
                              infoWindow: InfoWindow(
                                title: _kitchenName.text.isEmpty
                                    ? 'Kitchen'
                                    : _kitchenName.text,
                              ),
                            ),
                          },
                          myLocationButtonEnabled: false,
                          zoomControlsEnabled: false,
                          mapType: MapType.normal,
                        ),
                        // Tap hint
                        Positioned(
                          top: 10,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.65),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.touch_app_rounded,
                                    color: Colors.white,
                                    size: 13,
                                  ),
                                  SizedBox(width: 5),
                                  Text(
                                    'Tap map to move pin',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        // Recenter button
                        Positioned(
                          bottom: 10,
                          right: 10,
                          child: GestureDetector(
                            onTap: _recenterMap,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: _card,
                                shape: BoxShape.circle,
                                border: Border.all(color: _stroke),
                              ),
                              child: const Icon(
                                Icons.my_location_rounded,
                                color: _red,
                                size: 18,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
    );
  }

  Widget _sectionHeader(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(
      title,
      style: GoogleFonts.poppins(
        color: Colors.grey,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.8,
      ),
    ),
  );

  Widget _toggleTile(String label, bool value, ValueChanged<bool> onChanged) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _stroke),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(label, style: const TextStyle(color: Colors.white)),
            ),
            Switch(
              value: value,
              onChanged: onChanged,
              activeThumbColor: _red,
              activeTrackColor: _red.withValues(alpha: 0.3),
            ),
          ],
        ),
      );

  Widget _timeTile(String label, TimeOfDay time, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _stroke),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(label, style: const TextStyle(color: Colors.white)),
              ),
              Text(
                time.format(context),
                style: const TextStyle(
                  color: _red,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.access_time, color: Colors.grey, size: 18),
            ],
          ),
        ),
      );

  Widget _inputField(
    String label,
    TextEditingController ctrl, {
    String hint = '',
    int maxLines = 2,
    TextInputType? keyboardType,
    ValueChanged<String>? onChanged,
  }) => TextFormField(
    controller: ctrl,
    maxLines: maxLines,
    keyboardType: keyboardType,
    onChanged: onChanged,
    style: const TextStyle(color: Colors.white),
    decoration: InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: const TextStyle(color: Colors.grey),
      hintStyle: const TextStyle(color: Colors.grey, fontSize: 12),
      filled: true,
      fillColor: _card,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _stroke),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _stroke),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _red),
      ),
    ),
  );

  Widget _dateTimeTile(
    String label,
    DateTime? value,
    VoidCallback onTap, {
    VoidCallback? onClear,
  }) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: _card,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: _stroke),
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(color: Colors.grey, fontSize: 11),
              ),
              const SizedBox(height: 4),
              Text(
                value != null
                    ? DateFormat('MMM d, yyyy - h:mm a').format(value)
                    : 'Not Scheduled',
                style: TextStyle(
                  color: value != null ? _red : Colors.grey[600],
                  fontWeight: value != null
                      ? FontWeight.bold
                      : FontWeight.normal,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        if (onClear != null)
          IconButton(
            icon: const Icon(Icons.clear, color: Colors.grey, size: 18),
            onPressed: onClear,
          ),
        IconButton(
          icon: const Icon(Icons.calendar_month, color: _red, size: 20),
          onPressed: onTap,
        ),
      ],
    ),
  );
}
