import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hdk_core/hdk_core.dart';
import '../../data/repositories/order_repository.dart';
import '../../../products/data/repositories/product_service.dart';

const _red = Color(0xFFFF1E1E);
const _surface = Color(0xFF050505);
const _panel = Color(0xFF111111);
const _stroke = Color(0xFF2A2A2A);

class EditItemsDialog extends StatefulWidget {
  final Order order;
  final OrderRepository service;
  const EditItemsDialog({super.key, required this.order, required this.service});

  @override
  State<EditItemsDialog> createState() => _EditItemsDialogState();
}

class _EditItemsDialogState extends State<EditItemsDialog> {
  late List<Map<String, dynamic>> _items;
  final TextEditingController _discountCtrl = TextEditingController();
  final TextEditingController _reasonCtrl = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _items = widget.order.items
        .map(
          (i) => {
            'product_id': i.productId,
            'quantity': i.quantity,
            'name': i.productName,
            'price': i.price,
          },
        )
        .toList();
    if (widget.order.discountAmount > 0) {
      _discountCtrl.text = widget.order.discountAmount.toStringAsFixed(0);
      _reasonCtrl.text = widget.order.discountReason;
    }
  }

  @override
  void dispose() {
    _discountCtrl.dispose();
    _reasonCtrl.dispose();
    super.dispose();
  }

  double get _subtotal => _items.fold(
    0,
    (sum, i) => sum + (i['price'] as double) * (i['quantity'] as int),
  );

  double get _discount {
    final v = double.tryParse(_discountCtrl.text) ?? 0;
    return v.clamp(0, _subtotal);
  }

  double get _newTotal => (_subtotal - _discount).clamp(0, double.infinity);

  Future<void> _addItem() async {
    final Product? picked = await showModalBottomSheet<Product>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const ProductPickerSheet(),
    );
    if (picked == null) return;
    final existing = _items.indexWhere((i) => i['product_id'] == picked.id);
    if (existing >= 0) {
      setState(() => _items[existing]['quantity']++);
    } else {
      setState(
        () => _items.add({
          'product_id': picked.id,
          'quantity': 1,
          'name': picked.name,
          'price': picked.price,
        }),
      );
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final payload = _items
          .where((i) => (i['quantity'] as int) > 0)
          .map(
            (i) => {'product_id': i['product_id'], 'quantity': i['quantity']},
          )
          .toList();

      if (payload.isEmpty) {
        throw Exception('At least one item is required.');
      }

      Order updated = await widget.service.editItems(widget.order.id, payload);

      final d = _discount;
      if (d > 0) {
        updated = await widget.service.applyDiscount(
          widget.order.id,
          d,
          _reasonCtrl.text.trim(),
        );
      }

      if (mounted) Navigator.pop(context, updated);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: _panel,
      contentPadding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      title: const Text(
        'Edit Order',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Items ─────────────────────────────────────────────────
              const Text(
                'Items',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              ..._items.map((item) {
                final qty = item['quantity'] as int;
                final idx = _items.indexOf(item);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          item['name'] as String,
                          style: TextStyle(
                            color: qty == 0 ? Colors.grey : Colors.white,
                            decoration: qty == 0
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                      ),
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: const Icon(
                          Icons.remove_circle_outline,
                          color: Colors.redAccent,
                          size: 22,
                        ),
                        onPressed: qty > 0
                            ? () => setState(
                                () => _items[idx]['quantity'] = qty - 1,
                              )
                            : null,
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          '$qty',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: const Icon(
                          Icons.add_circle_outline,
                          color: _red,
                          size: 22,
                        ),
                        onPressed: () =>
                            setState(() => _items[idx]['quantity'] = qty + 1),
                      ),
                    ],
                  ),
                );
              }),

              // ── Add item button ────────────────────────────────────────
              TextButton.icon(
                onPressed: _addItem,
                icon: const Icon(Icons.add, color: _red, size: 18),
                label: const Text('Add Item', style: TextStyle(color: _red)),
              ),

              const Divider(color: _stroke, height: 20),

              // ── Discount section ───────────────────────────────────────
              const Text(
                'Discount (optional)',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _discountCtrl,
                      style: const TextStyle(color: Colors.white),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'^\d+\.?\d{0,2}'),
                        ),
                      ],
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        hintText: '₹ Amount',
                        hintStyle: TextStyle(color: Colors.grey),
                        prefixText: '₹ ',
                        prefixStyle: TextStyle(color: Colors.white),
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: _reasonCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: 'Reason (optional)',
                        hintStyle: TextStyle(color: Colors.grey),
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const Divider(color: _stroke, height: 20),

              // ── Live total preview ─────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Subtotal',
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                  Text(
                    '₹${_subtotal.toStringAsFixed(0)}',
                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                ],
              ),
              if (_discount > 0) ...[
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Discount',
                      style: TextStyle(color: Colors.greenAccent, fontSize: 13),
                    ),
                    Text(
                      '-₹${_discount.toStringAsFixed(0)}',
                      style: const TextStyle(
                        color: Colors.greenAccent,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'New Total',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  Text(
                    '₹${_newTotal.toStringAsFixed(0)}',
                    style: const TextStyle(
                      color: _red,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: _red),
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}

class ProductPickerSheet extends StatefulWidget {
  const ProductPickerSheet({super.key});

  @override
  State<ProductPickerSheet> createState() => _ProductPickerSheetState();
}

class _ProductPickerSheetState extends State<ProductPickerSheet> {
  final ProductService _svc = ProductService();
  final TextEditingController _search = TextEditingController();
  List<Product> _all = [];
  List<Product> _filtered = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final list = await _svc.getProducts();
      setState(() {
        _all = list;
        _filtered = list;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _filter(String q) {
    setState(() {
      _filtered = q.isEmpty
          ? _all
          : _all
                .where((p) => p.name.toLowerCase().contains(q.toLowerCase()))
                .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: _panel,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 8),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[700],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Text(
                    'Add Item',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.grey),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                controller: _search,
                style: const TextStyle(color: Colors.white),
                onChanged: _filter,
                decoration: InputDecoration(
                  hintText: 'Search menu…',
                  hintStyle: const TextStyle(color: Colors.grey),
                  prefixIcon: const Icon(Icons.search, color: Colors.grey),
                  filled: true,
                  fillColor: _surface,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: HdkPreloader(width: 120, height: 120))
                  : _error != null
                  ? ErrorRetryWidget(error: _error!, onRetry: _load)
                  : _filtered.isEmpty
                  ? const Center(
                      child: Text(
                        'No items found',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      controller: scrollCtrl,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _filtered.length,
                      itemBuilder: (_, i) {
                        final p = _filtered[i];
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 6,
                          ),
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: p.image.isNotEmpty
                                ? Image.network(
                                    p.image,
                                    width: 48,
                                    height: 48,
                                    fit: BoxFit.cover,
                                    errorBuilder: (ctx2, e2, st2) =>
                                        _placeholder(),
                                  )
                                : _placeholder(),
                          ),
                          title: Text(
                            p.name,
                            style: const TextStyle(color: Colors.white),
                          ),
                          subtitle: Text(
                            '₹${p.price.toStringAsFixed(0)}',
                            style: const TextStyle(color: Colors.grey),
                          ),
                          trailing: IconButton(
                            icon: const Icon(
                              Icons.add_circle,
                              color: _red,
                              size: 28,
                            ),
                            onPressed: () => Navigator.pop(ctx, p),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() => Container(
    width: 48,
    height: 48,
    color: _surface,
    child: const Icon(Icons.fastfood, color: Colors.grey, size: 24),
  );
}
