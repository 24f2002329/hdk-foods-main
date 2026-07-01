import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:hdk_core/hdk_core.dart';
import '../../data/repositories/product_service.dart';

const _red = Color(0xFFFF1E1E);
const _surface = Color(0xFF050505);
const _panel = Color(0xFF111111);

class ProductManagementScreen extends StatefulWidget {
  const ProductManagementScreen({super.key});

  @override
  State<ProductManagementScreen> createState() =>
      _ProductManagementScreenState();
}

class _ProductManagementScreenState extends State<ProductManagementScreen> {
  final ProductService _svc = ProductService();
  List<Product> _products = [];
  bool _loading = true;
  String? _error;
  final Map<int, bool> _toggling = {};

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
      final list = await _svc.getProducts();
      setState(() {
        _products = list;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _toggle(Product product) async {
    setState(() => _toggling[product.id] = true);
    try {
      final updated = await _svc.toggleAvailability(product.id);
      setState(() {
        final idx = _products.indexWhere((p) => p.id == product.id);
        if (idx >= 0) _products[idx] = updated;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _toggling.remove(product.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        backgroundColor: _surface,
        title: Text(
          'Manage Products',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: _red),
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: HdkPreloader())
          : _error != null
          ? ErrorRetryWidget(error: _error!, onRetry: _load)
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: _products.length,
                itemBuilder: (_, i) {
                  final p = _products[i];
                  final isBusy = _toggling[p.id] == true;
                  return Card(
                    color: _panel,
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: p.image.isNotEmpty
                            ? Image.network(
                                p.image,
                                width: 48,
                                height: 48,
                                fit: BoxFit.cover,
                                errorBuilder: (ctx2, e2, st2) => _placeholder(),
                              )
                            : _placeholder(),
                      ),
                      title: Text(
                        p.name,
                        style: TextStyle(
                          color: p.isAvailable ? Colors.white : Colors.grey,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        '₹${p.price.toStringAsFixed(0)} • '
                        '${p.isAvailable ? "Available" : "Unavailable"}',
                        style: TextStyle(
                          color: p.isAvailable ? Colors.grey : Colors.redAccent,
                          fontSize: 12,
                        ),
                      ),
                      trailing: isBusy
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: Center(
                                child: HdkPreloader(width: 24, height: 24),
                              ),
                            )
                          : Switch(
                              value: p.isAvailable,
                              activeThumbColor: _red,
                              onChanged: (_) => _toggle(p),
                            ),
                    ),
                  );
                },
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
