import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../data/models/customer_address.dart';
import '../../data/repositories/address_service.dart';
import 'location_picker_screen.dart';
import '../../../../core/navigation/app_routes.dart';
import 'package:shimmer/shimmer.dart';

const _brandOrange = Color(0xFFFF1E1E);
const _deepText = Colors.white;
const _mutedText = Color(0xFFB8B8B8);
const _surface = Color(0xFF050505);
const _panel = Color(0xFF111111);
const _panelAlt = Color(0xFF1E1E1E);
const _stroke = Color(0xFF2A2A2A);

class AddressScreen extends StatefulWidget {
  /// When true the screen works as a picker: tapping an address card pops
  /// with the selected [CustomerAddress] instead of managing addresses.
  final bool selectionMode;

  const AddressScreen({super.key, this.selectionMode = false});

  @override
  State<AddressScreen> createState() => _AddressScreenState();
}

class _AddressScreenState extends State<AddressScreen> {
  final AddressService _addressService = AddressService();
  late Future<List<CustomerAddress>> _addressesFuture;

  @override
  void initState() {
    super.initState();
    _addressesFuture = _addressService.getAddresses();
  }

  void _reload() {
    setState(() {
      _addressesFuture = _addressService.getAddresses();
    });
  }

  Future<void> _openAddressForm([CustomerAddress? address]) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _AddressFormSheet(
          address: address,
          onSave: (newAddress) async {
            if (newAddress.id == null) {
              await _addressService.createAddress(newAddress);
            } else {
              await _addressService.updateAddress(newAddress);
            }
          },
        );
      },
    );

    if (saved == true) {
      _reload();
    }
  }

  Future<void> _makeDefault(CustomerAddress address) async {
    try {
      await _addressService.updateAddress(address.copyWith(isDefault: true));
      _reload();
      _showMessage('Default address updated');
    } catch (error) {
      _showMessage(error.toString());
    }
  }

  Future<void> _deleteAddress(CustomerAddress address) async {
    try {
      await _addressService.deleteAddress(address);
      _reload();
      _showMessage('Address removed');
    } catch (error) {
      _showMessage(error.toString());
    }
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        title: const Text(
          'Delivery addresses',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded, color: _brandOrange),
            onPressed: () => _openAddressForm(),
            tooltip: 'Add Address',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddressForm(),
        backgroundColor: _brandOrange,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_location_alt_rounded),
        label: const Text('Add Address'),
      ),
      body: FutureBuilder<List<CustomerAddress>>(
        future: _addressesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const _AddressScreenSkeleton();
          }

          if (snapshot.hasError) {
            return _AddressEmptyState(
              icon: Icons.wifi_off_rounded,
              title: 'Could not load addresses',
              subtitle: snapshot.error.toString(),
              actionLabel: 'Try again',
              onAction: _reload,
            );
          }

          final addresses = snapshot.data ?? [];

          if (addresses.isEmpty) {
            return _AddressEmptyState(
              icon: Icons.add_home_work_rounded,
              title: 'Save your first address',
              subtitle: 'Add Home, Work, or Other before checkout.',
              actionLabel: 'Add Address',
              onAction: () => _openAddressForm(),
            );
          }

          return RefreshIndicator(
            color: _brandOrange,
            onRefresh: () async => _reload(),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
              itemCount: addresses.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final address = addresses[index];
                return _AddressCard(
                  address: address,
                  selectionMode: widget.selectionMode,
                  onTap: widget.selectionMode
                      ? () => Navigator.pop(context, address)
                      : null,
                  onEdit: () => _openAddressForm(address),
                  onDelete: () => _deleteAddress(address),
                  onMakeDefault: address.isDefault
                      ? null
                      : () => _makeDefault(address),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _AddressCard extends StatelessWidget {
  final CustomerAddress address;
  final bool selectionMode;
  final VoidCallback? onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onMakeDefault;

  const _AddressCard({
    required this.address,
    required this.selectionMode,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    required this.onMakeDefault,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _panel,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: selectionMode
                  ? (address.isDefault ? _brandOrange : _stroke)
                  : (address.isDefault ? _brandOrange : _stroke),
              width: selectionMode ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.36),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: _panelAlt,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Icon(
                      _iconForLabel(address.label),
                      color: _brandOrange,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              address.label,
                              style: const TextStyle(
                                color: _deepText,
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            if (address.isDefault) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: _brandOrange,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: const Text(
                                  'Default',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          address.lineOne,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _mutedText,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'edit') {
                        onEdit();
                      } else if (value == 'default') {
                        onMakeDefault?.call();
                      } else if (value == 'delete') {
                        onDelete();
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'edit', child: Text('Edit')),
                      if (onMakeDefault != null)
                        const PopupMenuItem(
                          value: 'default',
                          child: Text('Make default'),
                        ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('Delete'),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                address.lineTwo,
                style: const TextStyle(
                  color: _deepText,
                  fontSize: 14,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(
                    Icons.my_location_rounded,
                    size: 15,
                    color: _mutedText,
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      '${address.latitude.toStringAsFixed(5)}, '
                      '${address.longitude.toStringAsFixed(5)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _mutedText,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static IconData _iconForLabel(String label) {
    switch (label) {
      case 'Work':
        return Icons.work_rounded;
      case 'Other':
        return Icons.location_on_rounded;
      case 'Home':
      default:
        return Icons.home_rounded;
    }
  }
}

class _AddressFormSheet extends StatefulWidget {
  final CustomerAddress? address;
  final Future<void> Function(CustomerAddress address) onSave;

  const _AddressFormSheet({required this.address, required this.onSave});

  @override
  State<_AddressFormSheet> createState() => _AddressFormSheetState();
}

class _AddressFormSheetState extends State<_AddressFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _houseController = TextEditingController();
  final _streetController = TextEditingController();
  final _landmarkController = TextEditingController();
  final _cityController = TextEditingController();
  final _pincodeController = TextEditingController();
  final _latitudeController = TextEditingController(text: '0.000000');
  final _longitudeController = TextEditingController(text: '0.000000');

  String _label = 'Home';
  bool _isDefault = false;
  bool _isSaving = false;
  bool _isPickingLocation = false;

  @override
  void initState() {
    super.initState();

    final address = widget.address;
    if (address != null) {
      _label = address.label;
      _houseController.text = address.house;
      _streetController.text = address.street;
      _landmarkController.text = address.landmark;
      _cityController.text = address.city;
      _pincodeController.text = address.pincode;
      _latitudeController.text = address.latitude.toStringAsFixed(6);
      _longitudeController.text = address.longitude.toStringAsFixed(6);
      _isDefault = address.isDefault;
    }
  }

  @override
  void dispose() {
    _houseController.dispose();
    _streetController.dispose();
    _landmarkController.dispose();
    _cityController.dispose();
    _pincodeController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    super.dispose();
  }

  Future<void> _openLocationPicker() async {
    setState(() {
      _isPickingLocation = true;
    });

    try {
      final result = await AppRoutes.pushLocationPicker<LocationPickerResult>(
        context,
        initialLocation: LatLng(
          double.tryParse(_latitudeController.text.trim()) ?? 0,
          double.tryParse(_longitudeController.text.trim()) ?? 0,
        ),
        initialAddress: _streetController.text.trim(),
      );

      if (result == null) {
        return;
      }

      final place = result.place;
      _latitudeController.text = place.location.latitude.toStringAsFixed(6);
      _longitudeController.text = place.location.longitude.toStringAsFixed(6);

      if (place.street.trim().isNotEmpty) {
        _streetController.text = place.street;
      }

      if (place.city.trim().isNotEmpty) {
        _cityController.text = place.city;
      }

      if (place.pincode.trim().isNotEmpty) {
        _pincodeController.text = place.pincode;
      }

      if (_landmarkController.text.trim().isEmpty &&
          place.landmark.trim().isNotEmpty) {
        _landmarkController.text = place.landmark;
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPickingLocation = false;
        });
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final address = CustomerAddress(
      id: widget.address?.id,
      label: _label,
      house: _houseController.text.trim(),
      street: _streetController.text.trim(),
      landmark: _landmarkController.text.trim(),
      city: _cityController.text.trim(),
      pincode: _pincodeController.text.trim(),
      latitude: double.parse(_latitudeController.text.trim()),
      longitude: double.parse(_longitudeController.text.trim()),
      isDefault: _isDefault,
    );

    try {
      await widget.onSave(address);

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.90,
      minChildSize: 0.60,
      maxChildSize: 0.96,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Form(
            key: _formKey,
            child: ListView(
              controller: scrollController,
              padding: EdgeInsets.fromLTRB(
                20,
                14,
                20,
                MediaQuery.viewInsetsOf(context).bottom + 24,
              ),
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 5,
                    decoration: BoxDecoration(
                      color: _stroke,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  widget.address == null ? 'Add address' : 'Edit address',
                  style: const TextStyle(
                    color: _deepText,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 16),
                _LabelSelector(
                  selected: _label,
                  onChanged: (label) {
                    setState(() {
                      _label = label;
                    });
                  },
                ),
                const SizedBox(height: 18),
                _AddressField(
                  controller: _houseController,
                  label: 'House number / Flat (Optional)',
                  icon: Icons.home_rounded,
                ),
                _AddressField(
                  controller: _streetController,
                  label: 'Street / Area',
                  icon: Icons.signpost_rounded,
                  validator: _required,
                ),
                _AddressField(
                  controller: _landmarkController,
                  label: 'Landmark',
                  icon: Icons.place_rounded,
                ),
                Row(
                  children: [
                    Expanded(
                      child: _AddressField(
                        controller: _cityController,
                        label: 'City',
                        icon: Icons.location_city_rounded,
                        validator: _required,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _AddressField(
                        controller: _pincodeController,
                        label: 'Pincode',
                        icon: Icons.pin_rounded,
                        keyboardType: TextInputType.number,
                        validator: _required,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      child: _AddressField(
                        controller: _latitudeController,
                        label: 'Latitude',
                        icon: Icons.my_location_rounded,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                          signed: true,
                        ),
                        readOnly: true,
                        validator: _coordinate,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _AddressField(
                        controller: _longitudeController,
                        label: 'Longitude',
                        icon: Icons.explore_rounded,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                          signed: true,
                        ),
                        readOnly: true,
                        validator: _coordinate,
                      ),
                    ),
                  ],
                ),
                OutlinedButton.icon(
                  onPressed: _isPickingLocation ? null : _openLocationPicker,
                  icon: _isPickingLocation
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.map_rounded),
                  label: const Text('Pick on Google Map'),
                ),
                SwitchListTile(
                  value: _isDefault,
                  onChanged: (value) {
                    setState(() {
                      _isDefault = value;
                    });
                  },
                  contentPadding: EdgeInsets.zero,
                  activeThumbColor: _brandOrange,
                  title: const Text(
                    'Set as default address',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          widget.address == null
                              ? 'Save Address'
                              : 'Update Address',
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String? _required(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Required';
    }

    return null;
  }

  String? _coordinate(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Required';
    }

    if (double.tryParse(value.trim()) == null) {
      return 'Invalid';
    }

    return null;
  }
}

class _LabelSelector extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;

  const _LabelSelector({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<String>(
      segments: const [
        ButtonSegment(
          value: 'Home',
          label: Text('Home'),
          icon: Icon(Icons.home_rounded),
        ),
        ButtonSegment(
          value: 'Work',
          label: Text('Work'),
          icon: Icon(Icons.work_rounded),
        ),
        ButtonSegment(
          value: 'Other',
          label: Text('Other'),
          icon: Icon(Icons.location_on_rounded),
        ),
      ],
      selected: {selected},
      onSelectionChanged: (value) => onChanged(value.first),
      style: SegmentedButton.styleFrom(
        selectedBackgroundColor: _panelAlt,
        selectedForegroundColor: Colors.white,
      ),
    );
  }
}

class _AddressField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final bool readOnly;

  const _AddressField({
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType,
    this.validator,
    this.readOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        validator: validator,
        readOnly: readOnly,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: _brandOrange),
          filled: true,
          fillColor: _panel,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: _brandOrange),
          ),
        ),
      ),
    );
  }
}

class _AddressEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onAction;

  const _AddressEmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 82,
              height: 82,
              decoration: BoxDecoration(
                color: _panelAlt,
                borderRadius: BorderRadius.circular(26),
              ),
              child: Icon(icon, color: _brandOrange, size: 40),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _deepText,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _mutedText,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 18),
            ElevatedButton(onPressed: onAction, child: Text(actionLabel)),
          ],
        ),
      ),
    );
  }
}

class _AddressScreenSkeleton extends StatelessWidget {
  const _AddressScreenSkeleton();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: const Color(0xFF111111),
      highlightColor: const Color(0xFF2A2A2A),
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 3,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          return Container(
            height: 110,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
          );
        },
      ),
    );
  }
}
