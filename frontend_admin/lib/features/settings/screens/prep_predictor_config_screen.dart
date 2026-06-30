import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/config_service.dart';
import '../../../core/widgets/hdk_preloader.dart';

const _red = Color(0xFFFF1E1E);
const _surface = Color(0xFF050505);
const _card = Color(0xFF111111);
const _stroke = Color(0xFF2A2A2A);

class PrepPredictorConfigScreen extends StatefulWidget {
  const PrepPredictorConfigScreen({super.key});

  @override
  State<PrepPredictorConfigScreen> createState() => _PrepPredictorConfigScreenState();
}

class _PrepPredictorConfigScreenState extends State<PrepPredictorConfigScreen> {
  final AdminConfigService _svc = AdminConfigService();
  bool _loading = true;
  bool _saving = false;
  String? _error;

  final _queueMultiplier = TextEditingController();
  final _rushHourBonus = TextEditingController();
  final _overrideBoost = TextEditingController();
  final _peakStartTime = TextEditingController();
  final _peakEndTime = TextEditingController();
  final _peakWeekdays = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _queueMultiplier.dispose();
    _rushHourBonus.dispose();
    _overrideBoost.dispose();
    _peakStartTime.dispose();
    _peakEndTime.dispose();
    _peakWeekdays.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _svc.getPrepConfig();
      if (mounted) {
        setState(() {
          _queueMultiplier.text = (data['queue_multiplier'] ?? 2.0).toString();
          _rushHourBonus.text = (data['rush_hour_bonus'] ?? 5).toString();
          _overrideBoost.text = (data['override_boost'] ?? 0).toString();
          _peakStartTime.text = data['peak_start_time'] ?? '18:00:00';
          _peakEndTime.text = data['peak_end_time'] ?? '22:00:00';
          _peakWeekdays.text = data['peak_weekdays'] ?? '4,5,6';
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
    final double? qMult = double.tryParse(_queueMultiplier.text.trim());
    final int? rBonus = int.tryParse(_rushHourBonus.text.trim());
    final int? oBoost = int.tryParse(_overrideBoost.text.trim());

    if (qMult == null || rBonus == null || oBoost == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter valid numeric values for multiplier, bonus, and boost.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await _svc.updatePrepConfig({
        'queue_multiplier': qMult,
        'rush_hour_bonus': rBonus,
        'override_boost': oBoost,
        'peak_start_time': _peakStartTime.text.trim(),
        'peak_end_time': _peakEndTime.text.trim(),
        'peak_weekdays': _peakWeekdays.text.trim(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Smart Prep Configuration saved ✅')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        backgroundColor: _surface,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          'Smart Prep Time Predictor',
          style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 18),
        ),
        actions: [
          _saving
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(
                    child: HdkPreloader(width: 20, height: 20),
                  ),
                )
              : TextButton(
                  onPressed: _save,
                  child: const Text('Save', style: TextStyle(color: _red, fontWeight: FontWeight.bold)),
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
                      Text(_error!, style: const TextStyle(color: Colors.grey), textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      TextButton(onPressed: _load, child: const Text('Retry', style: TextStyle(color: _red))),
                    ],
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _red.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, color: _red, size: 24),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Define the predictive algorithm multipliers to dynamically compute preparation times based on kitchen backlog and peak rush hours.',
                              style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    _sectionHeader('Core Modifiers'),
                    _inputField(
                      'Queue Multiplier (Minutes added per active order)',
                      _queueMultiplier,
                      hint: 'e.g. 2.0',
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                    const SizedBox(height: 16),
                    _inputField(
                      'Rush Hour Bonus Minutes',
                      _rushHourBonus,
                      hint: 'e.g. 5',
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 16),
                    _inputField(
                      'Manual Override / Boost Minutes (Add/Subtract globally)',
                      _overrideBoost,
                      hint: 'e.g. 10 or -5',
                      keyboardType: const TextInputType.numberWithOptions(signed: true),
                    ),
                    const SizedBox(height: 24),
                    _sectionHeader('Peak Hours Definition'),
                    Row(
                      children: [
                        Expanded(
                          child: _inputField(
                            'Peak Start Time',
                            _peakStartTime,
                            hint: 'e.g. 18:00:00',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _inputField(
                            'Peak End Time',
                            _peakEndTime,
                            hint: 'e.g. 22:00:00',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _inputField(
                      'Peak Weekdays (0=Monday, 6=Sunday. Comma-separated)',
                      _peakWeekdays,
                      hint: 'e.g. 4,5,6',
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
    );
  }

  Widget _sectionHeader(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
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

  Widget _inputField(
    String label,
    TextEditingController ctrl, {
    String hint = '',
    TextInputType? keyboardType,
  }) =>
      TextFormField(
        controller: ctrl,
        keyboardType: keyboardType,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          labelStyle: const TextStyle(color: Colors.grey, fontSize: 13),
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
}
