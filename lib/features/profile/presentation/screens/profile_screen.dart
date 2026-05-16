import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../app/models/ghmera_models.dart';
import '../../../../app/providers/ghmera_app_state.dart';
import '../../../../core/ui/app_snack_bar.dart';
import 'blocked_accounts_screen.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../auth/presentation/screens/login_screen.dart';
import '../widgets/privacy_session_controls_card.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _openEditProfileScreen(
    BuildContext context,
    UserEntity user,
  ) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => _EditProfileScreen(user: user)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<GhmeraAppState>();
    final user = appState.currentUser;
    final theme = Theme.of(context);
    final trustFlags = appState.currentUserTrustFlags;
    final reportsAboutUser = appState.reportsAboutCurrentUser;
    final activeReports = reportsAboutUser
        .where(
          (report) =>
              report.status == ReportStatus.open ||
              report.status == ReportStatus.investigating,
        )
        .toList();
    final normalizedBio = user.shortBio.trim().toLowerCase();
    final showBio =
        user.shortBio.trim().isNotEmpty &&
        normalizedBio != 'new community member.' &&
        normalizedBio != 'new community member' &&
        normalizedBio != 'new community memner.' &&
        normalizedBio != 'new community memner';
    final locationLabel = [
      user.area.trim(),
      user.city.trim(),
    ].where((value) => value.isNotEmpty).join(', ');
    final isCurrentlyAvailable = appState.isUserAvailableForMatching(user);
    final availabilitySubtitle = _helperAvailabilitySubtitle(
      user: user,
      isCurrentlyAvailable: isCurrentlyAvailable,
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 28),
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: <Color>[Color(0xFFF1F3F6), Color(0xFFE3E7EC)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(5),
            border: Border.all(color: const Color(0xFFD5DBE3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ProfileAvatar(user: user, radius: 34),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.fullName,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            color: const Color(0xFF1A2A31),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (showBio) ...[
                          const SizedBox(height: 6),
                          Text(
                            user.shortBio,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: const Color(0xFF53626A),
                              height: 1.45,
                            ),
                          ),
                        ],
                        const SizedBox(height: 10),
                        Text(
                          locationLabel,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: const Color(0xFF61726F),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                alignment: WrapAlignment.center,
                runAlignment: WrapAlignment.center,
                children: [
                  _ProfilePill(
                    icon: Icons.workspace_premium_rounded,
                    label: 'Trust ${user.trustScore.toStringAsFixed(0)}',
                  ),
                  _ProfilePill(
                    icon: Icons.sync_alt_rounded,
                    label: 'Balance ${user.helpBalance}',
                  ),
                  _ProfilePill(
                    icon: Icons.notifications_active_outlined,
                    label: '${appState.unreadNotificationsCount} unread alerts',
                  ),
                ],
              ),
              const SizedBox(height: 18),
              SwitchListTile.adaptive(
                value: user.availability,
                onChanged: (_) => appState.toggleAvailability(),
                contentPadding: EdgeInsets.zero,
                activeThumbColor: Theme.of(context).colorScheme.primary,
                activeTrackColor: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.35),
                inactiveTrackColor: const Color(0xFFD0D7DF),
                title: const Text(
                  'Helper availability',
                  style: TextStyle(color: Color(0xFF1D3037)),
                ),
                subtitle: Text(
                  availabilitySubtitle,
                  style: TextStyle(
                    color: const Color(0xFF53626A),
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => _openEditProfileScreen(context, user),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(5),
              ),
            ),
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Edit profile'),
          ),
        ),
        const SizedBox(height: 16),
        _SectionCard(
          title: 'Impact and reciprocity',
          subtitle:
              'The platform stays fair by encouraging every user to both receive and give help over time.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _MetricTile(
                      label: 'Help given',
                      value: '${user.helpGivenCount}',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _MetricTile(
                      label: 'Help received',
                      value: '${user.helpReceivedCount}',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _MetricTile(
                      label: 'Average review',
                      value: user.averageRating.toStringAsFixed(1),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _MetricTile(
                      label: 'Completed help',
                      value: '${user.completedHelpCount}',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                appState.reciprocityMessage,
                style: theme.textTheme.bodyMedium?.copyWith(
                  height: 1.45,
                  color: const Color(0xFF4F5F5C),
                ),
              ),
              if (appState.hasReciprocityActivity) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: appState.reciprocityProgress,
                    minHeight: 3,
                    backgroundColor: const Color(0xFFE7EFEC),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Reciprocity value ${appState.reciprocityPercent}% of the current fairness window.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF667572),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        const PrivacySessionControlsCard(),
        const SizedBox(height: 16),
        _SectionCard(
          title: 'Reviews and safety signals',
          subtitle:
              'Community feedback reinforces helpfulness, respect, safety, reliability, and accuracy.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _MetricTile(
                      label: 'Active reports',
                      value: '${appState.activeSafetyReportsAboutCurrentUser}',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _MetricTile(
                      label: 'Flagged reviews',
                      value: '${appState.suspiciousReviewsAboutCurrentUser}',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (trustFlags.isNotEmpty) ...[
                Text(
                  'Live trust signals',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: trustFlags
                      .map((flag) => Chip(label: Text(flag)))
                      .toList(),
                ),
                const SizedBox(height: 14),
              ],
              if (activeReports.isNotEmpty)
                for (final report in activeReports.take(3))
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F3EB),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          report.reason,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          report.details.trim().isEmpty
                              ? report.status.label
                              : '${report.status.label}: ${report.details}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: const Color(0xFF586965),
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
              for (final review in appState.reviewsAboutCurrentUser)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F3EB),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              appState.userById(review.reviewerId).fullName,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          Text(
                            review.rating.toStringAsFixed(1),
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        review.feedback,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          height: 1.45,
                          color: const Color(0xFF586965),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          Chip(label: Text('Helpful ${review.helpfulness}/5')),
                          Chip(
                            label: Text('Respect ${review.respectfulness}/5'),
                          ),
                          Chip(label: Text('Safety ${review.safety}/5')),
                        ],
                      ),
                    ],
                  ),
                ),
              if (appState.reviewsAboutCurrentUser.isEmpty &&
                  activeReports.isEmpty &&
                  trustFlags.isEmpty)
                Text(
                  'No reviews or safety signals have been recorded for this account yet.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF586965),
                    height: 1.45,
                  ),
                ),
              if (appState.reviewsAboutCurrentUser.isNotEmpty ||
                  activeReports.isNotEmpty ||
                  trustFlags.isNotEmpty)
                const SizedBox(height: 4),
              _InfoRow(
                icon: Icons.block_rounded,
                title: '${user.blockedUserIds.length} blocked account(s)',
                subtitle: '${user.mutedUserIds.length} muted account(s)',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => const BlockedAccountsScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () async {
              await context.read<AuthProvider>().signOut();
              if (!context.mounted) {
                return;
              }

              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            },
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Sign out'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(5),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _EditProfileScreen extends StatefulWidget {
  const _EditProfileScreen({required this.user});

  final UserEntity user;

  @override
  State<_EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<_EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _bioController;
  late final TextEditingController _cityController;
  late final TextEditingController _areaController;
  late final TextEditingController _phoneController;
  late final TextEditingController _photoController;
  late final TextEditingController _availabilityTimeController;
  bool? _usesDeviceLocationOverride;
  bool _applyingDeviceLocation = false;
  int _availabilityStartMinuteOfDay = -1;
  int _availabilityEndMinuteOfDay = -1;

  bool get _hasAvailabilityWindow {
    return _availabilityStartMinuteOfDay >= 0 &&
        _availabilityEndMinuteOfDay >= 0;
  }

  bool get _usesDeviceLocation {
    return _usesDeviceLocationOverride ?? widget.user.usesDeviceLocation;
  }

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user.fullName);
    _bioController = TextEditingController(text: widget.user.shortBio);
    _cityController = TextEditingController(text: widget.user.city);
    _areaController = TextEditingController(text: widget.user.area);
    _phoneController = TextEditingController(text: widget.user.phone ?? '');
    _photoController = TextEditingController(
      text: widget.user.profilePhoto ?? '',
    );
    _availabilityStartMinuteOfDay = widget.user.availabilityStartMinuteOfDay;
    _availabilityEndMinuteOfDay = widget.user.availabilityEndMinuteOfDay;
    _availabilityTimeController = TextEditingController(
      text: _hasAvailabilityWindow
          ? _formatAvailabilityWindowLabel(
              _availabilityStartMinuteOfDay,
              _availabilityEndMinuteOfDay,
            )
          : '',
    );
    _cityController.addListener(_handleManualLocationEdit);
    _areaController.addListener(_handleManualLocationEdit);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _cityController.dispose();
    _areaController.dispose();
    _phoneController.dispose();
    _photoController.dispose();
    _availabilityTimeController.dispose();
    super.dispose();
  }

  void _saveProfile() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    context.read<GhmeraAppState>().updateCurrentUserProfile(
      fullName: _nameController.text,
      shortBio: _bioController.text,
      city: _cityController.text,
      area: _areaController.text,
      phone: _phoneController.text,
      profilePhoto: _photoController.text,
      usesDeviceLocation: _usesDeviceLocationOverride,
      availabilityStartMinuteOfDay: _availabilityStartMinuteOfDay,
      availabilityEndMinuteOfDay: _availabilityEndMinuteOfDay,
    );

    Navigator.of(context).pop();
  }

  void _handleManualLocationEdit() {
    if (_applyingDeviceLocation) {
      return;
    }

    _usesDeviceLocationOverride = false;
  }

  Future<void> _setUsesDeviceLocation(bool value) async {
    setState(() {
      _usesDeviceLocationOverride = value;
    });

    if (value) {
      await _useDeviceLocation();
    }
  }

  Future<void> _useDeviceLocation() async {
    setState(() {
      _applyingDeviceLocation = true;
    });

    final resolvedLocation = await context
        .read<GhmeraAppState>()
        .refreshCurrentUserLocationFromDevice();

    if (!mounted) {
      return;
    }

    if (resolvedLocation == null) {
      setState(() {
        _applyingDeviceLocation = false;
      });
      showGhmeraSnackBar(
        context,
        message: 'Unable to read device location right now.',
        type: SnackBarType.error,
      );
      return;
    }

    _cityController.text = resolvedLocation.city;
    _areaController.text = resolvedLocation.area;
    setState(() {
      _usesDeviceLocationOverride = true;
      _applyingDeviceLocation = false;
    });
    showGhmeraSnackBar(
      context,
      message: 'Device location loaded.',
      type: SnackBarType.success,
    );
  }

  Future<void> _selectAvailabilityWindow() async {
    final initialStart = _hasAvailabilityWindow
        ? _timeOfDayFromMinuteOfDay(_availabilityStartMinuteOfDay)
        : TimeOfDay.now();
    final selectedStart = await showTimePicker(
      context: context,
      initialTime: initialStart,
      helpText: 'Select available time start',
    );
    if (selectedStart == null || !mounted) {
      return;
    }

    final initialEnd = _hasAvailabilityWindow
        ? _timeOfDayFromMinuteOfDay(_availabilityEndMinuteOfDay)
        : TimeOfDay(
            hour: (selectedStart.hour + 1) % 24,
            minute: selectedStart.minute,
          );
    final selectedEnd = await showTimePicker(
      context: context,
      initialTime: initialEnd,
      helpText: 'Select available time end',
    );
    if (selectedEnd == null) {
      return;
    }

    setState(() {
      _availabilityStartMinuteOfDay = _minuteOfDayForTime(selectedStart);
      _availabilityEndMinuteOfDay = _minuteOfDayForTime(selectedEnd);
      _availabilityTimeController.text = _formatAvailabilityWindowLabel(
        _availabilityStartMinuteOfDay,
        _availabilityEndMinuteOfDay,
      );
    });
  }

  void _clearAvailabilityWindow() {
    setState(() {
      _availabilityStartMinuteOfDay = -1;
      _availabilityEndMinuteOfDay = -1;
      _availabilityTimeController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Edit profile')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Full name'),
                validator: (value) {
                  if ((value ?? '').trim().isEmpty) {
                    return 'Enter your full name.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _bioController,
                decoration: const InputDecoration(labelText: 'Short bio'),
                maxLines: 2,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _availabilityTimeController,
                readOnly: true,
                onTap: _selectAvailabilityWindow,
                decoration: InputDecoration(
                  labelText: 'Available time',
                  hintText: 'Tap to set helper matching time range',
                  suffixIcon: _hasAvailabilityWindow
                      ? IconButton(
                          tooltip: 'Clear available time',
                          onPressed: _clearAvailabilityWindow,
                          icon: const Icon(Icons.clear_rounded),
                        )
                      : const Icon(Icons.schedule_rounded),
                ),
              ),
              if (_hasAvailabilityWindow) ...[
                const SizedBox(height: 6),
                Text(
                  'Helper availability will automatically follow this time every day.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF586965),
                  ),
                ),
              ],
              const SizedBox(height: 10),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: _usesDeviceLocation,
                onChanged: _setUsesDeviceLocation,
                title: const Text('Always use my location'),
                subtitle: Text(
                  _usesDeviceLocation
                      ? 'Your road, town, state, and country will keep following your device location.'
                      : 'Turn this off to enter a custom road, town, state, and country manually.',
                ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _areaController,
                enabled: !_usesDeviceLocation,
                decoration: const InputDecoration(labelText: 'Road'),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _cityController,
                enabled: !_usesDeviceLocation,
                decoration: const InputDecoration(
                  labelText: 'Town, state, country',
                ),
              ),
              if (_usesDeviceLocation) ...[
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: _useDeviceLocation,
                    icon: const Icon(Icons.my_location_rounded),
                    label: const Text('Refresh device location'),
                  ),
                ),
              ],
              const SizedBox(height: 10),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(labelText: 'Phone'),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _photoController,
                decoration: const InputDecoration(
                  labelText: 'Profile photo URL or asset path',
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _saveProfile,
                  icon: const Icon(Icons.save_rounded),
                  label: const Text('Save profile'),
                ),
              ),
            ],
          ),
        ),
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
        borderRadius: BorderRadius.circular(5),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 24,
            offset: Offset(0, 12),
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

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F1E8),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: const Color(0xFF697774),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfilePill extends StatelessWidget {
  const _ProfilePill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFDCE2E9),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: const Color(0xFF1D3037)),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF1D3037),
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({required this.user, this.radius = 34});

  final UserEntity user;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final photoPath = user.profilePhoto?.trim();
    final size = radius * 2;
    final initials = _initialsForName(user.fullName);
    if (photoPath == null || photoPath.isEmpty) {
      return _fallbackAvatar(initials, size);
    }

    final isNetworkPhoto =
        photoPath.startsWith('http://') || photoPath.startsWith('https://');

    return ClipRRect(
      borderRadius: BorderRadius.circular(5),
      child: SizedBox(
        width: size,
        height: size,
        child: isNetworkPhoto
            ? Image.network(
                photoPath,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    _fallbackAvatar(initials, size),
              )
            : Image.asset(
                photoPath,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    _fallbackAvatar(initials, size),
              ),
      ),
    );
  }

  Widget _fallbackAvatar(String initials, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFFE7F1EE),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            color: const Color(0xFF103B36),
            fontWeight: FontWeight.w700,
            fontSize: size * 0.4,
          ),
        ),
      ),
    );
  }

  String _initialsForName(String fullName) {
    final parts = fullName
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();

    if (parts.isEmpty) {
      return '?';
    }

    final first = parts.first.characters.first.toUpperCase();
    final second = parts.length > 1
        ? parts[1].characters.first.toUpperCase()
        : '';
    return '$first$second';
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget content = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFE7F0ED),
            borderRadius: BorderRadius.circular(5),
          ),
          child: Icon(icon, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF667572),
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );

    if (onTap != null) {
      content = Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(5),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: content,
          ),
        ),
      );
    }

    return content;
  }
}

String _helperAvailabilitySubtitle({
  required UserEntity user,
  required bool isCurrentlyAvailable,
}) {
  if (!user.availability) {
    return 'You are hidden from new request broadcasts until you turn availability back on.';
  }

  if (!user.hasAvailabilityWindow) {
    return 'You are visible to matching for your chosen support categories.';
  }

  final window = _formatAvailabilityWindowLabel(
    user.availabilityStartMinuteOfDay,
    user.availabilityEndMinuteOfDay,
  );
  if (isCurrentlyAvailable) {
    return 'Time window: $window. You are currently visible to matching.';
  }

  return 'Time window: $window. You are currently outside this window, so matching will pause until your next available time.';
}

String _formatAvailabilityWindowLabel(
  int startMinuteOfDay,
  int endMinuteOfDay,
) {
  return '${_formatAvailabilityMinuteOfDay(startMinuteOfDay)} - ${_formatAvailabilityMinuteOfDay(endMinuteOfDay)}';
}

String _formatAvailabilityMinuteOfDay(int minuteOfDay) {
  if (minuteOfDay < 0 || minuteOfDay >= 24 * 60) {
    return '--:--';
  }

  final hour = minuteOfDay ~/ 60;
  final minute = minuteOfDay % 60;
  final period = hour >= 12 ? 'PM' : 'AM';
  final normalizedHour = hour % 12 == 0 ? 12 : hour % 12;
  final minuteText = minute.toString().padLeft(2, '0');
  return '$normalizedHour:$minuteText $period';
}

TimeOfDay _timeOfDayFromMinuteOfDay(int minuteOfDay) {
  final normalizedMinute = minuteOfDay < 0 ? 0 : minuteOfDay % (24 * 60);
  return TimeOfDay(hour: normalizedMinute ~/ 60, minute: normalizedMinute % 60);
}

int _minuteOfDayForTime(TimeOfDay time) {
  return time.hour * 60 + time.minute;
}
