import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme.dart';

Future<void> showForgotPasswordDialog(BuildContext context) {
  return showDialog(
    context: context,
    barrierDismissible: true,
    builder: (_) => const _ForgotPasswordDialog(),
  );
}

class _ForgotPasswordDialog extends StatefulWidget {
  const _ForgotPasswordDialog();
  @override
  State<_ForgotPasswordDialog> createState() => _ForgotPasswordDialogState();
}

class _ForgotPasswordDialogState extends State<_ForgotPasswordDialog> {
  final _emailCtrl = TextEditingController();
  bool _loading = false;
  bool _sent    = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final emailRaw   = _emailCtrl.text.trim();
    final emailLower = emailRaw.toLowerCase();

    if (emailRaw.isEmpty || !emailRaw.contains('@') || !emailRaw.contains('.')) {
      setState(() => _error = 'Please enter a valid email address.');
      return;
    }

    setState(() { _error = null; _loading = true; });

    try {
      final firestore = FirebaseFirestore.instance;

      // Try exact match first, then lowercase — covers however the
      // email was stored when the account was created.
      QuerySnapshot query = await firestore
          .collection('users')
          .where('email', isEqualTo: emailRaw)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        query = await firestore
            .collection('users')
            .where('email', isEqualTo: emailLower)
            .limit(1)
            .get();
      }

      if (!mounted) return;

      if (query.docs.isEmpty) {
        setState(() {
          _loading = false;
          _error   = 'No account found with this email address.';
        });
        return;
      }

      // Account confirmed in Firestore — send the reset email
      await FirebaseAuth.instance
          .sendPasswordResetEmail(email: emailRaw);

      if (!mounted) return;
      setState(() { _loading = false; _sent = true; });

    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error   = switch (e.code) {
          'invalid-email'     => 'The email address is not valid.',
          'too-many-requests' => 'Too many attempts. Please try again later.',
          _                   => 'Something went wrong. Please try again.',
        };
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error   = 'Something went wrong. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _sent ? _buildSuccess() : _buildForm(),
        ),
      ),
    );
  }

  Widget _buildForm() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: kAccent.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.lock_reset_rounded, color: kAccent, size: 22),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Forgot password?',
                  style: TextStyle(color: Color(0xFF1A202C), fontSize: 17, fontWeight: FontWeight.w800)),
              SizedBox(height: 2),
              Text("We'll send a reset link to your email.",
                  style: TextStyle(color: Color(0xFF6B7280), fontSize: 12)),
            ]),
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close_rounded, color: Color(0xFF9CA3AF), size: 20),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ]),
        const SizedBox(height: 20),
        const Text('Email address',
            style: TextStyle(color: Color(0xFF1A202C), fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextField(
          controller: _emailCtrl,
          keyboardType: TextInputType.emailAddress,
          style: const TextStyle(color: Color(0xFF1A202C)),
          onSubmitted: (_) => _submit(),
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'you@example.com',
            hintStyle: const TextStyle(color: Color(0xFFADB5BD)),
            prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFF9CA3AF), size: 20),
            filled: true,
            fillColor: const Color(0xFFF9FAFB),
            border:        OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: kAccent, width: 1.5)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: kDanger.withOpacity(0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: kDanger.withOpacity(0.25)),
            ),
            child: Row(children: [
              const Icon(Icons.error_outline, color: kDanger, size: 15),
              const SizedBox(width: 8),
              Expanded(child: Text(_error!, style: const TextStyle(color: kDanger, fontSize: 12))),
            ]),
          ),
        ],
        const SizedBox(height: 20),
        Row(children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                side: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
              child: const Text('Cancel',
                  style: TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: _loading ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: kAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
                textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
              child: _loading
                  ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                  : const Text('Send link'),
            ),
          ),
        ]),
      ],
    );
  }

  Widget _buildSuccess() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 8),
        Container(
          width: 56, height: 56,
          decoration: const BoxDecoration(color: Color(0xFFEAF3DE), shape: BoxShape.circle),
          child: const Icon(Icons.mark_email_read_outlined, color: Color(0xFF3B6D11), size: 28),
        ),
        const SizedBox(height: 16),
        const Text('Check your inbox',
            style: TextStyle(color: Color(0xFF1A202C), fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Text('A reset link was sent to\n${_emailCtrl.text.trim()}',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13, height: 1.5)),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: kAccent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
              textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
            child: const Text('Done'),
          ),
        ),
        const SizedBox(height: 10),
        TextButton(
          onPressed: () => setState(() { _sent = false; _emailCtrl.clear(); }),
          child: const Text('Try a different email',
              style: TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
        ),
      ],
    );
  }
}