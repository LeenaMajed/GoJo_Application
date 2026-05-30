import '../models/models.dart';

extension StringCap on String {
  String get capitalize => isEmpty ? '' : '${this[0].toUpperCase()}${substring(1)}';
}


const _petra       = 'https://i0.wp.com/www.touristjordan.com/wp-content/uploads/2022/05/shutterstock_1030695895-scaled.jpg?resize=2000%2C800&ssl=1';
const _wadirum     = 'https://q-xx.bstatic.com/xdata/images/city/608x352/640005.webp?k=64d6aa7a536165ecd001b23f8140b9fa22b7e0625c0e819ef3828c789add8733&o=';
const _ammanCity   = 'https://www.jdtours.com/wp-content/w3-webp/uploads/2019/06/amman-abdali.jpgw3.webp';
const _deadSea     = 'https://images.unsplash.com/photo-1544551763-46a013bb70d5?w=800&q=80';
const _jerash      = 'https://images.unsplash.com/photo-1544552866-d3ed42536cfd?w=800&q=80';
const _aqaba       = 'https://images.unsplash.com/photo-1559128010-7c1ad6e1b6a5?w=800&q=80';
const _madaba      = 'https://images.unsplash.com/photo-1614531341773-3bff8b7cb3fc?w=800&q=80';
const _dana        = 'https://images.unsplash.com/photo-1547981609-4b6bfe67ca0b?w=800&q=80';
const _hotelLux    = 'https://images.unsplash.com/photo-1566073771259-6a8506099945?w=800&q=80';
const _hotelPetra  = 'https://images.unsplash.com/photo-1520250497591-112f2f40a3f4?w=800&q=80';
const _hotelBeach  = 'https://images.unsplash.com/photo-1571896349842-33c89424de2d?w=800&q=80';
const _restaurant1 = 'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?w=800&q=80';
const _restaurant2 = 'https://images.unsplash.com/photo-1414235077428-338989a2e8c0?w=800&q=80';
const _restaurant3 = 'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?w=800&q=80';
const _event1      = 'https://images.unsplash.com/photo-1516450360452-9312f5e86fc7?w=800&q=80';
const _event2      = 'https://images.unsplash.com/photo-1540575467063-178a50c2df87?w=800&q=80';

final List<Place> AllPlaces = [
  // ── Attractions ──────────────────────────────────────────────────────────
  const Place(
    id: 'a1', name: 'Petra Treasury',
    description: 'The iconic rose-red treasury carved into sandstone cliffs, one of the New Seven Wonders of the World. A UNESCO World Heritage Site and Jordan\'s most visited landmark.',
    category: PlaceCategory.attraction, lat: 30.328, lng: 35.444,
    rating: 4.9, reviewCount: 8420, imageEmoji: '🏛️',
    location: 'Petra, Ma\'an', hours: '6 AM – 6 PM',
    tags: ['history', 'heritage', 'UNESCO', 'photography'],
    photoUrls: [_petra],
  ),
  const Place(
    id: 'a2', name: 'Wadi Rum Desert',
    description: 'Vast red sand desert with dramatic sandstone mountains. A UNESCO World Heritage Site used as a film location for The Martian and Lawrence of Arabia.',
    category: PlaceCategory.attraction, lat: 29.575, lng: 35.420,
    rating: 4.8, reviewCount: 5310, imageEmoji: '🏜️',
    location: 'Aqaba Governorate', hours: 'All day',
    tags: ['nature', 'adventure', 'camping', 'hiking'],
    photoUrls: [_wadirum],
  ),
  const Place(
    id: 'a3', name: 'Amman Citadel',
    description: 'Ancient hilltop landmark featuring Roman, Byzantine, and Umayyad ruins with panoramic city views over Amman.',
    category: PlaceCategory.attraction, lat: 31.955, lng: 35.936,
    rating: 4.6, reviewCount: 3120, imageEmoji: '🏯',
    location: 'Amman', hours: '8 AM – 7 PM',
    tags: ['history', 'ruins', 'views', 'culture'],
    photoUrls: [_ammanCity],
  ),
  const Place(
    id: 'a4', name: 'Dead Sea',
    description: 'The lowest point on Earth at 430m below sea level. Float effortlessly in the ultra-salty waters and cover yourself in mineral-rich mud.',
    category: PlaceCategory.attraction, lat: 31.559, lng: 35.473,
    rating: 4.7, reviewCount: 4890, imageEmoji: '🌊',
    location: 'Dead Sea Road', hours: 'All day',
    tags: ['nature', 'wellness', 'unique', 'swimming'],
    photoUrls: [_deadSea],
  ),
  const Place(
    id: 'a5', name: 'Jerash Roman City',
    description: 'One of the best-preserved Roman cities in the world with colonnaded streets, temples, theatres, and plazas dating back 2,000 years.',
    category: PlaceCategory.attraction, lat: 32.275, lng: 35.896,
    rating: 4.7, reviewCount: 2980, imageEmoji: '🏟️',
    location: 'Jerash', hours: '7:30 AM – 6:30 PM',
    tags: ['roman', 'history', 'ruins', 'culture'],
    photoUrls: [_jerash],
  ),
  const Place(
    id: 'a6', name: 'Aqaba Coral Reefs',
    description: 'Stunning coral ecosystems in the Red Sea — home to hundreds of fish species. World-class snorkeling and diving just meters from the shore.',
    category: PlaceCategory.attraction, lat: 29.510, lng: 34.990,
    rating: 4.8, reviewCount: 1870, imageEmoji: '🐠',
    location: 'Aqaba', hours: 'All day',
    tags: ['diving', 'nature', 'marine', 'adventure'],
    photoUrls: [_aqaba],
  ),
  const Place(
    id: 'a7', name: 'Madaba Mosaic Map',
    description: 'A 6th-century Byzantine mosaic map of the Middle East — the oldest surviving cartographic depiction of the Holy Land, inside St. George\'s Church.',
    category: PlaceCategory.attraction, lat: 31.716, lng: 35.793,
    rating: 4.5, reviewCount: 1540, imageEmoji: '🗺️',
    location: 'Madaba', hours: '8 AM – 5 PM',
    tags: ['history', 'art', 'church', 'culture'],
    photoUrls: [_madaba],
  ),
  const Place(
    id: 'a8', name: 'Dana Biosphere Reserve',
    description: 'Jordan\'s largest nature reserve spanning 300 km². From sandstone cliffs to desert wadis, home to over 800 plant species and rare wildlife.',
    category: PlaceCategory.attraction, lat: 30.696, lng: 35.605,
    rating: 4.7, reviewCount: 987, imageEmoji: '🌿',
    location: 'Dana, Tafilah', hours: 'All day',
    tags: ['nature', 'hiking', 'wildlife', 'adventure'],
    photoUrls: [_dana],
  ),

  // ── Hotels ────────────────────────────────────────────────────────────────
  const Place(
    id: 'h1', name: 'Mövenpick Resort Petra',
    description: 'Luxury resort at the entrance of Petra with stunning canyon views, world-class spa, and direct access to the Siq archaeological site.',
    category: PlaceCategory.hotel, lat: 30.330, lng: 35.448,
    rating: 4.7, reviewCount: 2340, imageEmoji: '🏨',
    location: 'Petra', pricePerNight: 180, hours: '24/7',
    tags: ['luxury', 'historic', 'views', 'spa'],
    photoUrls: [_hotelPetra],
  ),
  const Place(
    id: 'h2', name: 'Four Seasons Amman',
    description: 'Iconic luxury hotel in the heart of Amman with panoramic city views, exceptional dining, and impeccable service on the prestigious 5th Circle.',
    category: PlaceCategory.hotel, lat: 31.958, lng: 35.882,
    rating: 4.9, reviewCount: 1890, imageEmoji: '⭐',
    location: 'Amman', pricePerNight: 320, hours: '24/7',
    tags: ['luxury', 'city', 'business', 'fine-dining'],
    photoUrls: [_hotelLux],
  ),
  const Place(
    id: 'h3', name: 'Kempinski Hotel Aqaba',
    description: 'Beachfront luxury resort on the Red Sea with private beach, water sports, exceptional diving center, and panoramic views of Saudi Arabia and Israel.',
    category: PlaceCategory.hotel, lat: 29.520, lng: 34.993,
    rating: 4.8, reviewCount: 1450, imageEmoji: '🏖️',
    location: 'Aqaba', pricePerNight: 220, hours: '24/7',
    tags: ['beach', 'luxury', 'diving', 'water-sports'],
    photoUrls: [_hotelBeach],
  ),
  const Place(
    id: 'h4', name: 'Wadi Rum Night Luxury Camp',
    description: 'Glamping under a sea of stars in the heart of Wadi Rum. Private tents with ensuite bathrooms, gourmet Bedouin meals, and guided jeep tours.',
    category: PlaceCategory.hotel, lat: 29.580, lng: 35.425,
    rating: 4.9, reviewCount: 876, imageEmoji: '🌌',
    location: 'Wadi Rum', pricePerNight: 150, hours: 'All day',
    tags: ['unique', 'glamping', 'desert', 'stars'],
    photoUrls: [_wadirum],
  ),

  //  Restaurants 
  const Place(
    id: 'r1', name: 'Sufra Restaurant',
    description: 'Award-winning traditional Jordanian cuisine in a beautifully restored Ottoman building. Famous for mansaf, maqluba, and mezze. Warm, hospitable atmosphere.',
    category: PlaceCategory.restaurant, lat: 31.957, lng: 35.930,
    rating: 4.6, reviewCount: 3210, imageEmoji: '🍽️',
    location: 'Lweibdeh, Amman', phone: '+962 6 461 1468',
    hours: '12 PM – 11 PM', cuisine: 'Jordanian',
    tags: ['food', 'traditional', 'culture', 'local'],
    photoUrls: [_restaurant1],
  ),
  const Place(
    id: 'r2', name: 'Cantaloupe Rooftop',
    description: 'Rooftop restaurant with breathtaking Red Sea views of Saudi Arabia and Israel. Upscale Mediterranean and international cuisine with excellent cocktails.',
    category: PlaceCategory.restaurant, lat: 29.534, lng: 35.004,
    rating: 4.7, reviewCount: 2100, imageEmoji: '🌅',
    location: 'Aqaba', phone: '+962 3 203 0400',
    hours: '11 AM – 12 AM', cuisine: 'Mediterranean',
    tags: ['food', 'views', 'nightlife', 'seafood'],
    photoUrls: [_restaurant2],
  ),
  const Place(
    id: 'r3', name: 'Fakhr El-Din',
    description: 'Amman\'s most celebrated fine-dining restaurant in a 1920s villa. Impeccable Lebanese-Jordanian cuisine, refined service, and an elegant garden setting.',
    category: PlaceCategory.restaurant, lat: 31.962, lng: 35.881,
    rating: 4.8, reviewCount: 1980, imageEmoji: '🏡',
    location: '2nd Circle, Amman', phone: '+962 6 465 2399',
    hours: '12:30 PM – 11:30 PM', cuisine: 'Lebanese-Jordanian',
    tags: ['fine-dining', 'luxury', 'local', 'culture'],
    photoUrls: [_restaurant3],
  ),

  //  Events 
  const Place(
    id: 'ev1', name: 'Jerash Festival 2025',
    description: 'Jordan\'s premier cultural festival held annually in the magnificent ruins of Jerash. International artists perform on a stage set among 2,000-year-old columns.',
    category: PlaceCategory.event, lat: 32.275, lng: 35.896,
    rating: 4.8, reviewCount: 4200, imageEmoji: '🎭',
    location: 'Jerash', eventDate: 'Jul 22 – Aug 1, 2025',
    hours: '7 PM – 11 PM', tags: ['culture', 'music', 'art', 'heritage'],
    photoUrls: [_event1],
  ),
  const Place(
    id: 'ev2', name: 'Petra Night Walk',
    description: 'Experience Petra by candlelight — walk through the Siq to the Treasury while traditional Bedouin music fills the air. An unmissable, magical experience.',
    category: PlaceCategory.event, lat: 30.328, lng: 35.444,
    rating: 4.9, reviewCount: 3100, imageEmoji: '🕯️',
    location: 'Petra', eventDate: 'Mon, Wed, Thu',
    hours: '8:30 PM – 10:30 PM', tags: ['unique', 'heritage', 'photography', 'culture'],
    photoUrls: [_petra],
  ),
  const Place(
    id: 'ev3', name: 'Dead Sea Ultra Marathon',
    description: 'The world\'s lowest ultra marathon — a 50km race from the shores of the Dead Sea through dramatic desert canyons. Open to all fitness levels.',
    category: PlaceCategory.event, lat: 31.559, lng: 35.473,
    rating: 4.6, reviewCount: 890, imageEmoji: '🏃',
    location: 'Dead Sea', eventDate: 'Nov 15, 2025',
    hours: '6 AM – 4 PM', tags: ['adventure', 'sport', 'unique', 'nature'],
    photoUrls: [_deadSea],
  ),
  const Place(
    id: 'ev4', name: 'Amman Jazz Festival',
    description: 'Annual jazz festival bringing together local and international artists for performances across the iconic Rainbow Street and cultural venues.',
    category: PlaceCategory.event, lat: 31.950, lng: 35.920,
    rating: 4.5, reviewCount: 620, imageEmoji: '🎷',
    location: 'Rainbow Street, Amman', eventDate: 'Sep 5–7, 2025',
    hours: '6 PM – 11 PM', tags: ['music', 'nightlife', 'culture', 'art'],
    photoUrls: [_event2],
  ),
];

List<Place> get kAttractions => AllPlaces.where((p) => p.category == PlaceCategory.attraction).toList();
List<Place> get kHotels      => AllPlaces.where((p) => p.category == PlaceCategory.hotel).toList();
List<Place> get kRestaurants => AllPlaces.where((p) => p.category == PlaceCategory.restaurant).toList();
List<Place> get kEvents      => AllPlaces.where((p) => p.category == PlaceCategory.event).toList();

const _svcPhoto1 = 'https://images.unsplash.com/photo-1551632811-561732d1e306?w=600&q=80';
const _svcPhoto2 = 'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=600&q=80';
const _svcPhoto3 = 'https://images.unsplash.com/photo-1530521954074-e64f6810b32d?w=600&q=80';
const _svcPhoto4 = 'https://images.unsplash.com/photo-1571019613454-1cb2f99b2d8b?w=600&q=80';

final List<TripService> SampleServices = [
  const TripService(
    id: 'sv1', name: 'Wadi Rum Hiking Gear',
    description: 'Full hiking equipment rental: trekking poles, boots (sizes 36–48), backpacks, and hydration systems. Perfect for Wadi Rum and Dana Reserve treks.',
    category: ServiceCategory.equipment, customCategory: 'Hiking Equipment',
    ownerId: 'u_biz_demo', ownerName: 'Rum Adventures',
    location: 'Wadi Rum Village', phone: '+962 3 209 0000',
    hours: '7 AM – 5 PM', priceFrom: 15, priceUnit: 'per day',
    tags: ['hiking', 'adventure', 'nature', 'gear'],
    imageEmoji: '🎒', listingStatus: ListingStatus.approved,
    rating: 4.6, reviewCount: 142,
    lat: 29.575, lng: 35.420,
    photoUrls: [_svcPhoto1],
  ),
  const TripService(
    id: 'sv2', name: 'Petra Expert Guide',
    description: 'Licensed guide with 15+ years experience. Full-day tours of Petra including the Monastery, High Place of Sacrifice, and hidden trails most tourists never see.',
    category: ServiceCategory.guide, customCategory: 'Archaeological Tour Guide',
    ownerId: 'u_biz_demo', ownerName: 'Petra Guides Co.',
    location: 'Petra Visitor Center', phone: '+962 3 215 6044',
    hours: '7 AM – 5 PM', priceFrom: 45, priceUnit: 'per person',
    tags: ['history', 'heritage', 'culture', 'photography'],
    imageEmoji: '🧭', listingStatus: ListingStatus.approved,
    rating: 4.9, reviewCount: 378,
    lat: 30.328, lng: 35.444,
    photoUrls: [_svcPhoto2],
  ),
  const TripService(
    id: 'sv3', name: 'Airport Transfer — Amman',
    description: 'Comfortable, reliable transfers between Queen Alia International Airport and any Amman hotel. AC vehicles, English-speaking drivers. 24/7 availability.',
    category: ServiceCategory.transport, customCategory: 'Airport Transfer',
    ownerId: 'u_biz_demo', ownerName: 'Jordan Transfer',
    location: 'Queen Alia Airport', phone: '+962 6 445 7788',
    hours: '24/7', priceFrom: 25, priceUnit: 'per trip',
    tags: ['transport', 'airport', 'comfortable', 'family'],
    imageEmoji: '🚐', listingStatus: ListingStatus.approved,
    rating: 4.7, reviewCount: 524,
    lat: 31.722, lng: 35.993,
    photoUrls: [_svcPhoto3],
  ),
  const TripService(
    id: 'sv4', name: 'Dead Sea Mud & Float',
    description: 'Guided Dead Sea experience: mineral mud application, floating sessions, and access to freshwater pools. Includes transport from Amman.',
    category: ServiceCategory.experience, customCategory: 'Dead Sea Wellness',
    ownerId: 'u_biz_demo', ownerName: 'Sea & Spa Jordan',
    location: 'Dead Sea, Sweimeh', phone: '+962 5 349 1111',
    hours: '9 AM – 5 PM', priceFrom: 35, priceUnit: 'per person',
    tags: ['wellness', 'unique', 'nature', 'relaxation'],
    imageEmoji: '🌊', listingStatus: ListingStatus.approved,
    rating: 4.8, reviewCount: 211,
    lat: 31.559, lng: 35.473,
    photoUrls: [_svcPhoto4],
  ),
  const TripService(
    id: 'sv5', name: 'Wadi Rum Jeep Safari',
    description: 'Half or full-day 4WD jeep tours through Wadi Rum\'s red dunes, canyon narrows, and Bedouin camps. Sunset and overnight options available.',
    category: ServiceCategory.experience, customCategory: 'Jeep Desert Tour',
    ownerId: 'u_biz_demo', ownerName: 'Rum Jeep Tours',
    location: 'Wadi Rum', phone: '+962 3 209 0011',
    hours: '6 AM – 8 PM', priceFrom: 40, priceUnit: 'per person',
    tags: ['adventure', 'desert', 'nature', 'photography'],
    imageEmoji: '🚙', listingStatus: ListingStatus.approved,
    rating: 4.9, reviewCount: 689,
    lat: 29.580, lng: 35.415,
    photoUrls: [_svcPhoto1],
  ),
];

//  Sample data for admin panel 
final List<UserModel> kSampleUsers = [
  UserModel(id: 'u1', name: 'Sara Al-Khalidi', email: 'sara@example.com',
      role: UserRole.tourist, interests: ['history', 'culture', 'food']),
  UserModel(id: 'u2', name: 'James Morrison', email: 'james.m@gmail.com',
      role: UserRole.tourist, interests: ['adventure', 'hiking', 'photography']),
  UserModel(id: 'u3', name: 'Fatima Nasser', email: 'fatima.n@outlook.com',
      role: UserRole.tourist, interests: ['nature', 'wellness', 'art']),
  UserModel(id: 'u4', name: 'Ahmed Al-Rashidi', email: 'ahmed.biz@jo.com',
      role: UserRole.localBusiness, interests: []),
  UserModel(id: 'u5', name: 'Lena Becker', email: 'lena.b@travel.de',
      role: UserRole.tourist, interests: ['diving', 'nature', 'food']),
  UserModel(id: 'u_admin', name: 'Admin', email: 'admin@gojo.jo',
      role: UserRole.admin, interests: []),
  UserModel(id: 'u_biz_demo', name: 'Demo Business', email: 'business@gojo.jo',
      role: UserRole.localBusiness, interests: []),
];

final List<BusinessRegistration> SampleRegistrations = [];

final List<Review> kSampleReviews = [
  Review(id: 'rv1', userId: 'u1', userName: 'Sara Al-Khalidi',
      placeId: 'a1', rating: 5.0,
      text: 'Absolutely breathtaking. Walking through the Siq to reveal the Treasury is a moment I will never forget.',
      date: DateTime(2025, 3, 15)),
  Review(id: 'rv2', userId: 'u2', userName: 'James Morrison',
      placeId: 'a1', rating: 4.5,
      text: 'One of the most impressive archaeological sites I have ever visited. Go early to beat the crowds.',
      date: DateTime(2025, 3, 10)),
  Review(id: 'rv3', userId: 'u3', userName: 'Fatima Nasser',
      placeId: 'a4', rating: 5.0,
      text: 'Floating in the Dead Sea is truly a unique experience. The mud treatment was wonderful too.',
      date: DateTime(2025, 2, 20)),
  Review(id: 'rv4', userId: 'u5', userName: 'Lena Becker',
      placeId: 'r1', rating: 4.8,
      text: 'The mansaf here is the best I have had in Jordan. Authentic flavours and wonderful hospitality.',
      date: DateTime(2025, 3, 5)),
];
