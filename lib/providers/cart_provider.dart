import 'package:flutter/material.dart';
import '../services/database_helper.dart';

class CartItem {
  final int productId;
  final String name;
  final double price;
  int quantity;
  final int? parentId;
  final int bundleQty;
  final bool isDimsum;

  CartItem({
    required this.productId,
    required this.name,
    required this.price,
    this.quantity = 1,
    this.parentId,
    this.bundleQty = 1,
    this.isDimsum = false,
  });

  double get subtotal => price * quantity;
}

class CartProvider with ChangeNotifier {
  final Map<int, CartItem> _items = {};
  // Simple per-parent lock to avoid concurrent adds that can oversubscribe stock
  final Set<int> _locks = {};

  Map<int, CartItem> get items => _items;

  int get totalItems => _items.length;

  double get totalAmount {
    double total = 0.0;
    _items.forEach((key, value) => total += value.subtotal);
    return total;
  }

  // Hitung total unit yang terpakai untuk produk dasar tertentu
  int getTotalUsedUnits(int parentId) {
    int total = 0;
    _items.forEach((id, item) {
      final int itemParent = item.parentId ?? item.productId;
      if (itemParent == parentId) {
        total += item.quantity * item.bundleQty;
      }
    });
    return total;
  }

  /// Total dimsum raw units currently reserved in cart (sum of quantity * bundleQty for all items with isDimsum true)
  int getTotalDimsumUsed() {
    int total = 0;
    _items.forEach((id, item) {
      if (item.isDimsum) {
        total += item.quantity * item.bundleQty;
      }
    });
    return total;
  }

  /// Remaining global dimsum units based on provided shopStock and current cart reservations
  int getGlobalRemaining(int shopStock) {
    final int used = getTotalDimsumUsed();
    return shopStock - used;
  }

  // Parse parent key reliably from product map
  int _parentKeyFromProduct(dynamic p, int productId) {
    if (p == null) return productId;
    if (p['parent_id'] == null) return productId;
    return int.tryParse(p['parent_id'].toString()) ?? productId;
  }

  /// Return remaining stock for a product based on realtime cart reservations.
  /// For dimsum variants this returns remaining raw units; for non-variant it
  /// returns remaining item count.
  int getRemainingStock(dynamic p, int shopStock) {
    final int productId = int.tryParse(p['id']?.toString() ?? '0') ?? 0;
    final int bundleQty = int.tryParse(p['bundle_qty']?.toString() ?? '0') ?? 0;
    final bool isDimsum = bundleQty > 0;
    if (isDimsum) {
      return getGlobalRemaining(shopStock);
    } else {
      final int maxStock = int.tryParse(p['stock']?.toString() ?? '0') ?? 0;
      final int used = _items.containsKey(productId) ? _items[productId]!.quantity : 0;
      final int rem = maxStock - used;
      return rem < 0 ? 0 : rem;
    }
  }

  /// Check whether product p can be added without exceeding stock.
  bool canAddProduct(dynamic p, int shopStock) {
    return true; // Bypass semua pengecekan stok
  }

  Future<bool> addItem(dynamic p, int shopStock) async {
    final int productId = int.tryParse(p['id']?.toString() ?? '0') ?? 0;
    final String name = p['name']?.toString() ?? '';
    final double price = double.tryParse(p['price']?.toString() ?? '0') ?? 0;
    final int? parentId = p['parent_id'] != null ? (int.tryParse(p['parent_id'].toString())) : null;
    // Determine if product is dimsum variant (bundle_qty > 0) or non-dimsum (stock field used)
    final int bundleQty = int.tryParse(p['bundle_qty']?.toString() ?? '0') ?? 0;
    final bool isDimsum = bundleQty > 0;
    // For dimsum variants, we must check stock of the parent product (raw material)
    int maxStock;
    if (isDimsum) {
      // For dimsum, use the shop's stock (bundle count) passed from UI
      maxStock = shopStock;
    } else {
      maxStock = int.tryParse(p['stock']?.toString() ?? '0') ?? 0;
    }

    // Effective quantity counts bundle size for dimsum, else 1 per unit
    final int effectiveQty = isDimsum ? bundleQty : 1;

    final int parentKey = parentId ?? productId;

    // Acquire simple lock per parentKey to avoid concurrent oversubscribe
    if (_locks.contains(parentKey)) return false;
    _locks.add(parentKey);
    try {
      // Bypass stock checks

      // Snapshot previous quantity to allow rollback if needed
      final bool existed = _items.containsKey(productId);
      final int prevQty = existed ? _items[productId]!.quantity : 0;

      // Add or update item
      if (existed) {
        _items.update(productId, (existing) => CartItem(
          productId: existing.productId,
          name: existing.name,
          price: existing.price,
          quantity: existing.quantity + 1,
          parentId: existing.parentId,
          bundleQty: existing.bundleQty,
          isDimsum: existing.isDimsum,
        ));
      } else {
        _items.putIfAbsent(productId, () => CartItem(
          productId: productId,
          name: name,
          price: price,
          parentId: parentId,
          bundleQty: effectiveQty,
          isDimsum: isDimsum,
        ));
      }

      notifyListeners();
      return true;
    } finally {
      _locks.remove(parentKey);
    }
  }


  void removeOneItem(int productId) {
    if (!_items.containsKey(productId)) return;
    if (_items[productId]!.quantity > 1) {
      _items.update(productId, (existing) => CartItem(
        productId: existing.productId,
        name: existing.name,
        price: existing.price,
        quantity: existing.quantity - 1,
        parentId: existing.parentId,
        bundleQty: existing.bundleQty,
        isDimsum: existing.isDimsum,
      ));
    } else {
      _items.remove(productId);
    }
    notifyListeners();
  }

  void clear() {
    _items.clear();
    notifyListeners();
  }
}
