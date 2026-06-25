import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../models/store_item.dart';
import '../../models/store_profile.dart';
import '../../services/store_service.dart';

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

const Color _kPrimary = Color(0xFF10B981);
const Color _kPrimaryDark = Color(0xFF059669);
const Color _kPrimaryLight = Color(0xFFD1FAE5);
const Color _kBackground = Color(0xFFF8FAFC);

const List<String> kOrderStages = [
  'Order Received',
  'Order Being Prepared',
  'Order Ready for Delivery',
  'Out for Delivery',
  'Delivered',
];

// ---------------------------------------------------------------------------
// Root screen — 4-tab layout with BottomNavigationBar
// ---------------------------------------------------------------------------

class StoreMainScreen extends StatefulWidget {
  const StoreMainScreen({super.key});

  @override
  State<StoreMainScreen> createState() => _StoreMainScreenState();
}

class _StoreMainScreenState extends State<StoreMainScreen> {
  int _currentTab = 0;

  static const _titles = ['Dashboard', 'Orders', 'Inventory', 'My Store'];

  void _jumpToTab(int index) => setState(() => _currentTab = index);

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
        title: Row(
          children: [
            const Icon(Icons.storefront_rounded, size: 24),
            const SizedBox(width: 10),
            Text(
              _titles[_currentTab],
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 20,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
        actions: [
          if (_currentTab == 1)
            IconButton(
              icon: const Icon(Icons.bug_report_rounded),
              tooltip: 'Add test order',
              onPressed: () => _addDummyOrder(uid),
            ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Sign out',
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: IndexedStack(
        index: _currentTab,
        children: [
          _DashboardTab(uid: uid, onJumpToTab: _jumpToTab),
          const _OrdersTab(),
          _InventoryTab(uid: uid),
          _ProfileTab(uid: uid),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentTab,
        selectedItemColor: _kPrimary,
        unselectedItemColor: Colors.grey.shade400,
        type: BottomNavigationBarType.fixed,
        onTap: (index) => setState(() => _currentTab = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_rounded),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long_rounded),
            label: 'Orders',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory_2_rounded),
            label: 'Inventory',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.store_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  Future<void> _addDummyOrder(String uid) async {
    await FirebaseFirestore.instance.collection('orders').add({
      'storeId': uid,
      'customerName': 'Test Customer',
      'customerPhone': '+222 555 1234',
      'status': 'Order Received',
      'total': 45.0,
      'paymentMethod': 'Cash to Store',
      'items': [
        {'name': 'Premium Breakfast Box', 'qty': 1},
        {'name': 'Fresh Mango Juice', 'qty': 2},
      ],
      'createdAt': FieldValue.serverTimestamp(),
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Test order added!'),
          backgroundColor: _kPrimary,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

// ---------------------------------------------------------------------------
// Tab 0 – Dashboard
// ---------------------------------------------------------------------------

class _DashboardTab extends StatelessWidget {
  final String uid;
  final void Function(int) onJumpToTab;

  const _DashboardTab({required this.uid, required this.onJumpToTab});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .where('storeId', isEqualTo: uid)
          .snapshots(),
      builder: (context, orderSnap) {
        final orders = orderSnap.data?.docs ?? [];
        final activeOrders = orders
            .where((d) => (d.data()['status'] as String?) != 'Delivered')
            .length;

        return StreamBuilder<List<StoreItem>>(
          stream: StoreService().getStoreInventory(uid),
          builder: (context, invSnap) {
            final liveItems = (invSnap.data ?? [])
                .where((i) => i.isAvailable)
                .length;

            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Stat cards ──
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          label: 'Active Orders',
                          value: activeOrders.toString(),
                          icon: Icons.receipt_long_rounded,
                          iconBg: const Color(0xFFFEF3C7),
                          iconColor: const Color(0xFFF59E0B),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: _StatCard(
                          label: 'Total Live Items',
                          value: liveItems.toString(),
                          icon: Icons.inventory_2_rounded,
                          iconBg: _kPrimaryLight,
                          iconColor: _kPrimary,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 28),

                  // ── Quick actions ──
                  const Text(
                    'Quick Actions',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 14),

                  _QuickActionButton(
                    icon: Icons.add_box_rounded,
                    label: 'Add New Item',
                    subtitle: 'Add a product to your inventory',
                    onTap: () => onJumpToTab(2),
                  ),
                  const SizedBox(height: 10),
                  _QuickActionButton(
                    icon: Icons.store_rounded,
                    label: 'View Profile',
                    subtitle: 'Edit your store name, address & status',
                    onTap: () => onJumpToTab(3),
                  ),
                  const SizedBox(height: 10),
                  _QuickActionButton(
                    icon: Icons.receipt_long_rounded,
                    label: 'Go to Orders',
                    subtitle: 'Manage and update live orders',
                    onTap: () => onJumpToTab(1),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color iconBg;
  final Color iconColor;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconBg,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
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
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(height: 14),
          Text(
            value,
            style: const TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
              height: 1.1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _kPrimaryLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: _kPrimary, size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Orders Tab
// ---------------------------------------------------------------------------

class _OrdersTab extends StatelessWidget {
  const _OrdersTab();

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
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
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
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
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                      itemCount: docs.length,
                      itemBuilder: (context, index) =>
                          _OrderCard(doc: docs[index]),
                    ),
            ),
          ],
        );
      },
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
              decoration: const BoxDecoration(
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
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final mo = dt.month.toString().padLeft(2, '0');
    return '$d/$mo/${dt.year}  $h:$m';
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
    final paymentMethod = (data['paymentMethod'] as String?) ?? 'In-App';
    final rawItems = data['items'];
    final items = rawItems is List ? rawItems : <dynamic>[];
    final total = data['total'];
    final timestamp = data['createdAt'];

    final currentStatus = _currentStatus;
    final stageIndex = kOrderStages.indexOf(currentStatus);
    final safeIndex = stageIndex < 0 ? 0 : stageIndex;
    final isDelivered = currentStatus == 'Delivered';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 6,
      shadowColor: _kPrimary.withValues(alpha: 0.15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Header ---
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: _kPrimary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '#$shortId',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: _kPrimaryDark,
                      fontSize: 13,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _PaymentBadge(method: paymentMethod),
                const Spacer(),
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

            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 14),

            // --- Customer info ---
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
                        customerName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      if (customerPhone.isNotEmpty) ...[
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
                              customerPhone,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
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

            // --- Items ---
            if (items.isNotEmpty) ...[
              const SizedBox(height: 14),
              const Text(
                'Items',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: Color(0xFF475569),
                ),
              ),
              const SizedBox(height: 6),
              ...items.map<Widget>((item) {
                final name = item is Map
                    ? (item['name'] as String? ?? 'Item')
                    : item.toString();
                final qty = item is Map
                    ? (item['qty'] ?? item['quantity'])
                    : null;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
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
                    ],
                  ),
                );
              }),
            ],

            // --- Total ---
            if (total != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF475569),
                      ),
                    ),
                    Text(
                      '\$${total is num ? total.toStringAsFixed(2) : total}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),
            const SizedBox(height: 16),

            // --- 5-stage progress bar ---
            _StageProgressBar(stages: kOrderStages, currentIndex: safeIndex),

            const SizedBox(height: 14),

            // --- Status updater ---
            if (_isUpdating)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: _kPrimary,
                    ),
                  ),
                ),
              )
            else if (isDelivered)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: _kPrimaryLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _kPrimary.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.verified_rounded, color: _kPrimary, size: 18),
                    SizedBox(width: 6),
                    Text(
                      'Order Delivered',
                      style: TextStyle(
                        color: _kPrimaryDark,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              )
            else
              DropdownButtonFormField<String>(
                initialValue: kOrderStages.contains(currentStatus)
                    ? currentStatus
                    : kOrderStages.first,
                decoration: InputDecoration(
                  labelText: 'Update Status',
                  labelStyle: TextStyle(
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w600,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Colors.grey.shade300,
                      width: 0.8,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Colors.grey.shade300,
                      width: 0.8,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _kPrimary, width: 1.5),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
                icon: const Icon(
                  Icons.arrow_drop_down_rounded,
                  color: _kPrimary,
                ),
                items: kOrderStages
                    .map(
                      (stage) => DropdownMenuItem<String>(
                        value: stage,
                        child: Text(
                          stage,
                          style: const TextStyle(fontSize: 13),
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
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Payment badge
// ---------------------------------------------------------------------------

class _PaymentBadge extends StatelessWidget {
  final String method;

  const _PaymentBadge({required this.method});

  @override
  Widget build(BuildContext context) {
    final isInApp =
        method.toLowerCase().contains('in') ||
        method.toLowerCase().contains('app');
    final isCash = method.toLowerCase().contains('cash');

    final Color color;
    final IconData icon;
    final String label;

    if (isInApp && !isCash) {
      color = const Color(0xFF6366F1);
      icon = Icons.credit_card_rounded;
      label = 'In-App';
    } else {
      color = const Color(0xFFF59E0B);
      icon = Icons.payments_rounded;
      label = 'Cash to Store';
    }

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
    return Row(
      children: [
        for (int i = 0; i < stages.length; i++) ...[
          _buildNode(i),
          if (i < stages.length - 1)
            Expanded(
              child: Container(
                height: 3,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  color: i < currentIndex ? _kPrimary : Colors.grey.shade200,
                ),
              ),
            ),
        ],
      ],
    );
  }

  Widget _buildNode(int index) {
    final isDone = index <= currentIndex;
    final isCurrent = index == currentIndex;

    return Container(
      width: isCurrent ? 26 : 20,
      height: isCurrent ? 26 : 20,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isDone ? _kPrimary : Colors.grey.shade200,
        border: isCurrent ? Border.all(color: _kPrimaryLight, width: 3) : null,
        boxShadow: isCurrent
            ? [
                BoxShadow(
                  color: _kPrimary.withValues(alpha: 0.3),
                  blurRadius: 6,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Center(
        child: isDone
            ? const Icon(Icons.check_rounded, size: 12, color: Colors.white)
            : Text(
                '${index + 1}',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade500,
                ),
              ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tab 2 – Inventory (Firestore)
// ---------------------------------------------------------------------------

class _InventoryTab extends StatelessWidget {
  final String uid;

  const _InventoryTab({required this.uid});

  @override
  Widget build(BuildContext context) {
    final service = StoreService();

    return Scaffold(
      backgroundColor: _kBackground,
      body: StreamBuilder<List<StoreItem>>(
        stream: service.getStoreInventory(uid),
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
                  'Error loading inventory\n${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.red.shade400),
                ),
              ),
            );
          }

          final items = snapshot.data ?? [];

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Store Catalog',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${items.length} item${items.length == 1 ? '' : 's'} · Toggle availability for customers',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: items.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(48),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: const BoxDecoration(
                                  color: _kPrimaryLight,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.inventory_2_rounded,
                                  size: 48,
                                  color: _kPrimary.withValues(alpha: 0.6),
                                ),
                              ),
                              const SizedBox(height: 20),
                              Text(
                                'No items yet',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Tap + to add your first product.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.separated(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                        itemCount: items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final item = items[index];
                          return _InventoryItemTile(
                            item: item,
                            service: service,
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: _kPrimary,
        foregroundColor: Colors.white,
        tooltip: 'Add item',
        onPressed: () => _showAddItemDialog(context, uid, service),
        child: const Icon(Icons.add_rounded),
      ),
    );
  }

  Future<void> _showAddItemDialog(
    BuildContext context,
    String uid,
    StoreService service,
  ) async {
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Add New Item',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameCtrl,
                decoration: _inputDecoration('Item Name'),
                textCapitalization: TextCapitalization.words,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: priceCtrl,
                decoration: _inputDecoration('Price (e.g. 12.50)'),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Required';
                  if (double.tryParse(v.trim()) == null) return 'Invalid price';
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _kPrimary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final newItem = StoreItem(
                itemId: '',
                storeId: uid,
                name: nameCtrl.text.trim(),
                price: double.parse(priceCtrl.text.trim()),
              );
              Navigator.pop(ctx);
              await service.addOrUpdateItem(newItem);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}

InputDecoration _inputDecoration(String label) {
  return InputDecoration(
    labelText: label,
    labelStyle: TextStyle(color: Colors.grey.shade600),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Colors.grey.shade300),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: _kPrimary, width: 1.5),
    ),
  );
}

class _InventoryItemTile extends StatelessWidget {
  final StoreItem item;
  final StoreService service;

  const _InventoryItemTile({required this.item, required this.service});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.07),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: item.isAvailable ? _kPrimaryLight : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.shopping_basket_rounded,
                color: item.isAvailable ? _kPrimary : Colors.grey.shade400,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: item.isAvailable
                          ? const Color(0xFF1E293B)
                          : Colors.grey.shade500,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '\$${item.price.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _kPrimary,
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: item.isAvailable,
              activeColor: _kPrimary,
              onChanged: (val) {
                service.addOrUpdateItem(item.copyWith(isAvailable: val));
              },
            ),
            IconButton(
              icon: Icon(
                Icons.delete_outline_rounded,
                color: Colors.red.shade400,
              ),
              onPressed: () => _confirmDelete(context),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Item?'),
        content: Text('"${item.name}" will be permanently removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade500,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await service.deleteItem(item.itemId);
    }
  }
}

// ---------------------------------------------------------------------------
// Tab 3 – Store Profile
// ---------------------------------------------------------------------------

class _ProfileTab extends StatefulWidget {
  final String uid;

  const _ProfileTab({required this.uid});

  @override
  State<_ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<_ProfileTab> {
  final _service = StoreService();
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();

  bool _isLive = false;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final profile = await _service.getStoreProfile(widget.uid);
    if (!mounted) return;
    setState(() {
      _nameCtrl.text = profile?.name ?? '';
      _addressCtrl.text = profile?.address ?? '';
      _isLive = profile?.isLive ?? false;
      _isLoading = false;
    });
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final profile = StoreProfile(
        storeId: widget.uid,
        name: _nameCtrl.text.trim(),
        address: _addressCtrl.text.trim(),
        isLive: _isLive,
      );
      await _service.updateStoreProfile(profile);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile saved!'),
            backgroundColor: _kPrimary,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Save failed: $e'),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: _kPrimary));
    }

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 40),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Logo / avatar ──
            Center(
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: _kPrimaryLight,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Center(
                  child: Text('🏪', style: TextStyle(fontSize: 38)),
                ),
              ),
            ),

            const SizedBox(height: 28),

            const Text(
              'Store Information',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 14),

            TextFormField(
              controller: _nameCtrl,
              decoration: _inputDecoration('Store Name'),
              textCapitalization: TextCapitalization.words,
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Store name is required'
                  : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _addressCtrl,
              decoration: _inputDecoration('Address'),
              textCapitalization: TextCapitalization.sentences,
              maxLines: 2,
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Address is required'
                  : null,
            ),

            const SizedBox(height: 24),

            // ── isLive toggle ──
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _isLive
                      ? _kPrimary.withValues(alpha: 0.4)
                      : const Color(0xFFE2E8F0),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: _isLive ? _kPrimaryLight : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.wifi_tethering_rounded,
                      color: _isLive ? _kPrimary : Colors.grey.shade400,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Store is Live',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        Text(
                          _isLive
                              ? 'Visible to customers on the map'
                              : 'Hidden from customers',
                          style: TextStyle(
                            fontSize: 12,
                            color: _isLive
                                ? _kPrimaryDark
                                : Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _isLive,
                    activeColor: _kPrimary,
                    onChanged: (val) => setState(() => _isLive = val),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // ── Save button ──
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kPrimary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: _isSaving ? null : _saveProfile,
                child: _isSaving
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Save Profile',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
