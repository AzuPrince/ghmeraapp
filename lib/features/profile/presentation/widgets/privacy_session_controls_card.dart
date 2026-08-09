import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../app/providers/ghmera_app_state.dart';

class PrivacySessionControlsCard extends StatelessWidget {
  const PrivacySessionControlsCard({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<GhmeraAppState>();
    final user = appState.currentUser;
    final theme = Theme.of(context);
    String? currentSessionId;
    for (final session in user.sessions) {
      if (session.isCurrent) {
        currentSessionId = session.id;
        break;
      }
    }
    if (currentSessionId == null && user.sessions.isNotEmpty) {
      currentSessionId = user.sessions.first.id;
    }

    return _SectionCard(
      title: 'Privacy and session controls',
      subtitle:
          'Location and contact details stay protected until a match is accepted and both parties consent.',
      child: Column(
        children: [
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            activeTrackColor: const Color(0xFF103B36),
            title: const Text(
              'Show approximate location first',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: const Text('Use area-level location before acceptance.'),
            value: user.privacySettings.showApproximateLocation,
            onChanged: (value) {
              appState.updateCurrentUserPrivacySettings(
                user.privacySettings.copyWith(showApproximateLocation: value),
              );
            },
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            activeTrackColor: const Color(0xFF103B36),
            title: const Text(
              'Share phone only after acceptance',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            value: user.privacySettings.sharePhoneAfterAcceptance,
            onChanged: (value) {
              appState.updateCurrentUserPrivacySettings(
                user.privacySettings.copyWith(sharePhoneAfterAcceptance: value),
              );
            },
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            activeTrackColor: const Color(0xFF103B36),
            title: const Text(
              'Share email only after acceptance',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            value: user.privacySettings.shareEmailAfterAcceptance,
            onChanged: (value) {
              appState.updateCurrentUserPrivacySettings(
                user.privacySettings.copyWith(shareEmailAfterAcceptance: value),
              );
            },
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            activeTrackColor: const Color(0xFF103B36),
            title: const Text(
              'Allow support circle invites',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            value: user.privacySettings.allowSupportCircleInvites,
            onChanged: (value) {
              appState.updateCurrentUserPrivacySettings(
                user.privacySettings.copyWith(allowSupportCircleInvites: value),
              );
            },
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            activeTrackColor: const Color(0xFF103B36),
            title: const Text(
              'Allow message requests',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            value: user.privacySettings.allowMessageRequests,
            onChanged: (value) {
              appState.updateCurrentUserPrivacySettings(
                user.privacySettings.copyWith(allowMessageRequests: value),
              );
            },
          ),
          const SizedBox(height: 12),
          if (user.sessions.isNotEmpty) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Select current device session',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF103B36),
                ),
              ),
            ),
            const SizedBox(height: 8),
            for (final session in user.sessions)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(top: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF6F8F8),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE4ECEB)),
                ),
                child: Column(
                  children: [
                    // ignore: deprecated_member_use
                    RadioListTile<String>(
                      value: session.id,
                      // ignore: deprecated_member_use
                      groupValue: currentSessionId,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                      activeColor: const Color(0xFF103B36),
                      // ignore: deprecated_member_use
                      onChanged: (selectedSessionId) {
                        if (selectedSessionId == null) {
                          return;
                        }
                        appState.setCurrentSessionDevice(selectedSessionId);
                      },
                      title: Text(
                        session.label,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: Text(
                        session.isCurrent
                            ? 'Current device'
                            : 'Last active ${_relativeTime(session.lastActive)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF667572),
                        ),
                      ),
                      secondary: const Icon(
                        Icons.devices_rounded,
                        color: Color(0xFF103B36),
                      ),
                    ),
                    if (!session.isCurrent && user.sessions.length > 1)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: () {
                              appState.removeSessionDevice(session.id);
                            },
                            icon: const Icon(Icons.logout_rounded, size: 16),
                            label: const Text('Sign out this device'),
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFFD32F2F),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: const Color(0xFF103B36),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF61726F),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

String _relativeTime(DateTime timestamp) {
  final difference = DateTime.now().difference(timestamp);

  if (difference.inMinutes < 1) {
    return 'just now';
  }
  if (difference.inHours < 1) {
    return '${difference.inMinutes}m ago';
  }
  if (difference.inDays < 1) {
    return '${difference.inHours}h ago';
  }
  if (difference.inDays < 7) {
    return '${difference.inDays}d ago';
  }

  return '${difference.inDays ~/ 7}w ago';
}
