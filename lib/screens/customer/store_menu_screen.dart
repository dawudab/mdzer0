import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

const Color _kPrimary = Color(0xFF10B981);
const Color _kPrimaryDark = Color(0xFF059669);
const Color _kPrimaryLight = Color(0xFFD1FAE5);

// ---------------------------------------------------------------------------
// Cart item model (local, demo only)
// ---------------------------------------------------------------------------

class _CartItem {
  final String itemId;
  final String name;
  final double price;
  int quantity;

  _CartItem({
    required this.itemId,
    required this.name,
    required this.price,
    this.quantity = 1,
  });
}

// ---------------------------------------------------------------------------
// StoreMenuScreen
// ---------------------------------------------------------------------------

class StoreMenuScreen extends StatefulWidget {
  final String storeId;
  final String storeName;

  const StoreMenuScreen({
    super.key,
    required this.storeId,
    required this.storeName,
  });

  @override
  State<StoreMenuScreen> createState() => _StoreMenuScreenState();
}

class _StoreMenuScreenState extends State<StoreMenuScreen> {
  final Map<String, _CartItem> _cart = {};

  int get _cartCount => _cart.values.fold(0, (s, i) => s + i.quantity);
  double get _cartTotal =>
      _cart.values.fold(0.0, (s, i) => s + i.price * i.quantity);

  void _addToCart(String itemId, String name, double price) {
    setState(() {
      if (_cart.containsKey(itemId)) {
        _cart[itemId]!.quantity++;
      } else {
        _cart[itemId] =
            _CartItem(itemId: itemId, name: name, price: price);
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$name added to cart'),
        duration: const Duration(seconds: 1),
        backgroundColor: _kPrimary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _checkout() async {
    if (_cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Your cart is empty.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser!;
    final items = _cart.values
        .map((i) => {'name': i.name, 'qty': i.quantity, 'price': i.price})
        .toList();

    try {
      await FirebaseFirestore.instance.collection('orders').add({
        'customerId': user.uid,
        'customerName': user.displayName ?? 'Customer',
        'storeId': widget.storeId,
        'items': items,
        'total': _cartTotal,
        'status': 'Order Received',
        'paymentMethod': 'In-App',
        'createdAt': FieldValue.serverTimestamp(),
      });

      setState(() => _cart.clear());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                SizedBox(width: 10),
                Text(
                  'Order placed! Track it on the home screen.',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            backgroundColor: _kPrimary,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Order failed: $e'),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: _kPrimary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          widget.storeName,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          if (_cartCount > 0)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Icon(Icons.shopping_cart_rounded, size: 26),
                  Positioned(
                    top: 4,
                    right: 0,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          _cartCount > 9 ? '9+' : '$_cartCount',
                          style: const TextStyle(
                            fontSize: 9,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('items')
            .where('storeId', isEqualTo: widget.storeId)
            .where('isAvailable', isEqualTo: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: _kPrimary),
            );
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'Error loading menu\n${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.red.shade400),
                ),
              ),
            );
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(48),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(22),
                      decoration: const BoxDecoration(
                        color: _kPrimaryLight,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.restaurant_menu_rounded,
                        size: 48,
                        color: _kPrimary.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'No items available',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'This store hasn\'t added any items yet.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data();
              final name = (data['name'] as String?) ?? 'Item';
              final price = (data['price'] as num?)?.toDouble() ?? 0.0;
              final inCart = _cart.containsKey(doc.id);
              final qty = _cart[doc.id]?.quantity ?? 0;

              return _MenuItemTile(
                name: name,
                price: price,
                inCart: inCart,
                quantity: qty,
                onAdd: () => _addToCart(doc.id, name, price),
                onIncrement: () => setState(() => _cart[doc.id]!.quantity++),
                onDecrement: () => setState(() {
                  if (_cart[doc.id]!.quantity > 1) {
                    _cart[doc.id]!.quantity--;
                  } else {
                    _cart.remove(doc.id);
                  }
                }),
              );
            },
          );
        },
      ),
      floatingActionButton: _cartCount == 0
          ? null
          : FloatingActionButton.extended(
              backgroundColor: _kPrimary,
              foregroundColor: Colors.white,
              onPressed: _checkout,
              icon: const Icon(Icons.shopping_bag_rounded),
              label: Text(
                'Checkout · \$${_cartTotal.toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// Menu item tile
// ---------------------------------------------------------------------------

class _MenuItemTile extends StatelessWidget {
  final String name;
  final double price;
  final bool inCart;
  final int quantity;
  final VoidCallback onAdd;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  const _MenuItemTile({
    required this.name,
    required this.price,
    required this.inCart,
    required this.quantity,
    required this.onAdd,
    required this.onIncrement,
    required this.onDecrement,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.07),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            // Icon avatar
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: inCart ? _kPrimaryLight : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.lunch_dining_rounded,
                color: inCart ? _kPrimary : Colors.grey.shade400,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),

            // Name + price
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '\$${price.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _kPrimaryDark,
                    ),
                  ),
                ],
              ),
            ),

            // Add to cart / qty control
            if (!inCart)
              ElevatedButton(
                onPressed: onAdd,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kPrimary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'Add',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              )
            else
              Row(
                children: [
                  _CircleBtn(icon: Icons.remove, onTap: onDecrement),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text(
                      '$quantity',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                  ),
                  _CircleBtn(icon: Icons.add, onTap: onIncrement),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _CircleBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CircleBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: _kPrimaryLight,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 16, color: _kPrimaryDark),
      ),
    );
  }
}
