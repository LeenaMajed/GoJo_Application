import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme.dart';
import '../services/firebase_service.dart';
import '../services/app_state.dart';
import '../widgets/shared_widgets.dart';
import 'sign_in_screen.dart';
import 'help_support_screen.dart';
import 'terms_screen.dart';
import 'dart:convert';


class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _editing = false;
  bool _uploadingPhoto = false;
  late TextEditingController _nameCtrl;
  Set<String> _selectedInterests = {};
  String _selectedBudget = 'medium';
  String _selectedTravelStyle = 'cultural';
  late TextEditingController _nationalityCtrl;
  XFile? _pendingImage;   // picked but not yet saved
  final _picker = ImagePicker();

  final List<String> _allInterests = [
    'history', 'nature', 'food', 'adventure', 'culture',
    'diving', 'hiking', 'art', 'photography', 'religion',
    'wellness', 'architecture', 'desert', 'beach', 'nightlife',
  ];

  final List<Map<String, String>> _budgetOptions = [
    {'value': 'low',    'label': 'Budget',    'sub': 'Affordable'},
    {'value': 'medium', 'label': 'Mid-range', 'sub': 'Balanced'},
    {'value': 'high',   'label': 'Luxury',    'sub': 'All out'},
  ];

  final List<Map<String, String>> _travelStyles = [
    {'value': 'cultural',  'label': 'Cultural'},
    {'value': 'adventure', 'label': 'Adventure'},
    {'value': 'relaxed',   'label': 'Relaxed'},
    {'value': 'family',    'label': 'Family'},
    {'value': 'romantic',  'label': 'Romantic'},
    {'value': 'foodie',    'label': 'Foodie'},
  ];

  @override
  void initState() {
    super.initState();
    final user = context.read<AppState>().user;
    _nameCtrl        = TextEditingController(text: user?.name ?? '');
    _nationalityCtrl = TextEditingController(text: user?.nationality ?? '');
    _selectedInterests  = Set.from(user?.interests ?? []);
    _selectedBudget     = user?.budget ?? 'medium';
    _selectedTravelStyle = user?.travelStyle ?? 'cultural';
  }

  @override
  void dispose() { _nameCtrl.dispose(); _nationalityCtrl.dispose(); super.dispose(); }


  Future<String?> _convertImageToBase64() async {
  if (_pendingImage == null) return null;

  try {

    final bytes = await File(_pendingImage!.path).readAsBytes();

    // Decode and downscale to max 200×200 using Flutter's image package
    final codec = await ui.instantiateImageCodec(
      bytes,
      targetWidth: 200,
      targetHeight: 200,
    );
    final frame    = await codec.getNextFrame();
    final resized  = await frame.image.toByteData(format: ui.ImageByteFormat.png);

    if (resized == null) return null;

    final base64Str = base64Encode(resized.buffer.asUint8List());

  
    if (base64Str.length > 700000) {
      debugPrint('Image still too large after resize: ${base64Str.length} chars');
      return null;
    }

    return base64Str;
  } catch (e) {
    debugPrint('Base64 conversion failed: $e');
    return null;
  }
}
Future<void> _saveProfile() async {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return;

  setState(() => _uploadingPhoto = true);

  try {
    String? base64Image;

    if (_pendingImage != null) {
      base64Image = await _convertImageToBase64();
    } else {
      // ← Keep the existing photo — don't overwrite with null
      base64Image = context.read<AppState>().user?.photoUrl;
    }

    await context.read<AppState>().updateProfile(
      name: _nameCtrl.text.trim(),
      interests: _selectedInterests.toList(),
      budget: _selectedBudget,
      travelStyle: _selectedTravelStyle,
      nationality: _nationalityCtrl.text.trim().isNotEmpty
          ? _nationalityCtrl.text.trim()
          : null,
      photoUrl: base64Image,
    );

    if (!mounted) return;
    setState(() { _editing = false; _pendingImage = null; });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile updated!'), backgroundColor: kAccentDim));
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Update failed: $e'), backgroundColor: kDanger));
    }
  } finally {
    if (mounted) setState(() => _uploadingPhoto = false);
  }
}
  void _signOut() async {
    await context.read<AppState>().signOut();
    if (mounted) Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const SignInScreen()), (_) => false);
  }


  Future<void> _deleteAccount() async {
    final user = context.read<AppState>().user;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dlg) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: dlg.card,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 78, height: 78,
                decoration: BoxDecoration(
                  color: kDanger.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.delete_forever_rounded, color: kDanger, size: 40),
              ),
              const SizedBox(height: 20),
              Text('Delete Account?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: dlg.primary, fontSize: 22,
                  fontWeight: FontWeight.w800, letterSpacing: -0.4)),
              const SizedBox(height: 10),
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: TextStyle(color: dlg.secondary, fontSize: 13, height: 1.6),
                  children: [
                    const TextSpan(text: 'You are about to permanently delete\n'),
                    TextSpan(
                      text: user?.name ?? 'your account',
                      style: TextStyle(color: dlg.primary, fontWeight: FontWeight.w700)),
                    const TextSpan(text: '.\nYour profile, photo, and all saved data\nwill be gone forever.'),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: dlg.secondary,
                      side: BorderSide(color: dlg.divider),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                    onPressed: () => Navigator.pop(dlg, false),
                    child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600)))),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                    label: const Text('Delete', style: TextStyle(fontWeight: FontWeight.w700)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kDanger, foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                    onPressed: () => Navigator.pop(dlg, true))),
              ]),
            ],
          ),
        ),
      ),
    );
    if (confirmed != true) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      // 1. Delete profile photo from Storage
      try {
        await FirebaseStorage.instance
            .ref()
            .child('profile_photos/$uid.jpg')
            .delete();
      } catch (_) {} // ignore if no photo

      // 2. Delete Firestore user doc
      await FirebaseFirestore.instance.collection('users').doc(uid).delete();

      // 3. Delete Firebase Auth account
      await FirebaseAuth.instance.currentUser!.delete();

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const SignInScreen()), (_) => false);
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Please sign out and sign in again before deleting your account.'),
            backgroundColor: kDanger, behavior: SnackBarBehavior.floating));
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error: \${e.message}'),
            backgroundColor: kDanger, behavior: SnackBarBehavior.floating));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: \$e'),
          backgroundColor: kDanger, behavior: SnackBarBehavior.floating));
      }
    }
  }

  void _showImagePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 36, height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                  color: context.divider, borderRadius: BorderRadius.circular(2))),
          ListTile(
            leading: Container(padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: kAccent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.camera_alt_rounded, color: kAccent)),
            title: const Text('Take Photo', style: TextStyle(fontWeight: FontWeight.w600)),
            
              onTap: () async {
  Navigator.pop(context);

  final img = await _picker.pickImage(
    source: ImageSource.camera,
    imageQuality: 70,
    maxWidth: 800,
    maxHeight: 800,
  );

  if (img != null && mounted) {
    setState(() {
      _pendingImage = img;
    });
  }

            },
          ),
          ListTile(
            leading: Container(padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: kDeadSeaBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.photo_library_rounded, color: kDeadSeaBlue)),
            title: const Text('Choose from Gallery',
                style: TextStyle(fontWeight: FontWeight.w600)),
            
              onTap: () async {
  Navigator.pop(context);

  final img = await _picker.pickImage(
    source: ImageSource.gallery,
    imageQuality: 70,
    maxWidth: 800,
    maxHeight: 800,
  );

  if (img != null && mounted) {
    setState(() {
      _pendingImage = img;
    });
  }

            },
          ),
        ]),
      )),
    );
  }

  
Widget _avatar(String name, String? remoteUrl) {
  ImageProvider? provider;

  if (_pendingImage != null) {
    provider = FileImage(File(_pendingImage!.path));
  } else if (remoteUrl != null && remoteUrl.isNotEmpty) {
     provider = MemoryImage(base64Decode(remoteUrl));
    
  }

  return GestureDetector(
    onTap: _editing ? _showImagePicker : null,
    child: Stack(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: kAccent, width: 2),
          ),
          child: ClipOval(
            child: provider != null
                ? Image(
                    image: provider,
                    fit: BoxFit.cover,

                    // better loading behavior
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;

                      return Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: kAccent,
                        ),
                      );
                    },

                    errorBuilder: (_, __, ___) =>
                        _initialsCircle(name),
                  )
                : _initialsCircle(name),
          ),
        ),

        if (_editing)
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: _uploadingPhoto ? kWarning : kAccent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: context.surface,
                  width: 2,
                ),
              ),
              child: _uploadingPhoto
                  ? const SizedBox(
                      width: 11,
                      height: 11,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(
                      Icons.camera_alt_rounded,
                      size: 11,
                      color: Colors.white,
                    ),
            ),
          ),
      ],
    ),
  );
}

  Widget _initialsCircle(String name) => Container(
    color: kAccent.withOpacity(0.12),
    child: Center(child: Text(
      name.isNotEmpty ? name[0].toUpperCase() : '?',
      style: const TextStyle(color: kAccent, fontSize: 32, fontWeight: FontWeight.w700))));

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final user  = state.user;
    if (user == null) return const SizedBox.shrink();

    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      body: SafeArea(child: SingleChildScrollView(child: Column(children: [

        
        Container(
          color: context.surface,
          padding: const EdgeInsets.fromLTRB(20, 16, 12, 24),
          child: Column(children: [
            Row(children: [
              Text('Profile', style: TextStyle(color: context.primary,
                  fontSize: 22, fontWeight: FontWeight.w800)),
              const Spacer(),
              _editing
                  ? Row(mainAxisSize: MainAxisSize.min, children: [
                      TextButton(
                        onPressed: () => setState(() {
                          _editing = false; _pendingImage = null;
                        }),
                        child: Text('Cancel',
                            style: TextStyle(color: context.secondary))),
                      TextButton(
                        onPressed: _uploadingPhoto ? null : _saveProfile,
                        child: _uploadingPhoto
                            ? const SizedBox(width: 16, height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: kAccent))
                            : const Text('Save',
                                style: TextStyle(color: kAccent, fontWeight: FontWeight.w700))),
                    ])
                  : TextButton(
                      onPressed: () => setState(() {
                        _editing = true;
                        _nameCtrl.text = user.name;
                        _nationalityCtrl.text = user.nationality ?? '';
                        _selectedInterests   = Set.from(user.interests);
                        _selectedBudget      = user.budget ?? 'medium';
                        _selectedTravelStyle = user.travelStyle ?? 'cultural';
                      }),
                      child: const Text('Edit', style: TextStyle(color: kAccent))),
              const ThemeToggleButton(),
            ]),
            const SizedBox(height: 16),

            _avatar(user.name, user.photoUrl),

            // Pending image hint
            if (_pendingImage != null && _editing) ...[
              const SizedBox(height: 6),
              Text('New photo selected — tap Save to upload',
                  style: TextStyle(color: kAccent, fontSize: 11)),
            ],

            const SizedBox(height: 14),
            _editing
                ? TextField(controller: _nameCtrl, textAlign: TextAlign.center,
                    style: TextStyle(color: context.primary,
                        fontSize: 18, fontWeight: FontWeight.w700),
                    decoration: const InputDecoration(hintText: 'Your name'))
                : Text(user.name, style: TextStyle(color: context.primary,
                    fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(user.email, style: TextStyle(color: context.secondary, fontSize: 13)),
          ]),
        ),

        Padding(padding: const EdgeInsets.all(20), child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [

          
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(color: context.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: context.divider)),
            child: Row(children: [
              StreamBuilder<QuerySnapshot>(
                stream: context.read<AppState>().approvedPlacesStream,
                builder: (ctx, snap) {
                  final savedCount = (snap.data?.docs ?? [])
                      .where((doc) => state.isSaved(doc.id)).length;
                  return _statItem(context, '$savedCount', 'Places');
                }),
              Container(width: 1, height: 32, color: context.divider),
              StreamBuilder<QuerySnapshot>(
                stream: uid != null ? FirebaseService().itineraryStream(uid) : null,
                builder: (ctx, snap) {
                  final count = snap.data?.docs.length ?? 0;
                  return _statItem(context, '$count', 'Trips');
                }),
              Container(width: 1, height: 32, color: context.divider),
              StreamBuilder<QuerySnapshot>(
                stream: context.read<AppState>().approvedServicesStream,
                builder: (ctx, snap) {
                  final savedSvcsCount = (snap.data?.docs ?? [])
                      .where((doc) => state.isServiceSaved(doc.id)).length;
                  return _statItem(context, '$savedSvcsCount', 'Services');
                }),
            ]),
          ),
          const SizedBox(height: 20),

          
          Text('Travel Interests', style: TextStyle(color: context.primary,
              fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: _allInterests.map((t) {
            final sel = _selectedInterests.contains(t) ||
                (!_editing && user.interests.contains(t));
            return GestureDetector(
              onTap: _editing ? () => setState(() {
                sel ? _selectedInterests.remove(t) : _selectedInterests.add(t);
              }) : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: sel ? kAccent.withOpacity(0.12) : context.card,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: sel ? kAccent : context.divider,
                      width: sel ? 1.5 : 1)),
                child: Text(t, style: TextStyle(
                  color: sel ? kAccentDim : context.secondary,
                  fontSize: 13,
                  fontWeight: sel ? FontWeight.w700 : FontWeight.w400))));
          }).toList()),
          const SizedBox(height: 20),

          
          Text('Nationality', style: TextStyle(color: context.primary,
              fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          _editing
              ? TextField(
                  controller: _nationalityCtrl,
                  style: TextStyle(color: context.primary, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'e.g. Jordanian, American',
                    prefixIcon: Icon(Icons.flag_outlined, color: context.secondary, size: 20),
                  ))
              : Text(
                  user.nationality?.isNotEmpty == true ? user.nationality! : 'Not set',
                  style: TextStyle(
                      color: user.nationality?.isNotEmpty == true
                          ? context.primary : context.secondary,
                      fontSize: 14)),
          const SizedBox(height: 20),

          
          Text('Travel Budget', style: TextStyle(color: context.primary,
              fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('Used in AI itinerary generation',
              style: TextStyle(color: context.secondary, fontSize: 12)),
          const SizedBox(height: 10),
          _editing
              ? Row(children: _budgetOptions.asMap().entries.map((e) {
                  final b = e.value;
                  final isLast = e.key == _budgetOptions.length - 1;
                  final sel = _selectedBudget == b['value'];
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedBudget = b['value']!),
                      child: Container(
                        margin: EdgeInsets.only(right: isLast ? 0 : 8),
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                        decoration: BoxDecoration(
                          color: sel ? kAccent.withOpacity(0.08) : context.card,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: sel ? kAccent : context.divider,
                              width: sel ? 1.5 : 1)),
                        child: Column(children: [
                          Text(b['label']!, textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: sel ? kAccentDim : context.primary,
                                  fontWeight: FontWeight.w700, fontSize: 12)),
                          Text(b['sub']!, textAlign: TextAlign.center,
                              style: TextStyle(color: context.secondary, fontSize: 10)),
                        ]))));
                }).toList())
              : _profileChip(context, _budgetLabelFor(user.budget)),
          const SizedBox(height: 20),

        
          Text('Travel Style', style: TextStyle(color: context.primary,
              fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          _editing
              ? Wrap(spacing: 8, runSpacing: 8,
                  children: _travelStyles.map((s) {
                    final sel = _selectedTravelStyle == s['value'];
                    return GestureDetector(
                      onTap: () => setState(() => _selectedTravelStyle = s['value']!),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: sel ? kAccent.withOpacity(0.10) : context.card,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: sel ? kAccent : context.divider,
                              width: sel ? 1.5 : 1)),
                        child: Text(s['label']!, style: TextStyle(
                            color: sel ? kAccentDim : context.secondary,
                            fontSize: 13,
                            fontWeight: sel ? FontWeight.w700 : FontWeight.w400))));
                  }).toList())
              : _profileChip(context, _styleLabelFor(user.travelStyle)),
          const SizedBox(height: 24),

         
          _settingRow(context, Icons.help_outline_rounded, 'Help & Support',
              () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => const HelpSupportScreen()))),
          _settingRow(context, Icons.gavel_outlined, 'Terms of Service',
              () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => const TermsScreen()))),
          _settingRow(context, Icons.policy_outlined, 'Privacy Policy',
              () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => const TermsScreen(showPrivacy: true)))),
                
          const SizedBox(height: 16),
          

       
          SizedBox(width: double.infinity, child: OutlinedButton.icon(
            icon: const Icon(Icons.logout_rounded, size: 18),
            label: const Text('Sign Out'),
            style: OutlinedButton.styleFrom(
              foregroundColor: kDanger,
              side: const BorderSide(color: kDanger),
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: _signOut)),

          const SizedBox(height: 24),

          const SizedBox(height: 8),
          Center(child: TextButton(
            onPressed: _deleteAccount,
            style: TextButton.styleFrom(
              foregroundColor: context.secondary,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10)),
            child: Text('Delete account',
                style: TextStyle(
                  color: context.secondary,
                  fontSize: 12,
                  decoration: TextDecoration.underline,
                  decorationColor: context.secondary)))),
          const SizedBox(height: 24),
        ])),
      ]))),
    );
  }

  String _budgetLabelFor(String? b) {
    switch (b) {
      case 'low':  return 'Budget';
      case 'high': return 'Luxury';
      default:     return 'Mid-range';
    }
  }

  String _styleLabelFor(String? s) {
    const map = {
      'cultural':  'Cultural',
      'adventure': 'Adventure',
      'relaxed':   'Relaxed',
      'family':    'Family',
      'romantic':  'Romantic',
      'foodie':    'Foodie',
    };
    return map[s] ?? 'Cultural';
  }

  Widget _profileChip(BuildContext context, String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    decoration: BoxDecoration(
      color: kAccent.withOpacity(0.10),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: kAccent, width: 1.5)),
    child: Text(label, style: const TextStyle(
        color: kAccentDim, fontSize: 13, fontWeight: FontWeight.w700)));

  Widget _statItem(BuildContext context, String val, String label) =>
      Expanded(child: Column(children: [
        Text(val, style: TextStyle(color: context.primary,
            fontSize: 20, fontWeight: FontWeight.w800)),
        Text(label, style: TextStyle(color: context.secondary, fontSize: 12)),
      ]));

  Widget _settingRow(BuildContext ctx, IconData icon, String label, VoidCallback onTap) =>
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Container(padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: ctx.card, borderRadius: BorderRadius.circular(10),
                border: Border.all(color: ctx.divider)),
            child: Icon(icon, size: 18, color: ctx.secondary)),
        title: Text(label, style: TextStyle(color: ctx.primary,
            fontSize: 14, fontWeight: FontWeight.w600)),
        trailing: Icon(Icons.chevron_right_rounded, color: ctx.secondary),
        onTap: onTap,
      );
}