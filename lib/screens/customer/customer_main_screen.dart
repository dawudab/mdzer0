import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

const Color _kPrimary = Color(0xFF10B981);

const List<String> _kStages = [
  'Order Received',
  'Order Being Prepared',
  'Order Ready for Delivery',
  'Out for Delivery',
  'Delivered',
];

// ---------------------------------------------------------------------------
// Cart item model
// ---------------------------------------------------------------------------

class _CartItem {
  final String productId;
  final String name;
  final double price;
  final String? storeId;
  int quantity;

  _CartItem({
    required this.productId,
    required this.name,
    required this.price,
    this.storeId,
    this.quantity = 1,
  });

  _CartItem copyWith({int? quantity}) => _CartItem(
    productId: productId,
    name: name,
    price: price,
    storeId: storeId,
    quantity: quantity ?? this.quantity,
  );
}

// ---------------------------------------------------------------------------
// Main screen
// ---------------------------------------------------------------------------

class CustomerMainScreen extends StatefulWidget {
  const CustomerMainScreen({super.key});

  @override
  State<CustomerMainScreen> createState() => _CustomerMainScreenState();
}

class _CustomerMainScreenState extends State<CustomerMainScreen> {
  final Map<String, _CartItem> _cart = {};

  int get _cartCount => _cart.values.fold(0, (s, i) => s + i.quantity);

  void _addToCart(String id, String name, double price, String? storeId) {
    setState(() {
      if (_cart.containsKey(id)) {
        _cart[id]!.quantity++;
      } else {
        _cart[id] = _CartItem(
          productId: id,
          name: name,
          price: price,
          storeId: storeId,
        );
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$name added to cart'),
        duration: const Duration(seconds: 1),
        backgroundColor: _kPrimary,
      ),
    );
  }

  Future<void> _placeOrder(
    Map<String, _CartItem> localCart,
    String address,
    String paymentMethod,
  ) async {
    if (localCart.isEmpty) return;
    final user = FirebaseAuth.instance.currentUser!;
    final storeId = localCart.values.first.storeId ?? '';
    final total = localCart.values.fold(
      0.0,
      (s, i) => s + i.price * i.quantity,
    );
    final items = localCart.values
        .map((i) => {'name': i.name, 'quantity': i.quantity, 'price': i.price})
        .toList();

    try {
      await FirebaseFirestore.instance.collection('orders').add({
        'customerId': user.uid,
        'customerName': user.displayName ?? 'Customer',
        'customerAddress': address,
        'storeId': storeId,
        'items': items,
        'status': 'Order Received',
        'paymentMethod': paymentMethod,
        'totalAmount': total,
        'createdAt': FieldValue.serverTimestamp(),
      });
      setState(() => _cart.clear());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order placed! Track it in the banner above.'),
            backgroundColor: _kPrimary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to place order: $e')));
      }
    }
  }

  void _openCart() {
    if (_cart.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Your cart is empty.')));
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CartSheet(
        initialCart: _cart,
        onPlaceOrder: (localCart, address, paymentMethod) {
          Navigator.pop(context);
          _placeOrder(localCart, address, paymentMethod);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: _kPrimary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Browse & Order',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        actions: [
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.shopping_cart_outlined),
                onPressed: _openCart,
              ),
              if (_cartCount > 0)
                Positioned(
                  top: 8,
                  right: 6,
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
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _LiveOrderBanner(uid: uid),
          _MapPlaceholder(),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: Text(
              'Available Products',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1F2937),
              ),
            ),
          ),
          Expanded(child: _ProductGrid(onAddToCart: _addToCart)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Live order tracking banner
// ---------------------------------------------------------------------------

class _LiveOrderBanner extends StatelessWidget {
  final String uid;

  const _LiveOrderBanner({required this.uid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .where('customerId', isEqualTo: uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();

        final activeDocs =
            (snapshot.data?.docs ?? []).where((d) {
              return (d.data()['status'] as String?) != 'Delivered';
            }).toList()..sort((a, b) {
              final tsA = a.data()['createdAt'];
              final tsB = b.data()['createdAt'];
              if (tsA == null) return 1;
              if (tsB == null) return -1;
              return (tsB as Timestamp).compareTo(tsA as Timestamp);
            });

        if (activeDocs.isEmpty) return const SizedBox.shrink();

        final order = activeDocs.first;
        final status = (order.data()['status'] as String?) ?? _kStages[0];
        final stageIndex = _kStages.indexOf(status);
        final safeIndex = stageIndex < 0 ? 0 : stageIndex;

        return Container(
          margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF10B981), Color(0xFF059669)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: const [
              BoxShadow(
                color: Color(0x4D10B981),
                blurRadius: 8,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.local_shipping_outlined,
                    color: Colors.white,
                    size: 15,
                  ),
                  SizedBox(width: 6),
                  Text(
                    'Live Order Tracking',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _BannerProgressBar(stages: _kStages, currentIndex: safeIndex),
              const SizedBox(height: 8),
              Text(
                status,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// White progress bar used inside the banner
// ---------------------------------------------------------------------------

class _BannerProgressBar extends StatelessWidget {
  final List<String> stages;
  final int currentIndex;

  const _BannerProgressBar({required this.stages, required this.currentIndex});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (int i = 0; i < stages.length; i++) ...[
          _buildDot(i),
          if (i < stages.length - 1)
            Expanded(
              child: Container(
                height: 2,
                color: i < currentIndex
                    ? Colors.white
                    : const Color(0x59FFFFFF),
              ),
            ),
        ],
      ],
    );
  }

  Widget _buildDot(int index) {
    final isDone = index <= currentIndex;
    final isCurrent = index == currentIndex;
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isDone ? Colors.white : const Color(0x40FFFFFF),
      ),
      child: isDone
          ? Icon(
              isCurrent ? Icons.circle : Icons.check,
              size: isCurrent ? 8 : 11,
              color: _kPrimary,
            )
          : null,
    );
  }
}

// ---------------------------------------------------------------------------
// Map placeholder
// ---------------------------------------------------------------------------

class _MapPlaceholder extends StatefulWidget {
  const _MapPlaceholder();

  @override
  State<_MapPlaceholder> createState() => _MapPlaceholderState();
}

class _MapPlaceholderState extends State<_MapPlaceholder> {
  bool _locating = false;
  String _locationText = 'Tap to detect your location';

  Future<void> _detectLocation() async {
    setState(() {
      _locating = true;
      _locationText = 'Detecting location...';
    });
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      setState(() {
        _locating = false;
        _locationText = 'Location detected · showing nearby stores';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 185,
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: const Color(0xFFECFDF5),
        border: Border.all(color: const Color(0xFF6EE7B7), width: 1),
      ),
      clipBehavior: Clip.hardEdge,
      child: Stack(
        children: [
          CustomPaint(
            size: const Size(double.infinity, 185),
            painter: _MapGridPainter(),
          ),
          const _MockStorePin(left: 55, top: 35, label: 'Fresh Mart'),
          const _MockStorePin(left: 175, top: 80, label: 'Quick Bites'),
          const _MockStorePin(left: 270, top: 42, label: 'City Store'),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
              color: const Color(0xF0FFFFFF),
              child: Row(
                children: [
                  const Icon(Icons.location_on, color: _kPrimary, size: 15),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _locationText,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF374151),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _locating ? null : _detectLocation,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: _kPrimary,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: _locating
                          ? const SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Locate Me',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
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

class _MockStorePin extends StatelessWidget {
  final double left;
  final double top;
  final String label;

  const _MockStorePin({
    required this.left,
    required this.top,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: left,
      top: top,
      child: Column(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: const BoxDecoration(
              color: _kPrimary,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: Color(0x4010B981), blurRadius: 6)],
            ),
            child: const Icon(Icons.storefront, size: 14, color: Colors.white),
          ),
          const SizedBox(height: 2),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
              boxShadow: const [
                BoxShadow(color: Color(0x1A000000), blurRadius: 4),
              ],
            ),
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1F2937),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MapGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x1410B981)
      ..strokeWidth = 1;
    const step = 28.0;
    for (double x = 0; x <= size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y <= size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ---------------------------------------------------------------------------
// Product grid
// ---------------------------------------------------------------------------

class _ProductGrid extends StatelessWidget {
  final void Function(String id, String name, double price, String? storeId)
  onAddToCart;

  const _ProductGrid({required this.onAddToCart});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('products').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: _kPrimary),
          );
        }
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) return const _EmptyProductState();

        return GridView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.82,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data();
            return _ProductCard(
              id: doc.id,
              name: (data['name'] as String?) ?? 'Product',
              price: (data['price'] as num?)?.toDouble() ?? 0.0,
              description: (data['description'] as String?) ?? '',
              storeId: data['storeId'] as String?,
              onAddToCart: onAddToCart,
            );
          },
        );
      },
    );
  }
}

class _EmptyProductState extends StatelessWidget {
  const _EmptyProductState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.shopping_bag_outlined,
            size: 56,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 12),
          Text(
            'No products available yet',
            style: TextStyle(fontSize: 15, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 6),
          Text(
            'Check back soon',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
          ),
        ],
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final String id;
  final String name;
  final double price;
  final String description;
  final String? storeId;
  final void Function(String, String, double, String?) onAddToCart;

  const _ProductCard({
    required this.id,
    required this.name,
    required this.price,
    required this.description,
    required this.storeId,
    required this.onAddToCart,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 90,
            decoration: const BoxDecoration(
              color: Color(0xFFD1FAE5),
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: const Center(
              child: Icon(
                Icons.image_outlined,
                color: Color(0xFF6EE7B7),
                size: 36,
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (description.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        description,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  const Spacer(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '\$${price.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _kPrimary,
                          fontSize: 14,
                        ),
                      ),
                      InkWell(
                        onTap: () => onAddToCart(id, name, price, storeId),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: _kPrimary,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.add,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
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

// ---------------------------------------------------------------------------
// Cart bottom sheet
// ---------------------------------------------------------------------------

class _CartSheet extends StatefulWidget {
  final Map<String, _CartItem> initialCart;
  final void Function(
    Map<String, _CartItem> cart,
    String address,
    String paymentMethod,
  )
  onPlaceOrder;

  const _CartSheet({required this.initialCart, required this.onPlaceOrder});

  @override
  State<_CartSheet> createState() => _CartSheetState();
}

class _CartSheetState extends State<_CartSheet> {
  late Map<String, _CartItem> _cart;
  final _addressController = TextEditingController();
  String _paymentMethod = 'In-App';

  @override
  void initState() {
    super.initState();
    _cart = {
      for (final e in widget.initialCart.entries)
        e.key: e.value.copyWith(quantity: e.value.quantity),
    };
  }

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }

  double get _total =>
      _cart.values.fold(0.0, (s, i) => s + i.price * i.quantity);

  void _inc(String id) => setState(() => _cart[id]!.quantity++);

  void _dec(String id) => setState(() {
    if (_cart[id]!.quantity > 1) {
      _cart[id]!.quantity--;
    } else {
      _cart.remove(id);
    }
  });

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottomPadding),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Text(
              'Your Cart',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 14),

            if (_cart.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text(
                    'Your cart is empty.',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              )
            else ...[
              ..._cart.values.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              '\$${item.price.toStringAsFixed(2)} each',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          _QtyButton(
                            icon: Icons.remove,
                            onTap: () => _dec(item.productId),
                          ),
                          SizedBox(
                            width: 28,
                            child: Center(
                              child: Text(
                                '${item.quantity}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          _QtyButton(
                            icon: Icons.add,
                            onTap: () => _inc(item.productId),
                          ),
                        ],
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 60,
                        child: Text(
                          '\$${(item.price * item.quantity).toStringAsFixed(2)}',
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: _kPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                  Text(
                    '\$${_total.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: _kPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              TextField(
                controller: _addressController,
                decoration: InputDecoration(
                  labelText: 'Delivery Address',
                  prefixIcon: const Icon(
                    Icons.location_on_outlined,
                    color: _kPrimary,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: _kPrimary, width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 14,
                  ),
                ),
              ),
              const SizedBox(height: 14),

              const Text(
                'Payment Method',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _PaymentOption(
                    label: 'In-App',
                    icon: Icons.credit_card,
                    selected: _paymentMethod == 'In-App',
                    onTap: () => setState(() => _paymentMethod = 'In-App'),
                  ),
                  const SizedBox(width: 10),
                  _PaymentOption(
                    label: 'Direct to Store',
                    icon: Icons.storefront_outlined,
                    selected: _paymentMethod == 'Direct to Store',
                    onTap: () =>
                        setState(() => _paymentMethod = 'Direct to Store'),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (_cart.isEmpty) return;
                    if (_addressController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please enter a delivery address.'),
                        ),
                      );
                      return;
                    }
                    widget.onPlaceOrder(
                      _cart,
                      _addressController.text.trim(),
                      _paymentMethod,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kPrimary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Place Order',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Quantity +/- button
// ---------------------------------------------------------------------------

class _QtyButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _QtyButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, size: 14, color: const Color(0xFF374151)),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Payment option selector tile
// ---------------------------------------------------------------------------

class _PaymentOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _PaymentOption({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFECFDF5) : const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? _kPrimary : Colors.grey.shade300,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, color: selected ? _kPrimary : Colors.grey, size: 20),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: selected ? _kPrimary : Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
