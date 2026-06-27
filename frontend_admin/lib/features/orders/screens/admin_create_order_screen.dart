import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../products/models/product.dart';
import '../../products/services/product_service.dart';
import '../services/order_service.dart';

const _red = Color(0xFFFF1E1E);
const _surface = Color(0xFF050505);
const _card = Color(0xFF111111);
const _panel = Color(0xFF1C1C1C);
const _stroke = Color(0xFF2A2A2A);

class AdminCreateOrderScreen extends StatefulWidget {
  const AdminCreateOrderScreen({super.key});

  @override
  State<AdminCreateOrderScreen> createState() => _AdminCreateOrderScreenState();
}

class _AdminCreateOrderScreenState extends State<AdminCreateOrderScreen> {
  final _formKey = GlobalKey<FormState>();
  final _svc = OrderService();

  // Form Fields
  final _phoneCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _couponCtrl = TextEditingController();
  String _deliveryType = 'delivery'; // 'delivery' or 'pickup'
  String _paymentMethod = 'cod'; // 'cod' or 'prepaid'
  bool _saving = false;

  // Selected items: productId -> {quantity, product, selections: [{groupName, optionName, price}]}
  Map<int, Map<String, dynamic>> _selectedItems = {};

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    _notesCtrl.dispose();
    _couponCtrl.dispose();
    super.dispose();
  }

  double get _subtotal {
    double total = 0.0;
    _selectedItems.forEach((productId, itemData) {
      final double basePrice = (itemData['product'] as Product).price;
      double extra = 0.0;
      final selections = itemData['selections'] as List<Map<String, dynamic>>;
      for (final sel in selections) {
        extra += sel['price'] as double;
      }
      final int qty = itemData['quantity'] as int;
      total += (basePrice + extra) * qty;
    });
    return total;
  }

  Future<void> _pickItems() async {
    final result = await Navigator.push<Map<int, Map<String, dynamic>>>(
      context,
      MaterialPageRoute(
        builder: (_) => ProductPickerScreen(initialSelections: _selectedItems),
      ),
    );
    if (result != null) {
      setState(() {
        _selectedItems = result;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one item to the order.')),
      );
      return;
    }

    setState(() => _saving = true);

    // Format selected items for API payload
    final itemsPayload = <Map<String, dynamic>>[];
    final List<String> customDetails = [];

    _selectedItems.forEach((productId, itemData) {
      final product = itemData['product'] as Product;
      final int qty = itemData['quantity'] as int;
      final selections = itemData['selections'] as List<Map<String, dynamic>>;

      itemsPayload.add({
        'product_id': productId,
        'quantity': qty,
        'selections': selections,
      });

      // Build text representations for notes
      final List<String> specs = [];
      for (final sel in selections) {
        final grp = sel['group'] as String;
        final opt = sel['option'] as String;
        specs.add('$grp: $opt');
      }
      if (specs.isNotEmpty) {
        customDetails.add('${product.name} (${qty}x) -> ${specs.join(', ')}');
      }
    });

    final noteText = _notesCtrl.text.trim();
    final List<String> noteParts = [];
    if (noteText.isNotEmpty) noteParts.add(noteText);
    if (customDetails.isNotEmpty) noteParts.add(customDetails.join(' | '));

    final payload = {
      'phone_number': _phoneCtrl.text.trim(),
      'customer_name': _nameCtrl.text.trim(),
      'delivery_type': _deliveryType,
      'address_text': _deliveryType == 'delivery' ? _addressCtrl.text.trim() : 'Store Pickup',
      'items': itemsPayload,
      'payment_method': _paymentMethod,
      'delivery_notes': noteParts.join(' | '),
      'coupon_code': _couponCtrl.text.trim(),
    };

    try {
      await _svc.adminCreateOrder(payload);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Order created successfully! 🎉')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create order: $e')),
        );
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
        title: Text('Create Order',
            style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // 1. Customer Card
                  _cardContainer(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sectionHeader('Customer Information'),
                        TextFormField(
                          controller: _phoneCtrl,
                          keyboardType: TextInputType.phone,
                          style: const TextStyle(color: Colors.white),
                          validator: (v) => v == null || v.isEmpty ? 'Phone number is required' : null,
                          decoration: _inputDec('Phone Number *', 'e.g. 9876543210'),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _nameCtrl,
                          style: const TextStyle(color: Colors.white),
                          decoration: _inputDec('Customer Name (Optional)', 'e.g. Rahul Sharma'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 2. Order Settings Card
                  _cardContainer(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sectionHeader('Delivery & Payment Details'),
                        DropdownButtonFormField<String>(
                          value: _deliveryType,
                          dropdownColor: _card,
                          style: const TextStyle(color: Colors.white),
                          decoration: _inputDec('Delivery Type'),
                          items: const [
                            DropdownMenuItem(value: 'delivery', child: Text('Home Delivery')),
                            DropdownMenuItem(value: 'pickup', child: Text('Store Pickup')),
                          ],
                          onChanged: (v) => setState(() {
                            if (v != null) _deliveryType = v;
                          }),
                        ),
                        if (_deliveryType == 'delivery') ...[
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _addressCtrl,
                            maxLines: 2,
                            style: const TextStyle(color: Colors.white),
                            validator: (v) => _deliveryType == 'delivery' && (v == null || v.isEmpty)
                                ? 'Delivery address is required'
                                : null,
                            decoration: _inputDec('Delivery Address *', 'e.g. H.No 12, Sector 15, Chandigarh'),
                          ),
                        ],
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: _paymentMethod,
                          dropdownColor: _card,
                          style: const TextStyle(color: Colors.white),
                          decoration: _inputDec('Payment Method'),
                          items: const [
                            DropdownMenuItem(value: 'cod', child: Text('Cash on Delivery (COD)')),
                            DropdownMenuItem(value: 'prepaid', child: Text('Prepaid / Paid Online')),
                          ],
                          onChanged: (v) => setState(() {
                            if (v != null) _paymentMethod = v;
                          }),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _couponCtrl,
                          style: const TextStyle(color: Colors.white),
                          decoration: _inputDec('Coupon Code (Optional)', 'e.g. FREE50'),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _notesCtrl,
                          maxLines: 2,
                          style: const TextStyle(color: Colors.white),
                          decoration: _inputDec('Special Delivery Notes (Optional)', 'e.g. Leave at door'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 3. Cart Items Card
                  _cardContainer(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _sectionHeader('Order Items'),
                            TextButton.icon(
                              onPressed: _pickItems,
                              icon: const Icon(Icons.add, color: _red, size: 18),
                              label: Text(
                                _selectedItems.isEmpty ? 'Add Items' : 'Edit Items',
                                style: const TextStyle(color: _red, fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                        if (_selectedItems.isEmpty)
                          GestureDetector(
                            onTap: _pickItems,
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 36),
                              decoration: BoxDecoration(
                                color: _panel,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: _stroke, style: BorderStyle.solid),
                              ),
                              child: Column(
                                children: [
                                  Icon(Icons.shopping_bag_outlined, color: Colors.grey[600], size: 36),
                                  const SizedBox(height: 8),
                                  Text(
                                    'No items added. Tap here to add.',
                                    style: TextStyle(color: Colors.grey[500], fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          ..._selectedItems.entries.map((entry) {
                            final p = entry.value['product'] as Product;
                            final qty = entry.value['quantity'] as int;
                            final selections = entry.value['selections'] as List<Map<String, dynamic>>;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: _panel,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: _stroke),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(p.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                        const SizedBox(height: 2),
                                        Text('₹${p.price.toStringAsFixed(0)} each', style: const TextStyle(color: Colors.grey, fontSize: 11)),
                                        if (selections.isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Wrap(
                                            spacing: 6,
                                            children: selections.map((s) {
                                              return Chip(
                                                label: Text('${s['group']}: ${s['option']}', style: const TextStyle(fontSize: 10, color: Colors.white)),
                                                backgroundColor: _card,
                                                padding: EdgeInsets.zero,
                                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                side: const BorderSide(color: _stroke),
                                              );
                                            }).toList(),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  Text('${qty}x', style: const TextStyle(color: _red, fontWeight: FontWeight.bold, fontSize: 14)),
                                ],
                              ),
                            );
                          }),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Checkout Bottom Bar
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: _card,
                border: Border(top: BorderSide(color: _stroke)),
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Total Price:', style: TextStyle(color: Colors.grey, fontSize: 12)),
                          const SizedBox(height: 2),
                          Text(
                            '₹${_subtotal.toStringAsFixed(2)}',
                            style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: _saving
                          ? const Center(child: CircularProgressIndicator(color: _red))
                          : ElevatedButton(
                              onPressed: _submit,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _red,
                                minimumSize: const Size(double.infinity, 48),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              child: const Text('Place Order',
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cardContainer({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _stroke),
      ),
      child: child,
    );
  }

  Widget _sectionHeader(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(title,
            style: GoogleFonts.poppins(
                color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.8)),
      );

  InputDecoration _inputDec(String label, [String hint = '']) => InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(color: Colors.grey, fontSize: 12),
        hintStyle: const TextStyle(color: Colors.grey, fontSize: 11),
        filled: true,
        fillColor: _panel,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _stroke)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _stroke)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _red)),
      );
}

// ── PRODUCT PICKER SCREEN ───────────────────────────────────────────────────
class ProductPickerScreen extends StatefulWidget {
  final Map<int, Map<String, dynamic>> initialSelections;
  const ProductPickerScreen({super.key, required this.initialSelections});

  @override
  State<ProductPickerScreen> createState() => _ProductPickerScreenState();
}

class _ProductPickerScreenState extends State<ProductPickerScreen> {
  final _productSvc = ProductService();
  final _searchCtrl = TextEditingController();

  bool _loading = true;
  List<Product> _products = [];
  List<Product> _filteredProducts = [];

  // Temporary selections: productId -> {quantity, product, selections: []}
  Map<int, Map<String, dynamic>> _tempSelections = {};

  @override
  void initState() {
    super.initState();
    // Clone initial selections
    _tempSelections = Map<int, Map<String, dynamic>>.from(
      widget.initialSelections.map((key, val) => MapEntry(key, Map<String, dynamic>.from(val))),
    );
    _loadProducts();
    _searchCtrl.addListener(_filterProducts);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    try {
      final list = await _productSvc.getProducts();
      if (mounted) {
        setState(() {
          _products = list.where((p) => p.isAvailable).toList();
          _filteredProducts = _products;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load products: $e')),
        );
      }
    }
  }

  void _filterProducts() {
    final query = _searchCtrl.text.toLowerCase();
    setState(() {
      _filteredProducts = _products
          .where((p) => p.name.toLowerCase().contains(query))
          .toList();
    });
  }

  double get _subtotal {
    double total = 0.0;
    _tempSelections.forEach((productId, itemData) {
      final double basePrice = (itemData['product'] as Product).price;
      double extra = 0.0;
      final selections = itemData['selections'] as List<Map<String, dynamic>>;
      for (final sel in selections) {
        extra += sel['price'] as double;
      }
      final int qty = itemData['quantity'] as int;
      total += (basePrice + extra) * qty;
    });
    return total;
  }

  Future<void> _customizeItem(Product product) async {
    if (product.modifierGroups.isEmpty) return;

    final Map<int, List<ModifierOption>> tempSelections = {};
    
    if (_tempSelections.containsKey(product.id)) {
      final currentSels = _tempSelections[product.id]!['selections'] as List<Map<String, dynamic>>;
      for (final group in product.modifierGroups) {
        final groupSels = currentSels.where((s) => s['group'] == group.name).toList();
        final selectedOpts = <ModifierOption>[];
        for (final gs in groupSels) {
          final matchOpt = group.options.firstWhere(
            (o) => o.name == gs['option'],
            orElse: () => group.options.first,
          );
          selectedOpts.add(matchOpt);
        }
        tempSelections[group.id] = selectedOpts;
      }
    } else {
      for (final group in product.modifierGroups) {
        if (group.required && group.options.isNotEmpty) {
          tempSelections[group.id] = [group.options.first];
        }
      }
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              backgroundColor: _panel,
              title: Text('Customize ${product.name}',
                  style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: product.modifierGroups.length,
                  itemBuilder: (context, index) {
                    final group = product.modifierGroups[index];
                    final selectedList = tempSelections[group.id] ?? [];

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Row(
                            children: [
                              Text(group.name,
                                  style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                              if (group.required)
                                const Text(' *', style: TextStyle(color: _red, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                        if (group.description.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6.0),
                            child: Text(group.description,
                                style: const TextStyle(color: Colors.grey, fontSize: 11)),
                          ),
                        ...group.options.map((opt) {
                          final isSelected = selectedList.contains(opt);
                          if (group.isSingleSelect) {
                            return RadioListTile<ModifierOption>(
                              value: opt,
                              groupValue: selectedList.isNotEmpty ? selectedList.first : null,
                              title: Text(opt.name, style: const TextStyle(color: Colors.white, fontSize: 13)),
                              subtitle: opt.extraPrice > 0 ? Text('+₹${opt.extraPrice.toStringAsFixed(0)}', style: const TextStyle(color: _red, fontSize: 11)) : null,
                              activeColor: _red,
                              contentPadding: EdgeInsets.zero,
                              onChanged: (val) {
                                if (val != null) {
                                  setDialogState(() {
                                    tempSelections[group.id] = [val];
                                  });
                                }
                              },
                            );
                          } else {
                            return CheckboxListTile(
                              value: isSelected,
                              title: Text(opt.name, style: const TextStyle(color: Colors.white, fontSize: 13)),
                              subtitle: opt.extraPrice > 0 ? Text('+₹${opt.extraPrice.toStringAsFixed(0)}', style: const TextStyle(color: _red, fontSize: 11)) : null,
                              activeColor: _red,
                              contentPadding: EdgeInsets.zero,
                              onChanged: (val) {
                                setDialogState(() {
                                  final currentList = List<ModifierOption>.from(tempSelections[group.id] ?? []);
                                  if (val == true) {
                                    if (group.maxSelection > 0 && currentList.length >= group.maxSelection) {
                                      currentList.removeAt(0);
                                    }
                                    currentList.add(opt);
                                  } else {
                                    currentList.remove(opt);
                                  }
                                  tempSelections[group.id] = currentList;
                                });
                              },
                            );
                          }
                        }),
                        const Divider(color: _stroke),
                      ],
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: () {
                    for (final group in product.modifierGroups) {
                      if (group.required && (tempSelections[group.id] ?? []).isEmpty) {
                        ScaffoldMessenger.of(dialogCtx).showSnackBar(
                          SnackBar(content: Text('Please select an option for ${group.name}')),
                        );
                        return;
                      }
                    }
                    Navigator.pop(ctx, true);
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: _red, minimumSize: const Size(0, 36)),
                  child: const Text('Done', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed == true) {
      final flattenedSelections = <Map<String, dynamic>>[];
      tempSelections.forEach((groupId, list) {
        final group = product.modifierGroups.firstWhere((g) => g.id == groupId);
        for (final opt in list) {
          flattenedSelections.add({
            'group': group.name,
            'option': opt.name,
            'price': opt.extraPrice,
          });
        }
      });

      setState(() {
        if (!_tempSelections.containsKey(product.id)) {
          _tempSelections[product.id] = {
            'product': product,
            'quantity': 1,
            'selections': flattenedSelections,
          };
        } else {
          _tempSelections[product.id]!['selections'] = flattenedSelections;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        backgroundColor: _surface,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text('Select Products',
            style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _red))
          : Column(
              children: [
                // Search Bar
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: TextFormField(
                    controller: _searchCtrl,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Search products by name...',
                      prefixIcon: const Icon(Icons.search, color: Colors.grey, size: 18),
                      filled: true,
                      fillColor: _card,
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _stroke)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _stroke)),
                    ),
                  ),
                ),

                // Products List
                Expanded(
                  child: ListView.builder(
                    itemCount: _filteredProducts.length,
                    itemBuilder: (context, index) {
                      final p = _filteredProducts[index];
                      final selected = _tempSelections[p.id];
                      final qty = selected != null ? selected['quantity'] as int : 0;

                      return Card(
                        color: _card,
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: qty > 0 ? _red.withValues(alpha: 0.5) : _stroke),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(p.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                                    const SizedBox(height: 2),
                                    Text('₹${p.price.toStringAsFixed(0)}', style: const TextStyle(color: _red, fontWeight: FontWeight.w600, fontSize: 12)),
                                    if (p.modifierGroups.isNotEmpty) ...[
                                      const SizedBox(height: 6),
                                      GestureDetector(
                                        onTap: () => _customizeItem(p),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.tune, color: _red, size: 14),
                                            const SizedBox(width: 4),
                                            Text(
                                              qty > 0 && selected?['selections']?.isNotEmpty == true ? 'Edit Customizations' : 'Customize options',
                                              style: const TextStyle(color: _red, fontSize: 12, fontWeight: FontWeight.w600),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (qty > 0) ...[
                                    IconButton(
                                      icon: const Icon(Icons.remove_circle_outline, color: Colors.grey, size: 24),
                                      onPressed: () {
                                        setState(() {
                                          if (qty == 1) {
                                            _tempSelections.remove(p.id);
                                          } else {
                                            _tempSelections[p.id]!['quantity'] = qty - 1;
                                          }
                                        });
                                      },
                                    ),
                                    Text('$qty', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                                  ],
                                  IconButton(
                                    icon: const Icon(Icons.add_circle, color: _red, size: 24),
                                    onPressed: () {
                                      setState(() {
                                        if (selected == null) {
                                          _tempSelections[p.id] = {
                                            'product': p,
                                            'quantity': 1,
                                            'selections': <Map<String, dynamic>>[],
                                          };
                                          if (p.modifierGroups.isNotEmpty) {
                                            _customizeItem(p);
                                          }
                                        } else {
                                          _tempSelections[p.id]!['quantity'] = qty + 1;
                                        }
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // Basket Status Bar
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: _card,
                    border: Border(top: BorderSide(color: _stroke)),
                  ),
                  child: SafeArea(
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${_tempSelections.length} products selected', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                              const SizedBox(height: 2),
                              Text('₹${_subtotal.toStringAsFixed(2)}',
                                  style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17)),
                            ],
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context, _tempSelections);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _red,
                            minimumSize: const Size(120, 44),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Text('Add to Basket',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
