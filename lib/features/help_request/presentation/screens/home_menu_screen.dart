import 'package:flutter/material.dart';

import '../../../../core/ui/uniform_app_bar.dart';

class HomeMenuScreen extends StatelessWidget {
  const HomeMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final menuItems = <_MenuItem>[
      _MenuItem(
        icon: Icons.info_outline_rounded,
        title: 'About',
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
      appBar: AppBar(
        automaticallyImplyLeading: false,
        centerTitle: false,
        leading: uniformBackButton(context),
        title: uniformAppBarTitle(
          context,
          title: 'Menu',
          subtitle: 'Legal information and app details.',
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(10, 12, 10, 28),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF3F7),
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(
                'Use this menu to review important legal and platform information.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF3D4B53),
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 12),
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
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(5),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: const Color(0xFFE2EBE8),
          foregroundColor: const Color(0xFF0F6B5C),
          child: Icon(item.icon),
        ),
        title: Text(
          item.title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          item.subtitle,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: const Color(0xFF5A696E)),
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    );
  }
}

class AboutGhmeraScreen extends StatelessWidget {
  const AboutGhmeraScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
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
          padding: EdgeInsets.fromLTRB(10, 12, 10, 28),
          child: Column(
            children: [
              _DetailSection(
                title: 'Our mission',
                text:
                    'Ghmera connects people who need help with trusted people who can offer support in practical and emotional ways. The goal is to create reliable, dignity-first community assistance.',
              ),
              SizedBox(height: 10),
              _DetailSection(
                title: 'How matching works',
                text:
                    'Requests are matched using categories, urgency, location relevance, reciprocity balance, and trust signals. Contact sharing is limited until a match is accepted and consent is confirmed.',
              ),
              SizedBox(height: 10),
              _DetailSection(
                title: 'Community values',
                text:
                    'Ghmera is built around empathy, accountability, privacy, and safety. Every user is expected to communicate respectfully, avoid harmful behavior, and follow platform safeguards.',
              ),
              SizedBox(height: 10),
              _DetailSection(
                title: 'Support and updates',
                text:
                    'The app evolves through regular updates that improve trust logic, safety controls, and user experience. Review release notes and policy updates whenever a new version is installed.',
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
      appBar: AppBar(
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
          padding: EdgeInsets.fromLTRB(10, 12, 10, 28),
          child: Column(
            children: [
              _LegalMetaCard(
                lastUpdated: 'April 23, 2026',
                summary:
                    'These Terms govern access to and use of Ghmera services, features, and community interactions.',
              ),
              SizedBox(height: 10),
              _DetailSection(
                title: '1. Acceptance of Terms',
                text:
                    'By creating an account, accessing, or using Ghmera, you acknowledge that you have read, understood, and agree to be bound by these Terms and all related policies. If you do not agree, you must stop using the service immediately.',
              ),
              SizedBox(height: 10),
              _DetailSection(
                title: '2. Eligibility and Account Responsibility',
                text:
                    'You must provide accurate account information and keep your credentials secure. You are responsible for all activity under your account, including activity from authorized sessions on your devices.',
              ),
              SizedBox(height: 10),
              _DetailSection(
                title: '3. Service Scope and Availability',
                text:
                    'Ghmera provides tools for coordinating community support, communication, and safety workflows. We may modify, suspend, or discontinue features at any time. We do not guarantee uninterrupted availability in every region, network, or device environment.',
              ),
              SizedBox(height: 10),
              _DetailSection(
                title: '4. Acceptable Use and Prohibited Conduct',
                text:
                    'You may use Ghmera only for lawful and respectful support activity. Prohibited conduct includes harassment, threats, fraud, impersonation, hate speech, exploitative requests, dissemination of malicious content, and any behavior that creates safety risk for others.',
              ),
              SizedBox(height: 10),
              _DetailSection(
                title: '5. User Content and License',
                text:
                    'You retain ownership of content you submit, but grant Ghmera a limited license to host, process, and display that content to operate the service. You represent that your content does not infringe third-party rights and complies with applicable law.',
              ),
              SizedBox(height: 10),
              _DetailSection(
                title: '6. Safety, Moderation, and Enforcement',
                text:
                    'Ghmera may investigate reports, review safety signals, and apply enforcement actions including warnings, feature restrictions, temporary suspension, or permanent account termination. Severe or unlawful conduct may be referred to competent authorities.',
              ),
              SizedBox(height: 10),
              _DetailSection(
                title: '7. Disclaimers and Limitation of Liability',
                text:
                    'Ghmera is provided on an as-is and as-available basis. We do not warrant guaranteed outcomes for matches, response times, or user behavior. To the maximum extent permitted by law, Ghmera is not liable for indirect, incidental, special, or consequential damages arising from platform use.',
              ),
              SizedBox(height: 10),
              _DetailSection(
                title: '8. Indemnification',
                text:
                    'You agree to indemnify and hold harmless Ghmera and its affiliates from claims, liabilities, damages, and expenses resulting from your breach of these Terms, unlawful conduct, or misuse of the service.',
              ),
              SizedBox(height: 10),
              _DetailSection(
                title: '9. Changes to Terms and Contact',
                text:
                    'We may update these Terms to reflect legal, security, and product changes. Material updates will be published with a revised last-updated date. Continued use after updates constitutes acceptance of the revised Terms.',
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
      appBar: AppBar(
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
          padding: EdgeInsets.fromLTRB(10, 12, 10, 28),
          child: Column(
            children: [
              _LegalMetaCard(
                lastUpdated: 'April 23, 2026',
                summary:
                    'This Privacy Policy explains what data Ghmera collects, why it is processed, and the choices available to users.',
              ),
              SizedBox(height: 10),
              _DetailSection(
                title: '1. Scope and Data Controller',
                text:
                    'This policy applies to personal data processed through Ghmera applications and related services. Ghmera acts as the data controller for account, safety, and service-operation data described in this policy.',
              ),
              SizedBox(height: 10),
              _DetailSection(
                title: '2. Information We Collect',
                text:
                    'We may collect profile information, account identifiers, help request content, communication metadata, trust and moderation signals, device/session identifiers, and approximate location context needed for matching and safety workflows.',
              ),
              SizedBox(height: 10),
              _DetailSection(
                title: '3. Legal Bases for Processing',
                text:
                    'Depending on your jurisdiction, processing may rely on consent, contractual necessity, legitimate interests, legal obligations, and protection of vital interests such as user safety and fraud prevention.',
              ),
              SizedBox(height: 10),
              _DetailSection(
                title: '4. How We Use Personal Data',
                text:
                    'Data is used to authenticate accounts, match helpers and requesters, deliver communications, provide customer support, enforce policies, prevent abuse, and improve reliability, safety, and performance of Ghmera features.',
              ),
              SizedBox(height: 10),
              _DetailSection(
                title: '5. Sharing and Disclosure',
                text:
                    'We do not sell personal data. Data may be shared with service providers under contractual safeguards, with other users according to product controls, or with authorities where legally required for compliance or safety investigations.',
              ),
              SizedBox(height: 10),
              _DetailSection(
                title: '6. Data Retention',
                text:
                    'We retain data only as long as needed for service delivery, safety review, dispute handling, and legal compliance. Retention periods vary by data type, risk profile, and applicable legal requirements.',
              ),
              SizedBox(height: 10),
              _DetailSection(
                title: '7. Security Measures',
                text:
                    'Ghmera applies administrative, technical, and organizational controls designed to protect personal data against unauthorized access, loss, or misuse. No system is absolutely secure, but safeguards are continuously reviewed and improved.',
              ),
              SizedBox(height: 10),
              _DetailSection(
                title: '8. Your Rights and Choices',
                text:
                    'Subject to local law, you may request access, correction, deletion, portability, or restriction of processing, and may object to certain processing activities. You may also manage in-app privacy preferences and communication settings.',
              ),
              SizedBox(height: 10),
              _DetailSection(
                title: '9. Children and Sensitive Cases',
                text:
                    'Ghmera is not intended for unlawful use or any activity that endangers minors. Where required, additional safeguards apply to vulnerable users and high-risk moderation events.',
              ),
              SizedBox(height: 10),
              _DetailSection(
                title: '10. International Transfers and Policy Updates',
                text:
                    'Where data is processed across jurisdictions, Ghmera applies safeguards required by applicable law. We may update this policy periodically; material updates will be posted with an updated revision date.',
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
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(5),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF55656C),
              height: 1.45,
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
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF3F7),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Last updated: $lastUpdated',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: const Color(0xFF20323A),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            summary,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF45565E),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
