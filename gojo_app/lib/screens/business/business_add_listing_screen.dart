import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../theme.dart';
import '../../services/app_state.dart';
import '../../models/models.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../widgets/location_search_widget.dart';

enum _ListingMode { place, service }

String _normCuisine(String raw) => raw
    .trim()
    .split(RegExp(r'\s+'))
    .where((w) => w.isNotEmpty)
    .map((w) => w[0].toUpperCase() + w.substring(1).toLowerCase())
    .join(' ');

class _PhoneFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue o, TextEditingValue n) {
    final v = n.text.replaceAll(RegExp(r'[^\d+\s\-]'), '');
    return n.copyWith(text: v, selection: TextSelection.collapsed(offset: v.length));
  }
}

String _fmtTod(TimeOfDay t) {
  final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
  final m = t.minute.toString().padLeft(2, '0');
  return '$h:$m ${t.period == DayPeriod.am ? 'AM' : 'PM'}';
}

class _HoursSlot {
  TimeOfDay open;
  TimeOfDay close;
  Map<String, bool> days;

  _HoursSlot({
    TimeOfDay? open,
    TimeOfDay? close,
    Map<String, bool>? days,
  })  : open  = open  ?? const TimeOfDay(hour: 9,  minute: 0),
        close = close ?? const TimeOfDay(hour: 18, minute: 0),
        days  = days  ?? {
          'Mon': true, 'Tue': true, 'Wed': true, 'Thu': true,
          'Fri': true, 'Sat': false, 'Sun': false,
        };

  String toHoursString() {
    final selected = days.entries.where((e) => e.value).map((e) => e.key).toList();
    final daysStr  = selected.isEmpty ? 'By appointment' : _compressDays(selected);
    return '${_fmtTod(open)} – ${_fmtTod(close)}, $daysStr';
  }

  static String _compressDays(List<String> days) {
    const order = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
    final indices = days.map((d) => order.indexOf(d)).toList()..sort();
    if (indices.isEmpty) return '';
    final ranges = <String>[];
    int start = indices[0], prev = indices[0];
    for (int i = 1; i <= indices.length; i++) {
      final cur = i < indices.length ? indices[i] : -1;
      if (cur == prev + 1) { prev = cur; continue; }
      ranges.add(prev == start ? order[start] : '${order[start]}–${order[prev]}');
      if (i < indices.length) { start = cur; prev = cur; }
    }
    return ranges.join(', ');
  }
}
class BusinessAddListingScreen extends StatefulWidget {
  final Place? existingPlace;
  final TripService? existingService;
  const BusinessAddListingScreen({super.key, this.existingPlace, this.existingService});
  bool get isEditMode => existingPlace != null || existingService != null;
  @override
  State<BusinessAddListingScreen> createState() => _BizAddState();
}

class _BizAddState extends State<BusinessAddListingScreen> {
  late _ListingMode _mode;
  String? _error;

  final _nameCtrl      = TextEditingController();
  final _descCtrl      = TextEditingController();
  final _locationCtrl  = TextEditingController();
  final _phoneCtrl     = TextEditingController();
  final _whatsappCtrl  = TextEditingController();
  final _websiteCtrl   = TextEditingController();
  final _customTagCtrl = TextEditingController();
  final _pricePerNightCtrl = TextEditingController();
  final _priceFromCtrl     = TextEditingController();
  final Set<String> _tags  = {};

  PlaceCategory   _placeCategory   = PlaceCategory.restaurant;
  ServiceCategory _serviceCategory = ServiceCategory.equipment;
  String _customCategory = '';
  String _priceUnit      = 'per person';
  double? _lat, _lng;
  XFile?  _pickedImage;
  final ImagePicker _picker = ImagePicker();

  String? _selectedCuisine;
  final List<_HoursSlot> _slots = [_HoursSlot()];

  String _buildHoursString() =>
      _slots.map((s) => s.toHoursString()).join(' | ');
  void _loadHours(String? raw) {
    if (raw == null || raw.isEmpty) return;
    _slots.clear();
    final parts = raw.split('|').map((p) => p.trim()).where((p) => p.isNotEmpty);
    const allDays = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
    for (final part in parts) {
      final timeRe = RegExp(r'(\d+):(\d+)\s*(AM|PM)\s*[–\-]\s*(\d+):(\d+)\s*(AM|PM)', caseSensitive: false);
      final tm = timeRe.firstMatch(part);
      TimeOfDay open  = const TimeOfDay(hour: 9,  minute: 0);
      TimeOfDay close = const TimeOfDay(hour: 18, minute: 0);
      if (tm != null) {
        int oh = int.parse(tm.group(1)!), om = int.parse(tm.group(2)!);
        int ch = int.parse(tm.group(4)!), cm = int.parse(tm.group(5)!);
        if (tm.group(3)!.toUpperCase() == 'PM' && oh != 12) oh += 12;
        if (tm.group(3)!.toUpperCase() == 'AM' && oh == 12) oh = 0;
        if (tm.group(6)!.toUpperCase() == 'PM' && ch != 12) ch += 12;
        if (tm.group(6)!.toUpperCase() == 'AM' && ch == 12) ch = 0;
        open  = TimeOfDay(hour: oh, minute: om);
        close = TimeOfDay(hour: ch, minute: cm);
      }
      final days = { for (final d in allDays) d: part.contains(d) };
      _slots.add(_HoursSlot(open: open, close: close, days: days));
    }
    if (_slots.isEmpty) _slots.add(_HoursSlot());
  }

  final List<String> _suggestedTags = [
    'history','nature','food','adventure','culture','diving','hiking',
    'art','photography','wellness','luxury','family','budget','unique',
    'nightlife','local','heritage','wildlife','beach','desert','mountains',
    'religious','architecture',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.existingPlace != null) {
      _mode = _ListingMode.place;
      final p = widget.existingPlace!;
      _nameCtrl.text          = p.name;
      _descCtrl.text          = p.description;
      _locationCtrl.text      = p.location;
      _phoneCtrl.text         = p.phone ?? '';
      _placeCategory          = p.category;
      _selectedCuisine        = p.cuisine != null && p.cuisine!.trim().isNotEmpty
          ? _normCuisine(p.cuisine!) : null;
      _pricePerNightCtrl.text = p.pricePerNight?.toString() ?? '';
      _tags.addAll(p.tags);
      _lat = p.lat != 0 ? p.lat : null;
      _lng = p.lng != 0 ? p.lng : null;
      _loadHours(p.hours);
    } else if (widget.existingService != null) {
      _mode = _ListingMode.service;
      final s = widget.existingService!;
      _nameCtrl.text      = s.name;
      _descCtrl.text      = s.description;
      _locationCtrl.text  = s.location;
      _phoneCtrl.text     = s.phone ?? '';
      _whatsappCtrl.text  = s.whatsapp ?? '';
      _websiteCtrl.text   = s.website ?? '';
      _priceFromCtrl.text = s.priceFrom?.toString() ?? '';
      _priceUnit          = s.priceUnit ?? 'per person';
      _serviceCategory    = s.category;
      _customCategory     = s.customCategory;
      _tags.addAll(s.tags);
      _lat = s.lat; _lng = s.lng;
      _loadHours(s.hours);
    } else {
      _mode = _ListingMode.place;
    }
  }

  @override
  void dispose() {
    for (final c in [_nameCtrl, _descCtrl, _locationCtrl, _phoneCtrl,
        _whatsappCtrl, _websiteCtrl, _customTagCtrl,
        _pricePerNightCtrl, _priceFromCtrl]) c.dispose();
    super.dispose();
  }


  Future<void> _pickImage(ImageSource src) async {
    final img = await _picker.pickImage(source: src, imageQuality: 85);
    if (img != null) setState(() => _pickedImage = img);
  }

  void _showImageSheet() => showModalBottomSheet(
    context: context, backgroundColor: context.surface,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 36, height: 4, margin: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(color: context.divider, borderRadius: BorderRadius.circular(2))),
      ListTile(
        leading: Container(padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: kAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.camera_alt_rounded, color: kAccent)),
        title: const Text('Take a Photo', style: TextStyle(fontWeight: FontWeight.w600)),
        onTap: () { Navigator.pop(context); _pickImage(ImageSource.camera); }),
      ListTile(
        leading: Container(padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: kDeadSeaBlue.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.photo_library_rounded, color: kDeadSeaBlue)),
        title: const Text('Choose from Gallery', style: TextStyle(fontWeight: FontWeight.w600)),
        onTap: () { Navigator.pop(context); _pickImage(ImageSource.gallery); }),
      const SizedBox(height: 8),
    ])));

  String? _validate() {
   final hasExistingImage =
    widget.existingPlace?.photoUrls.isNotEmpty == true ||
    widget.existingService?.photoUrls.isNotEmpty == true;

if (_pickedImage == null && !hasExistingImage) {
  return 'Please add a cover photo.';
}
    if (_nameCtrl.text.trim().isEmpty)               return 'Name is required.';
    if (_descCtrl.text.trim().isEmpty)               return 'Description is required.';
    if (_locationCtrl.text.trim().isEmpty)           return 'Location / Address is required.';
    if (_lat == null || _lng == null)                return 'Please pin your location on the map.';
    final ph = _phoneCtrl.text.trim();
    if (ph.isEmpty)                                  return 'Phone number is required.';
    if (!RegExp(r'^\+?[\d\s\-]{7,}$').hasMatch(ph)) return 'Enter a valid phone (e.g. +962 79 000 0000).';
    if (_mode == _ListingMode.place) {
      if (_placeCategory == PlaceCategory.restaurant &&
          (_selectedCuisine == null || _selectedCuisine!.isEmpty))
        return 'Please select a cuisine type.';
      if (_placeCategory == PlaceCategory.hotel) {
        final p = _pricePerNightCtrl.text.trim();
        if (p.isEmpty)                  return 'Price per night is required.';
        if (double.tryParse(p) == null) return 'Price per night must be a number.';
      }
    } else {
      final pr = _priceFromCtrl.text.trim();
      if (pr.isEmpty)                  return 'Starting price is required.';
      if (double.tryParse(pr) == null) return 'Price must be a number.';
    }
    if (_tags.isEmpty) return 'Please add at least one tag.';
    return null;
  }

  Future<void> _submit() async {
    final err = _validate();
    if (err != null) { setState(() => _error = err); return; }
    setState(() => _error = null);

    final hours = _buildHoursString();
    final state = context.read<AppState>();
    final user  = state.user!;
    //final paths = [_pickedImage!.path];
    final lat = _lat!, lng = _lng!;
    final name = _nameCtrl.text.trim();
    final desc = _descCtrl.text.trim();
    final loc  = _locationCtrl.text.trim();
final paths = _pickedImage != null
    ? [_pickedImage!.path]
    : (widget.existingPlace?.photoUrls ??
       widget.existingService?.photoUrls ??
       []);
    if (_mode == _ListingMode.place) {
      if (widget.existingPlace != null) {
        await state.submitPlaceEdit(widget.existingPlace!.id, {
          'name': name, 'description': desc, 'location': loc,
          'phone': _v(_phoneCtrl), 'hours': hours,
          'pricePerNight': double.tryParse(_pricePerNightCtrl.text.trim()),
          'cuisine': _selectedCuisine, 'tags': _tags.toList(),
          'photoUrls': paths, 'lat': lat, 'lng': lng,
        });
      } else {
        await state.submitPlace({
          'name': name, 'description': desc, 'category': _placeCategory.name,
          'lat': lat, 'lng': lng, 'rating': 0.0, 'reviewCount': 0,
          'imageEmoji': _placeEmoji(_placeCategory), 'location': loc,
          'phone': _v(_phoneCtrl), 'hours': hours,
          'pricePerNight': double.tryParse(_pricePerNightCtrl.text.trim()),
          'cuisine': _selectedCuisine, 'tags': _tags.toList(),
          'ownerId': user.id, 'ownerName': user.name, 'photoUrls': paths,
        });
      }
    } else {
      if (widget.existingService != null) {
        await state.submitServiceEdit(widget.existingService!.id, {
          'name': name, 'description': desc, 'location': loc,
          'phone': _v(_phoneCtrl), 'hours': hours,
          'priceFrom': double.tryParse(_priceFromCtrl.text.trim()),
          'priceUnit': _priceUnit, 'tags': _tags.toList(), 'photoUrls': paths,
          'whatsapp': _v(_whatsappCtrl), 'website': _v(_websiteCtrl),
          'lat': lat, 'lng': lng,
        });
      } else {
        await state.submitService({
          'name': name, 'description': desc, 'category': _serviceCategory.name,
          'customCategory': _customCategory, 'ownerId': user.id, 'ownerName': user.name,
          'location': loc, 'phone': _v(_phoneCtrl), 'hours': hours,
          'priceFrom': double.tryParse(_priceFromCtrl.text.trim()),
          'priceUnit': _priceUnit, 'tags': _tags.toList(),
          'imageEmoji': _serviceEmoji(_serviceCategory), 'photoUrls': paths,
          'whatsapp': _v(_whatsappCtrl), 'website': _v(_websiteCtrl),
          'lat': lat, 'lng': lng, 'rating': 0.0, 'reviewCount': 0,
        });
      }
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
        const SizedBox(width: 10),
        Expanded(child: Text(
          widget.isEditMode ? 'Changes submitted for admin review'
              : 'Listing submitted — pending admin approval',
          style: const TextStyle(fontWeight: FontWeight.w600))),
      ]),
      backgroundColor: const Color(0xFF22C55E), behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
    _reset();
  }

  void _reset() => setState(() {
    for (final c in [_nameCtrl, _descCtrl, _locationCtrl, _phoneCtrl,
        _whatsappCtrl, _websiteCtrl, _customTagCtrl,
        _pricePerNightCtrl, _priceFromCtrl]) c.clear();
    _tags.clear(); _pickedImage = null; _lat = null; _lng = null;
    _priceUnit = 'per person'; _customCategory = '';
    _selectedCuisine = null;
    _placeCategory = PlaceCategory.restaurant;
    _serviceCategory = ServiceCategory.equipment;
    _slots
      ..clear()
      ..add(_HoursSlot());
  });

  String? _v(TextEditingController c) =>
      c.text.trim().isEmpty ? null : c.text.trim();
  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bg,
      appBar: AppBar(
        title: Text(widget.isEditMode ? 'Edit Listing' : 'Add Listing'),
        leading: Navigator.canPop(context)
            ? IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded),
                onPressed: () => Navigator.pop(context))
            : null,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          if (!widget.isEditMode) ...[
            Row(children: [
              Expanded(child: _modeBtn(_ListingMode.place,   'Place',   'Hotel, restaurant…')),
              const SizedBox(width: 12),
              Expanded(child: _modeBtn(_ListingMode.service, 'Service', 'Guide, transport…')),
            ]),
            const SizedBox(height: 24),
          ],

          _lbl('Cover Photo', req: true),
          const SizedBox(height: 8),
          _photoPicker(),
          const SizedBox(height: 20),

          _lbl('Name', req: true),
          const SizedBox(height: 6),
          _tf(_nameCtrl, 'e.g. "Petra Trail Tours"', Icons.label_outline_rounded),
          const SizedBox(height: 14),

          _lbl('Description', req: true),
          const SizedBox(height: 6),
          TextField(
            controller: _descCtrl, maxLines: 4,
            style: TextStyle(color: context.primary),
            decoration: InputDecoration(
              hintText: 'Describe what makes this special…',
              prefixIcon: Padding(padding: const EdgeInsets.only(bottom: 56),
                  child: Icon(Icons.description_outlined, color: context.secondary, size: 20)))),
          const SizedBox(height: 14),

          _lbl('Location / Address', req: true),
          const SizedBox(height: 6),
          _tf(_locationCtrl, 'e.g. "Rainbow Street, Amman"', Icons.location_on_outlined),
          const SizedBox(height: 14),

          _lbl('Pin on Map', req: true),
          const SizedBox(height: 6),
          _mapPicker(),
          const SizedBox(height: 14),

          _lbl('Phone', req: true),
          const SizedBox(height: 6),
          _phoneTf(_phoneCtrl, 'e.g. +962 79 000 0000'),
          const SizedBox(height: 20),

          _lbl('Opening Hours', req: true),
          const SizedBox(height: 4),
          Text('Add multiple schedules for different days',
              style: TextStyle(color: context.secondary, fontSize: 11)),
          const SizedBox(height: 10),
          _hoursSection(),
          const SizedBox(height: 20),

          _lbl(_mode == _ListingMode.place ? 'Place Type' : 'Service Category', req: true),
          const SizedBox(height: 10),
          _mode == _ListingMode.place ? _placeCats() : _serviceCats(),
          const SizedBox(height: 20),

          if (_mode == _ListingMode.place) ...[
            if (_placeCategory == PlaceCategory.restaurant) ...[
              _lbl('Cuisine Type', req: true),
              const SizedBox(height: 6),
              _cuisinePicker(),
              const SizedBox(height: 14),
            ],
            if (_placeCategory == PlaceCategory.hotel) ...[
              _lbl('Price per Night (JD)', req: true),
              const SizedBox(height: 6),
              _tf(_pricePerNightCtrl, '0.00', Icons.payments_outlined, kb: TextInputType.number),
              const SizedBox(height: 14),
            ],
          ],

          if (_mode == _ListingMode.service) ...[
            _lbl('Price From (JD)', req: true),
            const SizedBox(height: 6),
            _tf(_priceFromCtrl, '0.00', Icons.payments_outlined, kb: TextInputType.number),
            const SizedBox(height: 10),
            _priceUnitDrop(),
            const SizedBox(height: 14),
            _lbl('WhatsApp', hint: '(optional)'),
            const SizedBox(height: 6),
            _phoneTf(_whatsappCtrl, 'e.g. +962 79 000 0000'),
            const SizedBox(height: 14),
            _lbl('Website', hint: '(optional)'),
            const SizedBox(height: 6),
            _tf(_websiteCtrl, 'https://yourwebsite.com', Icons.language_outlined, kb: TextInputType.url),
            const SizedBox(height: 14),
          ],

          _lbl('Tags', req: true, hint: '(at least one)'),
          const SizedBox(height: 8),
          _tagsSection(),
          const SizedBox(height: 24),

          if (_error != null)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: kDanger.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: kDanger.withOpacity(0.3))),
              child: Row(children: [
                const Icon(Icons.error_outline_rounded, color: kDanger, size: 16),
                const SizedBox(width: 8),
                Expanded(child: Text(_error!, style: const TextStyle(color: kDanger, fontSize: 13))),
              ])),

          SizedBox(width: double.infinity, child: ElevatedButton(
            onPressed: _submit,
            child: Text(widget.isEditMode ? 'Submit for Review' : 'Submit for Approval'))),
          const SizedBox(height: 8),
          Center(child: Text(
            widget.isEditMode ? 'Changes reviewed by admin before going live.'
                : 'Listing reviewed by admin before publishing.',
            textAlign: TextAlign.center,
            style: TextStyle(color: context.secondary, fontSize: 11))),
          const SizedBox(height: 32),
        ]),
      ),
    );
  }

  Widget _hoursSection() => Column(children: [
    for (int i = 0; i < _slots.length; i++) _slotCard(i),

    // Add schedule button
    const SizedBox(height: 8),
    GestureDetector(
      onTap: () => setState(() => _slots.add(_HoursSlot(
          // Default new slot: next slot gets different suggested hours
          open:  const TimeOfDay(hour: 10, minute: 0),
          close: const TimeOfDay(hour: 23, minute: 0),
          days: { 'Mon': false, 'Tue': false, 'Wed': false, 'Thu': false,
                  'Fri': false, 'Sat': true,  'Sun': true }))),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: context.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kAccent.withOpacity(0.35), width: 1.5,
              style: BorderStyle.solid)),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.add_circle_outline_rounded, color: kAccent, size: 18),
          const SizedBox(width: 8),
          Text('Add another schedule',
              style: TextStyle(color: kAccent, fontSize: 13, fontWeight: FontWeight.w700)),
        ])),
    ),
  ]);

  Widget _slotCard(int index) {
    final slot = _slots[index];
    final preview = slot.toHoursString();
    final canRemove = _slots.length > 1;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.divider)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 0),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: kAccent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8)),
              child: Text('Schedule ${index + 1}',
                  style: TextStyle(color: kAccent, fontSize: 11, fontWeight: FontWeight.w700))),
            const Spacer(),
            if (canRemove)
              GestureDetector(
                onTap: () => setState(() => _slots.removeAt(index)),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: kDanger.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8)),
                  child: Icon(Icons.delete_outline_rounded, color: kDanger, size: 16))),
          ])),

        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
          child: Row(children: [
            Expanded(child: _timeTile('Opens', slot.open, () async {
              final p = await showTimePicker(context: context, initialTime: slot.open);
              if (p != null) setState(() => slot.open = p);
            })),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text('to', style: TextStyle(color: context.secondary, fontSize: 13))),
            Expanded(child: _timeTile('Closes', slot.close, () async {
              final p = await showTimePicker(context: context, initialTime: slot.close);
              if (p != null) setState(() => slot.close = p);
            })),
          ])),

        const SizedBox(height: 12),
        Divider(height: 1, color: context.divider),

        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
          child: Text('Active days',
              style: TextStyle(color: context.secondary, fontSize: 11, fontWeight: FontWeight.w600))),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: slot.days.keys.map((day) {
              final sel = slot.days[day]!;
              return GestureDetector(
                onTap: () => setState(() => slot.days[day] = !sel),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    color: sel ? kAccent : context.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: sel ? kAccent : context.divider,
                        width: sel ? 0 : 1)),
                  child: Center(child: Text(day.substring(0, 2),
                      style: TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w700,
                        color: sel ? Colors.white : context.secondary)))));
            }).toList())),

        Divider(height: 1, color: context.divider),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Row(children: [
            Icon(Icons.schedule_rounded, size: 13, color: kAccent),
            const SizedBox(width: 6),
            Expanded(child: Text(preview,
                style: TextStyle(color: context.primary, fontSize: 11, fontWeight: FontWeight.w600))),
          ])),
      ]));
  }

  Widget _timeTile(String label, TimeOfDay time, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: context.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: context.divider)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(color: context.secondary, fontSize: 10, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Row(children: [
              Icon(Icons.access_time_rounded, size: 14, color: kAccent),
              const SizedBox(width: 5),
              Text(_fmtTod(time),
                  style: TextStyle(color: context.primary, fontSize: 13, fontWeight: FontWeight.w700)),
            ]),
          ])));

  Widget _mapPicker() {
    final hasPin = _lat != null && _lng != null;
    return GestureDetector(
      onTap: () async {
        final result = await LocationPickerSheet.show(context,
            initialLat: _lat, initialLng: _lng,
            initialLabel: _locationCtrl.text.trim().isNotEmpty
                ? _locationCtrl.text.trim() : null);
        if (result != null) setState(() {
          _lat = result.lat; _lng = result.lng;
          if (_locationCtrl.text.trim().isEmpty) _locationCtrl.text = result.label;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: context.card, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: hasPin ? kAccent : context.divider, width: hasPin ? 1.5 : 1)),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: hasPin ? kAccent.withOpacity(0.1) : context.surface,
              borderRadius: BorderRadius.circular(10)),
            child: Icon(
              hasPin ? Icons.pin_drop_rounded : Icons.add_location_alt_rounded,
              color: hasPin ? kAccent : context.secondary, size: 20)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(hasPin ? 'Location pinned' : 'Pin on map',
                style: TextStyle(
                  color: hasPin ? context.primary : context.secondary,
                  fontSize: 14, fontWeight: hasPin ? FontWeight.w600 : FontWeight.w400)),
            const SizedBox(height: 2),
            Text(hasPin
                ? '${_lat!.toStringAsFixed(5)}, ${_lng!.toStringAsFixed(5)}'
                : 'Search a street, area or tap on map',
                style: TextStyle(color: context.secondary, fontSize: 11)),
          ])),
          if (hasPin)
            GestureDetector(
              onTap: () => setState(() { _lat = null; _lng = null; }),
              child: Icon(Icons.close_rounded, color: context.secondary, size: 18))
          else
            Icon(Icons.chevron_right_rounded, color: context.secondary, size: 20),
        ])));
  }

  Widget _photoPicker() {
    if (_pickedImage == null) {
      return GestureDetector(
        onTap: _showImageSheet,
        child: Container(
          height: 100,
          decoration: BoxDecoration(
            color: context.card, borderRadius: BorderRadius.circular(14),
            border: Border.all(color: context.divider)),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(
              width: 68, height: 68,
              decoration: BoxDecoration(
                color: kAccent.withOpacity(0.08), borderRadius: BorderRadius.circular(12),
                border: Border.all(color: kAccent.withOpacity(0.3))),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.add_a_photo_rounded, color: kAccent, size: 22),
                const SizedBox(height: 4),
                Text('Add', style: TextStyle(color: kAccent, fontSize: 10, fontWeight: FontWeight.w600)),
              ])),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text('Add a cover photo',
                  style: TextStyle(color: context.primary, fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 3),
              Text('Camera or gallery',
                  style: TextStyle(color: context.secondary, fontSize: 12)),
            ]),
          ])));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(children: [
          SizedBox(height: 200, width: double.infinity,
              child: Image.file(File(_pickedImage!.path), fit: BoxFit.cover)),
          Positioned(top: 8, right: 8,
            child: GestureDetector(
              onTap: () => setState(() => _pickedImage = null),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.55), shape: BoxShape.circle),
                child: const Icon(Icons.close_rounded, color: Colors.white, size: 16)))),
        ])),
      const SizedBox(height: 8),
      GestureDetector(
        onTap: _showImageSheet,
        child: Row(children: [
          Icon(Icons.edit_outlined, size: 14, color: kAccent), const SizedBox(width: 5),
          Text('Change photo',
              style: TextStyle(color: kAccent, fontSize: 12, fontWeight: FontWeight.w600)),
        ])),
    ]);
  }

  Widget _cuisinePicker() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('places')
          .where('category', isEqualTo: 'restaurant')
          .where('listingStatus', isEqualTo: 'approved')
          .snapshots(),
      builder: (context, snap) {
        final options = <String>{};
        for (final doc in snap.data?.docs ?? []) {
          final raw = (doc.data() as Map<String, dynamic>)['cuisine'];
          if (raw is String && raw.trim().isNotEmpty) options.add(_normCuisine(raw));
        }
        final sorted = options.toList()..sort();
        return Wrap(spacing: 8, runSpacing: 8, children: sorted.map((c) {
          final sel = _selectedCuisine == c;
          return GestureDetector(
            onTap: () => setState(() => _selectedCuisine = sel ? null : c),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: sel ? kAccent.withOpacity(0.1) : context.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: sel ? kAccent : context.divider, width: sel ? 1.5 : 1)),
              child: Text(c, style: TextStyle(
                  color: sel ? kAccentDim : context.primary,
                  fontSize: 13, fontWeight: sel ? FontWeight.w700 : FontWeight.w400))));
        }).toList());
      },
    );
  }

  Widget _tagsSection() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    if (_tags.isNotEmpty) ...[
      Wrap(spacing: 8, runSpacing: 6, children: _tags.map((t) => GestureDetector(
        onTap: () => setState(() => _tags.remove(t)),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: kAccent.withOpacity(0.12), borderRadius: BorderRadius.circular(20),
            border: Border.all(color: kAccent.withOpacity(0.4))),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(t, style: const TextStyle(color: kAccentDim, fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(width: 4),
            const Icon(Icons.close, size: 12, color: kAccentDim),
          ])))).toList()),
      const SizedBox(height: 8),
    ],
    TextField(
      controller: _customTagCtrl,
      style: TextStyle(color: context.primary, fontSize: 13),
      decoration: InputDecoration(
        hintText: 'Type a tag and press enter…',
        prefixIcon: Icon(Icons.add_rounded, color: context.secondary, size: 18),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
      onSubmitted: (v) {
        final t = v.trim().toLowerCase();
        if (t.isNotEmpty) setState(() { _tags.add(t); _customTagCtrl.clear(); });
      }),
    const SizedBox(height: 8),
    Wrap(spacing: 8, runSpacing: 6,
      children: _suggestedTags.where((t) => !_tags.contains(t)).map((t) =>
        GestureDetector(
          onTap: () => setState(() => _tags.add(t)),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: context.card, borderRadius: BorderRadius.circular(20),
              border: Border.all(color: context.divider)),
            child: Text(t, style: TextStyle(color: context.secondary, fontSize: 12))))).toList()),
  ]);

  Widget _lbl(String t, {bool req = false, String? hint}) => Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      Text(t, style: TextStyle(color: context.primary, fontSize: 14, fontWeight: FontWeight.w700)),
      if (req) const Text(' *', style: TextStyle(color: kDanger, fontSize: 14, fontWeight: FontWeight.w700)),
      if (hint != null) ...[
        const SizedBox(width: 4),
        Text(hint, style: TextStyle(color: context.secondary, fontSize: 12)),
      ],
    ]);

  Widget _tf(TextEditingController c, String hint, IconData icon, {TextInputType? kb, String? hint2}) =>
      TextField(controller: c, keyboardType: kb, style: TextStyle(color: context.primary),
          decoration: InputDecoration(
            hintText: hint, helperText: hint2,
            helperStyle: hint2 != null ? TextStyle(color: context.secondary, fontSize: 11) : null,
            prefixIcon: Icon(icon, color: context.secondary, size: 20)));

  Widget _phoneTf(TextEditingController c, String hint) => TextField(
    controller: c, keyboardType: TextInputType.phone,
    inputFormatters: [_PhoneFormatter()],
    style: TextStyle(color: context.primary),
    decoration: InputDecoration(
      hintText: hint,
      prefixIcon: Icon(Icons.phone_outlined, color: context.secondary, size: 20),
      helperText: 'Include country code, e.g. +962',
      helperStyle: TextStyle(color: context.secondary, fontSize: 11)));

  Widget _modeBtn(_ListingMode mode, String label, String sub) {
    final sel = _mode == mode;
    return GestureDetector(
      onTap: () => setState(() => _mode = mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: sel ? kAccent.withOpacity(0.1) : context.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: sel ? kAccent : context.divider, width: sel ? 2 : 1)),
        child: Column(children: [
          Text(label, style: TextStyle(
              color: sel ? kAccentDim : context.primary,
              fontWeight: FontWeight.w800, fontSize: 14)),
          const SizedBox(height: 2),
          Text(sub, textAlign: TextAlign.center,
              style: TextStyle(color: context.secondary, fontSize: 10, height: 1.3)),
        ])));
  }

  Widget _placeCats() => Wrap(spacing: 8, runSpacing: 8, children: [
    (PlaceCategory.restaurant, '🍽️', 'Restaurant'),
    (PlaceCategory.hotel,      '🏨', 'Hotel'),
    (PlaceCategory.attraction, '📍', 'Attraction'),
    (PlaceCategory.event,      '🎉', 'Event'),
  ].map((c) {
    final sel = _placeCategory == c.$1;
    return GestureDetector(
      onTap: () => setState(() => _placeCategory = c.$1),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: sel ? kAccent.withOpacity(0.1) : context.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: sel ? kAccent : context.divider, width: sel ? 1.5 : 1)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(c.$2, style: const TextStyle(fontSize: 16)), const SizedBox(width: 6),
          Text(c.$3, style: TextStyle(
              color: sel ? kAccentDim : context.primary,
              fontSize: 13, fontWeight: sel ? FontWeight.w700 : FontWeight.w400)),
        ])));
  }).toList());

  Widget _serviceCats() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Wrap(spacing: 8, runSpacing: 8, children: [
      (ServiceCategory.equipment,     '🎒', 'Equipment'),
      (ServiceCategory.guide,         '🧭', 'Tour Guide'),
      (ServiceCategory.transport,     '🚐', 'Transport'),
      (ServiceCategory.experience,    '⭐', 'Experience'),
      (ServiceCategory.wellness,      '🧘', 'Wellness'),
      (ServiceCategory.photography,   '📸', 'Photography'),
      (ServiceCategory.food,          '🍽️', 'Food & Catering'),
      (ServiceCategory.accommodation, '🏕️', 'Accommodation'),
      (ServiceCategory.retail,        '🛍️', 'Retail'),
      (ServiceCategory.other,         '🛠️', 'Other'),
    ].map((c) {
      final sel = _serviceCategory == c.$1;
      return GestureDetector(
        onTap: () => setState(() => _serviceCategory = c.$1),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: sel ? kDeadSeaBlue.withOpacity(0.1) : context.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: sel ? kDeadSeaBlue : context.divider, width: sel ? 1.5 : 1)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(c.$2, style: const TextStyle(fontSize: 14)), const SizedBox(width: 5),
            Text(c.$3, style: TextStyle(
                color: sel ? kDeadSeaBlue : context.primary,
                fontSize: 12, fontWeight: sel ? FontWeight.w700 : FontWeight.w400)),
          ])));
    }).toList()),
    const SizedBox(height: 12),
    TextField(
      onChanged: (v) => setState(() => _customCategory = v),
      controller: TextEditingController(text: _customCategory),
      style: TextStyle(color: context.primary, fontSize: 13),
      decoration: InputDecoration(
        hintText: 'Specific label e.g. "Camel Riding"',
        prefixIcon: Icon(Icons.label_outline_rounded, color: context.secondary, size: 18),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10))),
  ]);

  Widget _priceUnitDrop() => DropdownButtonFormField<String>(
    value: _priceUnit, dropdownColor: context.card,
    style: TextStyle(color: context.primary, fontSize: 14),
    decoration: InputDecoration(
        prefixIcon: Icon(Icons.schedule_outlined, color: context.secondary, size: 20)),
    items: ['per person','per day','per trip','per group','per hour','per item']
        .map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
    onChanged: (v) => setState(() => _priceUnit = v ?? _priceUnit));

  String _placeEmoji(PlaceCategory c) => switch (c) {
    PlaceCategory.hotel      => '🏨',
    PlaceCategory.restaurant => '🍽️',
    PlaceCategory.event      => '🎉',
    _                        => '📍',
  };

  String _serviceEmoji(ServiceCategory c) => switch (c) {
    ServiceCategory.guide         => '🧭',
    ServiceCategory.transport     => '🚐',
    ServiceCategory.experience    => '⭐',
    ServiceCategory.wellness      => '🧘',
    ServiceCategory.photography   => '📸',
    ServiceCategory.food          => '🍽️',
    ServiceCategory.accommodation => '🏕️',
    ServiceCategory.retail        => '🛍️',
    _                             => '🎒',
  };
}