import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme.dart';
import '../services/app_state.dart';
import '../models/models.dart';
import 'main_shell.dart';
import 'sign_up_screen.dart';
import 'forgot_password_dialog.dart';
import 'admin/admin_shell.dart';
import 'business/business_shell.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});
  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() { _error = null; _loading = true; });
    final state = context.read<AppState>();
    final ok = await state.signIn(_emailCtrl.text.trim(), _passCtrl.text.trim());
    if (!mounted) return;
    if (ok) {
      Widget dest;
      switch (state.role) {
        case UserRole.admin:         dest = const AdminShell();    break;
        case UserRole.localBusiness: dest = const BusinessShell(); break;
        default:                     dest = const MainShell();
      }
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => dest));
    } else {
      setState(() {
        _error = state.authError ?? 'Invalid credentials.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 64),
              // Logo
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFC8963E), Color(0xFF7A5020)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: kAccent.withOpacity(0.3),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    )
                  ],
                ),
                child: const Center(child: Icon(Icons.explore_rounded, color: kAccent, size: 38)),
              ),
              const SizedBox(height: 18),
              RichText(
                text: const TextSpan(children: [
                  TextSpan(text: 'Go', style: TextStyle(color: kAccent, fontSize: 36, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                  TextSpan(text: 'Jo', style: TextStyle(color: Color(0xFF1A202C), fontSize: 36, fontWeight: FontWeight.w200, letterSpacing: -0.5)),
                ]),
              ),
              const SizedBox(height: 4),
              const Text('Your Jordan travel companion',
                  style: TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
              const SizedBox(height: 48),
              // Form card
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFE8ECF0)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Welcome back',
                        style: TextStyle(
                            color: Color(0xFF1A202C),
                            fontSize: 22,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    const Text('Sign in to continue exploring Jordan',
                        style: TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
                    const SizedBox(height: 24),
                    _buildField(
                      controller: _emailCtrl,
                      hint: 'Email address',
                      icon: Icons.email_outlined,
                      type: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _passCtrl,
                      obscureText: _obscure,
                      style: const TextStyle(color: Color(0xFF1A202C)),
                      onSubmitted: (_) => _submit(),
                      decoration: InputDecoration(
                        hintText: 'Password',
                        hintStyle: const TextStyle(color: Color(0xFFADB5BD)),
                        prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF9CA3AF), size: 20),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                            color: const Color(0xFF9CA3AF), size: 20),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF9FAFB),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: kAccent, width: 1.5),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      ),
                    ),
                    
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => showForgotPasswordDialog(context),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text(
                          'Forgot password?',
                          style: TextStyle(
                            color: kAccent,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: kDanger.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: kDanger.withOpacity(0.25)),
                        ),
                        child: Row(children: [
                          const Icon(Icons.error_outline, color: kDanger, size: 16),
                          const SizedBox(width: 8),
                          Expanded(child: Text(_error!, style: const TextStyle(color: kDanger, fontSize: 12))),
                        ]),
                      ),
                    ],
                    const SizedBox(height: 22),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kAccent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                        ),
                        child: _loading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.white),
                              )
                            : const Text('Sign In'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Text("Don't have an account? ",
                    style: TextStyle(color: Color(0xFF6B7280), fontSize: 14)),
                GestureDetector(
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const SignUpScreen())),
                  child: const Text('Sign Up',
                      style: TextStyle(
                          color: kAccent,
                          fontWeight: FontWeight.w700,
                          fontSize: 14)),
                ),
              ]),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType? type,
  }) {
    return TextField(
      controller: controller,
      keyboardType: type,
      style: const TextStyle(color: Color(0xFF1A202C)),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFFADB5BD)),
        prefixIcon: Icon(icon, color: const Color(0xFF9CA3AF), size: 20),
        filled: true,
        fillColor: const Color(0xFFF9FAFB),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: kAccent, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }
}