import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../api.dart';
import '../theme.dart';
import '../services/app_state.dart';
import 'place_model.dart';
import 'itinerary_screen.dart';

class AiItineraryScreen extends StatefulWidget {
  const AiItineraryScreen({super.key});

  @override
  State<AiItineraryScreen> createState() => _AiItineraryScreenState();
}

class _AiItineraryScreenState extends State<AiItineraryScreen> {
  final ApiService _apiService = ApiService();
  final _favoritesController = TextEditingController();
  final _tagsController = TextEditingController();
  final _customInterestsController = TextEditingController();

  String selectedCategory = 'nature';
  String selectedBudget = 'low';
  int selectedDays = 2;
  bool isLoading = false;

  /// Whether to pre-fill from the user's profile instead of manual input
  bool _useProfile = false;

  @override
  void initState() {
    super.initState();
    // Default to using profile if the user has profile data
    final user = context.read<AppState>().user;
    if (user != null &&
        (user.budget != null ||
            user.travelStyle != null ||
            user.interests.isNotEmpty)) {
      _useProfile = true;
    }
    _syncFromProfile();
  }

  void _syncFromProfile() {
    if (!_useProfile) return;
    final user = context.read<AppState>().user;
    if (user == null) return;
    setState(() {
      if (user.budget != null) selectedBudget = user.budget!;
      if (user.interests.isNotEmpty) {
        _customInterestsController.text = user.interests.join(', ');
        // Map first interest to category if possible
        final first = user.interests.first;
        const catMap = {
          'nature': 'nature',
          'history': 'historical',
          'food': 'city',
          'adventure': 'nature',
          'culture': 'cultural',
          'diving': 'beach',
          'hiking': 'nature',
          'art': 'cultural',
          'photography': 'city',
          'religion': 'religious',
          'nightlife': 'city',
          'beach': 'beach',
        };
        selectedCategory = catMap[first] ?? 'nature';
      }
    });
  }

  @override
  void dispose() {
    _favoritesController.dispose();
    _tagsController.dispose();
    _customInterestsController.dispose();
    super.dispose();
  }

  Future<void> _generatePlan() async {
    if (isLoading) return;
    setState(() => isLoading = true);

    try {
      final user = context.read<AppState>().user;

      // When using profile, merge profile data with any manual overrides
      String budget = selectedBudget;
      String tags = _tagsController.text.trim();

      if (_useProfile && user != null) {
        budget = user.budget ?? selectedBudget;
        // Merge profile interests into tags
        final profileInterests = [
          ...user.interests,
          if (user.travelStyle != null) user.travelStyle!,
          if (user.nationality != null) user.nationality!,
        ].join(', ');
        final manualTags = _tagsController.text.trim();
        tags = [profileInterests, if (manualTags.isNotEmpty) manualTags]
            .join(', ');
      }

      final result = await _apiService.getItinerary(
        category: selectedCategory,
        budget: budget,
        days: selectedDays,
        favorites: _favoritesController.text.trim(),
        tags: tags,
      );

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ItineraryScreen(
            itinerary: result['itinerary'] as Map<String, List<Place>>,
            totals: result['totals'] as Map<String, int>,
            category: selectedCategory,
            budget: budget,
            days: selectedDays,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error: ${e.toString()}"),
          backgroundColor: kDanger,
        ),
      );
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AppState>().user;
    final hasProfile = user != null &&
        (user.budget != null ||
            user.travelStyle != null ||
            user.interests.isNotEmpty);

    return Scaffold(
      backgroundColor: context.bg,
      appBar: AppBar(
        title: const Text('AI Trip Planner'),
        backgroundColor: context.surface,
        foregroundColor: context.primary,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: context.divider),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── Profile toggle banner ─────────────────────────────────
            if (hasProfile) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: _useProfile
                      ? kAccent.withOpacity(0.08)
                      : context.card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _useProfile ? kAccent : context.divider,
                    width: _useProfile ? 1.5 : 1,
                  ),
                ),
                child: Row(children: [
                  Icon(Icons.person_rounded,
                      color: _useProfile ? kAccent : context.secondary,
                      size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text('Use my profile preferences',
                              style: TextStyle(
                                  color: _useProfile
                                      ? kAccentDim
                                      : context.primary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14)),
                          const SizedBox(height: 2),
                          Text(
                            _buildProfileSummary(user),
                            style: TextStyle(
                                color: context.secondary,
                                fontSize: 11),
                          ),
                        ]),
                  ),
                  Switch.adaptive(
                    value: _useProfile,
                    activeColor: kAccent,
                    onChanged: isLoading
                        ? null
                        : (val) {
                            setState(() => _useProfile = val);
                            if (val) _syncFromProfile();
                          },
                  ),
                ]),
              ),
              const SizedBox(height: 20),
            ],

            // ── Section label ─────────────────────────────────────────
            Text(
              'What kind of trip?',
              style: TextStyle(
                color: context.primary,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),

            // ── Category ─────────────────────────────────────────────
            DropdownButtonFormField<String>(
              value: selectedCategory,
              dropdownColor: context.surface,
              style: TextStyle(color: context.primary, fontSize: 14),
              decoration: InputDecoration(
                labelText: 'Category',
                labelStyle: TextStyle(color: context.secondary),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: kAccent, width: 1.5),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: context.divider),
                ),
                filled: true,
                fillColor: context.card,
              ),
              items: [
                'nature',
                'historical',
                'religious',
                'beach',
                'shopping',
                'city',
                'cultural'
              ]
                  .map((c) => DropdownMenuItem(
                        value: c,
                        child: Text(
                          c[0].toUpperCase() + c.substring(1),
                          style: TextStyle(color: context.primary),
                        ),
                      ))
                  .toList(),
              onChanged: isLoading
                  ? null
                  : (val) => setState(() => selectedCategory = val!),
            ),

            const SizedBox(height: 14),

            // ── Budget ───────────────────────────────────────────────
            // When using profile and profile has a budget, show a read-only chip
            if (_useProfile && user?.budget != null) ...[
              Text('Budget',
                  style: TextStyle(
                      color: context.secondary, fontSize: 13)),
              const SizedBox(height: 6),
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: kAccent.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: kAccent, width: 1.5),
                  ),
                  child: Text(
                    _budgetLabel(user!.budget!),
                    style: const TextStyle(
                        color: kAccentDim,
                        fontSize: 13,
                        fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 8),
                Text('from your profile',
                    style: TextStyle(
                        color: context.secondary, fontSize: 12)),
              ]),
            ] else ...[
              DropdownButtonFormField<String>(
                value: selectedBudget,
                dropdownColor: context.surface,
                style:
                    TextStyle(color: context.primary, fontSize: 14),
                decoration: InputDecoration(
                  labelText: 'Budget',
                  labelStyle: TextStyle(color: context.secondary),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                        color: kAccent, width: 1.5),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: context.divider),
                  ),
                  filled: true,
                  fillColor: context.card,
                ),
                items: ['low', 'medium', 'high']
                    .map((b) => DropdownMenuItem(
                          value: b,
                          child: Text(
                            b[0].toUpperCase() + b.substring(1),
                            style:
                                TextStyle(color: context.primary),
                          ),
                        ))
                    .toList(),
                onChanged: isLoading
                    ? null
                    : (val) =>
                        setState(() => selectedBudget = val!),
              ),
            ],

            const SizedBox(height: 20),

            // ── Days picker ──────────────────────────────────────────
            Text(
              'Trip Duration',
              style: TextStyle(
                color: context.primary,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: List.generate(5, (i) {
                final d = i + 1;
                final selected = selectedDays == d;
                return Expanded(
                  child: GestureDetector(
                    onTap: isLoading
                        ? null
                        : () =>
                            setState(() => selectedDays = d),
                    child: Container(
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(
                          vertical: 12),
                      decoration: BoxDecoration(
                        color: selected
                            ? kAccent.withOpacity(0.12)
                            : context.card,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: selected
                              ? kAccent
                              : context.divider,
                          width: selected ? 1.5 : 1,
                        ),
                      ),
                      child: Column(children: [
                        Text(
                          '$d',
                          style: TextStyle(
                            color: selected
                                ? kAccent
                                : context.primary,
                            fontWeight: FontWeight.w700,
                            fontSize: 18,
                          ),
                        ),
                        Text(
                          d == 1 ? 'day' : 'days',
                          style: TextStyle(
                            color: context.secondary,
                            fontSize: 10,
                          ),
                        ),
                      ]),
                    ),
                  ),
                );
              }),
            ),

            const SizedBox(height: 20),

            // ── Personalise section ──────────────────────────────────
            Text(
              _useProfile
                  ? 'Additional personalisation (optional)'
                  : 'Personalise (optional)',
              style: TextStyle(
                color: context.primary,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            if (_useProfile && hasProfile)
              Text(
                'Your profile interests & travel style are already included',
                style: TextStyle(
                    color: context.secondary, fontSize: 12),
              ),
            const SizedBox(height: 12),

            // When NOT using profile, show interests field
            if (!_useProfile) ...[
              TextField(
                controller: _customInterestsController,
                enabled: !isLoading,
                style:
                    TextStyle(color: context.primary, fontSize: 14),
                decoration: InputDecoration(
                  labelText: 'Interests / Tags',
                  hintText: 'e.g. hiking, food, history',
                  labelStyle: TextStyle(color: context.secondary),
                  hintStyle: TextStyle(
                      color: context.secondary.withOpacity(0.6)),
                  helperText:
                      'Comma-separated interests to guide recommendations',
                  helperStyle: TextStyle(
                      color: context.secondary, fontSize: 11),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                        color: kAccent, width: 1.5),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: context.divider),
                  ),
                  filled: true,
                  fillColor: context.card,
                ),
              ),
              const SizedBox(height: 14),
            ],

            TextField(
              controller: _favoritesController,
              enabled: !isLoading,
              style:
                  TextStyle(color: context.primary, fontSize: 14),
              decoration: InputDecoration(
                labelText: 'Favourite Places',
                hintText: 'e.g. Petra, Dead Sea',
                labelStyle: TextStyle(color: context.secondary),
                hintStyle: TextStyle(
                    color: context.secondary.withOpacity(0.6)),
                helperText:
                    'Comma-separated — boosts matching places',
                helperStyle: TextStyle(
                    color: context.secondary, fontSize: 11),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: kAccent, width: 1.5),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: context.divider),
                ),
                filled: true,
                fillColor: context.card,
              ),
            ),

            const SizedBox(height: 14),

            TextField(
              controller: _tagsController,
              enabled: !isLoading,
              style:
                  TextStyle(color: context.primary, fontSize: 14),
              decoration: InputDecoration(
                labelText: 'Extra Keywords',
                hintText: 'e.g. romance, family, must-see',
                labelStyle: TextStyle(color: context.secondary),
                hintStyle: TextStyle(
                    color: context.secondary.withOpacity(0.6)),
                helperText:
                    'Any extra keywords to refine recommendations',
                helperStyle: TextStyle(
                    color: context.secondary, fontSize: 11),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: kAccent, width: 1.5),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: context.divider),
                ),
                filled: true,
                fillColor: context.card,
              ),
            ),

            const SizedBox(height: 32),

            // ── Generate button ──────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: kAccent,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor:
                      kAccent.withOpacity(0.6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                onPressed: isLoading ? null : _generatePlan,
                child: isLoading
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : Row(
                        mainAxisAlignment:
                            MainAxisAlignment.center,
                        children: [

                          const SizedBox(width: 8),
                          Text(
                            _useProfile
                                ? 'Generate with My Profile'
                                : 'Generate My Itinerary',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  String _buildProfileSummary(dynamic user) {
    final parts = <String>[];
    if (user.budget != null) parts.add(_budgetLabel(user.budget!));
    if (user.travelStyle != null)
      parts.add(user.travelStyle![0].toUpperCase() +
          user.travelStyle!.substring(1));
    if (user.interests.isNotEmpty)
      parts.add('${user.interests.length} interests');
    return parts.isEmpty ? 'No profile data yet' : parts.join(' · ');
  }

  String _budgetLabel(String b) {
    switch (b) {
      case 'low':  return 'Budget ';
      case 'high': return 'Luxury ';
      default:     return 'Mid-range ';
    }
  }
}