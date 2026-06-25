import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/store_profile.dart';
import '../models/store_item.dart';

class StoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ---------------------------------------------------------------------------
  // Store Profile
  // ---------------------------------------------------------------------------

  Future<StoreProfile?> getStoreProfile(String uid) async {
    final doc = await _db.collection('stores').doc(uid).get();
    if (!doc.exists || doc.data() == null) return null;
    return StoreProfile.fromMap(doc.id, doc.data()!);
  }

  Future<void> updateStoreProfile(StoreProfile profile) {
    return _db
        .collection('stores')
        .doc(profile.storeId)
        .set(profile.toMap(), SetOptions(merge: true));
  }

  // ---------------------------------------------------------------------------
  // Store Inventory
  // ---------------------------------------------------------------------------

  Stream<List<StoreItem>> getStoreInventory(String uid) {
    return _db
        .collection('items')
        .where('storeId', isEqualTo: uid)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => StoreItem.fromMap(doc.id, doc.data()))
            .toList());
  }

  Future<void> addOrUpdateItem(StoreItem item) {
    final ref = item.itemId.isEmpty
        ? _db.collection('items').doc()
        : _db.collection('items').doc(item.itemId);
    return ref.set(item.toMap(), SetOptions(merge: true));
  }

  Future<void> deleteItem(String itemId) {
    return _db.collection('items').doc(itemId).delete();
  }
}
