import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cache/flutter_map_cache.dart';
import 'package:dio_cache_interceptor_file_store/dio_cache_interceptor_file_store.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import '../theme.dart';
import '../services/app_state.dart';
import '../services/firebase_service.dart';
import '../models/models.dart';
import '../widgets/shared_widgets.dart';
import '../widgets/location_search_widget.dart';
import 'place_detail_screen.dart';
import 'services_screen.dart';


Future<Map<String, dynamic>> _fetchRouteInfo(LatLng from, LatLng to) async {
  try {
    final url = 'https://router.project-osrm.org/route/v1/driving/'
        '${from.longitude},${from.latitude};${to.longitude},${to.latitude}'
        '?overview=full&geometries=geojson&steps=true';
    final req = await HttpClient().getUrl(Uri.parse(url));
    req.headers.set('User-Agent', 'GoJo-App/1.0');
    final res = await req.close();
    if (res.statusCode != 200) return {};
    final data = jsonDecode(await res.transform(utf8.decoder).join()) as Map;
    final route = data['routes'][0] as Map;
    return {
      'coords': (route['geometry']['coordinates'] as List)
          .map((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
          .toList(),
      'distance': (route['distance'] as num).toDouble(),
      'duration': (route['duration'] as num).toDouble(),
    };
  } catch (_) {
    return {};
  }
}

String _fmtDur(double s) {
  final m = (s / 60).round();
  return m < 60 ? '$m min' : '${m ~/ 60}h${m % 60 == 0 ? "" : " ${m % 60}m"}';
}

String _fmtDist(double m) =>
    m < 1000 ? '${m.round()} m' : '${(m / 1000).toStringAsFixed(1)} km';


LatLng _simLoc = const LatLng(31.958, 35.933);


const _kTileLight =
    'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png';
const _kTileDark =
    'https://{s}.basemaps.cartocdn.com/dark_matter/{z}/{x}/{y}{r}.png';

class _Region {
  final String name, governorate;
  final LatLng center;
  final double zoom;
  final LatLng sw, ne;
  final double mb;
  const _Region({
    required this.name,
    required this.governorate,
    required this.center,
    required this.zoom,
    required this.sw,
    required this.ne,
    required this.mb,
  });
}

const _kAllRegions = [
  _Region(name: 'Amman',      governorate: 'Amman',   center: LatLng(31.958, 35.933), zoom: 12, sw: LatLng(31.70, 35.72), ne: LatLng(32.17, 36.10), mb: 42),
  _Region(name: 'Zarqa',      governorate: 'Zarqa',   center: LatLng(32.073, 36.088), zoom: 12, sw: LatLng(31.90, 35.90), ne: LatLng(32.25, 36.30), mb: 18),
  _Region(name: 'Petra',      governorate: "Ma'an",   center: LatLng(30.328, 35.444), zoom: 13, sw: LatLng(30.15, 35.30), ne: LatLng(30.55, 35.60), mb: 28),
  _Region(name: 'Wadi Rum',   governorate: "Ma'an",   center: LatLng(29.575, 35.420), zoom: 12, sw: LatLng(29.35, 35.20), ne: LatLng(29.85, 35.65), mb: 18),
  _Region(name: 'Aqaba',      governorate: 'Aqaba',   center: LatLng(29.510, 34.990), zoom: 13, sw: LatLng(29.30, 34.85), ne: LatLng(29.75, 35.10), mb: 22),
  _Region(name: 'Dead Sea',   governorate: 'Balqa',   center: LatLng(31.559, 35.473), zoom: 12, sw: LatLng(31.20, 35.35), ne: LatLng(31.90, 35.60), mb: 15),
  _Region(name: 'Jerash',     governorate: 'Jerash',  center: LatLng(32.275, 35.896), zoom: 13, sw: LatLng(32.10, 35.75), ne: LatLng(32.45, 36.05), mb: 12),
  _Region(name: 'Ajloun',     governorate: 'Ajloun',  center: LatLng(32.330, 35.750), zoom: 12, sw: LatLng(32.15, 35.60), ne: LatLng(32.50, 35.90), mb: 10),
  _Region(name: 'Irbid',      governorate: 'Irbid',   center: LatLng(32.555, 35.850), zoom: 12, sw: LatLng(32.35, 35.65), ne: LatLng(32.75, 36.05), mb: 20),
  _Region(name: 'Umm Qais',   governorate: 'Irbid',   center: LatLng(32.654, 35.682), zoom: 13, sw: LatLng(32.55, 35.58), ne: LatLng(32.75, 35.78), mb: 8),
  _Region(name: 'Madaba',     governorate: 'Madaba',  center: LatLng(31.716, 35.793), zoom: 12, sw: LatLng(31.55, 35.65), ne: LatLng(31.90, 35.95), mb: 10),
  _Region(name: 'Salt',       governorate: 'Balqa',   center: LatLng(32.037, 35.727), zoom: 12, sw: LatLng(31.85, 35.55), ne: LatLng(32.25, 35.90), mb: 12),
  _Region(name: 'Karak',      governorate: 'Karak',   center: LatLng(31.184, 35.704), zoom: 12, sw: LatLng(30.95, 35.55), ne: LatLng(31.40, 35.85), mb: 14),
  _Region(name: 'Tafilah',    governorate: 'Tafilah', center: LatLng(30.837, 35.603), zoom: 12, sw: LatLng(30.65, 35.45), ne: LatLng(31.05, 35.75), mb: 9),
  _Region(name: "Ma'an City", governorate: "Ma'an",   center: LatLng(30.194, 35.737), zoom: 12, sw: LatLng(30.00, 35.55), ne: LatLng(30.40, 35.90), mb: 11),
  _Region(name: 'Azraq',      governorate: 'Zarqa',   center: LatLng(31.838, 36.825), zoom: 12, sw: LatLng(31.65, 36.65), ne: LatLng(32.05, 37.00), mb: 7),
  _Region(name: 'Mafraq',     governorate: 'Mafraq',  center: LatLng(32.342, 36.204), zoom: 11, sw: LatLng(32.10, 35.95), ne: LatLng(32.60, 36.50), mb: 13),
];

const _kTotalStorageMb = 300.0;
const _kCenter = LatLng(31.25, 36.5);

enum _Filter { all, attractions, hotels, restaurants, services, events }

class MapScreen extends StatefulWidget {
  final LatLng? focusPoint;
  final String? focusLabel;
  const MapScreen({super.key, this.focusPoint, this.focusLabel});
  @override
  State<MapScreen> createState() => _MapState();
}

class _MapState extends State<MapScreen> with TickerProviderStateMixin {
  final _mapCtrl = MapController();
  _Filter _filter = _Filter.all;
  bool _showRegions = false;
  bool _geoMode = false;
  final _searchCtrl = TextEditingController();
  String _searchQ = '';

  Place? _selPlace;
  TripService? _selSvc;
  late AnimationController _popupAnim;
  late Animation<double> _popupSlide;

  // Location
  LatLng _myLoc = _simLoc;
  bool _tracking = false;
  Timer? _locTimer;
  double _accuracy = 18.0;
  List<LatLng> _pathHistory = [];

  
  List<LatLng> _routePts = [];
  String _routeDur = '', _routeDist = '';
  bool _loadingRoute = false;
  LatLng? _routeDest;
  String _routeName = '';

  double _currentZoom = 7.0;

  
  List<Place> _livePlaces = [];
  List<TripService> _liveServices = [];
  StreamSubscription? _placesSub;
  StreamSubscription? _svcsSub;

  final Map<String, bool> _savedRegions = {};
  final Map<String, double> _dlProgress = {};
  final Map<String, bool> _downloading = {};
  CacheStore? _tileStore;
  String? _tileCacheDir;

  bool _justTappedMarker = false;

  @override
  void initState() {
    super.initState();
  
    _currentZoom = widget.focusPoint != null ? 15.0 : 7.0;

    _popupAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 320));
    _popupSlide =
        CurvedAnimation(parent: _popupAnim, curve: Curves.easeOutCubic);
    _initTileCache();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final st = context.read<AppState>();
      _placesSub = st.approvedPlacesStream.listen((snap) {
        if (!mounted) return;
        setState(() =>
            _livePlaces = snap.docs.map(FirebaseService.placeFromDoc).toList());
      });
      _svcsSub = st.approvedServicesStream.listen((snap) {
        if (!mounted) return;
        setState(() => _liveServices =
            snap.docs.map(FirebaseService.serviceFromDoc).toList());
      });
      _loadSavedRegions();
      if (widget.focusPoint != null) {
        _mapCtrl.move(widget.focusPoint!, 15);
      }
    });
  }

  Future<void> _initTileCache() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      _tileCacheDir = '${dir.path}${Platform.pathSeparator}MapTiles';
      await Directory(_tileCacheDir!).create(recursive: true);
      _tileStore = FileCacheStore(_tileCacheDir!);
      if (mounted) setState(() {});
    } catch (_) {}
  }

  String get _prefsKey => 'gojo_saved_regions_guest';

  Future<void> _loadSavedRegions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getStringList(_prefsKey) ?? [];
      if (!mounted) return;
      setState(() {
        for (final name in saved) {
          _savedRegions[name] = true;
        }
      });
    } catch (_) {}
  }

  Future<void> _persistSavedRegions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
          _prefsKey,
          _savedRegions.entries
              .where((e) => e.value)
              .map((e) => e.key)
              .toList());
    } catch (_) {}
  }

  @override
  void dispose() {
    _placesSub?.cancel();
    _svcsSub?.cancel();
    _popupAnim.dispose();
    _searchCtrl.dispose();
    _locTimer?.cancel();
    super.dispose();
  }

  void _startTracking() {
    HapticFeedback.mediumImpact();
    setState(() {
      _tracking = true;
      _accuracy = 18.0;
      _pathHistory = [_myLoc];
    });
    _mapCtrl.move(_myLoc, 15.5);
    _locTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (!mounted) return;
      setState(() {
        final rnd = math.Random();
        _myLoc = LatLng(
          _myLoc.latitude + (rnd.nextDouble() - 0.5) * 0.00018,
          _myLoc.longitude + (rnd.nextDouble() - 0.5) * 0.00018,
        );
        _simLoc = _myLoc;
        if (_accuracy > 4) _accuracy -= 0.8;
        _pathHistory.add(_myLoc);
        if (_pathHistory.length > 60) _pathHistory.removeAt(0);
        if (_tracking) _mapCtrl.move(_myLoc, _mapCtrl.camera.zoom);
      });
    });
  }

  void _stopTracking() {
    _locTimer?.cancel();
    setState(() {
      _tracking = false;
      _accuracy = 18.0;
    });
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted && !_tracking) setState(() => _pathHistory = []);
    });
  }

  void _centerOnMe() {
    HapticFeedback.lightImpact();
    _mapCtrl.move(_myLoc, 15.5);
    if (!_tracking) _startTracking();
  }

  Future<void> _routeTo(LatLng target, String name) async {
    setState(() {
      _loadingRoute = true;
      _routeDest = target;
      _routeName = name;
    });
    _clearSel();
    final info = await _fetchRouteInfo(_myLoc, target);
    if (!mounted) return;
    if (info.isEmpty) {
      setState(() => _loadingRoute = false);
      _snack('Could not load route — check connection');
      return;
    }
    final coords = info['coords'] as List<LatLng>;
    setState(() {
      _routePts = coords;
      _routeDur = _fmtDur(info['duration'] as double);
      _routeDist = _fmtDist(info['distance'] as double);
      _loadingRoute = false;
    });
    if (coords.isNotEmpty) {
      final lats = coords.map((p) => p.latitude);
      final lngs = coords.map((p) => p.longitude);
      _mapCtrl.fitCamera(CameraFit.bounds(
        bounds: LatLngBounds(
          LatLng(lats.reduce(math.min) - 0.02, lngs.reduce(math.min) - 0.02),
          LatLng(lats.reduce(math.max) + 0.02, lngs.reduce(math.max) + 0.02),
        ),
        padding: const EdgeInsets.fromLTRB(32, 130, 32, 100),
      ));
    }
  }

  void _clearRoute() => setState(() {
        _routePts = [];
        _routeDur = '';
        _routeDist = '';
        _routeDest = null;
        _routeName = '';
      });

  void _snack(String msg, {Color? color}) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w500)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ));

  List<Place> _places(AppState s) {
    final all = _livePlaces.where((p) => p.lat != 0 && p.lng != 0);
    switch (_filter) {
      case _Filter.attractions:
        return all.where((p) => p.category == PlaceCategory.attraction).toList();
      case _Filter.hotels:
        return all.where((p) => p.category == PlaceCategory.hotel).toList();
      case _Filter.restaurants:
        return all.where((p) => p.category == PlaceCategory.restaurant).toList();
      case _Filter.events:
        return all.where((p) => p.category == PlaceCategory.event).toList();
      case _Filter.services:
        return [];
      default:
        return all.where((p) => p.category != PlaceCategory.event).toList();
    }
  }

  List<TripService> _svcs(AppState s) {
    if (_filter != _Filter.all && _filter != _Filter.services) return [];
    return _liveServices.where((sv) => sv.lat != null).toList();
  }

  List<dynamic> _searchResults(AppState s) {
    final q = _searchQ.toLowerCase().trim();
    if (q.isEmpty) return [];
    return [
      ..._livePlaces.where((p) =>
          p.name.toLowerCase().contains(q) ||
          p.location.toLowerCase().contains(q)),
      ..._liveServices.where((sv) =>
          sv.name.toLowerCase().contains(q) ||
          sv.location.toLowerCase().contains(q)),
    ];
  }

  void _onSelPlace(Place p) {
    _justTappedMarker = true;
    setState(() {
      _selPlace = p;
      _selSvc = null;
    });
    _popupAnim.forward(from: 0);
    HapticFeedback.selectionClick();
    _mapCtrl.move(
        LatLng(p.lat - 0.008, p.lng), math.max(_mapCtrl.camera.zoom, 14));
  }

  void _onSelSvc(TripService sv) {
    _justTappedMarker = true;
    setState(() {
      _selSvc = sv;
      _selPlace = null;
    });
    _popupAnim.forward(from: 0);
    HapticFeedback.selectionClick();
    if (sv.lat != null) {
      _mapCtrl.move(
          LatLng(sv.lat! - 0.008, sv.lng!), math.max(_mapCtrl.camera.zoom, 14));
    }
  }

  void _clearSel() {
    setState(() {
      _selPlace = null;
      _selSvc = null;
    });
    _popupAnim.reverse();
  }

  Color _catColor(PlaceCategory c) {
    switch (c) {
      case PlaceCategory.attraction:
        return const Color(0xFF1A73E8);
      case PlaceCategory.hotel:
        return const Color(0xFFE8890C);
      case PlaceCategory.restaurant:
        return const Color(0xFFE53935);
      case PlaceCategory.event:
        return const Color(0xFF8E24AA);
    }
  }

  List<Marker> _buildPlaceMarkers(List<Place> places) {
    if (_currentZoom < 6) return _clusterPlaces(places);
    return places.map((p) {
      final sel = _selPlace?.id == p.id;
      return Marker(
        point: LatLng(p.lat, p.lng),
        width: sel ? 54 : 44,
        height: sel ? 68 : 54,
        child: GestureDetector(
          onTap: () => _onSelPlace(p),
          child: _PlaceMarker(
              place: p, color: _catColor(p.category), selected: sel),
        ),
      );
    }).toList();
  }

  List<Marker> _buildSvcMarkers(List<TripService> svcs) {
    if (_currentZoom < 6) return [];
    return svcs.where((s) => s.lat != null).map((sv) {
      final sel = _selSvc?.id == sv.id;
      return Marker(
        point: LatLng(sv.lat!, sv.lng!),
        width: sel ? 54 : 44,
        height: sel ? 54 : 44,
        child: GestureDetector(
          onTap: () => _onSelSvc(sv),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutBack,
            decoration: BoxDecoration(
                color: sel ? kDeadSeaBlue : Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: kDeadSeaBlue, width: sel ? 0 : 2.5),
                boxShadow: [
                  BoxShadow(
                      color: kDeadSeaBlue.withOpacity(sel ? 0.5 : 0.2),
                      blurRadius: sel ? 16 : 6)
                ]),
            child: Icon(Icons.build_rounded,
                color: sel ? Colors.white : kDeadSeaBlue,
                size: sel ? 22 : 17),
          ),
        ),
      );
    }).toList();
  }

  List<Marker> _clusterPlaces(List<Place> places) {
    final grid = _currentZoom < 5 ? 3.0 : 1.5;
    final Map<String, List<Place>> cells = {};
    for (final p in places) {
      final key = '${(p.lat / grid).floor()}_${(p.lng / grid).floor()}';
      cells.putIfAbsent(key, () => []).add(p);
    }
    return cells.entries.map((e) {
      final g = e.value;
      final lat = g.map((p) => p.lat).reduce((a, b) => a + b) / g.length;
      final lng = g.map((p) => p.lng).reduce((a, b) => a + b) / g.length;
      return Marker(
        point: LatLng(lat, lng),
        width: 46,
        height: 46,
        child: GestureDetector(
          onTap: () {
            _mapCtrl.move(LatLng(lat, lng), _mapCtrl.camera.zoom + 2.5);
          },
          child: Container(
            decoration: BoxDecoration(
                color: const Color(0xFF1A73E8),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: [
                  BoxShadow(
                      color: const Color(0xFF1A73E8).withOpacity(0.45),
                      blurRadius: 12)
                ]),
            child: Center(
                child: Text('${g.length}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w800))),
          ),
        ),
      );
    }).toList();
  }

  double get _usedMb => _savedRegions.entries.where((e) => e.value).fold(0.0,
      (sum, e) {
    final region = _kAllRegions.where((r) => r.name == e.key).firstOrNull;
    return sum + (region?.mb ?? 0);
  });

  List<String> _tileUrlsForRegion(_Region r, bool isDark) {
    final urls = <String>[];
    final template = isDark ? _kTileDark : _kTileLight;
    const subdomains = ['a', 'b', 'c', 'd'];
    for (int z = 9; z <= 15; z++) {
      final minTileX = _lonToTileX(r.sw.longitude, z);
      final maxTileX = _lonToTileX(r.ne.longitude, z);
      final minTileY = _latToTileY(r.ne.latitude, z);
      final maxTileY = _latToTileY(r.sw.latitude, z);
      for (int x = minTileX; x <= maxTileX; x++) {
        for (int y = minTileY; y <= maxTileY; y++) {
          final s = subdomains[(x + y) % subdomains.length];
          urls.add(template
              .replaceAll('{s}', s)
              .replaceAll('{z}', '$z')
              .replaceAll('{x}', '$x')
              .replaceAll('{y}', '$y')
              .replaceAll('{r}', ''));
        }
      }
    }
    return urls;
  }

  int _lonToTileX(double lon, int z) =>
      ((lon + 180) / 360 * math.pow(2, z)).floor();

  int _latToTileY(double lat, int z) {
    final latRad = lat * math.pi / 180;
    return ((1 -
                math.log(math.tan(latRad) + 1 / math.cos(latRad)) / math.pi) /
            2 *
            math.pow(2, z))
        .floor();
  }

  Future<void> _downloadRegion(_Region r, StateSetter setM) async {
    if (_usedMb + r.mb > _kTotalStorageMb) {
      _snack('Not enough space. Delete a region first.', color: kDanger);
      return;
    }
    setM(() {
      _downloading[r.name] = true;
      _dlProgress[r.name] = 0;
    });
    final isDark = context.isDark;
    final urls = _tileUrlsForRegion(r, isDark);
    final total = urls.length;
    int done = 0;
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10);
    const batch = 6;
    for (int i = 0; i < total; i += batch) {
      if (!mounted) {
        client.close();
        return;
      }
      final slice = urls.skip(i).take(batch);
      await Future.wait(slice.map((url) async {
        try {
          final req = await client.getUrl(Uri.parse(url));
          req.headers.set('User-Agent', 'GoJo-App/1.0');
          final res = await req.close();
          await res.drain<void>();
        } catch (_) {}
        done++;
        setM(() => _dlProgress[r.name] = (done / total).clamp(0.0, 1.0));
      }));
    }
    client.close();
    if (!mounted) return;
    setM(() {
      _downloading[r.name] = false;
      _savedRegions[r.name] = true;
    });
    await _persistSavedRegions();
    _snack('${r.name} saved — ${r.mb.toStringAsFixed(0)} MB',
        color: const Color(0xFF22C55E));
  }

  Future<void> _deleteRegion(_Region r, StateSetter setM) async {
    setM(() {
      _savedRegions[r.name] = false;
      _dlProgress.remove(r.name);
    });
    await _persistSavedRegions();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final places = _places(state);
    final svcs = _svcs(state);
    final results = _searchResults(state);
    final hasSel = _selPlace != null || _selSvc != null;
    final hasRoute = _routePts.isNotEmpty;
    final isDark = context.isDark;

    return Scaffold(
      backgroundColor: context.bg,
      resizeToAvoidBottomInset: false,
      body: Stack(children: [
       
        FlutterMap(
          mapController: _mapCtrl,
          options: MapOptions(
            initialCenter: widget.focusPoint ?? _kCenter,
            initialZoom: widget.focusPoint != null ? 15 : 7,
            minZoom: 4,
            maxZoom: 18,
            
            onPositionChanged: (pos, _) {
              final z = pos.zoom;
              if ((z - _currentZoom).abs() > 0.1) {
                setState(() => _currentZoom = z);
              }
            },
            
            onTap: (_, __) {
              if (_justTappedMarker) {
                _justTappedMarker = false;
                return;
              }
              _clearSel();
              setState(() => _geoMode = false);
            },
          ),
          children: [
            TileLayer(
              urlTemplate: isDark ? _kTileDark : _kTileLight,
              subdomains: const ['a', 'b', 'c', 'd'],
              userAgentPackageName: 'com.gojo.app',
              maxZoom: 19,
              retinaMode: RetinaMode.isHighDensity(context),
              tileProvider: _tileStore != null
                  ? CachedTileProvider(
                      store: _tileStore!,
                      maxStale: const Duration(days: 365),
                    )
                  : NetworkTileProvider(),
              errorTileCallback: (_, __, ___) {},
            ),
            if (_pathHistory.length > 1)
              PolylineLayer(polylines: [
                Polyline(
                  points: _pathHistory,
                  strokeWidth: 4,
                  color: const Color(0xFF1A73E8).withOpacity(0.5),
                  borderStrokeWidth: 1.5,
                  borderColor: Colors.white.withOpacity(0.6),
                ),
              ]),
            if (hasRoute)
              PolylineLayer(polylines: [
                Polyline(
                    points: _routePts,
                    strokeWidth: 10,
                    color: Colors.white.withOpacity(0.7)),
                Polyline(
                    points: _routePts,
                    strokeWidth: 6,
                    color: const Color(0xFF1A73E8)),
              ]),
            CircleLayer(circles: [
              CircleMarker(
                point: _myLoc,
                radius: (_accuracy * 2.5).clamp(10, 80),
                useRadiusInMeter: false,
                color: const Color(0xFF1A73E8).withOpacity(0.10),
                borderColor: const Color(0xFF1A73E8).withOpacity(0.35),
                borderStrokeWidth: 1,
              ),
            ]),
            MarkerLayer(markers: [
              Marker(
                  point: _myLoc,
                  width: 28,
                  height: 28,
                  child: _MyLocDot(tracking: _tracking)),
            ]),
            if (widget.focusPoint != null)
              MarkerLayer(markers: [
                Marker(
                    point: widget.focusPoint!,
                    width: 44,
                    height: 58,
                    child: _PinMarker(color: kAccent)),
              ]),
            if (_routeDest != null)
              MarkerLayer(markers: [
                Marker(
                    point: _routeDest!,
                    width: 44,
                    height: 58,
                    child: _PinMarker(color: const Color(0xFF1A73E8))),
              ]),
            MarkerLayer(markers: _buildPlaceMarkers(places)),
            MarkerLayer(markers: _buildSvcMarkers(svcs)),
          ],
        ),

        // ── Top gradient ───────────────────────────────────────────────
        Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
                height: 180,
                decoration: BoxDecoration(
                    gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                      context.bg.withOpacity(0.95),
                      context.bg.withOpacity(0)
                    ])))),

        SafeArea(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
            child: Row(children: [
              _fab(context,
                  child: Icon(Icons.arrow_back_ios_new_rounded,
                      size: 16, color: context.primary),
                  onTap: () => Navigator.pop(context)),
              const SizedBox(width: 10),
              Expanded(
                  child: GestureDetector(
                onTap: () => setState(() => _geoMode = true),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  decoration: BoxDecoration(
                      color: context.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: context.divider),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withOpacity(0.09),
                            blurRadius: 10,
                            offset: const Offset(0, 3))
                      ]),
                  child: Row(children: [
                    Icon(Icons.search_rounded,
                        size: 18, color: context.secondary),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(
                      _searchQ.isNotEmpty
                          ? _searchQ
                          : 'Search Jordan places…',
                      style: TextStyle(
                          color: _searchQ.isNotEmpty
                              ? context.primary
                              : context.secondary,
                          fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    )),
                    if (_searchQ.isNotEmpty)
                      GestureDetector(
                          onTap: () {
                            _searchCtrl.clear();
                            setState(() => _searchQ = '');
                          },
                          child: Icon(Icons.close_rounded,
                              size: 16, color: context.secondary)),
                  ]),
                ),
              )),
              const SizedBox(width: 10),
              _fab(context,
                  child: Icon(Icons.layers_outlined,
                      size: 18, color: context.primary),
                  onTap: () =>
                      setState(() => _showRegions = !_showRegions)),
            ]),
          ),

          // Geo search overlay
          if (_geoMode)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 0),
              child: MapSearchOverlay(
                onPlaceSelected: (geo) {
                  setState(() {
                    _geoMode = false;
                    _searchQ = geo.shortName;
                  });
                  _mapCtrl.move(LatLng(geo.lat, geo.lng), 16);
                },
                onClose: () => setState(() => _geoMode = false),
              ),
            ),

          if (!_geoMode && _searchQ.isNotEmpty && results.isNotEmpty)
            Container(
              margin: const EdgeInsets.fromLTRB(14, 6, 14, 0),
              constraints: const BoxConstraints(maxHeight: 200),
              decoration: BoxDecoration(
                  color: context.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: context.divider),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 14)
                  ]),
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 4),
                itemCount: results.length.clamp(0, 6),
                separatorBuilder: (_, __) =>
                    Divider(height: 1, color: context.divider),
                itemBuilder: (_, i) {
                  final item = results[i];
                  if (item is Place)
                    return ListTile(
                        dense: true,
                        leading: placeThumb(item, context,
                            size: 36, radius: 8),
                        title: Text(item.name,
                            style: TextStyle(
                                color: context.primary,
                                fontSize: 13,
                                fontWeight: FontWeight.w600)),
                        subtitle: Text(item.location,
                            style: TextStyle(
                                color: context.secondary, fontSize: 11)),
                        trailing: Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                                color: _catColor(item.category),
                                shape: BoxShape.circle)),
                        onTap: () => _onSelPlace(item));
                  final sv = item as TripService;
                  return ListTile(
                      dense: true,
                      leading:
                          serviceThumb(sv, context, size: 36, radius: 8),
                      title: Text(sv.name,
                          style: TextStyle(
                              color: context.primary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600)),
                      subtitle: Text(sv.location,
                          style: TextStyle(
                              color: context.secondary, fontSize: 11)),
                      trailing: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                              color: kDeadSeaBlue, shape: BoxShape.circle)),
                      onTap: () {
                        if (sv.lat != null) _onSelSvc(sv);
                      });
                },
              ),
            ),

          // Region picker
          if (_showRegions)
            Container(
              margin: const EdgeInsets.fromLTRB(14, 8, 14, 0),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: context.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: context.divider),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 16)
                  ]),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _kAllRegions
                    .map((r) => GestureDetector(
                          onTap: () {
                            _mapCtrl.move(r.center, r.zoom);
                            setState(() => _showRegions = false);
                            HapticFeedback.lightImpact();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                                color: _savedRegions[r.name] == true
                                    ? kAccent.withOpacity(0.12)
                                    : context.bg,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                    color: _savedRegions[r.name] == true
                                        ? kAccent
                                        : context.divider)),
                            child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (_savedRegions[r.name] == true)
                                    const Padding(
                                        padding:
                                            EdgeInsets.only(right: 4),
                                        child: Icon(
                                            Icons.offline_pin_rounded,
                                            color: kAccent,
                                            size: 13)),
                                  Text(r.name,
                                      style: TextStyle(
                                          color:
                                              _savedRegions[r.name] == true
                                                  ? kAccent
                                                  : context.primary,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600)),
                                ]),
                          ),
                        ))
                    .toList(),
              ),
            ),

          const SizedBox(height: 8),

          // Filter chips
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              children: _Filter.values.map((f) {
                const labels = {
                  _Filter.all: 'All',
                  _Filter.attractions: 'Sights',
                  _Filter.hotels: 'Hotels',
                  _Filter.restaurants: 'Food',
                  _Filter.services: 'Services',
                  _Filter.events: 'Events',
                };
                const icons = {
                  _Filter.all: Icons.layers_rounded,
                  _Filter.attractions: Icons.account_balance_rounded,
                  _Filter.hotels: Icons.hotel_rounded,
                  _Filter.restaurants: Icons.restaurant_rounded,
                  _Filter.services: Icons.build_rounded,
                  _Filter.events: Icons.event_rounded,
                };
                final sel = _filter == f;
                return GestureDetector(
                  onTap: () => setState(() => _filter = f),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                        color: sel
                            ? const Color(0xFF1A73E8)
                            : context.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: sel
                                ? const Color(0xFF1A73E8)
                                : context.divider),
                        boxShadow: sel
                            ? [
                                const BoxShadow(
                                    color: Color(0x441A73E8),
                                    blurRadius: 8)
                              ]
                            : null),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(icons[f],
                          size: 13,
                          color: sel ? Colors.white : context.secondary),
                      const SizedBox(width: 5),
                      Text(labels[f]!,
                          style: TextStyle(
                              color:
                                  sel ? Colors.white : context.primary,
                              fontSize: 12,
                              fontWeight: sel
                                  ? FontWeight.w700
                                  : FontWeight.w400)),
                    ]),
                  ),
                );
              }).toList(),
            ),
          ),
        ])),

        Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
                height: 220,
                decoration: BoxDecoration(
                    gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                      context.bg.withOpacity(0.6),
                      Colors.transparent
                    ])))),

        if (hasRoute)
          Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                  child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 70, 14, 0),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
                  decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [
                        Color(0xFF1A73E8),
                        Color(0xFF0D60D8)
                      ]),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                            color:
                                const Color(0xFF1A73E8).withOpacity(0.4),
                            blurRadius: 16)
                      ]),
                  child: Row(children: [
                    const Icon(Icons.navigation_rounded,
                        color: Colors.white, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(_routeName,
                              style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500)),
                          Row(children: [
                            Text(_routeDur,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800)),
                            const SizedBox(width: 10),
                            Text(_routeDist,
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 13)),
                          ]),
                        ])),
                    GestureDetector(
                        onTap: _clearRoute,
                        child: Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.18),
                                shape: BoxShape.circle),
                            child: const Icon(Icons.close_rounded,
                                color: Colors.white, size: 16))),
                  ]),
                ),
              ))),

        
        if (_loadingRoute)
          Positioned.fill(
              child: ColoredBox(
                  color: Colors.black.withOpacity(0.12),
                  child: Center(
                      child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 22, vertical: 14),
                    decoration: BoxDecoration(
                        color: context.card,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withOpacity(0.15),
                              blurRadius: 20)
                        ]),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Color(0xFF1A73E8))),
                      const SizedBox(width: 12),
                      Text('Finding best route…',
                          style: TextStyle(
                              color: context.primary,
                              fontSize: 14,
                              fontWeight: FontWeight.w600)),
                    ]),
                  )))),

       
        if (!hasSel)
          Positioned(
              bottom: hasRoute ? 36 : 28,
              right: 14,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                GestureDetector(
                  onTap: _tracking ? _stopTracking : _centerOnMe,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                        color: _tracking
                            ? const Color(0xFF1A73E8)
                            : context.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: _tracking
                                ? const Color(0xFF1A73E8)
                                : context.divider),
                        boxShadow: [
                          BoxShadow(
                              color: _tracking
                                  ? const Color(0xFF1A73E8).withOpacity(0.4)
                                  : Colors.black.withOpacity(0.1),
                              blurRadius: 12,
                              offset: const Offset(0, 3))
                        ]),
                    child: Icon(
                        _tracking
                            ? Icons.my_location_rounded
                            : Icons.location_searching_rounded,
                        size: 20,
                        color:
                            _tracking ? Colors.white : context.primary),
                  ),
                ),
                const SizedBox(height: 10),
                _fab(context,
                    child: Icon(Icons.download_rounded,
                        size: 18, color: context.primary),
                    onTap: () => _showOfflineSheet(context)),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                      color: context.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: context.divider),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 8)
                      ]),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text('${places.length + svcs.length}',
                        style: const TextStyle(
                            color: Color(0xFF1A73E8),
                            fontSize: 18,
                            fontWeight: FontWeight.w900)),
                    Text('pins',
                        style: TextStyle(
                            color: context.secondary,
                            fontSize: 9,
                            fontWeight: FontWeight.w500)),
                  ]),
                ),
              ])),

        // Accuracy badge
        if (_tracking && !hasSel)
          Positioned(
              bottom: 28,
              left: 14,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                    color: const Color(0xFF1A73E8),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                          color: const Color(0xFF1A73E8).withOpacity(0.35),
                          blurRadius: 10)
                    ]),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.gps_fixed_rounded,
                      color: Colors.white, size: 13),
                  const SizedBox(width: 5),
                  Text('±${_accuracy.toStringAsFixed(0)} m',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700)),
                ]),
              )),

        if (_selPlace != null)
          Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: SlideTransition(
                position:
                    Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
                        .animate(_popupSlide),
                child: _PlacePopup(
                  place: _selPlace!,
                  color: _catColor(_selPlace!.category),
                  onClose: _clearSel,
                  onView: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              PlaceDetailScreen(place: _selPlace!))),
                  onDirections: () => _routeTo(
                      LatLng(_selPlace!.lat, _selPlace!.lng),
                      _selPlace!.name),
                ),
              )),

        if (_selSvc != null)
          Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: SlideTransition(
                position:
                    Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
                        .animate(_popupSlide),
                child: _ServicePopup(
                  svc: _selSvc!,
                  onClose: _clearSel,
                  onView: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => ServicesScreen(
                                highlightTags: context
                                        .read<AppState>()
                                        .user
                                        ?.interests ??
                                    [],
                                initialService: _selSvc,
                              ))),
                  onDirections: () {
                    if (_selSvc!.lat != null)
                      _routeTo(
                          LatLng(_selSvc!.lat!, _selSvc!.lng!), _selSvc!.name);
                  },
                ),
              )),
      ]),
    );
  }

  Widget _fab(BuildContext ctx,
          {required Widget child, required VoidCallback onTap}) =>
      GestureDetector(
          onTap: onTap,
          child: Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
                color: ctx.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: ctx.divider),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.09),
                      blurRadius: 10,
                      offset: const Offset(0, 3))
                ]),
            child: Center(child: child),
          ));

  void _showOfflineSheet(BuildContext context) {
    final center = _mapCtrl.camera.center;
    final sorted = List<_Region>.from(_kAllRegions)
      ..sort((a, b) {
        final aSaved = _savedRegions[a.name] == true ? 0 : 1;
        final bSaved = _savedRegions[b.name] == true ? 0 : 1;
        if (aSaved != bSaved) return aSaved - bSaved;
        double dist(LatLng x) => math.sqrt(
            math.pow(x.latitude - center.latitude, 2) +
                math.pow(x.longitude - center.longitude, 2));
        return dist(a.center).compareTo(dist(b.center));
      });

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => StatefulBuilder(builder: (ctx, setM) {
        final usedMb = _savedRegions.entries.where((e) => e.value).fold(0.0,
            (sum, e) {
          final region =
              _kAllRegions.where((r) => r.name == e.key).firstOrNull;
          return sum + (region?.mb ?? 0);
        });
        final pct = (usedMb / _kTotalStorageMb).clamp(0.0, 1.0);

        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          maxChildSize: 0.95,
          minChildSize: 0.4,
          builder: (_, sc) => Container(
            decoration: BoxDecoration(
                color: context.card,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24))),
            child: Column(children: [
              Center(
                  child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                          color: context.divider,
                          borderRadius: BorderRadius.circular(2)))),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Row(children: [
                  Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                          color: kAccent.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.download_rounded,
                          color: kAccent, size: 22)),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text('Offline Maps',
                            style: TextStyle(
                                color: context.primary,
                                fontSize: 18,
                                fontWeight: FontWeight.w800)),
                        Text('All Jordan cities — use without internet',
                            style: TextStyle(
                                color: context.secondary, fontSize: 12)),
                      ])),
                  GestureDetector(
                      onTap: () async {
                        for (final r in _kAllRegions) {
                          if (_savedRegions[r.name] != true &&
                              !(_downloading[r.name] ?? false)) {
                            await _downloadRegion(r, setM);
                          }
                        }
                      },
                      child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                              color: kAccent.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: kAccent.withOpacity(0.3))),
                          child: const Text('Save All',
                              style: TextStyle(
                                  color: kAccent,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700)))),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Text('Storage',
                            style: TextStyle(
                                color: context.primary,
                                fontSize: 12,
                                fontWeight: FontWeight.w700)),
                        const Spacer(),
                        Text(
                            '${usedMb.toStringAsFixed(0)} / ${_kTotalStorageMb.toStringAsFixed(0)} MB',
                            style: TextStyle(
                                color: context.secondary, fontSize: 12)),
                      ]),
                      const SizedBox(height: 6),
                      Stack(children: [
                        Container(
                            height: 8,
                            decoration: BoxDecoration(
                                color: context.divider,
                                borderRadius: BorderRadius.circular(4))),
                        AnimatedFractionallySizedBox(
                          duration: const Duration(milliseconds: 400),
                          widthFactor: pct,
                          child: Container(
                              height: 8,
                              decoration: BoxDecoration(
                                  gradient: LinearGradient(colors: [
                                    pct > 0.8 ? kDanger : kAccent,
                                    pct > 0.8
                                        ? kDanger.withOpacity(0.7)
                                        : kAccent.withOpacity(0.7),
                                  ]),
                                  borderRadius: BorderRadius.circular(4))),
                        ),
                      ]),
                      if (pct > 0.8)
                        const Padding(
                            padding: EdgeInsets.only(top: 4),
                            child: Text('Running low on space',
                                style: TextStyle(
                                    color: kDanger, fontSize: 11))),
                    ]),
              ),
              Expanded(
                  child: ListView.builder(
                controller: sc,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                itemCount: sorted.length,
                itemBuilder: (_, i) {
                  final r = sorted[i];
                  final isSaved = _savedRegions[r.name] == true;
                  final isDownloading = _downloading[r.name] == true;
                  final progress = _dlProgress[r.name] ?? 0.0;
                  final wouldExceed =
                      usedMb + r.mb > _kTotalStorageMb && !isSaved;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: isSaved
                            ? kAccent.withOpacity(0.05)
                            : context.card,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: isSaved
                                ? kAccent.withOpacity(0.2)
                                : isDownloading
                                    ? kAccent.withOpacity(0.3)
                                    : context.divider)),
                    child: Column(children: [
                      Row(children: [
                        Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                                color: isSaved
                                    ? kAccent.withOpacity(0.1)
                                    : context.bg,
                                borderRadius: BorderRadius.circular(10)),
                            child: Icon(
                                isSaved
                                    ? Icons.offline_pin_rounded
                                    : Icons.map_outlined,
                                color: isSaved ? kAccent : context.secondary,
                                size: 20)),
                        const SizedBox(width: 12),
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text(r.name,
                                  style: TextStyle(
                                      color: context.primary,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14)),
                              const SizedBox(height: 1),
                              Row(children: [
                                Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 1),
                                    decoration: BoxDecoration(
                                        color: context.bg,
                                        borderRadius:
                                            BorderRadius.circular(6)),
                                    child: Text(r.governorate,
                                        style: TextStyle(
                                            color: context.secondary,
                                            fontSize: 10))),
                                const SizedBox(width: 6),
                                Text('${r.mb.toStringAsFixed(0)} MB',
                                    style: TextStyle(
                                        color: isSaved
                                            ? kAccent
                                            : context.secondary,
                                        fontSize: 11,
                                        fontWeight: isSaved
                                            ? FontWeight.w700
                                            : FontWeight.w400)),
                              ]),
                            ])),
                        if (isSaved)
                          GestureDetector(
                              onTap: () => _deleteRegion(r, setM),
                              child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 7),
                                  decoration: BoxDecoration(
                                      color: kDanger.withOpacity(0.08),
                                      borderRadius:
                                          BorderRadius.circular(8),
                                      border: Border.all(
                                          color:
                                              kDanger.withOpacity(0.2))),
                                  child: const Text('Delete',
                                      style: TextStyle(
                                          color: kDanger,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600))))
                        else if (isDownloading)
                          SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                  value: progress,
                                  strokeWidth: 2.5,
                                  color: kAccent))
                        else
                          GestureDetector(
                              onTap: wouldExceed
                                  ? () => _snack(
                                      'Not enough space. Delete a region first.',
                                      color: kDanger)
                                  : () => _downloadRegion(r, setM),
                              child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 7),
                                  decoration: BoxDecoration(
                                      color: wouldExceed
                                          ? context.divider
                                          : kAccent.withOpacity(0.1),
                                      borderRadius:
                                          BorderRadius.circular(8),
                                      border: Border.all(
                                          color: wouldExceed
                                              ? context.divider
                                              : kAccent.withOpacity(0.3))),
                                  child: Text('Save',
                                      style: TextStyle(
                                          color: wouldExceed
                                              ? context.secondary
                                              : kAccent,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700)))),
                      ]),
                      if (isDownloading) ...[
                        const SizedBox(height: 10),
                        Row(children: [
                          Expanded(
                              child: ClipRRect(
                                  borderRadius: BorderRadius.circular(3),
                                  child: LinearProgressIndicator(
                                      value: progress,
                                      minHeight: 5,
                                      backgroundColor: context.divider,
                                      valueColor:
                                          const AlwaysStoppedAnimation<
                                              Color>(kAccent)))),
                          const SizedBox(width: 8),
                          Text('${(progress * 100).toStringAsFixed(0)}%',
                              style: const TextStyle(
                                  color: kAccent,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700)),
                        ]),
                      ],
                    ]),
                  );
                },
              )),
            ]),
          ),
        );
      }),
    );
  }
}

class _MyLocDot extends StatefulWidget {
  final bool tracking;
  const _MyLocDot({required this.tracking});
  @override
  State<_MyLocDot> createState() => _MyLocDotState();
}

class _MyLocDotState extends State<_MyLocDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ac;
  @override
  void initState() {
    super.initState();
    _ac = AnimationController(
        vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _ac,
        builder: (_, __) => Stack(alignment: Alignment.center, children: [
          if (widget.tracking)
            Container(
                width: 28 + _ac.value * 10,
                height: 28 + _ac.value * 10,
                decoration: BoxDecoration(
                    color: const Color(0xFF1A73E8)
                        .withOpacity(0.12 * (1 - _ac.value * 0.4)),
                    shape: BoxShape.circle)),
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
                color: const Color(0xFF1A73E8),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: [
                  BoxShadow(
                      color: const Color(0xFF1A73E8).withOpacity(0.5),
                      blurRadius: 10)
                ]),
          ),
        ]),
      );
}

class _PlaceMarker extends StatefulWidget {
  final Place place;
  final Color color;
  final bool selected;
  const _PlaceMarker(
      {required this.place, required this.color, required this.selected});
  @override
  State<_PlaceMarker> createState() => _PlaceMarkerState();
}

class _PlaceMarkerState extends State<_PlaceMarker>
    with SingleTickerProviderStateMixin {
  late AnimationController _ac;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 350));
    _scale = CurvedAnimation(parent: _ac, curve: Curves.elasticOut);
    if (widget.selected) _ac.value = 1;
  }

  @override
  void didUpdateWidget(_PlaceMarker old) {
    super.didUpdateWidget(old);
    if (widget.selected && !old.selected) _ac.forward(from: 0);
    else if (!widget.selected && old.selected) _ac.reverse();
  }

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sz = widget.selected ? 52.0 : 40.0;
    return ScaleTransition(
      scale: Tween<double>(begin: 0.8, end: 1.0).animate(_scale),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: sz,
          height: sz,
          decoration: BoxDecoration(
              color: widget.color,
              shape: BoxShape.circle,
              border: Border.all(
                  color: Colors.white, width: widget.selected ? 3 : 2.5),
              boxShadow: [
                BoxShadow(
                    color: widget.color
                        .withOpacity(widget.selected ? 0.55 : 0.3),
                    blurRadius: widget.selected ? 20 : 8,
                    spreadRadius: widget.selected ? 1 : 0)
              ]),
          child: ClipOval(child: _photo()),
        ),
        Container(
            width: 3,
            height: widget.selected ? 11 : 8,
            decoration: BoxDecoration(
                gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [widget.color, widget.color.withOpacity(0)]),
                borderRadius:
                    const BorderRadius.vertical(bottom: Radius.circular(2)))),
      ]),
    );
  }

  Widget _photo() {
    if (widget.place.photoUrls.isNotEmpty) {
      final url = widget.place.photoUrls.first;
      return url.startsWith('http')
          ? Image.network(url,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _fallback())
          : Image.file(File(url),
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _fallback());
    }
    return _fallback();
  }

  Widget _fallback() {
    final icons = {
      PlaceCategory.attraction: Icons.account_balance_rounded,
      PlaceCategory.hotel: Icons.hotel_rounded,
      PlaceCategory.restaurant: Icons.restaurant_rounded,
      PlaceCategory.event: Icons.event_rounded,
    };
    return Center(
        child: Icon(icons[widget.place.category] ?? Icons.place_rounded,
            color: Colors.white, size: widget.selected ? 24 : 18));
  }
}

class _PinMarker extends StatelessWidget {
  final Color color;
  const _PinMarker({required this.color});
  @override
  Widget build(BuildContext context) =>
      Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2.5),
                boxShadow: [
                  BoxShadow(color: color.withOpacity(0.5), blurRadius: 14)
                ]),
            child: const Icon(Icons.place_rounded,
                color: Colors.white, size: 20)),
        Container(
            width: 3,
            height: 10,
            decoration: BoxDecoration(
                gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [color, color.withOpacity(0)]))),
      ]);
}

bool _isNet(String s) => s.startsWith('http');

class _PlacePopup extends StatelessWidget {
  final Place place;
  final Color color;
  final VoidCallback onClose, onView, onDirections;
  const _PlacePopup(
      {required this.place,
      required this.color,
      required this.onClose,
      required this.onView,
      required this.onDirections});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 20),
        decoration: BoxDecoration(
            color: context.card,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: context.divider),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.14),
                  blurRadius: 24,
                  offset: const Offset(0, -4))
            ]),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Center(
              child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(top: 10),
                  decoration: BoxDecoration(
                      color: context.divider,
                      borderRadius: BorderRadius.circular(2)))),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 16),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Photo
              ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: SizedBox(
                      width: 72,
                      height: 72,
                      child: place.photoUrls.isNotEmpty
                          ? (_isNet(place.photoUrls.first)
                              ? Image.network(place.photoUrls.first,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                      color: color.withOpacity(0.12),
                                      child: Icon(Icons.image_outlined,
                                          color: color, size: 28)))
                              : Image.file(File(place.photoUrls.first),
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                      color: color.withOpacity(0.12))))
                          : Container(
                              color: color.withOpacity(0.12),
                              child: Icon(Icons.place_rounded,
                                  color: color, size: 30)))),
              const SizedBox(width: 12),
              // Info
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                            color: color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6)),
                        child: Text(_catLabel(place.category),
                            style: TextStyle(
                                color: color,
                                fontSize: 9,
                                fontWeight: FontWeight.w800))),
                    const SizedBox(height: 5),
                    Text(place.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: context.primary,
                            fontSize: 16,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Row(children: [
                      Icon(Icons.place_rounded,
                          size: 11, color: context.secondary),
                      const SizedBox(width: 3),
                      Expanded(
                          child: Text(place.location,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: context.secondary, fontSize: 11))),
                    ]),
                    const SizedBox(height: 4),
                    Row(children: [
                      const Icon(Icons.star_rounded,
                          size: 13, color: kWarning),
                      const SizedBox(width: 3),
                      Text(place.rating.toStringAsFixed(1),
                          style: TextStyle(
                              color: context.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.w700)),
                      Text('  (${place.reviewCount})',
                          style: TextStyle(
                              color: context.secondary, fontSize: 11)),
                      if (place.hours != null) ...[
                        const SizedBox(width: 8),
                        Icon(Icons.schedule_rounded,
                            size: 11, color: context.secondary),
                        const SizedBox(width: 2),
                        Expanded(
                            child: Text(place.hours!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    color: context.secondary,
                                    fontSize: 11))),
                      ],
                    ]),
                  ])),
              const SizedBox(width: 8),
              // Buttons
              Column(mainAxisSize: MainAxisSize.min, children: [
                GestureDetector(
                    onTap: onClose,
                    child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(Icons.close_rounded,
                            color: context.secondary, size: 18))),
                const SizedBox(height: 8),
                SizedBox(
                    width: 80,
                    child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: color,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding:
                                const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10))),
                        onPressed: onView,
                        child: const Text('View',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700)))),
                const SizedBox(height: 6),
                SizedBox(
                    width: 80,
                    child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF1A73E8),
                            side: const BorderSide(
                                color: Color(0xFF1A73E8)),
                            padding:
                                const EdgeInsets.symmetric(vertical: 7),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10))),
                        onPressed: onDirections,
                        child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.directions_rounded, size: 12),
                              SizedBox(width: 3),
                              Text('Go',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700)),
                            ]))),
              ]),
            ]),
          ),
        ]),
      );

  String _catLabel(PlaceCategory c) {
    switch (c) {
      case PlaceCategory.attraction:
        return 'ATTRACTION';
      case PlaceCategory.hotel:
        return 'HOTEL';
      case PlaceCategory.restaurant:
        return 'RESTAURANT';
      case PlaceCategory.event:
        return 'EVENT';
    }
  }
}

class _ServicePopup extends StatelessWidget {
  final TripService svc;
  final VoidCallback onClose, onView, onDirections;
  const _ServicePopup(
      {required this.svc,
      required this.onClose,
      required this.onView,
      required this.onDirections});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 20),
        decoration: BoxDecoration(
            color: context.card,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: context.divider),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.14),
                  blurRadius: 24,
                  offset: const Offset(0, -4))
            ]),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Center(
              child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(top: 10),
                  decoration: BoxDecoration(
                      color: context.divider,
                      borderRadius: BorderRadius.circular(2)))),
          Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 12, 16),
              child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    serviceThumb(svc, context, size: 72, radius: 14),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                  color: kDeadSeaBlue.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6)),
                              child: Text(
                                  (svc.customCategory.isNotEmpty
                                          ? svc.customCategory
                                          : svc.category.name)
                                      .toUpperCase(),
                                  style: const TextStyle(
                                      color: kDeadSeaBlue,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800))),
                          const SizedBox(height: 5),
                          Text(svc.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: context.primary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800)),
                          const SizedBox(height: 2),
                          Text('by ${svc.ownerName}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: context.secondary, fontSize: 11)),
                          if (svc.priceFrom != null) ...[
                            const SizedBox(height: 3),
                            Text(
                                'From JD${svc.priceFrom!.toInt()} ${svc.priceUnit ?? ''}',
                                style: const TextStyle(
                                    color: kAccentDim,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700)),
                          ],
                        ])),
                    const SizedBox(width: 8),
                    Column(mainAxisSize: MainAxisSize.min, children: [
                      GestureDetector(
                          onTap: onClose,
                          child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: Icon(Icons.close_rounded,
                                  color: context.secondary, size: 18))),
                      const SizedBox(height: 8),
                      SizedBox(
                          width: 80,
                          child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: kDeadSeaBlue,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 8),
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(10))),
                              onPressed: onView,
                              child: const Text('View',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700)))),
                      const SizedBox(height: 6),
                      SizedBox(
                          width: 80,
                          child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF1A73E8),
                                  side: const BorderSide(
                                      color: Color(0xFF1A73E8)),
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 7),
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(10))),
                              onPressed: onDirections,
                              child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.center,
                                  children: const [
                                    Icon(Icons.directions_rounded,
                                        size: 12),
                                    SizedBox(width: 3),
                                    Text('Go',
                                        style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700)),
                                  ]))),
                    ]),
                  ])),
        ]),
      );
}