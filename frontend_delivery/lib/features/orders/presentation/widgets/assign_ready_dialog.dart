import 'package:flutter/material.dart';
import '../../../delivery_staff/data/models/delivery_staff.dart';

const _red = Color(0xFFFF1E1E);
const _panel = Color(0xFF111111);

class ReadyResult {
  final int? deliveryUserId;
  ReadyResult({this.deliveryUserId});
}

class AssignAndReadyDialog extends StatefulWidget {
  final List<DeliveryStaff> staff;
  final DeliveryStaff? initial;
  const AssignAndReadyDialog({super.key, required this.staff, this.initial});

  @override
  State<AssignAndReadyDialog> createState() => _AssignAndReadyDialogState();
}

class _AssignAndReadyDialogState extends State<AssignAndReadyDialog> {
  DeliveryStaff? _selected;

  @override
  void initState() {
    super.initState();
    _selected =
        widget.initial ?? (widget.staff.isNotEmpty ? widget.staff.first : null);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: _panel,
      title: const Text(
        'Assign Delivery Person',
        style: TextStyle(color: Colors.white),
      ),
      content: RadioGroup<int>(
        groupValue: _selected?.id,
        onChanged: (value) {
          if (value == null) return;
          final selected = widget.staff.firstWhere((s) => s.id == value);
          setState(() => _selected = selected);
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: widget.staff.map((s) {
            final sel = _selected?.id == s.id;
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Radio<int>(value: s.id, activeColor: _red),
              title: Text(
                s.displayName,
                style: const TextStyle(color: Colors.white),
              ),
              subtitle: s.isDefaultDelivery
                  ? const Text(
                      'Default',
                      style: TextStyle(color: _red, fontSize: 11),
                    )
                  : null,
              tileColor: sel ? _red.withValues(alpha: 0.08) : null,
              onTap: () => setState(() => _selected = s),
            );
          }).toList(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () =>
              Navigator.pop(context, ReadyResult(deliveryUserId: null)),
          child: const Text('Skip', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: _red),
          onPressed: () => Navigator.pop(
            context,
            ReadyResult(deliveryUserId: _selected?.id),
          ),
          child: const Text('Confirm'),
        ),
      ],
    );
  }
}
