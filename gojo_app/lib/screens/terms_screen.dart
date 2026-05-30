import 'package:flutter/material.dart';
import '../theme.dart';

class TermsScreen extends StatelessWidget {
  final bool showPrivacy;
  const TermsScreen({super.key, this.showPrivacy = false});

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 2,
    initialIndex: showPrivacy ? 1 : 0,
    child: Scaffold(
      backgroundColor: context.bg,
      appBar: AppBar(
        backgroundColor: context.surface,
        title: const Text('Legal'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: context.primary, size: 18),
          onPressed: () => Navigator.pop(context)),
        bottom: TabBar(
          labelColor: kAccent,
          unselectedLabelColor: context.secondary,
          indicatorColor: kAccent,
          tabs: const [Tab(text: 'Terms of Service'), Tab(text: 'Privacy Policy')],
        )),
      body: TabBarView(children: [_terms(context), _privacy(context)]),
    ));

  Widget _terms(BuildContext ctx) => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      _h(ctx, 'Terms of Service'),
      _sub(ctx, 'Last updated: April 2025'),
      const SizedBox(height: 16),
      _sec(ctx, '1. Acceptance', 'By using GoJo you agree to these Terms. '
        'They apply to tourists, local businesses, and administrators alike. '
        'If you do not agree, please uninstall the app.'),
      _sec(ctx, '2. Use of the App', 'GoJo is a Jordan tourism discovery platform. '
        'You may browse places, save favourites, generate itineraries, and interact with '
        'local businesses. You agree not to misuse any feature, submit false information, '
        'or interfere with other users.'),
      _sec(ctx, '3. Business Listings', 'Businesses confirm all submitted information is '
        'accurate and current. Misleading, fraudulent, or inappropriate listings will be '
        'dismissed and may result in account suspension. GoJo may remove any listing at any time.'),
      _sec(ctx, '4. Comments & Reviews', 'Comments must be honest, relevant, and respectful. '
        'GoJo may remove content that is hateful, spam, or demonstrably false. '
        'You may not post reviews in exchange for payment or other incentives.'),
      _sec(ctx, '5. Intellectual Property', 'All GoJo content — text, images, logos, and design '
        '— is owned by GoJo or its licensors. You may not reproduce or distribute any part '
        'without written permission.'),
      _sec(ctx, '6. Limitation of Liability', 'GoJo provides information for discovery only. '
        'We are not responsible for the accuracy of business-provided data, prices, or '
        'availability. Confirm all details directly with the provider before booking.'),
      _sec(ctx, '7. Map & Location Services', 'Map tiles are provided by Carto / OpenStreetMap '
        'contributors under the Open Database Licence. Routing is powered by OSRM, a free '
        'open-source service. GPS location is used only within the app.'),
      _sec(ctx, '8. Account Termination', 'GoJo may suspend accounts that violate these Terms, '
        'engage in fraud, or harm other users or businesses.'),
      _sec(ctx, '9. Changes to Terms', 'We may update these Terms at any time. Continued use '
        'constitutes acceptance. Major changes will be notified in-app.'),
      _sec(ctx, '10. Governing Law', 'These Terms are governed by the laws of the '
        'Hashemite Kingdom of Jordan.'),
      _sec(ctx, '11. Contact', 'Questions? Email legal@gojo.jo or use Help & Support in the app.'),
    ]);

  Widget _privacy(BuildContext ctx) => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      _h(ctx, 'Privacy Policy'),
      _sub(ctx, 'Last updated: April 2025'),
      const SizedBox(height: 16),
      _sec(ctx, '1. What We Collect', 'Account data (name, email) when you sign up. '
        'Optional profile data (interests, photo) you provide. '
        'Usage data (searches, views, bookmarks) to improve recommendations. '
        'GPS coordinates when you use Map features — stored only on your device.'),
      _sec(ctx, '2. How We Use It', 'To personalise place and service recommendations; '
        'improve search relevance; power the itinerary generator; and surface relevant tips. '
        'We do not sell personal data to third parties.'),
      _sec(ctx, '3. Local Storage', 'Interests, search history, and saved places are stored '
        'locally on your device and do not leave it unless explicitly synced.'),
      _sec(ctx, '4. Location', 'GPS coordinates are used only to show your position and '
        'calculate routes. They are not stored on GoJo servers. Tile requests go to Carto '
        'and OpenStreetMap — their policies apply to those requests.'),
      _sec(ctx, '5. Photos', 'Profile photos are visible only to you. Business listing photos '
        'become visible to all users after admin approval.'),
      _sec(ctx, '6. Business Data', 'Listing data (name, location, hours, prices, photos) '
        'is stored by GoJo and shown to tourists after approval. Owners may request '
        'editing or deletion at any time.'),
      _sec(ctx, '7. Analytics', 'GoJo analyses anonymised, aggregated usage patterns to '
        'improve the app. Individual behaviour is never sold.'),
      _sec(ctx, '8. Data Retention', 'Account data is kept while your account is active. '
        'Request deletion at any time at support@gojo.jo. '
        'Deleted accounts are purged within 30 days.'),
      _sec(ctx, '9. Children', 'GoJo is not directed at children under 13. '
        'If you believe a child has provided data, contact us immediately.'),
      _sec(ctx, '10. Your Rights', 'You may access, correct, or delete your data at any time. '
        'Contact privacy@gojo.jo to exercise these rights.'),
      _sec(ctx, '11. Changes', 'Significant policy changes will be communicated in-app. '
        'Continued use constitutes acceptance.'),
      _sec(ctx, '12. Contact', 'privacy@gojo.jo\nGoJo Tourism Technology, Amman, Jordan'),
    ]);

  Widget _h(BuildContext ctx, String t) => Text(t,
    style: TextStyle(color: ctx.primary, fontSize: 20, fontWeight: FontWeight.w800));
  Widget _sub(BuildContext ctx, String t) => Text(t,
    style: TextStyle(color: ctx.secondary, fontSize: 12));
  Widget _sec(BuildContext ctx, String title, String body) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: TextStyle(color: ctx.primary,
        fontSize: 14, fontWeight: FontWeight.w700)),
      const SizedBox(height: 5),
      Text(body, style: TextStyle(color: ctx.secondary, fontSize: 13, height: 1.6)),
    ]));
}
