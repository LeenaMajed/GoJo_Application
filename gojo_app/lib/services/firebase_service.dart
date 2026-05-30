import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/models.dart';
import '../screens/place_model.dart' as ai;


class FirebaseService {
  static final FirebaseService _i = FirebaseService._();
  factory FirebaseService() => _i;
  FirebaseService._();

  final _auth = FirebaseAuth.instance;
  final _db   = FirebaseFirestore.instance;

  
  User? get currentUser => _auth.currentUser;
  String? get uid       => _auth.currentUser?.uid;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  DocumentReference _userDoc(String uid) => _db.collection('users').doc(uid);


  Future<UserCredential?> signIn(String email, String password) async {
    try {
      return await _auth.signInWithEmailAndPassword(
          email: email.trim(), password: password.trim());
    } on FirebaseAuthException {
      rethrow;
    }
  }

  Future<UserCredential?> signUp(String email, String password) async {
    try {
      return await _auth.createUserWithEmailAndPassword(
          email: email.trim(), password: password.trim());
    } on FirebaseAuthException {
      rethrow;
    }
  }

  Future<void> signOut() => _auth.signOut();

  Future<void> saveUserProfile({
    required String uid,
    required String name,
    required String email,
    required String role,
    List<String> interests = const [],
    String? budget,
    String? travelStyle,
    String? nationality,
    String? photoUrl,
  }) async {
    final data = <String, dynamic>{
      'name':      name,
      'email':     email,
      'role':      role,
      'interests': interests,
      'savedPlaceIds':   [],
      'savedServiceIds': [],
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (budget      != null) data['budget']      = budget;
    if (travelStyle != null) data['travelStyle']  = travelStyle;
    if (nationality != null) data['nationality']  = nationality;
    if (photoUrl    != null) data['photoUrl']    = photoUrl;
    await _userDoc(uid).set(data, SetOptions(merge: true));
  }

  Future<Map<String, dynamic>?> loadUserProfile(String uid) async {
    final doc = await _userDoc(uid).get();
    return doc.exists ? doc.data() as Map<String, dynamic>? : null;
  }

  Future<void> updateProfile({
    required String uid,
    String? name,
    List<String>? interests,
    String? budget,
    String? travelStyle,
    String? nationality,
    String? photoUrl,
  }) async {
    final data = <String, dynamic>{'updatedAt': FieldValue.serverTimestamp()};
    if (name        != null) data['name']        = name;
    if (interests   != null) data['interests']   = interests;
    if (budget      != null) data['budget']      = budget;
    if (travelStyle != null) data['travelStyle'] = travelStyle;
    if (nationality != null) data['nationality'] = nationality;
    if (photoUrl    != null) data['photoUrl']    = photoUrl;
    await _userDoc(uid).update(data);
  }

  CollectionReference get _msgsCol => _db.collection('messages');

  Future<void> sendMessage({
    required String senderId,
    required String senderName,
    required String senderRole,  
    required String topic,
    required String body,
  }) =>
      _msgsCol.add({
        'senderId':   senderId,
        'senderName': senderName,
        'senderRole': senderRole,
        'topic':      topic,
        'body':       body,
        'reply':      null,
        'replyAt':    null,
        'adminRead':  false,  
        'userRead':   true,   
        'createdAt':  FieldValue.serverTimestamp(),
      });

  Future<void> replyToMessage(String msgId, String reply) =>
      _msgsCol.doc(msgId).update({
        'reply':     reply,
        'replyAt':   FieldValue.serverTimestamp(),
        'userRead':  false,   // user hasn't seen the reply yet
        'adminRead': true,
      });

  Future<void> markMessageAdminRead(String msgId) =>
      _msgsCol.doc(msgId).update({'adminRead': true});

  Future<void> markMessageUserRead(String msgId) =>
      _msgsCol.doc(msgId).update({'userRead': true});

  
  Stream<QuerySnapshot> allMessagesStream() =>
      _msgsCol.orderBy('createdAt', descending: true).snapshots();

 
  Stream<QuerySnapshot> unreadMessagesStream() =>
      _msgsCol.where('adminRead', isEqualTo: false).snapshots();

 
  Stream<QuerySnapshot> userMessagesStream(String userId) =>
      _msgsCol
          .where('senderId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .snapshots();

  Stream<QuerySnapshot> unreadRepliesStream(String userId) =>
      _msgsCol
          .where('senderId', isEqualTo: userId)
          .where('userRead', isEqualTo: false)
          .where('reply', isNull: false)
          .snapshots();

  Future<void> savePlace(String uid, String placeId) async {
    await _userDoc(uid).update({
      'savedPlaceIds': FieldValue.arrayUnion([placeId]),
    });
  }

  Future<void> unsavePlace(String uid, String placeId) async {
    await _userDoc(uid).update({
      'savedPlaceIds': FieldValue.arrayRemove([placeId]),
    });
  }

  Future<List<String>> getSavedPlaceIds(String uid) async {
    final doc = await _userDoc(uid).get();
    if (!doc.exists) return [];
    final data = doc.data() as Map<String, dynamic>;
    return List<String>.from(data['savedPlaceIds'] ?? []);
  }

  Future<void> saveService(String uid, String serviceId) async {
    await _userDoc(uid).update({
      'savedServiceIds': FieldValue.arrayUnion([serviceId]),
    });
  }

  Future<void> unsaveService(String uid, String serviceId) async {
    await _userDoc(uid).update({
      'savedServiceIds': FieldValue.arrayRemove([serviceId]),
    });
  }

  Future<List<String>> getSavedServiceIds(String uid) async {
    final doc = await _userDoc(uid).get();
    if (!doc.exists) return [];
    final data = doc.data() as Map<String, dynamic>;
    return List<String>.from(data['savedServiceIds'] ?? []);
  }

  CollectionReference _itinCol(String uid) =>
      _userDoc(uid).collection('savedItineraries');

  Future<void> saveAiItinerary({
    required String uid,
    required String title,
    required String category,
    required String budget,
    required int days,
    required Map<String, List<ai.Place>> itinerary,
  }) async {
    final stops = <Map<String, dynamic>>[];
    itinerary.forEach((day, places) {
      for (final p in places) {
        stops.add({
          'day':             day,
          'placeId':         p.placeId,
          'name':            p.name,
          'imageUrl':        p.imageUrl,
          'durationMinutes': p.durationMinutes,
          'category':        p.category ?? '',
          'costLevel':       p.costLevel ?? '',
          'reasonWhy':       p.reasonWhy ?? '',
          'rating':          p.rating ?? 0.0,
          'latitude':        p.latitude ?? 0.0,
          'longitude':       p.longitude ?? 0.0,
        });
      }
    });

    await _itinCol(uid).add({
      'title':     title,
      'category':  category,
      'budget':    budget,
      'days':      days,
      'stops':     stops,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot> itineraryStream(String uid) =>
      _itinCol(uid).orderBy('createdAt', descending: true).snapshots();

  Future<void> deleteItinerary(String uid, String docId) =>
      _itinCol(uid).doc(docId).delete();

  
  Future<void> addReview({
    required String placeId,
    required String uid,
    required String userName,
    required double rating,
    required String comment,
  }) async {
    await _db.collection('reviews').add({
      'placeId':   placeId,
      'uid':       uid,
      'userName':  userName,
      'rating':    rating,
      'comment':   comment,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot> reviewsStream(String placeId) => _db
      .collection('reviews')
      .where('placeId', isEqualTo: placeId)
      .orderBy('createdAt', descending: true)
      .snapshots();

  CollectionReference get _placesCol => _db.collection('places');

  Stream<QuerySnapshot> allPlacesStream() => _placesCol.snapshots();

  Stream<QuerySnapshot> approvedPlacesStream() =>
      _placesCol.where('listingStatus', isEqualTo: 'approved').snapshots();

  Stream<QuerySnapshot> pendingPlacesStream() =>
      _placesCol.where('listingStatus', isEqualTo: 'pending').snapshots();

  Stream<QuerySnapshot> businessPlacesStream(String ownerId) =>
      _placesCol.where('ownerId', isEqualTo: ownerId).snapshots();

  Future<String> submitPlace(Map<String, dynamic> data) async {
    try {
      final doc = await _placesCol.add({
        ...data,
        'listingStatus': 'pending',
        'submittedAt': FieldValue.serverTimestamp(),
      });
      return doc.id;
    } catch (e) {
      throw Exception('Failed to submit place: $e\nCheck Firestore rules allow writes for your user role.');
    }
  }

  Future<void> approvePlace(String placeId) =>
      _placesCol.doc(placeId).update({'listingStatus': 'approved'});

  Future<void> rejectPlace(String placeId, {String? note}) =>
      _placesCol.doc(placeId).update({
        'listingStatus': 'dismissed',
        'adminDismissNote': note,
      });

  Future<void> submitPlaceEdit(String placeId, Map<String, dynamic> editData) =>
      _placesCol.doc(placeId).update({
        'pendingEdit': {...editData, 'status': 'pending',
          'submittedAt': FieldValue.serverTimestamp()},
      });

  Future<void> approvePlaceEdit(String placeId, Map<String, dynamic> editData) =>
      _placesCol.doc(placeId).update({
        ...editData,
        'pendingEdit': FieldValue.delete(),
      });

  Future<void> rejectPlaceEdit(String placeId) =>
      _placesCol.doc(placeId).update({'pendingEdit': FieldValue.delete()});

  Future<void> deletePlace(String id, {required String ownerUid}) async {
    final doc = await _placesCol.doc(id).get();
    if (!doc.exists) return; // Already gone — treat as success.
    final data = doc.data() as Map<String, dynamic>;
    if (data['ownerId'] != ownerUid) {
      throw Exception('Permission denied: you can only delete your own listings.');
    }
    await _placesCol.doc(id).delete();
  }

  /// Admin permanently removes any place without ownership check.
  Future<void> adminDeletePlace(String id) => _placesCol.doc(id).delete();


  CollectionReference get _servicesCol => _db.collection('services');

  Stream<QuerySnapshot> allServicesStream() => _servicesCol.snapshots();

  Stream<QuerySnapshot> approvedServicesStream() =>
      _servicesCol.where('listingStatus', isEqualTo: 'approved').snapshots();

  Stream<QuerySnapshot> pendingServicesStream() =>
      _servicesCol.where('listingStatus', isEqualTo: 'pending').snapshots();

  Stream<QuerySnapshot> businessServicesStream(String ownerId) =>
      _servicesCol.where('ownerId', isEqualTo: ownerId).snapshots();

  Future<String> submitService(Map<String, dynamic> data) async {
    try {
      final doc = await _servicesCol.add({
        ...data,
        'listingStatus': 'pending',
        'submittedAt': FieldValue.serverTimestamp(),
      });
      return doc.id;
    } catch (e) {
      throw Exception('Failed to submit service: $e\nCheck Firestore rules allow writes for your user role.');
    }
  }

  Future<void> approveService(String serviceId) =>
      _servicesCol.doc(serviceId).update({'listingStatus': 'approved'});

  Future<void> rejectService(String serviceId, {String? note}) =>
      _servicesCol.doc(serviceId).update({
        'listingStatus': 'dismissed',
        'adminDismissNote': note,
      });

  Future<void> submitServiceEdit(String serviceId, Map<String, dynamic> editData) =>
      _servicesCol.doc(serviceId).update({
        'pendingEdit': {...editData, 'status': 'pending',
          'submittedAt': FieldValue.serverTimestamp()},
      });

  Future<void> approveServiceEdit(String serviceId, Map<String, dynamic> editData) =>
      _servicesCol.doc(serviceId).update({
        ...editData,
        'pendingEdit': FieldValue.delete(),
      });

  Future<void> rejectServiceEdit(String serviceId) =>
      _servicesCol.doc(serviceId).update({'pendingEdit': FieldValue.delete()});

  
  Future<void> deleteService(String id, {required String ownerUid}) async {
    final doc = await _servicesCol.doc(id).get();
    if (!doc.exists) return;
    final data = doc.data() as Map<String, dynamic>;
    if (data['ownerId'] != ownerUid) {
      throw Exception('Permission denied: you can only delete your own listings.');
    }
    await _servicesCol.doc(id).delete();
  }

  
  Future<void> adminDeleteService(String id) => _servicesCol.doc(id).delete();

  CollectionReference get _regsCol => _db.collection('businessRegistrations');

  Stream<QuerySnapshot> allRegistrationsStream() => _regsCol
      .orderBy('submittedAt', descending: true)
      .snapshots();

  Stream<QuerySnapshot> pendingRegistrationsStream() =>
      _regsCol.where('status', isEqualTo: 'pending').snapshots();

  Stream<QuerySnapshot> registrationForOwnerStream(String ownerUid) =>
      _regsCol.where('ownerUid', isEqualTo: ownerUid)
          .orderBy('submittedAt', descending: true)
          .limit(1)
          .snapshots();

  Future<void> submitRegistration(Map<String, dynamic> data) =>
      _regsCol.add({...data, 'status': 'pending',
        'submittedAt': FieldValue.serverTimestamp()});

  Future<void> approveRegistration(String regId, String ownerUid) async {
    await _regsCol.doc(regId).update({'status': 'approved'});
    await _userDoc(ownerUid).update({'role': 'localBusiness'});
  }

  Future<void> dismissRegistration(String regId, {String? note}) =>
      _regsCol.doc(regId).update({'status': 'dismissed', 'adminNote': note});

  CollectionReference get _notifsCol => _db.collection('notifications');

  Stream<QuerySnapshot> notificationsStream(String ownerUid) =>
      _notifsCol.where('ownerUid', isEqualTo: ownerUid)
          .orderBy('createdAt', descending: true)
          .snapshots();

  Future<void> sendNotification({
    required String ownerUid,
    required String type,
    required String listingName,
    required bool isPlace,
    String? adminNote,
  }) =>
      _notifsCol.add({
        'ownerUid':    ownerUid,
        'type':        type,
        'listingName': listingName,
        'isPlace':     isPlace,
        'adminNote':   adminNote,
        'read':        false,
        'createdAt':   FieldValue.serverTimestamp(),
      });

  Future<void> markNotificationRead(String notifId) =>
      _notifsCol.doc(notifId).update({'read': true});

  Future<void> deleteNotification(String notifId) =>
      _notifsCol.doc(notifId).delete();

  
  Stream<QuerySnapshot> allUsersStream() => _db.collection('users').snapshots();

  
  static Place placeFromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return Place(
      id:          doc.id,
      name:        d['name']        ?? '',
      description: d['description'] ?? '',
      category:    _placeCategory(d['category'] ?? 'attraction'),
      lat:         (d['lat']    ?? 0.0).toDouble(),
      lng:         (d['lng']    ?? 0.0).toDouble(),
      rating:      (d['rating'] ?? 0.0).toDouble(),
      reviewCount: (d['reviewCount'] ?? 0) as int,
      imageEmoji:  d['imageEmoji']  ?? '📍',
      location:    d['location']    ?? '',
      phone:       d['phone'],
      hours:       d['hours'],
      pricePerNight: d['pricePerNight'] != null
          ? (d['pricePerNight'] as num).toDouble() : null,
      cuisine:     d['cuisine'],
      ownerId:     d['ownerId'],
      ownerName:   d['ownerName'],
      tags:        List<String>.from(d['tags'] ?? []),
      photoUrls:   List<String>.from(d['photoUrls'] ?? []),
      photoEmojis: List<String>.from(d['photoEmojis'] ?? []),
      listingStatus: _listingStatus(d['listingStatus'] ?? 'pending'),
      adminDismissNote: d['adminDismissNote'],
      pendingEdit: d['pendingEdit'] != null
          ? _pendingEditFromMap(d['pendingEdit'] as Map<String, dynamic>) : null,
    );
  }

  static TripService serviceFromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return TripService(
      id:          doc.id,
      name:        d['name']        ?? '',
      description: d['description'] ?? '',
      category:    _serviceCategory(d['category'] ?? 'other'),
      ownerId:     d['ownerId']     ?? '',
      ownerName:   d['ownerName']   ?? '',
      location:    d['location']    ?? '',
      imageEmoji:  d['imageEmoji']  ?? '🏷️',
      phone:       d['phone'],
      hours:       d['hours'],
      priceFrom:   d['priceFrom'] != null ? (d['priceFrom'] as num).toDouble() : null,
      priceUnit:   d['priceUnit'],
      whatsapp:    d['whatsapp'],
      website:     d['website'],
      lat:         d['lat'] != null ? (d['lat'] as num).toDouble() : null,
      lng:         d['lng'] != null ? (d['lng'] as num).toDouble() : null,
      tags:        List<String>.from(d['tags'] ?? []),
      photoUrls:   List<String>.from(d['photoUrls'] ?? []),
      listingStatus: _listingStatus(d['listingStatus'] ?? 'pending'),
      adminDismissNote: d['adminDismissNote'],
      rating:      (d['rating']      ?? 0.0).toDouble(),
      reviewCount: (d['reviewCount'] ?? 0) as int,
    );
  }

  static UserModel userFromDoc(DocumentSnapshot doc) {
  final d = doc.data() as Map<String, dynamic>;
  return UserModel(
    id:       doc.id,
    name:     d['name']  ?? '',
    email:    d['email'] ?? '',
    photoUrl: d['photoUrl'],                                   
    role:     _userRole(d['role'] ?? 'tourist'),
    interests: List<String>.from(d['interests'] ?? []),
    savedIds:  List<String>.from(d['savedPlaceIds'] ?? []),    
    budget:      d['budget'],                                  
    travelStyle: d['travelStyle'],                             
    nationality: d['nationality'],                             
  );
}

  static BusinessRegistration registrationFromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    BusinessStatus st;
    switch (d['status']) {
      case 'approved':  st = BusinessStatus.approved; break;
      case 'dismissed': st = BusinessStatus.dismissed; break;
      default:          st = BusinessStatus.pending;
    }
    return BusinessRegistration(
      id:           doc.id,
      ownerId:      d['ownerUid']     ?? '',
      ownerName:    d['ownerName']    ?? '',
      ownerEmail:   d['ownerEmail']   ?? '',
      businessName: d['businessName'] ?? '',
      businessType: d['businessType'] ?? '',
      description:  d['description']  ?? '',
      location:     d['location']     ?? '',
      phone:        d['phone'],
      website:      d['website'],
      whatsapp:     d['whatsapp'],
      tags:         List<String>.from(d['tags'] ?? []),
      status:       st,
      adminNote:    d['adminNote'],
      submittedAt:  (d['submittedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  static PlaceCategory _placeCategory(String s) {
    switch (s) {
      case 'hotel':      return PlaceCategory.hotel;
      case 'restaurant': return PlaceCategory.restaurant;
      case 'event':      return PlaceCategory.event;
      default:           return PlaceCategory.attraction;
    }
  }

  static ListingStatus _listingStatus(String s) {
    switch (s) {
      case 'approved':  return ListingStatus.approved;
      case 'dismissed': return ListingStatus.dismissed;
      default:          return ListingStatus.pending;
    }
  }

  static UserRole _userRole(String s) {
    switch (s) {
      case 'admin':         return UserRole.admin;
      case 'localBusiness': return UserRole.localBusiness;
      default:              return UserRole.tourist;
    }
  }

  static ServiceCategory _serviceCategory(String s) {
    switch (s) {
      case 'equipment':     return ServiceCategory.equipment;
      case 'guide':         return ServiceCategory.guide;
      case 'transport':     return ServiceCategory.transport;
      case 'experience':    return ServiceCategory.experience;
      case 'wellness':      return ServiceCategory.wellness;
      case 'photography':   return ServiceCategory.photography;
      case 'food':          return ServiceCategory.food;
      case 'accommodation': return ServiceCategory.accommodation;
      case 'retail':        return ServiceCategory.retail;
      default:              return ServiceCategory.other;
    }
  }

  static PendingEdit _pendingEditFromMap(Map<String, dynamic> m) => PendingEdit(
    name:        m['name']        ?? '',
    description: m['description'] ?? '',
    location:    m['location']    ?? '',
    phone:       m['phone'],
    hours:       m['hours'],
    pricePerNight: m['pricePerNight'] != null ? (m['pricePerNight'] as num).toDouble() : null,
    cuisine:     m['cuisine'],
    tags:        List<String>.from(m['tags'] ?? []),
    photoUrls:   List<String>.from(m['photoUrls'] ?? []),
    lat:         m['lat'] != null ? (m['lat'] as num).toDouble() : null,
    lng:         m['lng'] != null ? (m['lng'] as num).toDouble() : null,
    status:      m['status'] == 'approved' ? EditStatus.approved : EditStatus.pending,
    submittedAt: DateTime.now(),
  );
}