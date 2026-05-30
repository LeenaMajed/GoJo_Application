import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/models.dart';
import '../data/mock_data.dart';
import 'firebase_service.dart';


class AppState extends ChangeNotifier {
  final _fb = FirebaseService();

  ThemeMode _themeMode = ThemeMode.light;
  ThemeMode get themeMode => _themeMode;
  bool get isDark => _themeMode == ThemeMode.dark;
  void toggleTheme() {
    _themeMode = _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
  }

  
  UserModel? _user;
  UserModel? get user  => _user;
  bool get isLoggedIn  => _user != null;
  UserRole get role    => _user?.role ?? UserRole.tourist;
  bool _authLoading    = false;
  bool get authLoading => _authLoading;
  String? _authError;
  String? get authError => _authError;

  AppState() {
    _fb.authStateChanges.listen((fu) async {
      if (fu == null) {
        _user = null;
        _savedPlaceIds.clear();
        _savedServiceIds.clear();
        notifyListeners();
      } else {
        await _loadProfile(fu);
      }
    });
  }

  Future<void> _loadProfile(User fu) async {
    try {
      final d = await _fb.loadUserProfile(fu.uid);
      if (d != null) {
        _user = UserModel(
  id: fu.uid,
  name: d['name'] ?? fu.email!.split('@').first,
  email: fu.email ?? '',
  role: _rol(d['role'] ?? 'tourist'),
  interests: List<String>.from(d['interests'] ?? []),
  budget: d['budget'] as String?,
  travelStyle: d['travelStyle'] as String?,
  nationality: d['nationality'] as String?,
  photoUrl: d['photoUrl'] as String?,   
);
        _savedPlaceIds   = Set<String>.from(d['savedPlaceIds']   ?? []);
        _savedServiceIds = Set<String>.from(d['savedServiceIds'] ?? []);
      } else {
        _user = UserModel(
          id: fu.uid, name: fu.email!.split('@').first,
          email: fu.email ?? '', role: UserRole.tourist,
        );
        await _fb.saveUserProfile(
          uid: fu.uid, name: _user!.name,
          email: _user!.email, role: 'tourist',
        );
      }
    } catch (_) {}
    notifyListeners();
  }

  UserRole _rol(String s) {
    switch (s) {
      case 'admin':         return UserRole.admin;
      case 'localBusiness': return UserRole.localBusiness;
      default:              return UserRole.tourist;
    }
  }

  String _rolStr(UserRole r) {
    switch (r) {
      case UserRole.admin:         return 'admin';
      case UserRole.localBusiness: return 'localBusiness';
      default:                     return 'tourist';
    }
  }

  Future<bool> signIn(String email, String password) async {
    _authError = null; _authLoading = true; notifyListeners();
    try {
      final cred = await _fb.signIn(email, password);
      if (cred?.user == null) {
        _authError = 'Sign in failed.';
        _authLoading = false; notifyListeners(); return false;
      }
      await _loadProfile(cred!.user!);
      _authLoading = false; notifyListeners(); return true;
    } on FirebaseAuthException catch (ex) {
      _authError = _ferr(ex.code); _authLoading = false; notifyListeners(); return false;
    }
  }

  Future<bool> signUp(String name, String email, String password,
      UserRole sel, {
        List<String> interests = const [],
        String? budget,
        String? travelStyle,
        String? nationality,
      }) async {
    _authError = null; _authLoading = true; notifyListeners();
    try {
      final cr = await _fb.signUp(email, password);
      if (cr?.user == null) { _authLoading = false; notifyListeners(); return false; }
      await _fb.saveUserProfile(
          uid: cr!.user!.uid, name: name.trim(),
          email: email.trim(), role: _rolStr(sel), interests: interests,
          budget: budget, travelStyle: travelStyle, nationality: nationality);
      _authLoading = false; notifyListeners(); return true;
    } on FirebaseAuthException catch (ex) {
      _authError = _ferr(ex.code); _authLoading = false; notifyListeners(); return false;
    }
  }

  Future<void> signOut() async {
    await _fb.signOut();
  }

  Future<void> updateProfile({
  String? name,
  List<String>? interests,
  String? budget,
  String? travelStyle,
  String? nationality,
  String? photoUrl,         
}) async {
  if (_user == null) return;
  _user = _user!.copyWith(
    name: name, interests: interests,
    budget: budget, travelStyle: travelStyle, nationality: nationality,
    photoUrl: photoUrl,      
  );
  notifyListeners();
  final uid = _fb.uid;
  if (uid != null) await _fb.updateProfile(
    uid: uid, name: name, interests: interests,
    budget: budget, travelStyle: travelStyle, nationality: nationality,
    photoUrl: photoUrl,      
  );
}

  String _ferr(String c) {
    switch (c) {
      case 'user-not-found':       return 'No account found with this email.';
      case 'wrong-password':       return 'Incorrect password.';
      case 'email-already-in-use': return 'This email is already registered.';
      case 'weak-password':        return 'Password must be at least 6 characters.';
      case 'invalid-email':        return 'Please enter a valid email address.';
      default:                     return 'Authentication failed. Please try again.';
    }
  }

  Stream<QuerySnapshot> get allPlacesStream => _fb.allPlacesStream();

  Stream<QuerySnapshot> get allServicesStream => _fb.allServicesStream();

  
  Stream<QuerySnapshot> get approvedPlacesStream => _fb.approvedPlacesStream();


  Stream<QuerySnapshot> get approvedServicesStream => _fb.approvedServicesStream();


  Stream<QuerySnapshot> get pendingPlacesStream => _fb.pendingPlacesStream();


  Stream<QuerySnapshot> get pendingServicesStream => _fb.pendingServicesStream();

  Stream<QuerySnapshot> get allRegistrationsStream => _fb.allRegistrationsStream();

  Stream<QuerySnapshot> get pendingRegistrationsStream => _fb.pendingRegistrationsStream();

  
  Stream<QuerySnapshot> businessPlacesStream(String ownerId) =>
      _fb.businessPlacesStream(ownerId);

  Stream<QuerySnapshot> businessServicesStream(String ownerId) =>
      _fb.businessServicesStream(ownerId);


  Stream<QuerySnapshot> get allUsersStream => _fb.allUsersStream();

  Stream<QuerySnapshot>? notificationsStream(String ownerUid) =>
      _fb.notificationsStream(ownerUid);


  Stream<QuerySnapshot>? get itineraryStream {
    final uid = _fb.uid;
    return uid != null ? _fb.itineraryStream(uid) : null;
  }

  Future<void> submitPlace(Map<String, dynamic> data) {
    final uid = _fb.uid ?? _user?.id;
    return _fb.submitPlace({...data, if (uid != null) 'ownerId': uid});
  }

  Future<void> submitPlaceEdit(String id, Map<String, dynamic> data) =>
      _fb.submitPlaceEdit(id, data);

  Future<void> approvePlace(String id, {String? ownerUid, String? name}) async {
    await _fb.approvePlace(id);
    if (ownerUid != null && name != null)
      await _fb.sendNotification(ownerUid: ownerUid,
          type: 'approved', listingName: name, isPlace: true);
  }

  Future<void> rejectPlace(String id,
      {String? note, String? ownerUid, String? name}) async {
    await _fb.rejectPlace(id, note: note);
    if (ownerUid != null && name != null)
      await _fb.sendNotification(ownerUid: ownerUid,
          type: 'dismissed', listingName: name, isPlace: true, adminNote: note);
  }

  Future<void> approvePlaceEdit(String id, Map<String, dynamic> edit,
      {String? ownerUid, String? name}) async {
    await _fb.approvePlaceEdit(id, edit);
    if (ownerUid != null && name != null)
      await _fb.sendNotification(ownerUid: ownerUid,
          type: 'editApproved', listingName: name, isPlace: true);
  }

  Future<void> rejectPlaceEdit(String id,
      {String? ownerUid, String? name, String? note}) async {
    await _fb.rejectPlaceEdit(id);
    if (ownerUid != null && name != null)
      await _fb.sendNotification(ownerUid: ownerUid,
          type: 'editRejected', listingName: name, isPlace: true, adminNote: note);
  }

  

  Future<void> submitService(Map<String, dynamic> data) {
    final uid = _fb.uid ?? _user?.id;
    return _fb.submitService({...data, if (uid != null) 'ownerId': uid});
  }

  Future<void> submitServiceEdit(String id, Map<String, dynamic> data) =>
      _fb.submitServiceEdit(id, data);

  Future<void> approveService(String id, {String? ownerUid, String? name}) async {
    await _fb.approveService(id);
    if (ownerUid != null && name != null)
      await _fb.sendNotification(ownerUid: ownerUid,
          type: 'approved', listingName: name, isPlace: false);
  }

  Future<void> rejectService(String id,
      {String? note, String? ownerUid, String? name}) async {
    await _fb.rejectService(id, note: note);
    if (ownerUid != null && name != null)
      await _fb.sendNotification(ownerUid: ownerUid,
          type: 'dismissed', listingName: name, isPlace: false, adminNote: note);
  }

  Future<void> approveServiceEdit(String id, Map<String, dynamic> edit,
      {String? ownerUid, String? name}) async {
    await _fb.approveServiceEdit(id, edit);
    if (ownerUid != null && name != null)
      await _fb.sendNotification(ownerUid: ownerUid,
          type: 'editApproved', listingName: name, isPlace: false);
  }

  Future<void> rejectServiceEdit(String id,
      {String? ownerUid, String? name, String? note}) async {
    await _fb.rejectServiceEdit(id);
    if (ownerUid != null && name != null)
      await _fb.sendNotification(ownerUid: ownerUid,
          type: 'editRejected', listingName: name, isPlace: false, adminNote: note);
  }

  Future<void> deleteListing(String id,
      {required bool isPlace, String? ownerUid, String? name}) async {
    final uid = ownerUid ?? _fb.uid ?? _user?.id;
    if (uid == null) throw Exception('Not authenticated.');
    if (isPlace) {
      await _fb.deletePlace(id, ownerUid: uid);
    } else {
      await _fb.deleteService(id, ownerUid: uid);
    }
  }

  Future<void> adminDeleteListing(String id,
      {required bool isPlace, String? ownerUid, String? name}) async {
    if (isPlace) {
      await _fb.adminDeletePlace(id);
    } else {
      await _fb.adminDeleteService(id);
    }
    if (ownerUid != null && name != null) {
      try {
        await _fb.sendNotification(ownerUid: ownerUid,
            type: 'dismissed', listingName: name, isPlace: isPlace,
            adminNote: 'Your listing has been permanently removed by admin.');
      } catch (_) {}
    }
  }

  Future<void> sendMessage({required String topic, required String body}) {
    final u = _user;
    if (u == null) throw Exception('Not logged in');
    return _fb.sendMessage(
      senderId:   u.id,
      senderName: u.name,
      senderRole: u.role == UserRole.localBusiness ? 'localBusiness' : 'tourist',
      topic:      topic,
      body:       body,
    );
  }

  Future<void> replyToMessage(String msgId, String reply) =>
      _fb.replyToMessage(msgId, reply);

  Future<void> markMessageAdminRead(String msgId) =>
      _fb.markMessageAdminRead(msgId);

  Future<void> markMessageUserRead(String msgId) =>
      _fb.markMessageUserRead(msgId);

  Stream<QuerySnapshot> get allMessagesStream => _fb.allMessagesStream();
  Stream<QuerySnapshot> get unreadMessagesStream => _fb.unreadMessagesStream();

  Stream<QuerySnapshot>? userMessagesStream() {
    final uid = _fb.uid;
    return uid != null ? _fb.userMessagesStream(uid) : null;
  }

  Stream<QuerySnapshot>? unreadRepliesStream() {
    final uid = _fb.uid;
    return uid != null ? _fb.unreadRepliesStream(uid) : null;
  }
  
  Future<void> submitBusinessRegistration(Map<String, dynamic> data) =>
      _fb.submitRegistration({
        ...data,
        'ownerUid':   _user?.id    ?? '',
        'ownerName':  _user?.name  ?? '',
        'ownerEmail': _user?.email ?? '',
      });

  Future<void> submitRegistrationObject(BusinessRegistration reg) =>
      _fb.submitRegistration({
        'ownerUid':     reg.ownerId,
        'ownerName':    reg.ownerName,
        'ownerEmail':   reg.ownerEmail,
        'businessName': reg.businessName,
        'businessType': reg.businessType,
        'description':  reg.description,
        'location':     reg.location,
        'phone':        reg.phone,
        'website':      reg.website,
        'whatsapp':     reg.whatsapp,
        'tags':         reg.tags,
      });

  void submitBusinessRegistrationObj(BusinessRegistration reg) {
    submitRegistrationObject(reg);
  }

  Future<void> approveRegistration(String regId, String ownerUid) =>
      _fb.approveRegistration(regId, ownerUid);

  Future<void> dismissRegistration(String regId, {String? note}) =>
      _fb.dismissRegistration(regId, note: note);

  Future<void> deleteNotification(String id) => _fb.deleteNotification(id);
  Future<void> markNotificationRead(String id) => _fb.markNotificationRead(id);

  void dismissNotification(String id) => _fb.deleteNotification(id);

  Set<String> _savedPlaceIds   = {};
  Set<String> _savedServiceIds = {};

  bool isSaved(String id)        => _savedPlaceIds.contains(id);
  bool isServiceSaved(String id) => _savedServiceIds.contains(id);

  void toggleSave(String id) {
    final uid = _fb.uid;
    if (_savedPlaceIds.contains(id)) {
      _savedPlaceIds.remove(id);
      if (uid != null) _fb.unsavePlace(uid, id);
    } else {
      _savedPlaceIds.add(id);
      if (uid != null) _fb.savePlace(uid, id);
    }
    notifyListeners();
  }

  void toggleServiceSave(String id) {
    final uid = _fb.uid;
    if (_savedServiceIds.contains(id)) {
      _savedServiceIds.remove(id);
      if (uid != null) _fb.unsaveService(uid, id);
    } else {
      _savedServiceIds.add(id);
      if (uid != null) _fb.saveService(uid, id);
    }
    notifyListeners();
  }

  Future<void> deleteItinerary(String uid, String docId) =>
      _fb.deleteItinerary(uid, docId);

  // Legacy in-memory list (kept for savedItineraries getter)
  final List<Itinerary> _savedItineraries = [];
  List<Itinerary> get savedItineraries => List.unmodifiable(_savedItineraries);
  void saveLegacyItinerary(Itinerary it) {
    _savedItineraries.removeWhere((i) => i.id == it.id);
    _savedItineraries.add(it); notifyListeners();
  }
  void deleteLegacyItinerary(String id) {
    _savedItineraries.removeWhere((i) => i.id == id); notifyListeners();
  }

  final List<Review> _reviews = List<Review>.from(kSampleReviews);
  List<Review> reviewsFor(String placeId) =>
      _reviews.where((r) => r.placeId == placeId).toList()
        ..sort((a, b) => b.date.compareTo(a.date));
  void addReview(Review r) { _reviews.add(r); notifyListeners(); }

  Future<void> removeUser(String userId) =>
      FirebaseFirestore.instance.collection('users').doc(userId).delete();

  final Map<String, int> _searchCounts  = {};
  final Map<String, int> _categoryViews = {};
  int _totalSearches = 0;

  void recordSearch(String q) {
    final k = q.toLowerCase().trim();
    _searchCounts[k] = (_searchCounts[k] ?? 0) + 1;
    _totalSearches++; notifyListeners();
  }

  void recordBehavior(BehaviorEvent event, {String? tag}) {
    if (event == BehaviorEvent.viewedPlace && tag != null)
      _categoryViews[tag] = (_categoryViews[tag] ?? 0) + 1;
    notifyListeners();
  }

  List<BehaviorTip> getBehaviorTips() {
    final tips = <BehaviorTip>[];
    final interests = _user?.interests ?? [];
    if (_totalSearches == 0 && _categoryViews.isEmpty) {
      if (interests.isNotEmpty) tips.add(BehaviorTip(
        title: 'Based on your interests',
        body: 'You love ${interests.take(2).join(' and ')}. Search to find hidden gems.',
        icon: Icons.favorite_rounded));
      tips.add(BehaviorTip(
        title: 'Tip: Use advanced filters',
        body: 'Tap the tune icon to sort by rating, filter by price and tags.',
        icon: Icons.tune_rounded));
      return tips;
    }
    if (_searchCounts.isNotEmpty) {
      final top = (_searchCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value))).first;
      tips.add(BehaviorTip(
        title: 'Your top search: "${top.key}"',
        body: 'Searched ${top.value} time${top.value > 1 ? "s" : ""}.',
        icon: Icons.search_rounded));
    }
    return tips.take(3).toList();
  }
  
}
