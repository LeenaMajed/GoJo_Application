import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../theme.dart';

class GeoPlace {
  final String shortName, displayName, type;
  final double lat, lng;
  const GeoPlace({
    required this.shortName, required this.displayName,
    required this.type, required this.lat, required this.lng,
  });
}

class NominatimService {
  static final Map<String, List<GeoPlace>> _cache = {};
  static Timer? _debounce;

  static Future<List<GeoPlace>> search(String q) async {
    final key = q.trim().toLowerCase();
    if (_cache.containsKey(key)) return _cache[key]!;
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/search'
        '?q=${Uri.encodeComponent(q)}'
        '&format=json&limit=8&countrycodes=jo'
        '&addressdetails=1&accept-language=en');
      final req = await HttpClient().getUrl(uri);
      req.headers
        ..set('User-Agent', 'GoJo-App/1.0 (jordan-tourism)')
        ..set('Accept-Language', 'en');
      final res = await req.close();
      if (res.statusCode != 200) return [];
      final body = await res.transform(utf8.decoder).join();
      final list = (jsonDecode(body) as List).cast<Map<String, dynamic>>();
      final results = list.map((j) {
        final addr = j['address'] as Map<String, dynamic>? ?? {};
        final type = (j['type'] as String? ?? 'place');
        final name = addr['tourism'] ?? addr['amenity'] ?? addr['road'] ??
            addr['suburb'] ?? addr['city_district'] ?? addr['city'] ??
            addr['town'] ?? addr['village'] ?? j['display_name'];
        return GeoPlace(
          shortName: name as String,
          displayName: j['display_name'] as String,
          type: type,
          lat: double.parse(j['lat'] as String),
          lng: double.parse(j['lon'] as String),
        );
      }).toList();
      _cache[key] = results;
      return results;
    } catch (_) { return []; }
  }

  static Future<String?> reverse(double lat, double lng) async {
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse'
        '?lat=$lat&lon=$lng&format=json&accept-language=en');
      final req = await HttpClient().getUrl(uri);
      req.headers
        ..set('User-Agent', 'GoJo-App/1.0')
        ..set('Accept-Language', 'en');
      final res = await req.close();
      final body = await res.transform(utf8.decoder).join();
      final data = jsonDecode(body) as Map;
      final addr = data['address'] as Map? ?? {};
      return addr['road'] ?? addr['suburb'] ?? addr['city_district'] ??
          addr['city'] ?? data['display_name'];
    } catch (_) { return null; }
  }

  /// Debounced search — waits 400ms after last keystroke
  static void debounced(String q, void Function(String) callback) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () => callback(q));
  }
}

class LocationPickerSheet extends StatefulWidget {
  final double? initialLat;
  final double? initialLng;
  final String? initialLabel;

  const LocationPickerSheet({super.key, this.initialLat, this.initialLng, this.initialLabel});

  static Future<({double lat, double lng, String label})?> show(
    BuildContext context, {double? initialLat, double? initialLng, String? initialLabel}) {
    return showModalBottomSheet<({double lat, double lng, String label})?>(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => LocationPickerSheet(
        initialLat: initialLat, initialLng: initialLng, initialLabel: initialLabel));
  }

  @override
  State<LocationPickerSheet> createState() => _LocationPickerSheetState();
}

class _LocationPickerSheetState extends State<LocationPickerSheet>
    with SingleTickerProviderStateMixin {
  static const _jordan = LatLng(31.95, 35.93);

  final _searchCtrl = TextEditingController();
  final _mapCtrl    = MapController();
  final _focus      = FocusNode();

  double? _lat, _lng;
  String _label = '';
  bool _loading = false;
  bool _reverseGeocoding = false;
  List<GeoPlace> _results = [];
  bool _showResults = false;

  // Pin drop animation
  late AnimationController _pinAnim;
  late Animation<double> _pinBounce;

  @override
  void initState() {
    super.initState();
    _pinAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _pinBounce = CurvedAnimation(parent: _pinAnim, curve: Curves.elasticOut);
    if (widget.initialLat != null) {
      _lat = widget.initialLat;
      _lng = widget.initialLng;
      _label = widget.initialLabel ?? '';
      _searchCtrl.text = _label;
      _pinAnim.value = 1.0;
    }
    _focus.addListener(() {
      if (_focus.hasFocus && _results.isNotEmpty)
        setState(() => _showResults = true);
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose(); _focus.dispose(); _pinAnim.dispose(); super.dispose();
  }

  void _onSearchChanged(String q) {
    if (q.trim().length < 2) {
      setState(() { _results = []; _showResults = false; });
      return;
    }
    setState(() => _loading = true);
    NominatimService.debounced(q, (_) async {
      if (!mounted) return;
      final r = await NominatimService.search(q);
      if (!mounted) return;
      setState(() { _results = r; _loading = false; _showResults = r.isNotEmpty; });
    });
  }

  void _pickResult(GeoPlace p) {
    HapticFeedback.selectionClick();
    _searchCtrl.text = p.shortName;
    _focus.unfocus();
    setState(() { _lat = p.lat; _lng = p.lng; _label = p.shortName; _showResults = false; _results = []; });
    _mapCtrl.move(LatLng(p.lat, p.lng), 16);
    _pinAnim.forward(from: 0);
  }

  Future<void> _onMapTap(LatLng point) async {
    HapticFeedback.lightImpact();
    setState(() { _lat = point.latitude; _lng = point.longitude; _label = ''; _reverseGeocoding = true; });
    _focus.unfocus();
    setState(() => _showResults = false);
    _pinAnim.forward(from: 0);

    final name = await NominatimService.reverse(point.latitude, point.longitude);
    if (!mounted) return;
    setState(() {
      _reverseGeocoding = false;
      if (name != null) { _label = name; _searchCtrl.text = name; }
      else { _label = '${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}'; }
    });
  }

  void _useMyLocation() {
    // Simulated current location (Amman city centre)
    // In production: replace with Geolocator.getCurrentPosition()
    const lat = 31.9539; const lng = 35.9106;
    HapticFeedback.mediumImpact();
    setState(() { _lat = lat; _lng = lng; _label = 'Current Location'; _reverseGeocoding = true; });
    _searchCtrl.text = 'Current Location';
    _mapCtrl.move(const LatLng(lat, lng), 16);
    _pinAnim.forward(from: 0);
    NominatimService.reverse(lat, lng).then((name) {
      if (!mounted) return;
      setState(() {
        _reverseGeocoding = false;
        if (name != null) { _label = name; _searchCtrl.text = name; }
      });
    });
  }

  void _confirm() {
    if (_lat == null) return;
    HapticFeedback.mediumImpact();
    Navigator.pop(context, (lat: _lat!, lng: _lng!, label: _label));
  }

  bool get _hasPin => _lat != null;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.92, minChildSize: 0.5, maxChildSize: 0.95,
      builder: (_, sc) => Container(
        decoration: BoxDecoration(
          color: context.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
        child: Column(children: [
          
          _Header(onClose: () => Navigator.pop(context)),

          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 0),
            child: Column(children: [
              // Search input row
              Row(children: [
                Expanded(child: Container(
                  decoration: BoxDecoration(
                    color: context.bg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _focus.hasFocus ? kAccent : context.divider, width: _focus.hasFocus ? 1.5 : 1)),
                  child: Row(children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: _loading
                          ? const SizedBox(width: 16, height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: kAccent))
                          : Icon(Icons.search_rounded, size: 18, color: context.secondary)),
                    Expanded(child: TextField(
                      controller: _searchCtrl,
                      focusNode: _focus,
                      onChanged: _onSearchChanged,
                      style: TextStyle(color: context.primary, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Search street, area, landmark…',
                        hintStyle: TextStyle(color: context.secondary, fontSize: 14),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 12)),
                    )),
                    if (_searchCtrl.text.isNotEmpty)
                      GestureDetector(
                        onTap: () {
                          _searchCtrl.clear();
                          setState(() { _results = []; _showResults = false; });
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Icon(Icons.close_rounded, size: 18, color: context.secondary))),
                  ]),
                )),
                const SizedBox(width: 8),
                // My location shortcut
                GestureDetector(
                  onTap: _useMyLocation,
                  child: Container(
                    padding: const EdgeInsets.all(11),
                    decoration: BoxDecoration(
                      color: kAccent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: kAccent.withOpacity(0.3))),
                    child: const Icon(Icons.my_location_rounded, color: kAccent, size: 20))),
              ]),
              const SizedBox(height: 2),

              if (_showResults && _results.isNotEmpty)
                Container(
                  constraints: const BoxConstraints(maxHeight: 230),
                  decoration: BoxDecoration(
                    color: context.surface,
                    border: Border.all(color: context.divider),
                    borderRadius: BorderRadius.circular(12)),
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: _results.length,
                    separatorBuilder: (_, __) => Divider(height: 1, color: context.divider),
                    itemBuilder: (_, i) {
                      final r = _results[i];
                      return ListTile(
                        dense: true,
                        leading: _typeIcon(r.type),
                        title: Text(r.shortName, style: TextStyle(
                            color: context.primary, fontSize: 13, fontWeight: FontWeight.w600),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(r.displayName, style: TextStyle(
                            color: context.secondary, fontSize: 11),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        onTap: () => _pickResult(r),
                      );
                    },
                  ),
                ),
            ]),
          ),
          const SizedBox(height: 6),

          Expanded(child: Stack(children: [
            FlutterMap(
              mapController: _mapCtrl,
              options: MapOptions(
                initialCenter: _lat != null ? LatLng(_lat!, _lng!) : _jordan,
                initialZoom: _lat != null ? 15.0 : 10.0,
                minZoom: 4, maxZoom: 18,
                onTap: (_, point) => _onMapTap(point),
              ),
              children: [
                // Carto Voyager — Google Maps-like styling
                TileLayer(
                  urlTemplate: context.isDark
                      ? 'https://{s}.basemaps.cartocdn.com/dark_matter/{z}/{x}/{y}{r}.png'
                      : 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
                  subdomains: const ['a', 'b', 'c', 'd'],
                  userAgentPackageName: 'com.gojo.app',
                ),
                // Accuracy ring
                if (_hasPin) CircleLayer(circles: [
                  CircleMarker(
                    point: LatLng(_lat!, _lng!),
                    radius: 28, useRadiusInMeter: false,
                    color: kAccent.withOpacity(0.12),
                    borderColor: kAccent.withOpacity(0.3), borderStrokeWidth: 1),
                ]),
                // Drop pin
                if (_hasPin) MarkerLayer(markers: [
                  Marker(
                    point: LatLng(_lat!, _lng!),
                    width: 44, height: 60, alignment: Alignment.topCenter,
                    child: ScaleTransition(
                      scale: _pinBounce,
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(
                            color: kAccent, shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2.5),
                            boxShadow: [BoxShadow(
                              color: kAccent.withOpacity(0.5), blurRadius: 14, spreadRadius: 1)]),
                          child: const Icon(Icons.place_rounded, color: Colors.white, size: 22)),
                        Container(width: 3, height: 10,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter, end: Alignment.bottomCenter,
                              colors: [kAccent, kAccent.withOpacity(0)]))),
                      ]),
                    ),
                  ),
                ]),
              ],
            ),

            // Tap hint (when no pin)
            if (!_hasPin) Positioned(bottom: 80, left: 0, right: 0,
              child: Center(child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.65),
                  borderRadius: BorderRadius.circular(22)),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.touch_app_rounded, color: Colors.white, size: 16),
                  SizedBox(width: 6),
                  Text('Tap the map to drop a pin',
                      style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
                ]),
              ))),

            // Reverse geocoding indicator
            if (_reverseGeocoding) Positioned(top: 14, left: 0, right: 0,
              child: Center(child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: context.surface.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8)]),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const SizedBox(width: 12, height: 12,
                    child: CircularProgressIndicator(strokeWidth: 1.5, color: kAccent)),
                  const SizedBox(width: 8),
                  Text('Finding address…',
                      style: TextStyle(color: context.secondary, fontSize: 12)),
                ]),
              ))),

            if (_hasPin && _label.isNotEmpty && !_reverseGeocoding)
              Positioned(top: 14, left: 14, right: 14,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: context.surface.withOpacity(0.97),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: kAccent.withOpacity(0.2)),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10)]),
                  child: Row(children: [
                    Icon(Icons.place_rounded, color: kAccent, size: 16),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_label, style: TextStyle(
                        color: context.primary, fontSize: 13, fontWeight: FontWeight.w600),
                        maxLines: 2, overflow: TextOverflow.ellipsis)),
                  ]),
                )),

            // Zoom controls
            Positioned(right: 12, bottom: _hasPin ? 88 : 68,
              child: Column(children: [
                _mapBtn(Icons.add_rounded, () {
                  final z = _mapCtrl.camera.zoom;
                  _mapCtrl.move(_mapCtrl.camera.center, z + 1);
                }),
                const SizedBox(height: 6),
                _mapBtn(Icons.remove_rounded, () {
                  final z = _mapCtrl.camera.zoom;
                  _mapCtrl.move(_mapCtrl.camera.center, math.max(z - 1, 4));
                }),
              ])),

            // Confirm button
            if (_hasPin) Positioned(bottom: 16, left: 14, right: 14,
              child: ElevatedButton(
                onPressed: _confirm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kAccent, foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15), elevation: 3,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.check_circle_rounded, size: 18),
                  const SizedBox(width: 8),
                  Flexible(child: Text(
                    _label.isNotEmpty ? 'Use: $_label' : 'Use this location',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                    maxLines: 1, overflow: TextOverflow.ellipsis)),
                ]),
              )),
          ])),
        ]),
      ),
    );
  }

  Widget _mapBtn(IconData icon, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 38, height: 38,
      decoration: BoxDecoration(
        color: context.surface, borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.divider),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 6)]),
      child: Icon(icon, size: 20, color: context.primary)));

  Widget _typeIcon(String type) {
    final icons = <String, IconData>{
      'hotel': Icons.hotel_rounded, 'restaurant': Icons.restaurant_rounded,
      'attraction': Icons.account_balance_rounded, 'museum': Icons.museum_rounded,
      'park': Icons.park_rounded, 'shop': Icons.store_rounded,
      'road': Icons.add_road_rounded, 'suburb': Icons.location_city_rounded,
      'city': Icons.location_city_rounded, 'town': Icons.location_city_rounded,
    };
    final icon = icons[type] ?? Icons.place_rounded;
    return Container(
      width: 32, height: 32,
      decoration: BoxDecoration(
        color: kAccent.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
      child: Icon(icon, color: kAccent, size: 16));
  }
}

class _Header extends StatelessWidget {
  final VoidCallback onClose;
  const _Header({required this.onClose});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 10, 16, 12),
    child: Row(children: [
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Center(child: Container(
          width: 40, height: 4, margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(color: context.divider, borderRadius: BorderRadius.circular(2)))),
        Text('Pick Location', style: TextStyle(
            color: context.primary, fontSize: 17, fontWeight: FontWeight.w800)),
        Text('Search or tap the map to set a pin',
            style: TextStyle(color: context.secondary, fontSize: 12)),
      ]),
      const Spacer(),
      GestureDetector(onTap: onClose,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: context.bg, shape: BoxShape.circle,
            border: Border.all(color: context.divider)),
          child: Icon(Icons.close_rounded, size: 18, color: context.secondary))),
    ]),
  );
}

class MapSearchOverlay extends StatefulWidget {
  final void Function(GeoPlace) onPlaceSelected;
  final VoidCallback onClose;
  const MapSearchOverlay({super.key, required this.onPlaceSelected, required this.onClose});
  @override
  State<MapSearchOverlay> createState() => _MapSearchOverlayState();
}

class _MapSearchOverlayState extends State<MapSearchOverlay> {
  final _ctrl  = TextEditingController();
  final _focus = FocusNode();
  List<GeoPlace> _results = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() { _ctrl.dispose(); _focus.dispose(); super.dispose(); }

  void _onChanged(String q) {
    if (q.trim().length < 2) { setState(() { _results = []; _loading = false; }); return; }
    setState(() => _loading = true);
    NominatimService.debounced(q, (_) async {
      if (!mounted) return;
      final r = await NominatimService.search(q);
      if (!mounted) return;
      setState(() { _results = r; _loading = false; });
    });
  }

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.symmetric(horizontal: 14),
    decoration: BoxDecoration(
      color: context.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: kAccent, width: 1.5),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 16)]),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      // Search input
      Row(children: [
        Padding(padding: const EdgeInsets.symmetric(horizontal: 12),
          child: _loading
              ? const SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: kAccent))
              : const Icon(Icons.search_rounded, size: 18, color: kAccent)),
        Expanded(child: TextField(
          controller: _ctrl,
          focusNode: _focus,
          onChanged: _onChanged,
          style: TextStyle(color: context.primary, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Search streets, areas, landmarks…',
            hintStyle: TextStyle(color: context.secondary, fontSize: 13),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 13)),
        )),
        GestureDetector(
          onTap: widget.onClose,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Icon(Icons.close_rounded, size: 18, color: context.secondary))),
      ]),
      // Results
      if (_results.isNotEmpty) ...[
        Divider(height: 1, color: context.divider),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 220),
          child: ListView.separated(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(vertical: 4),
            itemCount: _results.length.clamp(0, 6),
            separatorBuilder: (_, __) => Divider(height: 1, color: context.divider),
            itemBuilder: (_, i) {
              final r = _results[i];
              return ListTile(
                dense: true,
                leading: Container(width: 30, height: 30,
                  decoration: BoxDecoration(
                    color: kAccent.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.place_rounded, color: kAccent, size: 15)),
                title: Text(r.shortName, style: TextStyle(
                    color: context.primary, fontSize: 13, fontWeight: FontWeight.w600),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(r.displayName, style: TextStyle(
                    color: context.secondary, fontSize: 11),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                onTap: () {
                  _ctrl.clear();
                  widget.onPlaceSelected(r);
                },
              );
            },
          ),
        ),
      ],
    ]),
  );
}