import 'package:flutter/material.dart';

import '../../../../core/ui/uniform_app_bar.dart';

class HomeMenuScreen extends StatelessWidget {
  const HomeMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final menuItems = <_MenuItem>[
      _MenuItem(
        icon: Icons.info_outline_rounded,
        title: 'About Ghmera',
        subtitle: 'Learn what Ghmera is and how the platform works.',
        builder: (_) => const AboutGhmeraScreen(),
      ),
      _MenuItem(
        icon: Icons.gavel_outlined,
        title: 'Terms of Use',
        subtitle: 'Read the platform rules, responsibilities, and limits.',
        builder: (_) => const TermsOfUseScreen(),
      ),
      _MenuItem(
        icon: Icons.privacy_tip_outlined,
        title: 'Privacy Policy',
        subtitle: 'See how personal data is handled and protected.',
        builder: (_) => const PrivacyPolicyScreen(),
      ),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        centerTitle: false,
        leading: uniformBackButton(context),
        title: uniformAppBarTitle(
          context,
          title: 'Menu & Legal',
          subtitle: 'Legal information and app details.',
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFE8F2F0), Color(0xFFD6E6E3)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFC3D7D3)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: const BoxDecoration(
                      color: Color(0xFF103B36),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.shield_outlined,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'Use this menu to review important legal information, terms of service, and privacy standards.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF103B36),
                        height: 1.45,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            for (final item in menuItems)
              _MenuTile(
                item: item,
                onTap: () {
                  Navigator.of(
                    context,
                  ).push<void>(MaterialPageRoute<void>(builder: item.builder));
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _MenuItem {
  const _MenuItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.builder,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final WidgetBuilder builder;
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({required this.item, required this.onTap});

  final _MenuItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE6ECEB)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 10,
        ),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFF103B36).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(item.icon, color: const Color(0xFF103B36), size: 22),
        ),
        title: Text(
          item.title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: const Color(0xFF103B36),
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            item.subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF5A696E),
              height: 1.35,
            ),
          ),
        ),
        trailing: const Icon(
          Icons.chevron_right_rounded,
          color: Color(0xFF103B36),
        ),
      ),
    );
  }
}

class AboutGhmeraScreen extends StatelessWidget {
  const AboutGhmeraScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        centerTitle: false,
        leading: uniformBackButton(context),
        title: uniformAppBarTitle(
          context,
          title: 'About Ghmera',
          subtitle: 'Mission, platform model, and community principles.',
        ),
      ),
      body: const SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 32),
          child: Column(
            children: [
              _LegalMetaCard(
                lastUpdated: 'August 9, 2026',
                summary:
                    'Ghmera is a community-support platform operated by PEATECH SERVICES LLC. It helps people request, offer, and coordinate practical or emotional support.',
              ),
              SizedBox(height: 14),
              _DetailSection(
                title: 'Our purpose',
                text:
                    'Ghmera is designed to make local support easier to find while preserving dignity, choice, and accountability. Members can create help requests, volunteer, review potential matches, and coordinate through in-app chat.',
              ),
              SizedBox(height: 12),
              _DetailSection(
                title: 'How matching works',
                text:
                    'Matching considers the requested category, urgency, approximate location, availability, service radius, trust signals, reciprocity, blocks, and safety requirements. A suggestion is not a guarantee, endorsement, employment relationship, or professional background check.',
              ),
              SizedBox(height: 12),
              _DetailSection(
                title: 'Accounts and verification',
                text:
                    'Members sign up with an email address and password, then confirm a six-digit code delivered by PEATECH SERVICES LLC. Verification confirms control of the email address; it does not guarantee a person’s identity, qualifications, intentions, or conduct.',
              ),
              SizedBox(height: 12),
              _DetailSection(
                title: 'Safety and emergencies',
                text:
                    'Ghmera provides blocking, reporting, consent, moderation, and high-risk warnings, but it is not an emergency service. Do not use the app as a replacement for police, ambulance, fire, medical, crisis, legal, or financial professionals. Contact local emergency services when anyone faces immediate danger.',
              ),
              SizedBox(height: 12),
              _DetailSection(
                title: 'Technology and maps',
                text:
                    'The app uses Firebase-hosted authentication and backend services, PEATECH SERVICES LLC email infrastructure, device location and geocoding services, and OpenStreetMap map tiles. Map markers are intended to be approximate and may be delayed, incomplete, or inaccurate.',
              ),
              SizedBox(height: 12),
              _DetailSection(
                title: 'Contact and feedback',
                text:
                    'Questions about Ghmera, safety, privacy, or these policies can be sent to info@peatechservice.com. Please do not include passwords, verification codes, financial credentials, or unnecessary sensitive information in support messages.',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TermsOfUseScreen extends StatelessWidget {
  const TermsOfUseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        centerTitle: false,
        leading: uniformBackButton(context),
        title: uniformAppBarTitle(
          context,
          title: 'Terms of Use',
          subtitle: 'Rules and responsibilities for using the platform.',
        ),
      ),
      body: const SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 32),
          child: Column(
            children: [
              _LegalMetaCard(
                lastUpdated: 'August 9, 2026',
                summary:
                    'These Terms form an agreement between you and PEATECH SERVICES LLC for access to Ghmera, its community features, and related services.',
              ),
              SizedBox(height: 14),
              _DetailSection(
                title: '1. Acceptance of Terms',
                text:
                    'By creating an account, selecting the acceptance button, or using Ghmera, you confirm that you have read and agree to these Terms and the Privacy Policy. If you do not agree, do not create an account or use the service.',
              ),
              SizedBox(height: 12),
              _DetailSection(
                title: '2. Eligibility and Account Responsibility',
                text:
                    'You must be at least 18 years old, or the age of legal majority where you live, and legally able to enter this agreement. Provide accurate information, use only your own email address, keep your password and verification codes confidential, and promptly report suspected account misuse.',
              ),
              SizedBox(height: 12),
              _DetailSection(
                title: '3. What Ghmera Provides',
                text:
                    'Ghmera provides technology for publishing help requests, suggesting or accepting matches, displaying approximate map locations, communicating in-app, recording completion and reviews, and using safety tools. Ghmera does not employ users, supervise meetings, guarantee a match or outcome, or verify every statement made by a member.',
              ),
              SizedBox(height: 12),
              _DetailSection(
                title: '4. No Emergency or Professional Service',
                text:
                    'Ghmera is not an emergency-response, healthcare, crisis, legal, financial, transport, safeguarding, or background-check service. Do not rely on it where delay could cause injury, loss, or danger. Contact qualified professionals or local emergency services when appropriate.',
              ),
              SizedBox(height: 12),
              _DetailSection(
                title: '5. Community Conduct',
                text:
                    'Use Ghmera lawfully, honestly, and respectfully. You must not harass, threaten, discriminate, exploit, stalk, impersonate, defraud, solicit illegal goods or services, request unsafe transfers of money, distribute malware, disclose another person’s private information, manipulate reviews, evade blocks, or create content that risks harm.',
              ),
              SizedBox(height: 12),
              _DetailSection(
                title: '6. Requests, Matches, and In-Person Contact',
                text:
                    'You decide whether to create, accept, continue, or cancel a request. Review available profile and safety information, keep early communication in the app, meet in suitable public places where possible, avoid sharing unnecessary contact or financial information, and leave any interaction that feels unsafe. You are responsible for your own decisions and conduct.',
              ),
              SizedBox(height: 12),
              _DetailSection(
                title: '7. Location and Map Information',
                text:
                    'Location, distance, geocoding, and map results are estimates and may be inaccurate or unavailable. Do not use map markers as proof of a person’s identity, current position, safety, or ability to help. OpenStreetMap and device-platform services may have separate terms that apply to their services.',
              ),
              SizedBox(height: 12),
              _DetailSection(
                title: '8. User Content and Permission to Operate the Service',
                text:
                    'You retain ownership of content you submit. You give PEATECH SERVICES LLC a worldwide, non-exclusive, royalty-free license to host, store, reproduce, display, transmit, moderate, and otherwise process that content only as reasonably needed to operate, secure, improve, and enforce Ghmera. You must have the right to submit the content.',
              ),
              SizedBox(height: 12),
              _DetailSection(
                title: '9. Contact Sharing and Communications',
                text:
                    'In-app chat is not a guarantee of confidentiality or end-to-end encryption. Contact details should be shared only when both participants consent. You must not use another member’s email address, phone number, messages, or location outside the agreed support purpose.',
              ),
              SizedBox(height: 12),
              _DetailSection(
                title: '10. Moderation and Account Enforcement',
                text:
                    'PEATECH SERVICES LLC may review reports and safety signals, preserve relevant records, remove content, limit features, cancel matches, warn, suspend, or terminate accounts, and cooperate with lawful authorities. Blocking stops supported interactions but cannot prevent contact that occurs outside Ghmera.',
              ),
              SizedBox(height: 12),
              _DetailSection(
                title: '11. Availability and Third-Party Services',
                text:
                    'Ghmera may change, interrupt, or discontinue features and does not guarantee uninterrupted service, data delivery, map coverage, email delivery, or compatibility with every device or region. Firebase, email, mapping, geocoding, network, and operating-system providers may affect availability.',
              ),
              SizedBox(height: 12),
              _DetailSection(
                title: '12. Disclaimers and Liability',
                text:
                    'Ghmera is provided on an as-is and as-available basis. To the fullest extent permitted by law, PEATECH SERVICES LLC disclaims implied warranties and is not responsible for user conduct, failed matches, inaccurate content, or indirect, incidental, special, exemplary, or consequential loss. Nothing in these Terms excludes rights or liability that cannot legally be excluded.',
              ),
              SizedBox(height: 12),
              _DetailSection(
                title: '13. Suspension, Termination, and Survival',
                text:
                    'You may stop using Ghmera at any time. We may restrict or end access where reasonably necessary for safety, security, legal compliance, prolonged inactivity, or a breach of these Terms. Provisions concerning content rights, enforcement, disclaimers, liability, and disputes survive termination where applicable.',
              ),
              SizedBox(height: 12),
              _DetailSection(
                title: '14. Updates and Contact',
                text:
                    'We may revise these Terms for product, security, operational, or legal reasons. Material changes will be identified by a new last-updated date and, where required, additional notice or consent. Questions may be sent to info@peatechservice.com.',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        centerTitle: false,
        leading: uniformBackButton(context),
        title: uniformAppBarTitle(
          context,
          title: 'Privacy Policy',
          subtitle: 'How data is collected, used, and safeguarded.',
        ),
      ),
      body: const SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 32),
          child: Column(
            children: [
              _LegalMetaCard(
                lastUpdated: 'August 9, 2026',
                summary:
                    'This policy explains how PEATECH SERVICES LLC collects, uses, shares, stores, and protects information when you use Ghmera.',
              ),
              SizedBox(height: 14),
              _DetailSection(
                title: '1. Scope and Data Controller',
                text:
                    'This policy applies to Ghmera applications, backend functions, support communications, and related services. PEATECH SERVICES LLC determines why and how the information described here is processed. Privacy questions and rights requests may be sent to info@peatechservice.com.',
              ),
              SizedBox(height: 12),
              _DetailSection(
                title: '2. Account and Profile Information',
                text:
                    'We process your email address, account identifier, verification status, display name, profile photo URL, phone number if provided, biography, city, area, availability, support categories, service radius, privacy choices, device/session records, blocks, mutes, trust indicators, and account restrictions. Passwords are handled through the authentication service and are not stored as readable text in the Ghmera app database.',
              ),
              SizedBox(height: 12),
              _DetailSection(
                title: '3. Requests, Messages, and Safety Information',
                text:
                    'We process help requests, descriptions, categories, urgency, preferred times, attachments or labels, match activity, in-app messages, consent states, completion records, reviews, mood check-ins, reports, moderation status, and action logs. Other members may see information needed to evaluate a request or match according to the app’s visibility and privacy controls.',
              ),
              SizedBox(height: 12),
              _DetailSection(
                title: '4. Email Verification and Password Reset',
                text:
                    'Registration and password-reset codes are sent through PEATECH SERVICES LLC email infrastructure. Code records are protected using hashes, expire after a limited period, and are used to confirm control of an email address or authorize a password reset. Never send a verification code or password to another person.',
              ),
              SizedBox(height: 12),
              _DetailSection(
                title: '5. Location, Geocoding, and Maps',
                text:
                    'If you grant location permission or enable automatic location, Ghmera may process and store precise latitude and longitude to update your profile, estimate distance, and support matching. City, area, request locations, and approximate marker positions may be shown to other users. Device geocoding services convert place names and coordinates, while OpenStreetMap tile servers receive technical request data such as IP address and user-agent information when map tiles load.',
              ),
              SizedBox(height: 12),
              _DetailSection(
                title: '6. How We Use Information',
                text:
                    'We use information to create and secure accounts, deliver email codes, operate requests and matches, calculate recommendations and reciprocity, display maps, enable chat, support wellbeing features, enforce consent and blocks, investigate reports, prevent abuse, provide support, maintain service reliability, and comply with legal obligations.',
              ),
              SizedBox(height: 12),
              _DetailSection(
                title: '7. Legal Bases',
                text:
                    'Where data-protection law requires a legal basis, processing may be necessary to perform our agreement with you, based on your consent for optional location or profile choices, required by law, needed to protect vital interests, or based on legitimate interests such as platform security, fraud prevention, moderation, service improvement, and protecting users.',
              ),
              SizedBox(height: 12),
              _DetailSection(
                title: '8. When Information Is Shared',
                text:
                    'We do not sell personal data. Information may be shared with matched or eligible users as the service requires; with Google Firebase for authentication, Cloud Functions, and Firestore hosting; with our email infrastructure for code delivery; with mapping, geocoding, device, and network providers; with advisers or vendors supporting operations; and with authorities or affected persons when reasonably necessary for law, rights, fraud prevention, or safety.',
              ),
              SizedBox(height: 12),
              _DetailSection(
                title: '9. Retention and Deletion',
                text:
                    'We retain information while needed to provide Ghmera and for reasonable periods afterward for account recovery, security, safety reviews, disputes, backups, and legal obligations. Verification codes expire after 15 minutes and are normally deleted after successful use or replacement. Safety records may be kept longer where necessary. You may request deletion, but some records may be retained where law or legitimate safety needs require it.',
              ),
              SizedBox(height: 12),
              _DetailSection(
                title: '10. Security',
                text:
                    'We use access controls, authenticated backend operations, expiring verification codes, hashed code records, encrypted network connections, provider security measures, and moderation controls. No internet service can guarantee absolute security. Protect your device and credentials and contact us promptly if you suspect unauthorized access.',
              ),
              SizedBox(height: 12),
              _DetailSection(
                title: '11. Your Choices and Rights',
                text:
                    'You can edit profile information, change privacy and contact-sharing settings, disable automatic location, deny device location permission, block users, and stop using the service. Depending on applicable law, you may request access, correction, deletion, portability, restriction, or objection, and may withdraw consent without affecting earlier lawful processing. Send requests to info@peatechservice.com; identity verification may be required.',
              ),
              SizedBox(height: 12),
              _DetailSection(
                title: '12. International Processing',
                text:
                    'Ghmera and its service providers may process information in countries other than your own. Where required, we use contractual, technical, or legal safeguards intended to protect information during international processing or transfer.',
              ),
              SizedBox(height: 12),
              _DetailSection(
                title: '13. Children',
                text:
                    'Ghmera is intended for adults and is not directed to anyone under 18 or the age of legal majority where they live. If you believe a child has provided personal information, contact info@peatechservice.com so the situation can be reviewed and appropriate action taken.',
              ),
              SizedBox(height: 12),
              _DetailSection(
                title: '14. Policy Changes and Complaints',
                text:
                    'We may update this policy for product, security, operational, or legal reasons. Material changes will be identified by a revised date and additional notice where required. You may contact us first with a concern and may also complain to the data-protection authority available under applicable law.',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({required this.title, required this.text});

  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE6ECEB)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: const Color(0xFF103B36),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF55656C),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _LegalMetaCard extends StatelessWidget {
  const _LegalMetaCard({required this.lastUpdated, required this.summary});

  final String lastUpdated;
  final String summary;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE8F2F0), Color(0xFFD6E6E3)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFC3D7D3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.calendar_today_rounded,
                size: 16,
                color: Color(0xFF103B36),
              ),
              const SizedBox(width: 8),
              Text(
                'Last updated: $lastUpdated',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF103B36),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            summary,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF2C4B45),
              height: 1.45,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
