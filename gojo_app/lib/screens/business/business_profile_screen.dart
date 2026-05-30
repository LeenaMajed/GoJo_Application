import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../theme.dart';
import '../help_support_screen.dart';
import '../terms_screen.dart';
import '../../services/app_state.dart';
import '../sign_in_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import 'dart:ui' as ui;

class BusinessProfileScreen extends StatefulWidget {
  const BusinessProfileScreen({super.key});
  @override
  State<BusinessProfileScreen> createState() => _BusinessProfileScreenState();
}

class _BusinessProfileScreenState extends State<BusinessProfileScreen> {
  XFile? _profileImage;
  final _picker = ImagePicker();
  bool _editing = false;
  late TextEditingController _nameCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: context.read<AppState>().user?.name ?? '');
  }
Future<void> _deleteAccount() async {
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
              width: 78,
              height: 78,
              decoration: BoxDecoration(
                color: kDanger.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.delete_forever_rounded,
                color: kDanger,
                size: 40,
              ),
            ),

            const SizedBox(height: 20),

            Text(
              'Delete Business Account?',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: dlg.primary,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),

            const SizedBox(height: 10),

            Text(
              'This will permanently remove your business account and listings.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: dlg.secondary,
                fontSize: 13,
                height: 1.6,
              ),
            ),

            const SizedBox(height: 22),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(dlg, false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: dlg.secondary,
                      side: BorderSide(color: dlg.divider),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                    label: const Text('Delete'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kDanger,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () => Navigator.pop(dlg, true),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );

  if (confirmed != true) return;

  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return;

  try {
    final places = await FirebaseFirestore.instance
        .collection('places')
        .where('businessId', isEqualTo: uid)
        .get();

    for (final doc in places.docs) {
      await doc.reference.delete();
    }
    final services = await FirebaseFirestore.instance
        .collection('services')
        .where('businessId', isEqualTo: uid)
        .get();

    for (final doc in services.docs) {
      await doc.reference.delete();
    }

    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .delete();

    await FirebaseAuth.instance.currentUser!.delete();

    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const SignInScreen()),
        (_) => false,
      );
    }

  } on FirebaseAuthException catch (e) {

    if (e.code == 'requires-recent-login') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please sign in again before deleting your account.',
          ),
          backgroundColor: kDanger,
        ),
      );
    }

  } catch (e) {

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Error: $e'),
        backgroundColor: kDanger,
      ),
    );
  }
}
  @override
  void dispose() { _nameCtrl.dispose(); super.dispose(); }

void _showImagePicker() {
  showModalBottomSheet(
    context: context,
    backgroundColor: context.surface,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 36, height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(color: context.divider, borderRadius: BorderRadius.circular(2))),
          ListTile(
            leading: Container(padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: kAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.camera_alt_rounded, color: kAccent)),
            title: const Text('Take Photo', style: TextStyle(fontWeight: FontWeight.w600)),
            onTap: () async {
              Navigator.pop(context);
              final img = await _picker.pickImage(
                source: ImageSource.camera, imageQuality: 70,
                maxWidth: 800, maxHeight: 800);
              if (img != null && mounted) setState(() => _profileImage = img);
            },
          ),
          ListTile(
            leading: Container(padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: kDeadSeaBlue.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.photo_library_rounded, color: kDeadSeaBlue)),
            title: const Text('Choose from Gallery', style: TextStyle(fontWeight: FontWeight.w600)),
            onTap: () async {
              Navigator.pop(context);
              final img = await _picker.pickImage(
                source: ImageSource.gallery, imageQuality: 70,
                maxWidth: 800, maxHeight: 800);
              if (img != null && mounted) setState(() => _profileImage = img);
            },
          ),
        ]),
      ),
    ),
  );
}

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final user  = state.user!;
  
            return Scaffold(
              backgroundColor: context.bg,
              body: SafeArea(child: SingleChildScrollView(child: Column(children: [
                Container(
                  color: context.surface,
                  padding: const EdgeInsets.all(24),
                  child: Column(children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text('Profile', style: TextStyle(color: context.primary,
                          fontSize: 22, fontWeight: FontWeight.w800)),
                      Row(children: [
                        if (_editing)
                          TextButton(
                           onPressed: () async {
  String? base64Image;
  if (_profileImage != null) {
    base64Image = await _convertImageToBase64();
  } else {
    base64Image = context.read<AppState>().user?.photoUrl; 
  }
  await context.read<AppState>().updateProfile(
    name: _nameCtrl.text.trim(),
    photoUrl: base64Image,
  );
  if (mounted) setState(() => _editing = false);
  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile updated!'), backgroundColor: kAccentDim));
},
                            child: const Text('Save', style: TextStyle(color: kAccent)))
                        else
                          TextButton(
                            onPressed: () => setState(() => _editing = true),
                            child: const Text('Edit', style: TextStyle(color: kAccent))),
                        GestureDetector(
                          onTap: () => context.read<AppState>().toggleTheme(),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: context.bg,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: context.divider)),
                            child: Icon(
                                context.isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                                size: 18, color: context.secondary),
                          ),
                        ),
                      ]),
                    ]),
                    const SizedBox(height: 20),

                    // Avatar
                    GestureDetector(
  onTap: _showImagePicker,
  child: Stack(children: [
    Container(
      width: 84, height: 84,
      decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: kAccent, width: 2)),
      child: ClipOval(child: () {
        if (_profileImage != null) {
          return Image.file(File(_profileImage!.path), fit: BoxFit.cover);
        }
        final saved = user.photoUrl;
        if (saved != null && saved.isNotEmpty) {
          return Image.memory(base64Decode(saved), fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _initials(user.name));
        }
        return _initials(user.name);
      }()),
    ),
    Positioned(bottom: 0, right: 0, child: Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(color: kAccent, shape: BoxShape.circle,
          border: Border.all(color: context.surface, width: 2)),
      child: const Icon(Icons.camera_alt_rounded, size: 12, color: Colors.white))),
  ]),
),
                    const SizedBox(height: 12),

                    _editing
                        ? TextField(
                            controller: _nameCtrl,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: context.primary, fontSize: 18, fontWeight: FontWeight.w700),
                            decoration: const InputDecoration(hintText: 'Business name'))
                        : Text(user.name, style: TextStyle(color: context.primary,
                            fontSize: 20, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text(user.email, style: TextStyle(color: context.secondary, fontSize: 13)),
                    const SizedBox(height: 10),

                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(color: kAccent.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.storefront_rounded, color: kAccentDim, size: 14),
                        const SizedBox(width: 6),
                        Text('Local Business Account',
                            style: TextStyle(color: kAccentDim, fontSize: 12, fontWeight: FontWeight.w700)),
                      ]),
                    ),
                    const SizedBox(height: 16),

                  
                  ]),
                ),
                Padding(padding: const EdgeInsets.all(20), child: Column(children: [
                  _settingRow(context, Icons.help_outline_rounded, 'Help & Support',
                      () => Navigator.push(context, MaterialPageRoute(
                          builder: (_) => const HelpSupportScreen(isBusiness: true)))),
                  _settingRow(context, Icons.gavel_outlined, 'Terms of Service',
                      () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TermsScreen()))),
                  _settingRow(context, Icons.policy_outlined, 'Privacy Policy',
                      () => Navigator.push(context, MaterialPageRoute(
                          builder: (_) => const TermsScreen(showPrivacy: true)))),
                  const SizedBox(height: 16),
                  SizedBox(width: double.infinity, child: OutlinedButton.icon(
                    icon: const Icon(Icons.logout_rounded, size: 18),
                    label: const Text('Sign Out'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: kDanger, side: const BorderSide(color: kDanger),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    onPressed: () async {
                      await context.read<AppState>().signOut();
                      if (context.mounted) Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(builder: (_) => const SignInScreen()), (_) => false);
                    })),
                    const SizedBox(height: 18),

Center(
  child: TextButton(
    onPressed: _deleteAccount,
    child: Text(
      'Delete account',
      style: TextStyle(
        color: context.secondary,
        fontSize: 12,
        decoration: TextDecoration.underline,
      ),
    ),
  ),
),
                ])),
              ]))),
            );
            }
      
Widget _initials(String name) => Container(
  color: kAccent.withOpacity(0.12),
  child: Center(child: Text(
    name.isNotEmpty ? name[0].toUpperCase() : 'B',
    style: const TextStyle(color: kAccent, fontSize: 32, fontWeight: FontWeight.w900))));

  Widget _settingRow(BuildContext ctx, IconData icon, String label, VoidCallback onTap) =>
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Container(padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: ctx.card, borderRadius: BorderRadius.circular(10),
                border: Border.all(color: ctx.divider)),
            child: Icon(icon, size: 18, color: ctx.secondary)),
        title: Text(label, style: TextStyle(color: ctx.primary, fontSize: 14, fontWeight: FontWeight.w600)),
        trailing: Icon(Icons.chevron_right_rounded, color: ctx.secondary),
        onTap: onTap,
      );
      Future<String?> _convertImageToBase64() async {
  if (_profileImage == null) return null;
  try {
    final bytes = await File(_profileImage!.path).readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes, targetWidth: 200, targetHeight: 200);
    final frame = await codec.getNextFrame();
    final resized = await frame.image.toByteData(format: ui.ImageByteFormat.png);
    if (resized == null) return null;
    final base64Str = base64Encode(resized.buffer.asUint8List());
    if (base64Str.length > 700000) return null;
    return base64Str;
  } catch (e) {
    debugPrint('Base64 conversion failed: $e');
    return null;
  }
}
}
