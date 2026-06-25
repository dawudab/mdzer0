import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'store_menu_screen.dart';

const Color _kPrimary = Color(0xFF10B981);
const Color _kPrimaryLight = Color(0xFFD1FAE5);

const List<String> _kStages = [
  'Order Received',
  'Order Being Prepared',
  'Order Ready for Delivery',
  'Out for Delivery',
  'Delivered',
];

// ---------------------------------------------------------------------------
// Main screen
// ---------------------------------------------------------------------------

class CustomerMainScreen extends StatelessWidget {
  const CustomerMainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: _kPrimary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Browse Stores',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
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
            padding: EdgeInsets.fromLTRB(16, 16, 16, 6),
            child: Text(
              'Stores Near You',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1F2937),
              ),
            ),
          ),
          const Expanded(child: _LiveStoreList()),
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
// Live store list
// ---------------------------------------------------------------------------

class _LiveStoreList extends StatelessWidget {
  const _LiveStoreList();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('stores')
          .where('isLive', isEqualTo: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: _kPrimary),
          );
        }
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error loading stores\n${snapshot.error}',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.red.shade400),
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
                      Icons.storefront_rounded,
                      size: 48,
                      color: _kPrimary.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'No stores open right now',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Check back soon — stores will appear\nhere once they go live.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade500,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.separated(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 14),
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data();
            return _StoreCard(
              storeId: doc.id,
              name: (data['name'] as String?) ?? 'Store',
              address: (data['address'] as String?) ?? '',
              logoUrl: (data['logoUrl'] as String?) ?? '🏪',
            );
          },
        );
      },
    );
  }
}

class _StoreCard extends StatelessWidget {
  final String storeId;
  final String name;
  final String address;
  final String logoUrl;

  const _StoreCard({
    required this.storeId,
    required this.name,
    required this.address,
    required this.logoUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => StoreMenuScreen(storeId: storeId, storeName: name),
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.07),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Banner
              Container(
                height: 100,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF10B981), Color(0xFF059669)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(18),
                  ),
                ),
                child: Center(
                  child: Text(logoUrl, style: const TextStyle(fontSize: 44)),
                ),
              ),
              // Info row
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          if (address.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  Icons.location_on_rounded,
                                  size: 13,
                                  color: Colors.grey.shade500,
                                ),
                                const SizedBox(width: 3),
                                Expanded(
                                  child: Text(
                                    address,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade500,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: _kPrimaryLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        'View Menu',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF059669),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
