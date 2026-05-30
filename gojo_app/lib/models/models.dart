import 'package:flutter/material.dart' show IconData, VoidCallback;
// User Role 
enum UserRole { tourist, localBusiness, admin }
enum BusinessStatus { pending, approved, dismissed }
enum EditStatus { pending, approved, rejected }
enum ListingStatus { pending, approved, dismissed }  
enum ListingType { place, service }
enum ServiceCategory {
  equipment, guide, transport, experience, wellness,
  photography, food, accommodation, retail, other,
}

class BusinessRegistration {
  final String id, ownerId, ownerName, ownerEmail, businessName, businessType, description, location;
  final String? phone, website, whatsapp;
  final List<String> tags, photoEmojis;
  BusinessStatus status;
  final DateTime submittedAt;
  String? adminNote;

  BusinessRegistration({
    required this.id, required this.ownerId, required this.ownerName,
    required this.ownerEmail, required this.businessName, required this.businessType,
    required this.description, required this.location,
    this.phone, this.website, this.whatsapp,
    this.tags = const [], this.photoEmojis = const [],
    this.status = BusinessStatus.pending, required this.submittedAt, this.adminNote,
  });
}

class UserModel {
  String id, name, email;
  String? photoUrl;
  List<String> interests, savedIds, savedItineraryIds;
  UserRole role;
  
  String? budget;        
  String? travelStyle;   
  String? nationality;

  UserModel({
    required this.id, required this.name, required this.email,
    this.photoUrl, this.interests = const [], this.savedIds = const [],
    this.savedItineraryIds = const [], this.role = UserRole.tourist,
    this.budget, this.travelStyle, this.nationality,
  });

  UserModel copyWith({
    String? name, String? email, String? photoUrl,
    List<String>? interests, List<String>? savedIds,
    List<String>? savedItineraryIds, UserRole? role,
    String? budget, String? travelStyle, String? nationality,
  }) => UserModel(
    id: id, name: name ?? this.name, email: email ?? this.email,
    photoUrl: photoUrl ?? this.photoUrl,
    interests: interests ?? this.interests,
    savedIds: savedIds ?? this.savedIds,
    savedItineraryIds: savedItineraryIds ?? this.savedItineraryIds,
    role: role ?? this.role,
    budget: budget ?? this.budget,
    travelStyle: travelStyle ?? this.travelStyle,
    nationality: nationality ?? this.nationality,
  );
}

enum PlaceCategory { attraction, hotel, restaurant, event }

class PendingEdit {
  final String name, description, location;
  final String? phone, hours, cuisine;
  final double? pricePerNight, lat, lng;
  final List<String> tags, photoEmojis, photoUrls;
  final EditStatus status;
  final DateTime submittedAt;

  const PendingEdit({
    required this.name, required this.description, required this.location,
    this.phone, this.hours, this.pricePerNight, this.cuisine,
    this.tags = const [], this.photoEmojis = const [], this.photoUrls = const [],
    this.lat, this.lng, this.status = EditStatus.pending, required this.submittedAt,
  });

  PendingEdit copyWith({EditStatus? status}) => PendingEdit(
    name: name, description: description, location: location,
    phone: phone, hours: hours, pricePerNight: pricePerNight, cuisine: cuisine,
    tags: tags, photoEmojis: photoEmojis, photoUrls: photoUrls,
    lat: lat, lng: lng, status: status ?? this.status, submittedAt: submittedAt,
  );
}

class Place {
  final String id, name, description;
  final PlaceCategory category;
  final double lat, lng, rating;
  final int reviewCount;
  final String imageEmoji, location;
  final String? phone, hours, cuisine, eventDate, ownerId, ownerName;
  final double? pricePerNight;
  final List<String> tags, photoEmojis, photoUrls;
  final ListingStatus listingStatus; 
  final String? adminDismissNote;     
  final PendingEdit? pendingEdit;

  
  bool get isApproved => listingStatus == ListingStatus.approved;
  bool get isDismissed => listingStatus == ListingStatus.dismissed;

  const Place({
    required this.id, required this.name, required this.description,
    required this.category, required this.lat, required this.lng,
    required this.rating, required this.reviewCount,
    required this.imageEmoji, required this.location,
    this.phone, this.hours, this.pricePerNight, this.cuisine, this.eventDate,
    this.ownerId, this.ownerName,
    this.tags = const [], this.photoEmojis = const [], this.photoUrls = const [],
    this.listingStatus = ListingStatus.approved,
    this.adminDismissNote,
    this.pendingEdit,
  });

  Place copyWith({
    ListingStatus? listingStatus, String? adminDismissNote,
    double? rating, int? reviewCount,
    List<String>? photoEmojis, List<String>? photoUrls,
    PendingEdit? pendingEdit, bool clearPendingEdit = false,
    String? name, String? description, String? location,
    String? phone, String? hours, double? pricePerNight,
    String? cuisine, List<String>? tags, double? lat, double? lng,
  }) => Place(
    id: id, name: name ?? this.name, description: description ?? this.description,
    category: category, lat: lat ?? this.lat, lng: lng ?? this.lng,
    rating: rating ?? this.rating, reviewCount: reviewCount ?? this.reviewCount,
    imageEmoji: imageEmoji, location: location ?? this.location,
    phone: phone ?? this.phone, hours: hours ?? this.hours,
    pricePerNight: pricePerNight ?? this.pricePerNight,
    cuisine: cuisine ?? this.cuisine, eventDate: eventDate,
    ownerId: ownerId, ownerName: ownerName,
    tags: tags ?? this.tags,
    photoEmojis: photoEmojis ?? this.photoEmojis,
    photoUrls: photoUrls ?? this.photoUrls,
    listingStatus: listingStatus ?? this.listingStatus,
    adminDismissNote: adminDismissNote ?? this.adminDismissNote,
    pendingEdit: clearPendingEdit ? null : (pendingEdit ?? this.pendingEdit),
  );
}

class PendingServiceEdit {
  final String name, description, location;
  final String? phone, hours, priceUnit, whatsapp, website;
  final double? priceFrom, lat, lng;
  final List<String> tags, photoEmojis, photoUrls;
  final EditStatus status;
  final DateTime submittedAt;

  const PendingServiceEdit({
    required this.name, required this.description, required this.location,
    this.phone, this.hours, this.priceFrom, this.priceUnit,
    this.tags = const [], this.photoEmojis = const [], this.photoUrls = const [],
    this.whatsapp, this.website, this.lat, this.lng,
    this.status = EditStatus.pending, required this.submittedAt,
  });

  PendingServiceEdit copyWith({EditStatus? status}) => PendingServiceEdit(
    name: name, description: description, location: location,
    phone: phone, hours: hours, priceFrom: priceFrom, priceUnit: priceUnit,
    tags: tags, photoEmojis: photoEmojis, photoUrls: photoUrls,
    whatsapp: whatsapp, website: website, lat: lat, lng: lng,
    status: status ?? this.status, submittedAt: submittedAt,
  );
}

class TripService {
  final String id, name, description;
  final ServiceCategory category;
  final String customCategory, ownerId, ownerName, location;
  final String? phone, hours, priceUnit, whatsapp, website;
  final double? priceFrom, lat, lng;
  final List<String> tags, photoEmojis, photoUrls;
  final String imageEmoji;
  final ListingStatus listingStatus;  
  final String? adminDismissNote;
  final double rating;
  final int reviewCount;
  final PendingServiceEdit? pendingEdit;

  bool get isApproved  => listingStatus == ListingStatus.approved;
  bool get isDismissed => listingStatus == ListingStatus.dismissed;

  const TripService({
    required this.id, required this.name, required this.description,
    required this.category, this.customCategory = '',
    required this.ownerId, required this.ownerName, required this.location,
    this.phone, this.hours, this.priceFrom, this.priceUnit,
    this.tags = const [], required this.imageEmoji,
    this.photoEmojis = const [], this.photoUrls = const [],
    this.listingStatus = ListingStatus.pending,
    this.adminDismissNote,
    this.rating = 0.0, this.reviewCount = 0,
    this.whatsapp, this.website, this.lat, this.lng, this.pendingEdit,
  });

  TripService copyWith({
    ListingStatus? listingStatus, String? adminDismissNote,
    PendingServiceEdit? pendingEdit, bool clearPendingEdit = false,
    String? name, String? description, String? location,
    String? phone, String? hours, double? priceFrom, String? priceUnit,
    List<String>? tags, List<String>? photoEmojis, List<String>? photoUrls,
    String? whatsapp, String? website, double? lat, double? lng,
  }) => TripService(
    id: id, name: name ?? this.name, description: description ?? this.description,
    category: category, customCategory: customCategory,
    ownerId: ownerId, ownerName: ownerName, location: location ?? this.location,
    phone: phone ?? this.phone, hours: hours ?? this.hours,
    priceFrom: priceFrom ?? this.priceFrom, priceUnit: priceUnit ?? this.priceUnit,
    tags: tags ?? this.tags, imageEmoji: imageEmoji,
    photoEmojis: photoEmojis ?? this.photoEmojis,
    photoUrls: photoUrls ?? this.photoUrls,
    listingStatus: listingStatus ?? this.listingStatus,
    adminDismissNote: adminDismissNote ?? this.adminDismissNote,
    rating: rating, reviewCount: reviewCount,
    whatsapp: whatsapp ?? this.whatsapp, website: website ?? this.website,
    lat: lat ?? this.lat, lng: lng ?? this.lng,
    pendingEdit: clearPendingEdit ? null : (pendingEdit ?? this.pendingEdit),
  );
}
 
class Review {
  final String id, userId, userName, placeId;
  final double rating;
  final String text;
  final DateTime date;
  Review({required this.id, required this.userId, required this.userName,
      required this.placeId, required this.rating, required this.text, required this.date});
}

class ItineraryDay {
  final int day;
  final List<ItineraryStop> stops;
  final List<String> recommendedServiceIds;
  const ItineraryDay({required this.day, required this.stops, this.recommendedServiceIds = const []});
}

class ItineraryStop {
  final String placeId, placeName, time, note, emoji;
  const ItineraryStop({required this.placeId, required this.placeName,
      required this.time, required this.note, required this.emoji});
}

class Itinerary {
  final String id, title;
  final int days;
  final List<String> interests;
  final List<ItineraryDay> schedule;
  final DateTime createdAt;
  Itinerary({required this.id, required this.title, required this.days,
      required this.interests, required this.schedule, required this.createdAt});
}

enum BizNotifType { approved, dismissed, editApproved, editRejected }

class BizNotification {
  final String id;
  final BizNotifType type;
  final String listingName;
  final bool isPlace;       
  final String? adminNote;
  final DateTime createdAt;
  bool dismissed;           

  BizNotification({
    required this.id, required this.type, required this.listingName,
    required this.isPlace, this.adminNote,
    required this.createdAt, this.dismissed = false,
  });
}

enum BehaviorEvent { openedSearch, viewedPlace, savedPlace, openedMap, generatedItinerary }

class BehaviorTip {
  final String title, body;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;
  const BehaviorTip({
    required this.title, required this.body, required this.icon,
    this.actionLabel, this.onAction,
  });
}