import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

const Color _kPrimary = Color(0xFF10B981);
const Color _kPrimaryDark = Color(0xFF059669);
const Color _kPrimaryLight = Color(0xFFD1FAE5);
const Color _kSurface = Color(0xFFF0FDF4);
const Color _kBackground = Color(0xFFF8FAFC);

const List<String> kOrderStages = [
  'Received',
  'Preparing',
  'Ready',
  'Out for Delivery',
  'Delivered',
];

const Map<String, IconData> _kStageIcons = {
  'Received': Icons.inbox_rounded,
  'Preparing': Icons.restaurant_rounded,
  'Ready': Icons.check_circle_outline_rounded,
  'Out for Delivery': Icons.delivery_dining_rounded,
  'Delivered': Icons.done_all_rounded,
};

// ---------------------------------------------------------------------------
// Root screen
// ---------------------------------------------------------------------------

class StoreMainScreen extends StatelessWidget {
  const StoreMainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      backgroundColor: _kBackground,
      appBar: AppBar(
        backgroundColor: _kPrimary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        title: const Row(
          children: [
            Icon(Icons.storefront_rounded, size: 24),
            SizedBox(width: 10),
            Text(
              'Store Dashboard',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 20,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Sign out',
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('orders')
            .where('storeId', isEqualTo: uid)
            .orderBy('createdAt', descending: true)
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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.error_outline_rounded,
                      size: 48,
                      color: Colors.red.shade300,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Error loading orders',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${snapshot.error}',
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

          final docs = snapshot.data?.docs ?? [];
          final today = DateTime.now();

          final activeOrders = docs.where((d) {
            final status = d.data()['status'] as String? ?? '';
            return status != 'Delivered';
          }).length;

          final completedToday = docs.where((d) {
            final data = d.data();
            if ((data['status'] as String?) != 'Delivered') return false;
            final ts = data['createdAt'];
            if (ts == null) return false;
            final dt = (ts as Timestamp).toDate();
            return dt.year == today.year &&
                dt.month == today.month &&
                dt.day == today.day;
          }).length;

          return Column(
            children: [
              _SummaryRow(
                activeOrders: activeOrders,
                completedToday: completedToday,
              ),
              Expanded(
                child: docs.isEmpty
                    ? const _EmptyState()
                    : ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                        itemCount: docs.length,
                        itemBuilder: (context, index) =>
                            _OrderCard(doc: docs[index]),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Summary row
// ---------------------------------------------------------------------------

class _SummaryRow extends StatelessWidget {
  final int activeOrders;
  final int completedToday;

  const _SummaryRow({required this.activeOrders, required this.completedToday});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_kPrimary, _kPrimaryDark],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
      child: Row(
        children: [
          Expanded(
            child: _SummaryTile(
              label: 'Active Orders',
              value: activeOrders.toString(),
              icon: Icons.receipt_long_rounded,
              iconBg: const Color(0xFFFEF3C7),
              iconColor: const Color(0xFFF59E0B),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _SummaryTile(
              label: 'Completed Today',
              value: completedToday.toString(),
              icon: Icons.check_circle_rounded,
              iconBg: _kPrimaryLight,
              iconColor: _kPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color iconBg;
  final Color iconColor;

  const _SummaryTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconBg,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1E293B),
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade500,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty state
// ---------------------------------------------------------------------------

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: _kPrimaryLight,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.inbox_rounded,
                size: 56,
                color: _kPrimary.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No orders yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'New orders will appear here in real-time\nas customers place them.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Order card
// ---------------------------------------------------------------------------

class _OrderCard extends StatefulWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;

  const _OrderCard({required this.doc});

  @override
  State<_OrderCard> createState() => _OrderCardState();
}

class _OrderCardState extends State<_OrderCard> {
  bool _isUpdating = false;

  Map<String, dynamic> get _data => widget.doc.data();

  String get _currentStatus =>
      (_data['status'] as String?) ?? kOrderStages.first;

  Future<void> _updateStatus(String newStatus) async {
    if (newStatus == _currentStatus) return;
    setState(() => _isUpdating = true);
    try {
      await FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.doc.id)
          .update({'status': newStatus});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Update failed: $e'),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  String _formatTimestamp(dynamic ts) {
    if (ts == null) return 'N/A';
    final dt = (ts as Timestamp).toDate().toLocal();
    return DateFormat('dd MMM yyyy, hh:mm a').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    final orderId = widget.doc.id;
    final shortId = orderId.length > 8
        ? orderId.substring(0, 8).toUpperCase()
        : orderId.toUpperCase();

    final customerName = (data['customerName'] as String?) ?? 'Customer';
    final customerPhone = (data['customerPhone'] as String?) ?? '';
    final customerAddress =
        (data['customerAddress'] as String?) ?? 'Location not provided';
    final paymentMethod = (data['paymentMethod'] as String?) ?? 'In-App';
    final rawItems = data['items'];
    final items = rawItems is List ? rawItems : <dynamic>[];
    final timestamp = data['createdAt'];

    final grossTotal = _calculateTotal(items);
    final currentStatus = _currentStatus;
    final stageIndex = kOrderStages.indexOf(currentStatus);
    final safeIndex = stageIndex < 0 ? 0 : stageIndex;
    final isDelivered = currentStatus == 'Delivered';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: _kPrimary.withValues(alpha: isDelivered ? 0.0 : 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Header ---
            _buildHeader(shortId, paymentMethod, timestamp),

            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- Customer info ---
                  _buildCustomerSection(
                    customerName,
                    customerPhone,
                    customerAddress,
                  ),

                  // --- Items list ---
                  if (items.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _buildItemsSection(items),
                  ],

                  // --- Total ---
                  if (grossTotal > 0) ...[
                    const SizedBox(height: 14),
                    _buildTotalRow(grossTotal),
                  ],

                  const SizedBox(height: 16),
                  const Divider(height: 1, color: Color(0xFFE2E8F0)),
                  const SizedBox(height: 16),

                  // --- 5-stage progress bar ---
                  _StageProgressBar(
                    stages: kOrderStages,
                    currentIndex: safeIndex,
                  ),

                  const SizedBox(height: 16),

                  // --- Status updater ---
                  _buildStatusUpdater(currentStatus, isDelivered),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(String shortId, String paymentMethod, dynamic timestamp) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: _kSurface,
        border: Border(
          bottom: BorderSide(color: _kPrimary.withValues(alpha: 0.12)),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _kPrimary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '#$shortId',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: _kPrimaryDark,
                fontSize: 13,
                letterSpacing: 0.5,
                fontFamily: 'monospace',
              ),
            ),
          ),
          const SizedBox(width: 10),
          _PaymentChip(method: paymentMethod),
          const Spacer(),
          Icon(
            Icons.access_time_rounded,
            size: 13,
            color: Colors.grey.shade400,
          ),
          const SizedBox(width: 4),
          Text(
            _formatTimestamp(timestamp),
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade500,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerSection(String name, String phone, String address) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 0.8),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _kPrimaryLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.person_rounded,
                  size: 18,
                  color: _kPrimary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    if (phone.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(
                            Icons.phone_rounded,
                            size: 12,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            phone,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.location_on_rounded,
                size: 16,
                color: Colors.grey.shade400,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  address,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: Colors.grey.shade600,
                    height: 1.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildItemsSection(List<dynamic> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.shopping_bag_rounded,
              size: 16,
              color: Colors.grey.shade600,
            ),
            const SizedBox(width: 6),
            Text(
              'Order Items',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: Colors.grey.shade700,
                letterSpacing: 0.3,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: _kPrimaryLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${items.length} item${items.length > 1 ? 's' : ''}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _kPrimaryDark,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...items.map<Widget>((item) {
          final name = item is Map
              ? (item['name'] as String? ?? 'Item')
              : item.toString();
          final qty = item is Map ? item['quantity'] : null;
          final price = item is Map ? item['price'] : null;
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: _kPrimary,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    qty != null ? '$name  ×  $qty' : name,
                    style: const TextStyle(
                      fontSize: 13.5,
                      color: Color(0xFF334155),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (price != null)
                  Text(
                    '\$${_formatPrice(price)}',
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E293B),
                    ),
                  ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildTotalRow(double total) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Gross Total',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF475569),
            ),
          ),
          Text(
            '\$${total.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusUpdater(String currentStatus, bool isDelivered) {
    if (_isUpdating) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: SizedBox(
            height: 28,
            width: 28,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: _kPrimary,
            ),
          ),
        ),
      );
    }

    if (isDelivered) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [_kPrimary.withValues(alpha: 0.1), _kPrimaryLight],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _kPrimary.withValues(alpha: 0.25)),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.verified_rounded, color: _kPrimary, size: 20),
            SizedBox(width: 8),
            Text(
              'Order Delivered Successfully',
              style: TextStyle(
                color: _kPrimaryDark,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Update Status',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade600,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: kOrderStages.map((stage) {
            final isActive = stage == currentStatus;
            final stageIdx = kOrderStages.indexOf(stage);
            final currentIdx = kOrderStages.indexOf(currentStatus);
            final isPast = stageIdx < currentIdx;

            return ActionChip(
              avatar: Icon(
                _kStageIcons[stage] ?? Icons.circle,
                size: 16,
                color: isActive
                    ? Colors.white
                    : isPast
                    ? _kPrimary
                    : Colors.grey.shade400,
              ),
              label: Text(
                stage,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  color: isActive
                      ? Colors.white
                      : isPast
                      ? _kPrimaryDark
                      : Colors.grey.shade600,
                ),
              ),
              backgroundColor: isActive
                  ? _kPrimary
                  : isPast
                  ? _kPrimaryLight
                  : Colors.grey.shade100,
              side: BorderSide(
                color: isActive
                    ? _kPrimary
                    : isPast
                    ? _kPrimary.withValues(alpha: 0.3)
                    : Colors.grey.shade300,
                width: isActive ? 1.5 : 0.8,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              onPressed: () => _updateStatus(stage),
            );
          }).toList(),
        ),
      ],
    );
  }

  double _calculateTotal(List<dynamic> items) {
    double total = 0;
    for (final item in items) {
      if (item is Map) {
        final price = item['price'];
        final qty = item['quantity'] ?? 1;
        if (price != null) {
          total +=
              (price is num ? price.toDouble() : 0.0) *
              (qty is num ? qty.toDouble() : 1.0);
        }
      }
    }
    return total;
  }

  String _formatPrice(dynamic price) {
    if (price is num) return price.toStringAsFixed(2);
    return price.toString();
  }
}

// ---------------------------------------------------------------------------
// Payment method chip
// ---------------------------------------------------------------------------

class _PaymentChip extends StatelessWidget {
  final String method;

  const _PaymentChip({required this.method});

  @override
  Widget build(BuildContext context) {
    final isInApp =
        method.toLowerCase().contains('in') ||
        method.toLowerCase().contains('app');

    final color = isInApp ? const Color(0xFF6366F1) : const Color(0xFFF59E0B);
    final icon = isInApp ? Icons.credit_card_rounded : Icons.payments_rounded;
    final label = isInApp ? 'In-App' : 'Cash to Store';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 5-stage progress bar
// ---------------------------------------------------------------------------

class _StageProgressBar extends StatelessWidget {
  final List<String> stages;
  final int currentIndex;

  const _StageProgressBar({required this.stages, required this.currentIndex});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            for (int i = 0; i < stages.length; i++) ...[
              _buildNode(i),
              if (i < stages.length - 1)
                Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    height: 3,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(2),
                      color: i < currentIndex
                          ? _kPrimary
                          : Colors.grey.shade200,
                    ),
                  ),
                ),
            ],
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Icon(
              _kStageIcons[stages[currentIndex]] ?? Icons.circle,
              size: 16,
              color: _kPrimary,
            ),
            const SizedBox(width: 6),
            Text(
              stages[currentIndex],
              style: const TextStyle(
                fontSize: 13,
                color: _kPrimaryDark,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildNode(int index) {
    final isDone = index <= currentIndex;
    final isCurrent = index == currentIndex;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: isCurrent ? 26 : 22,
      height: isCurrent ? 26 : 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isDone ? _kPrimary : Colors.grey.shade200,
        border: isCurrent ? Border.all(color: _kPrimaryLight, width: 3) : null,
        boxShadow: isCurrent
            ? [
                BoxShadow(
                  color: _kPrimary.withValues(alpha: 0.3),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Center(
        child: isDone
            ? const Icon(Icons.check_rounded, size: 13, color: Colors.white)
            : Text(
                '${index + 1}',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade500,
                ),
              ),
      ),
    );
  }
}
