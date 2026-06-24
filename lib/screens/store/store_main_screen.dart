import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

const Color _kPrimary = Color(0xFF10B981);

const List<String> kOrderStages = [
  'Order Received',
  'Order Being Prepared',
  'Order Ready for Delivery',
  'Out for Delivery',
  'Delivered',
];

// ---------------------------------------------------------------------------
// Root screen
// ---------------------------------------------------------------------------

class StoreMainScreen extends StatelessWidget {
  const StoreMainScreen({super.key});

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
          'Store Dashboard',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('orders')
            .where('storeId', isEqualTo: uid)
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
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Error loading orders:\n${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final docs = snapshot.data?.docs ?? [];
          docs.sort((a, b) {
            final tsA = a.data()['createdAt'];
            final tsB = b.data()['createdAt'];
            if (tsA == null && tsB == null) return 0;
            if (tsA == null) return 1;
            if (tsB == null) return -1;
            return (tsB as Timestamp).compareTo(tsA as Timestamp);
          });

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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
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
      color: _kPrimary,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Row(
        children: [
          Expanded(
            child: _SummaryTile(
              label: 'Active Orders',
              value: activeOrders.toString(),
              icon: Icons.receipt_long_outlined,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _SummaryTile(
              label: 'Completed Today',
              value: completedToday.toString(),
              icon: Icons.check_circle_outline,
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

  const _SummaryTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        child: Row(
          children: [
            Icon(icon, color: _kPrimary, size: 26),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: _kPrimary,
                  ),
                ),
                Text(
                  label,
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
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
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_outlined, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(
            'No orders yet',
            style: TextStyle(fontSize: 16, color: Colors.grey.shade500),
          ),
        ],
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

  String get _currentStatus =>
      (widget.doc.data()['status'] as String?) ?? kOrderStages[0];

  Future<void> _updateStatus(String newStatus) async {
    setState(() => _isUpdating = true);
    try {
      await FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.doc.id)
          .update({'status': newStatus});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Update failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  String _formatTimestamp(dynamic ts) {
    if (ts == null) return 'N/A';
    final dt = (ts as Timestamp).toDate().toLocal();
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final mo = dt.month.toString().padLeft(2, '0');
    return '$d/$mo/${dt.year}  $h:$m';
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.doc.data();
    final orderId = widget.doc.id;
    final shortId = orderId.length > 8
        ? orderId.substring(0, 8).toUpperCase()
        : orderId.toUpperCase();

    final customerName = (data['customerName'] as String?) ?? 'Customer';
    final customerAddress =
        (data['customerAddress'] as String?) ?? 'Address not provided';
    final rawItems = data['items'];
    final items = rawItems is List ? rawItems : <dynamic>[];
    final timestamp = data['createdAt'];

    final currentStatus = _currentStatus;
    final stageIndex = kOrderStages.indexOf(currentStatus);
    final safeIndex = stageIndex < 0 ? 0 : stageIndex;
    final isDelivered = currentStatus == 'Delivered';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Header: order ID + timestamp ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _kPrimary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Order #$shortId',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _kPrimary,
                      fontSize: 13,
                    ),
                  ),
                ),
                Text(
                  _formatTimestamp(timestamp),
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),

            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),

            // --- Customer info ---
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.person_outline, size: 16, color: Colors.grey),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        customerName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            size: 13,
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 2),
                          Expanded(
                            child: Text(
                              customerAddress,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // --- Items list ---
            if (items.isNotEmpty) ...[
              const SizedBox(height: 10),
              const Text(
                'Items',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const SizedBox(height: 4),
              ...items.map<Widget>((item) {
                final name = item is Map
                    ? (item['name'] as String? ?? 'Item')
                    : item.toString();
                final qty = item is Map ? item['quantity'] : null;
                final price = item is Map ? item['price'] : null;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Row(
                    children: [
                      const Text(
                        '• ',
                        style: TextStyle(
                          color: _kPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          qty != null ? '$name × $qty' : name,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                      if (price != null)
                        Text(
                          '\$${price.toString()}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                    ],
                  ),
                );
              }),
            ],

            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),

            // --- 5-stage progress bar ---
            _StageProgressBar(stages: kOrderStages, currentIndex: safeIndex),

            const SizedBox(height: 12),

            // --- Status updater ---
            if (!isDelivered)
              Row(
                children: [
                  const Text(
                    'Update Status:',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _isUpdating
                        ? const Center(
                            child: SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: _kPrimary,
                              ),
                            ),
                          )
                        : DropdownButton<String>(
                            value: kOrderStages.contains(currentStatus)
                                ? currentStatus
                                : kOrderStages[0],
                            isExpanded: true,
                            underline: Container(
                              height: 1,
                              color: _kPrimary.withValues(alpha: 0.4),
                            ),
                            icon: const Icon(
                              Icons.arrow_drop_down,
                              color: _kPrimary,
                            ),
                            items: kOrderStages
                                .map(
                                  (stage) => DropdownMenuItem<String>(
                                    value: stage,
                                    child: Text(
                                      stage,
                                      style: const TextStyle(fontSize: 13),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (val) {
                              if (val != null && val != currentStatus) {
                                _updateStatus(val);
                              }
                            },
                          ),
                  ),
                ],
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: _kPrimary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle, color: _kPrimary, size: 18),
                    SizedBox(width: 6),
                    Text(
                      'Order Delivered',
                      style: TextStyle(
                        color: _kPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
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
              _buildDot(i),
              if (i < stages.length - 1)
                Expanded(
                  child: Container(
                    height: 2,
                    color: i < currentIndex ? _kPrimary : Colors.grey.shade300,
                  ),
                ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        Text(
          stages[currentIndex],
          style: const TextStyle(
            fontSize: 12,
            color: _kPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildDot(int index) {
    final isDone = index <= currentIndex;
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isDone ? _kPrimary : Colors.grey.shade300,
      ),
      child: isDone
          ? const Icon(Icons.check, size: 12, color: Colors.white)
          : null,
    );
  }
}
