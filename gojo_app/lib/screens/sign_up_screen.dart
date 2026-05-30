import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme.dart';
import '../services/app_state.dart';
import '../models/models.dart';
//import '../widgets/shared_widgets.dart';
import 'main_shell.dart';
import 'business/business_shell.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});
  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _nationalityCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _error;
  final Set<String> _interests = {};
  UserRole _selectedRole = UserRole.tourist;
  String _selectedBudget = 'medium';
  String _selectedTravelStyle = 'cultural';

  final List<String> _allInterests = [
    'history', 'nature', 'food', 'adventure', 'culture',
    'diving', 'hiking', 'art', 'photography', 'religion', 'nightlife',
  ];

  final List<Map<String, String>> _budgetOptions = [
    {'value': 'low',    'label': 'Budget',    'sub': 'Keep it affordable'},
    {'value': 'medium', 'label': 'Mid-range', 'sub': 'Balanced spending'},
    {'value': 'high',   'label': 'Luxury',    'sub': 'Go all out'},
  ];

  final List<Map<String, String>> _travelStyles = [
    {'value': 'cultural',  'label': ' Cultural',  'sub': 'History & heritage'},
    {'value': 'adventure', 'label': ' Adventure', 'sub': 'Thrill & outdoors'},
    {'value': 'relaxed',   'label': ' Relaxed',   'sub': 'Slow & peaceful'},
    {'value': 'family',    'label': ' Family',   'sub': 'Kid-friendly'},
    {'value': 'romantic',  'label': ' Romantic',  'sub': 'Couples & getaways'},
    {'value': 'foodie',    'label': ' Foodie',    'sub': 'Eat your way around'},
  ];

  @override
  void dispose() {
    _nameCtrl.dispose(); _emailCtrl.dispose();
    _passCtrl.dispose(); _confirmCtrl.dispose();
    _nationalityCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_passCtrl.text != _confirmCtrl.text) {
      setState(() => _error = 'Passwords do not match.');
      return;
    }
    if (_nameCtrl.text.trim().isEmpty ||
        _emailCtrl.text.trim().isEmpty ||
        _passCtrl.text.trim().length < 6) {
      setState(() => _error =
          'Please fill all fields correctly. Password must be 6+ chars.');
      return;
    }
    setState(() { _error = null; _loading = true; });
    final state = context.read<AppState>();
    final ok = await state.signUp(
      _nameCtrl.text.trim(),
      _emailCtrl.text.trim(),
      _passCtrl.text.trim(),
      _selectedRole,
      interests: _interests.toList(),
      budget: _selectedRole == UserRole.tourist ? _selectedBudget : null,
      travelStyle: _selectedRole == UserRole.tourist ? _selectedTravelStyle : null,
      nationality: _nationalityCtrl.text.trim().isNotEmpty
          ? _nationalityCtrl.text.trim()
          : null,
    );
    if (!mounted) return;
    if (ok) {
      final dest = _selectedRole == UserRole.localBusiness
          ? const BusinessShell()
          : const MainShell();
      Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => dest));
    } else {
      setState(() {
        _error = state.authError ?? 'Sign up failed.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F9FC),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Create Account',
            style: TextStyle(
                color: Color(0xFF1A202C), fontWeight: FontWeight.w700)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Join GoJo',
                style: TextStyle(
                    color: Color(0xFF1A202C),
                    fontSize: 26,
                    fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            const Text('Start exploring Jordan your way',
                style: TextStyle(color: Color(0xFF6B7280), fontSize: 14)),
            const SizedBox(height: 28),

            const Text('I am a...',
                style: TextStyle(
                    color: Color(0xFF374151),
                    fontSize: 15,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            Row(children: [
              _roleOption(
                  role: UserRole.tourist,
                  emoji: '🧳',
                  label: 'Tourist',
                  sub: 'Exploring Jordan'),
              const SizedBox(width: 10),
              _roleOption(
                  role: UserRole.localBusiness,
                  emoji: '🏪',
                  label: 'Business',
                  sub: 'List my business'),
            ]),
            const SizedBox(height: 20),

            _buildField(
                controller: _nameCtrl,
                hint: 'Full name',
                icon: Icons.person_outline),
            const SizedBox(height: 14),
            _buildField(
                controller: _emailCtrl,
                hint: 'Email address',
                icon: Icons.email_outlined,
                type: TextInputType.emailAddress),
            const SizedBox(height: 14),
            _buildPasswordField(
                controller: _passCtrl, hint: 'Password (min 6 chars)'),
            const SizedBox(height: 14),
            _buildPasswordField(
                controller: _confirmCtrl,
                hint: 'Confirm password',
                obscure: true),
            const SizedBox(height: 14),
            _buildField(
                controller: _nationalityCtrl,
                hint: 'Nationality (optional)',
                icon: Icons.flag_outlined),

            // ── Tourist-only itinerary fields ─────────────────────────
            if (_selectedRole == UserRole.tourist) ...[
              const SizedBox(height: 28),
              _sectionHeader('Travel Budget',
                  'Used to personalise your AI itinerary recommendations'),
              const SizedBox(height: 12),
              Row(children: _budgetOptions.asMap().entries.map((e) {
                final b = e.value;
                final isLast = e.key == _budgetOptions.length - 1;
                final sel = _selectedBudget == b['value'];
                return Expanded(
                  child: GestureDetector(
                    onTap: () =>
                        setState(() => _selectedBudget = b['value']!),
                    child: Container(
                      margin: EdgeInsets.only(right: isLast ? 0 : 8),
                      padding: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: 4),
                      decoration: BoxDecoration(
                        color: sel
                            ? kAccent.withOpacity(0.08)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: sel
                              ? kAccent
                              : const Color(0xFFE5E7EB),
                          width: sel ? 2 : 1,
                        ),
                      ),
                      child: Column(children: [
                        Text(b['label']!,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: sel
                                    ? kAccentDim
                                    : const Color(0xFF374151),
                                fontWeight: FontWeight.w700,
                                fontSize: 12)),
                        const SizedBox(height: 2),
                        Text(b['sub']!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: Color(0xFF9CA3AF),
                                fontSize: 10)),
                      ]),
                    ),
                  ),
                );
              }).toList()),

              const SizedBox(height: 22),
              _sectionHeader(
                  'Travel Style', 'How do you like to explore?'),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _travelStyles.map((s) {
                  final sel = _selectedTravelStyle == s['value'];
                  return GestureDetector(
                    onTap: () => setState(
                        () => _selectedTravelStyle = s['value']!),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 9),
                      decoration: BoxDecoration(
                        color: sel
                            ? kAccent.withOpacity(0.10)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: sel
                              ? kAccent
                              : const Color(0xFFE5E7EB),
                          width: sel ? 1.5 : 1,
                        ),
                      ),
                      child: Text(s['label']!,
                          style: TextStyle(
                            color: sel
                                ? kAccentDim
                                : const Color(0xFF6B7280),
                            fontSize: 13,
                            fontWeight: sel
                                ? FontWeight.w700
                                : FontWeight.w400,
                          )),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 22),
              _sectionHeader('Your Interests',
                  'Further personalises your AI itinerary'),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _allInterests.map((t) => GestureDetector(
                  onTap: () => setState(() {
                    _interests.contains(t)
                        ? _interests.remove(t)
                        : _interests.add(t);
                  }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: _interests.contains(t)
                          ? kAccent.withOpacity(0.12)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _interests.contains(t)
                            ? kAccent
                            : const Color(0xFFE5E7EB),
                      ),
                    ),
                    child: Text(t,
                        style: TextStyle(
                          color: _interests.contains(t)
                              ? kAccentDim
                              : const Color(0xFF6B7280),
                          fontSize: 13,
                          fontWeight: _interests.contains(t)
                              ? FontWeight.w600
                              : FontWeight.w400,
                        )),
                  ),
                )).toList(),
              ),
            ],

            if (_selectedRole == UserRole.localBusiness) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF9EC),
                  borderRadius: BorderRadius.circular(14),
                  border:
                      Border.all(color: kWarning.withOpacity(0.3)),
                ),
                child: const Row(children: [
                  Icon(Icons.info_outline, color: kWarning, size: 18),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'After signing up, you can add your business for admin review. Listings go live once approved.',
                      style: TextStyle(
                          color: Color(0xFF92400E),
                          fontSize: 12,
                          height: 1.4),
                    ),
                  ),
                ]),
              ),
            ],

            if (_error != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: kDanger.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: kDanger.withOpacity(0.25))),
                child: Text(_error!,
                    style: const TextStyle(
                        color: kDanger, fontSize: 12)),
              ),
            ],
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kAccent,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                  textStyle: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 16),
                ),
                child: _loading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white))
                    : Text(_selectedRole ==
                            UserRole.localBusiness
                        ? 'Create Business Account'
                        : 'Create Account'),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title, String sub) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  color: Color(0xFF374151),
                  fontSize: 15,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(sub,
              style: const TextStyle(
                  color: Color(0xFF6B7280), fontSize: 12)),
        ],
      );

  Widget _roleOption({
    required UserRole role,
    required String emoji,
    required String label,
    required String sub,
  }) {
    final selected = _selectedRole == role;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedRole = role),
        child: Container(
          padding: const EdgeInsets.symmetric(
              vertical: 16, horizontal: 12),
          decoration: BoxDecoration(
            color: selected
                ? kAccent.withOpacity(0.08)
                : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? kAccent
                  : const Color(0xFFE5E7EB),
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(children: [
            Text(emoji,
                style: const TextStyle(fontSize: 28)),
            const SizedBox(height: 6),
            Text(label,
                style: TextStyle(
                    color: selected
                        ? kAccentDim
                        : const Color(0xFF374151),
                    fontWeight: FontWeight.w700,
                    fontSize: 14)),
            Text(sub,
                style: const TextStyle(
                    color: Color(0xFF9CA3AF), fontSize: 11)),
          ]),
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType? type,
  }) =>
      TextField(
        controller: controller,
        keyboardType: type,
        decoration: _inputDec(hint, icon),
      );

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String hint,
    bool obscure = false,
  }) {
    return StatefulBuilder(
      builder: (ctx, setSt) {
        final obs = obscure ? true : _obscure;
        return TextField(
          controller: controller,
          obscureText: obs,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFFADB5BD)),
            prefixIcon: const Icon(Icons.lock_outline,
                color: Color(0xFF9CA3AF), size: 20),
            suffixIcon: obscure
                ? null
                : IconButton(
                    icon: Icon(
                        _obscure
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: const Color(0xFF9CA3AF),
                        size: 20),
                    onPressed: () =>
                        setState(() => _obscure = !_obscure),
                  ),
            filled: true,
            fillColor: const Color(0xFFF9FAFB),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                    color: Color(0xFFE5E7EB))),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                    color: Color(0xFFE5E7EB))),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide:
                    const BorderSide(color: kAccent, width: 1.5)),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 16),
          ),
        );
      },
    );
  }

  InputDecoration _inputDec(String hint, IconData icon) =>
      InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFFADB5BD)),
        prefixIcon:
            Icon(icon, color: const Color(0xFF9CA3AF), size: 20),
        filled: true,
        fillColor: const Color(0xFFF9FAFB),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide:
                const BorderSide(color: Color(0xFFE5E7EB))),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide:
                const BorderSide(color: Color(0xFFE5E7EB))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide:
                const BorderSide(color: kAccent, width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 16),
      );
}