import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme.dart';
import '../services/app_state.dart';
import '../services/firebase_service.dart';
import '../models/models.dart';
import '../widgets/shared_widgets.dart';
import 'map_screen.dart';
import 'place_detail_screen.dart';
import 'dart:math' show sin, cos, sqrt, atan2, pi;
import 'package:geolocator/geolocator.dart';
import 'services_screen.dart';


enum _SortBy { relevance, rating, nameAZ, priceLow }


enum _CatTab { all, attraction, hotel, restaurant, event, services }

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {

  final _ctrl  = TextEditingController();
  final _focus = FocusNode();
  Timer? _debounce;

  
  _CatTab _tab = _CatTab.all;


  String        _query          = '';
  _SortBy       _sort           = _SortBy.relevance;
  double        _minRating      = 0;
  RangeValues   _priceRange     = const RangeValues(0, 500);
  final Set<String> _tagFilters = {};
  double?       _userLat;
  double?       _userLng;
  double        _maxDistanceKm  = 25.0;
  final _distCtrl               = TextEditingController(text: '25');
  bool          _locationLoading = false;

 
  final List<String> _history = [];

  
  bool _panelOpen = false;

  List<Place>       _allPlaces   = [];
  List<TripService> _allServices = [];
  StreamSubscription? _placesSub;
  StreamSubscription? _svcsSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppState>().recordBehavior(BehaviorEvent.openedSearch);
      _placesSub = context.read<AppState>().approvedPlacesStream.listen((snap) {
        if (!mounted) return;
        setState(() => _allPlaces = snap.docs.map(FirebaseService.placeFromDoc).toList());
      });
      _svcsSub = context.read<AppState>().approvedServicesStream.listen((snap) {
        if (!mounted) return;
        setState(() => _allServices = snap.docs.map(FirebaseService.serviceFromDoc).toList());
      });
    });
  }

  @override
  void dispose() {
    _placesSub?.cancel();
    _svcsSub?.cancel();
    _ctrl.dispose(); _focus.dispose(); _distCtrl.dispose(); _debounce?.cancel();
    super.dispose();
  }


  void _onChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() => _query = v.trim());
      if (v.trim().length > 2) {
        context.read<AppState>().recordSearch(v.trim());
        if (!_history.contains(v.trim())) {
          setState(() {
            _history.insert(0, v.trim());
            if (_history.length > 8) _history.removeLast();
          });
        }
      }
    });
  }

  PlaceCategory? get _tabCategory {
    switch (_tab) {
      case _CatTab.attraction: return PlaceCategory.attraction;
      case _CatTab.hotel:      return PlaceCategory.hotel;
      case _CatTab.restaurant: return PlaceCategory.restaurant;
      case _CatTab.event:      return PlaceCategory.event;
      default:                 return null;
    }
  }

  List<Place> get _places {
    // Services-only tab → no places
    if (_tab == _CatTab.services) return [];

    var list = List<Place>.from(_allPlaces);

    final cat = _tabCategory;
    if (cat != null) list = list.where((p) => p.category == cat).toList();

    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      list = list.where((p) =>
        p.name.toLowerCase().contains(q) ||
        p.description.toLowerCase().contains(q) ||
        p.location.toLowerCase().contains(q) ||
        p.tags.any((t) => t.toLowerCase().contains(q))
      ).toList();
    }

    if (_tagFilters.isNotEmpty) {
      list = list.where((p) => p.tags.any(_tagFilters.contains)).toList();
    }

    if (_minRating > 0) list = list.where((p) => p.rating >= _minRating).toList();

    list = list.where((p) {
      if (p.category != PlaceCategory.hotel) return true;
      if (p.pricePerNight == null) return true;
      return p.pricePerNight! >= _priceRange.start && p.pricePerNight! <= _priceRange.end;
    }).toList();

 
    if (_userLat != null && _userLng != null) {
      list = list.where((p) {
        if (p.lat == 0 && p.lng == 0) return false;
        return _haversineKm(_userLat!, _userLng!, p.lat, p.lng) <= _maxDistanceKm;
      }).toList();
    }

    if (_userLat != null && _userLng != null && _sort == _SortBy.relevance) {
      list.sort((a, b) => _haversineKm(_userLat!, _userLng!, a.lat, a.lng)
          .compareTo(_haversineKm(_userLat!, _userLng!, b.lat, b.lng)));
    } else {
      switch (_sort) {
        case _SortBy.rating:   list.sort((a, b) => b.rating.compareTo(a.rating)); break;
        case _SortBy.nameAZ:   list.sort((a, b) => a.name.compareTo(b.name)); break;
        case _SortBy.priceLow: list.sort((a, b) =>
            (a.pricePerNight ?? 999999).compareTo(b.pricePerNight ?? 999999)); break;
        default: break;
      }
    }

    return list;
  }

  List<TripService> get _services {
    // Only show services on "All" or "Services" tab
    if (_tab != _CatTab.all && _tab != _CatTab.services) return [];

    var list = List<TripService>.from(_allServices);

    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      list = list.where((s) =>
        s.name.toLowerCase().contains(q) ||
        s.description.toLowerCase().contains(q) ||
        s.location.toLowerCase().contains(q) ||
        s.tags.any((t) => t.toLowerCase().contains(q))
      ).toList();
    }

    if (_tagFilters.isNotEmpty) {
      list = list.where((s) => s.tags.any(_tagFilters.contains)).toList();
    }

    if (_minRating > 0) list = list.where((s) => s.rating >= _minRating).toList();

    if (_sort == _SortBy.rating) list.sort((a, b) => b.rating.compareTo(a.rating));
    if (_sort == _SortBy.nameAZ) list.sort((a, b) => a.name.compareTo(b.name));

    return list;
  }

  
bool get _showResults =>
    _query.isNotEmpty ||
    _anyFilter ||
    _tab == _CatTab.all ||
    _tab == _CatTab.services ||
    _tab == _CatTab.attraction ||
    _tab == _CatTab.hotel ||
    _tab == _CatTab.restaurant ||
    _tab == _CatTab.event;

  bool get _anyFilter =>
      _sort != _SortBy.relevance || _minRating > 0 ||
      _tagFilters.isNotEmpty ||
      _priceRange != const RangeValues(0, 500) ||
      _userLat != null;

  void _clearAll() => setState(() {
    _sort = _SortBy.relevance; _minRating = 0;
    _tagFilters.clear();
    _priceRange = const RangeValues(0, 500);
    _userLat = null; _userLng = null; _maxDistanceKm = 25;
    _distCtrl.text = '25';
  });

  double _haversineKm(double lat1, double lng1, double lat2, double lng2) {
    const r = 6371.0;
    final dLat = (lat2 - lat1) * pi / 180;
    final dLng = (lng2 - lng1) * pi / 180;
    final a = sin(dLat/2)*sin(dLat/2) +
        cos(lat1*pi/180)*cos(lat2*pi/180)*sin(dLng/2)*sin(dLng/2);
    return r * 2 * atan2(sqrt(a), sqrt(1-a));
  }

  Future<void> _requestLocation() async {
    setState(() => _locationLoading = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          setState(() => _locationLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Location services are disabled. Enable GPS and try again.')));
        }
        return;
      }
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.deniedForever || perm == LocationPermission.denied) {
        if (mounted) {
          setState(() => _locationLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Location permission denied. Enable it in device settings.')));
        }
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium));
      if (mounted) setState(() {
        _userLat = pos.latitude; _userLng = pos.longitude; _locationLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _locationLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not get location: $e')));
      }
    }
  }

  List<String> get _allTags {
    final freq = <String, int>{};
    for (final p in _allPlaces) {
      for (final t in p.tags) freq[t] = (freq[t] ?? 0) + 1;
    }
    for (final s in _allServices) {
      for (final t in s.tags) freq[t] = (freq[t] ?? 0) + 1;
    }
    return (freq.entries.toList()..sort((a, b) => b.value.compareTo(a.value)))
        .take(16).map((e) => e.key).toList();
  }

  @override
  Widget build(BuildContext context) {
    final places   = _places;
    final services = _services;
    final total    = places.length + services.length;

    return Scaffold(
      backgroundColor: context.bg,
      body: SafeArea(child: Column(children: [

        Container(
          color: context.surface,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: Column(children: [

            Row(children: [
              Text('Explore', style: TextStyle(
                color: context.primary, fontSize: 22, fontWeight: FontWeight.w800)),
              const Spacer(),
              _mapBtn(context),
            ]),
            const SizedBox(height: 10),

            Row(children: [
              Expanded(child: TextField(
                controller: _ctrl,
                focusNode: _focus,
                style: TextStyle(color: context.primary, fontSize: 14),
                onChanged: _onChanged,
                decoration: InputDecoration(
                  hintText: 'Places, hotels, food, tags…',
                  prefixIcon: Icon(Icons.search_rounded, color: context.secondary, size: 20),
                  suffixIcon: _query.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear_rounded, color: context.secondary, size: 18),
                          onPressed: () { _ctrl.clear(); setState(() => _query = ''); })
                      : null,
                ),
              )),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => setState(() => _panelOpen = !_panelOpen),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: (_anyFilter || _panelOpen) ? kAccent : context.bg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: (_anyFilter || _panelOpen) ? kAccent : context.divider)),
                  child: Stack(alignment: Alignment.center, children: [
                    Icon(Icons.tune_rounded,
                      color: (_anyFilter || _panelOpen) ? Colors.white : context.secondary, size: 20),
                    if (_anyFilter) Positioned(top: 7, right: 7, child: Container(
                      width: 7, height: 7,
                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle))),
                  ]),
                ),
              ),
            ]),
            const SizedBox(height: 10),

            // Category chips
            SizedBox(height: 36, child: ListView(scrollDirection: Axis.horizontal, children: [
              _catChip('All',      _CatTab.all,        Icons.layers_rounded),
              _catChip('Sights',   _CatTab.attraction, Icons.account_balance_rounded),
              _catChip('Hotels',   _CatTab.hotel,      Icons.hotel_rounded),
              _catChip('Food',     _CatTab.restaurant, Icons.restaurant_rounded),
              _catChip('Events',   _CatTab.event,      Icons.event_rounded),
              _catChip('Services', _CatTab.services,   Icons.build_rounded),
            ])),
            const SizedBox(height: 10),
          ]),
        ),

if (_panelOpen)
  Expanded(
    flex: 100,
    child: SingleChildScrollView(
      child: _FilterPanel(
        sort: _sort, minRating: _minRating,
        priceRange: _priceRange, tagFilters: _tagFilters,
        allTags: _allTags,
        userLat: _userLat, userLng: _userLng,
        maxDistanceKm: _maxDistanceKm,
        locationLoading: _locationLoading,
        distCtrl: _distCtrl,
        onSort:            (s) => setState(() => _sort = s),
        onRating:          (r) => setState(() => _minRating = r),
        onPrice:           (r) => setState(() => _priceRange = r),
        onTag:             (t) => setState(() =>
            _tagFilters.contains(t) ? _tagFilters.remove(t) : _tagFilters.add(t)),
        onDistance:        (d) { setState(() => _maxDistanceKm = d); _distCtrl.text = d.toInt().toString(); },
        onRequestLocation: _requestLocation,
        onClearLocation:   () => setState(() {
          _userLat = null; _userLng = null;
          _maxDistanceKm = 25; _distCtrl.text = '25';
        }),
        onClear: () { _clearAll(); setState(() => _panelOpen = false); },
      ),
    ),
  ),

        if (_anyFilter && !_panelOpen)
          _ActiveFiltersBar(
            sort: _sort, minRating: _minRating, tagFilters: _tagFilters,
            hasPrice: _priceRange != const RangeValues(0, 500),
            hasLocation: _userLat != null,
            onClear: _clearAll,
          ),

        
        if (_showResults)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 2),
            child: Row(children: [
              Expanded(child: Text(
                '$total result${total != 1 ? "s" : ""}'
                '${_query.isNotEmpty ? "  for  \"$_query\"" : ""}',
                style: TextStyle(color: context.secondary, fontSize: 12))),
              if (_anyFilter)
                GestureDetector(
                  onTap: _clearAll,
                  child: const Text('Clear filters',
                    style: TextStyle(color: kAccent, fontSize: 12, fontWeight: FontWeight.w600))),
            ]),
          ),

        Expanded(child: !_showResults
            ? _DiscoveryView(history: _history, onSearch: (q) { _ctrl.text = q; _onChanged(q); })
            : total == 0
                ? _emptyState()
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    children: [
                      ...places.map((p) => GestureDetector(
                        onTap: () {
                          context.read<AppState>().recordBehavior(
                            BehaviorEvent.viewedPlace, tag: p.category.name);
                          Navigator.push(context,
                            MaterialPageRoute(builder: (_) => PlaceDetailScreen(place: p)));
                        },
                        child: PlaceListTile(place: p),
                      )),
                      if (services.isNotEmpty) ...[
                        if (places.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(0, 10, 0, 8),
                            child: Text('Services (${services.length})',
                              style: TextStyle(color: context.primary,
                                fontSize: 14, fontWeight: FontWeight.w700))),
                        ...services.map((s) => _ServiceTile(
                          svc: s,
                          onTap: () => showServiceDetail(
    context,
    s,
    context.read<AppState>(),
  ),
                        )),
                      ],
                    ],
                  ),
        ),
      ])),
    );
  }

  Widget _mapBtn(BuildContext ctx) => GestureDetector(
    onTap: () {
      ctx.read<AppState>().recordBehavior(BehaviorEvent.openedMap);
      Navigator.push(ctx, MaterialPageRoute(builder: (_) => const MapScreen()));
    },
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: kAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kAccent.withOpacity(0.3))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.map_rounded, color: kAccent, size: 15),
        const SizedBox(width: 5),
        Text('Map', style: TextStyle(color: kAccentDim, fontSize: 12, fontWeight: FontWeight.w700)),
      ]),
    ),
  );

  Widget _catChip(String label, _CatTab tab, IconData icon) {
    final sel = _tab == tab;
    return GestureDetector(
      onTap: () => setState(() => _tab = tab),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: sel ? kAccent : context.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: sel ? kAccent : context.divider, width: sel ? 1.5 : 1)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13, color: sel ? Colors.white : context.secondary),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(
            color: sel ? Colors.white : context.primary,
            fontSize: 12, fontWeight: sel ? FontWeight.w700 : FontWeight.w400)),
        ]),
      ),
    );
  }

  Widget _emptyState() => Center(child: Padding(
    padding: const EdgeInsets.all(40),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.search_off_rounded, size: 52, color: context.secondary.withOpacity(0.35)),
      const SizedBox(height: 12),
      Text('No results', style: TextStyle(
        color: context.primary, fontSize: 16, fontWeight: FontWeight.w700)),
      const SizedBox(height: 6),
      Text('Try different keywords\nor clear some filters',
        style: TextStyle(color: context.secondary, fontSize: 13), textAlign: TextAlign.center),
      const SizedBox(height: 16),
      TextButton.icon(
        icon: const Icon(Icons.filter_alt_off_rounded, size: 16),
        label: const Text('Clear all filters'),
        onPressed: _clearAll),
    ]),
  ));
}

class _ActiveFiltersBar extends StatelessWidget {
  final _SortBy sort;
  final double minRating;
  final Set<String> tagFilters;
  final bool hasPrice, hasLocation;
  final VoidCallback onClear;
  const _ActiveFiltersBar({
    required this.sort, required this.minRating, required this.tagFilters,
    required this.hasPrice, required this.hasLocation, required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final chips = <String>[
      if (sort == _SortBy.rating)   'Top Rated',
      if (sort == _SortBy.nameAZ)   'A–Z',
      if (sort == _SortBy.priceLow) 'Price ↑',
      if (minRating > 0)            '${minRating.toInt()}★+',
      if (hasPrice)                 'Price filter',
      if (hasLocation)              '📍 Nearby',
      ...tagFilters,
    ];
    return Container(
      height: 36,
      color: context.surface,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          ...chips.map((c) => Container(
            margin: const EdgeInsets.only(right: 6),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: kAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(20),
              border: Border.all(color: kAccent.withOpacity(0.3))),
            child: Text(c, style: const TextStyle(
              color: kAccent, fontSize: 11, fontWeight: FontWeight.w600)),
          )),
          GestureDetector(
            onTap: onClear,
            child: Container(
              margin: const EdgeInsets.only(right: 6),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: kDanger.withOpacity(0.08), borderRadius: BorderRadius.circular(20),
                border: Border.all(color: kDanger.withOpacity(0.3))),
              child: const Text('Clear all',
                style: TextStyle(color: kDanger, fontSize: 11, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterPanel extends StatelessWidget {
  final _SortBy sort;
  final double minRating;
  final RangeValues priceRange;
  final Set<String> tagFilters;
  final List<String> allTags;
  final double? userLat;
  final double? userLng;
  final double maxDistanceKm;
  final bool locationLoading;
  final void Function(_SortBy) onSort;
  final void Function(double) onRating;
  final void Function(RangeValues) onPrice;
  final void Function(String) onTag;
  final TextEditingController distCtrl;
  final void Function(double) onDistance;
  final VoidCallback onRequestLocation;
  final VoidCallback onClearLocation;
  final VoidCallback onClear;

  _FilterPanel({
    required this.sort, required this.minRating, required this.priceRange,
    required this.tagFilters, required this.allTags,
    required this.onSort, required this.onRating,
    required this.onPrice, required this.onTag, required this.onDistance,
    required this.onRequestLocation, required this.onClearLocation,
    required this.onClear, required this.distCtrl,
    this.userLat, this.userLng, this.maxDistanceKm = 25, this.locationLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: context.surface,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Divider(height: 1, color: context.divider),
          const SizedBox(height: 14),

          // Sort
          _label(context, 'Sort by'),
          const SizedBox(height: 8),
          SizedBox(height: 34, child: ListView(scrollDirection: Axis.horizontal, children: [
            for (final s in _SortBy.values) _sortChip(context, s),
          ])),
          const SizedBox(height: 14),

          // Min rating
          Row(children: [
            _label(context, 'Min rating'),
            const Spacer(),
            ...List.generate(5, (i) => GestureDetector(
              onTap: () => onRating(minRating == i + 1.0 ? 0 : i + 1.0),
              child: Icon(i < minRating ? Icons.star_rounded : Icons.star_outline_rounded,
                color: kWarning, size: 26))),
          ]),
          const SizedBox(height: 14),

          // Price range (hotels only label)
          Row(children: [
            _label(context, 'Hotel price / night'),
            const Spacer(),
            Text('JD${priceRange.start.toInt()} – JD${priceRange.end.toInt()}',
              style: const TextStyle(color: kAccent, fontSize: 12, fontWeight: FontWeight.w700)),
          ]),
          RangeSlider(
            values: priceRange, min: 0, max: 500, divisions: 25,
            activeColor: kAccent,
            labels: RangeLabels('JD${priceRange.start.toInt()}', 'JD${priceRange.end.toInt()}'),
            onChanged: onPrice),
          const SizedBox(height: 6),

          // Distance
          _label(context, 'Distance from me'),
          const SizedBox(height: 8),
          if (userLat == null)
            GestureDetector(
              onTap: locationLoading ? null : onRequestLocation,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: kAccent.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: kAccent.withOpacity(0.3))),
                child: Row(children: [
                  locationLoading
                      ? const SizedBox(width: 18, height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: kAccent))
                      : const Icon(Icons.my_location_rounded, color: kAccent, size: 18),
                  const SizedBox(width: 8),
                  Text(locationLoading ? 'Getting location…' : 'Use my current location',
                    style: const TextStyle(color: kAccent, fontSize: 13, fontWeight: FontWeight.w600)),
                ]),
              ))
          else
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: kAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.location_on_rounded, color: kAccent, size: 14),
                    SizedBox(width: 4),
                    Text('Location active',
                      style: TextStyle(color: kAccent, fontSize: 12, fontWeight: FontWeight.w600)),
                  ])),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: onClearLocation,
                  child: const Text('✕ Clear',
                    style: TextStyle(color: kDanger, fontSize: 11, fontWeight: FontWeight.w600))),
              ]),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [
                 for (final km in [1, 5, 10, 25, 50, 100, 200, 500, 1000])
                    GestureDetector(
                      onTap: () { distCtrl.text = km.toString(); onDistance(km.toDouble()); },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        margin: const EdgeInsets.only(right: 7),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: maxDistanceKm.toInt() == km ? kAccent : context.card,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: maxDistanceKm.toInt() == km ? kAccent : context.divider,
                            width: maxDistanceKm.toInt() == km ? 1.5 : 1)),
                        child: Text('$km km', style: TextStyle(
                          color: maxDistanceKm.toInt() == km ? Colors.white : context.secondary,
                          fontSize: 12,
                          fontWeight: maxDistanceKm.toInt() == km ? FontWeight.w700 : FontWeight.w400)),
                      ),
                    ),
                ]),
              ),
              const SizedBox(height: 8),
              Row(children: [
                Text('1 km', style: TextStyle(color: context.secondary, fontSize: 10)),
                Expanded(child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: kAccent, thumbColor: kAccent,
                    inactiveTrackColor: kAccent.withOpacity(0.15),
                    overlayColor: kAccent.withOpacity(0.12),
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7)),
                  child: Slider(
                    value: maxDistanceKm.clamp(1, 200),
                    min: 1, max: 1000, divisions: 999,
                    label: '${maxDistanceKm.toInt()} km',
                    onChanged: (v) { distCtrl.text = v.toInt().toString(); onDistance(v); }),
                )),
                Text('1000 km', style: TextStyle(color: context.secondary, fontSize: 10)),
              ]),
            ]),
          const SizedBox(height: 14),

          // Tags — dynamic from real data
          _label(context, 'Topics'),
          const SizedBox(height: 8),
          allTags.isEmpty
              ? Text('No topics yet', style: TextStyle(color: context.secondary, fontSize: 12))
              : Wrap(spacing: 7, runSpacing: 7,
                  children: allTags.map((t) => _tagChip(context, t)).toList()),
          const SizedBox(height: 16),

          // Clear
          SizedBox(width: double.infinity, child: OutlinedButton(
            onPressed: onClear,
            style: OutlinedButton.styleFrom(
              foregroundColor: kDanger,
              side: BorderSide(color: kDanger.withOpacity(0.5))),
            child: const Text('Clear all filters & close'))),
        ]),
      ),
    );
  }

  Widget _label(BuildContext ctx, String text) =>
    Text(text, style: TextStyle(color: ctx.primary, fontSize: 13, fontWeight: FontWeight.w700));

  static const _sortLabels = {
    _SortBy.relevance: 'Best Match',
    _SortBy.rating:    'Top Rated',
    _SortBy.nameAZ:    'A – Z',
    _SortBy.priceLow:  'Price ↑',
  };

  Widget _sortChip(BuildContext ctx, _SortBy s) {
    final sel = sort == s;
    return GestureDetector(
      onTap: () => onSort(s),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: sel ? kAccent : ctx.bg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: sel ? kAccent : ctx.divider)),
        child: Text(_sortLabels[s]!, style: TextStyle(
          color: sel ? Colors.white : ctx.primary,
          fontSize: 12, fontWeight: sel ? FontWeight.w700 : FontWeight.w400))));
  }

  Widget _tagChip(BuildContext ctx, String t) {
    final sel = tagFilters.contains(t);
    return GestureDetector(
      onTap: () => onTag(t),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: sel ? kAccent.withOpacity(0.12) : ctx.bg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: sel ? kAccent : ctx.divider)),
        child: Text(t, style: TextStyle(
          color: sel ? kAccent : ctx.secondary,
          fontSize: 12, fontWeight: sel ? FontWeight.w700 : FontWeight.w400))));
  }
}

// ══ Discovery view ════════════════════════════════════════════════════════════
class _DiscoveryView extends StatelessWidget {
  final List<String> history;
  final void Function(String) onSearch;
  const _DiscoveryView({required this.history, required this.onSearch});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        if (history.isNotEmpty) ...[
          _sectionHead(context, Icons.history_rounded, 'Recent searches', context.secondary),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final h in history)
              GestureDetector(
                onTap: () => onSearch(h),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: context.card, borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: context.divider)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.history_rounded, size: 13, color: context.secondary),
                    const SizedBox(width: 5),
                    Text(h, style: TextStyle(color: context.primary, fontSize: 12)),
                  ]))),
          ]),
        ],
        if (history.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 60),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.explore_outlined, size: 56,
                color: context.secondary.withOpacity(0.3)),
              const SizedBox(height: 12),
              Text('Search or pick a category above',
                style: TextStyle(color: context.secondary, fontSize: 14)),
            ]),
          ),
      ],
    );
  }

  static Widget _sectionHead(BuildContext ctx, IconData icon, String label, Color color) =>
    Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Icon(icon, size: 15, color: color), const SizedBox(width: 6),
        Text(label, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w700)),
      ]),
    );
}

class _ServiceTile extends StatelessWidget {
  final TripService svc;
  final VoidCallback onTap;
  const _ServiceTile({required this.svc, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: context.card, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.divider),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)]),
      child: Row(children: [
        ClipRRect(
          borderRadius: const BorderRadius.horizontal(left: Radius.circular(14)),
          child: SizedBox(width: 80, height: 80, child: servicePhoto(svc, context))),
        Expanded(child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(svc.name, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(color: context.primary, fontWeight: FontWeight.w700, fontSize: 14)),
            const SizedBox(height: 3),
            Text(svc.location, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(color: context.secondary, fontSize: 12)),
            if (svc.priceFrom != null)
              Text('From JD${svc.priceFrom!.toInt()} ${svc.priceUnit ?? ""}',
                style: const TextStyle(color: kAccentDim, fontSize: 11, fontWeight: FontWeight.w600)),
          ]))),
        Padding(padding: const EdgeInsets.only(right: 12),
          child: Icon(Icons.chevron_right_rounded, color: context.secondary, size: 20)),
      ]),
    ),
  );
}