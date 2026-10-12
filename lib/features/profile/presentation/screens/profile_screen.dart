import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../app/models/ghmera_models.dart';
import '../../../../app/providers/ghmera_app_state.dart';
import '../../../../core/ui/app_snack_bar.dart';
import '../../../../core/ui/ghmera_components.dart';
import '../../../../core/ui/uniform_app_bar.dart';
import '../../../credits/presentation/widgets/credit_wallet_card.dart';
import 'blocked_accounts_screen.dart';
import '../../../auth/domain/constants/auth_messages.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../auth/presentation/screens/login_screen.dart';
import '../widgets/account_deletion_button.dart';
import '../widgets/privacy_session_controls_card.dart';
import '../../../../core/ui/ghmera_theme.dart';

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

  Future<void> _deleteAccount(BuildContext context) async {
    final appState = context.read<GhmeraAppState>();
    final authProvider = context.read<AuthProvider>();
    await appState.prepareForAccountDeletion();

    try {
      await authProvider.deleteAccount();
      appState.completeAccountDeletion();
      if (!context.mounted) {
        return;
      }

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    } catch (error) {
      appState.cancelAccountDeletion();
      if (!context.mounted) {
        return;
      }

      final message = error is AuthException
          ? error.message
          : cleanAuthenticationErrorMessage(
              error.toString(),
              fallbackMessage:
                  'We could not delete your account. Please try again.',
            );
      showGhmeraSnackBar(context, message: message, type: SnackBarType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<GhmeraAppState>();
    final authProvider = context.watch<AuthProvider>();
    final user = appState.currentUser;
    final theme = Theme.of(context);
    final trustFlags = appState.currentUserTrustFlags;
    final credits = appState.currentUserCredits;
    final stats = appState.helpStatsForUser(user.id);
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
    final reviews = appState.reviewsAboutCurrentUser;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: [
        GhCard(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  GhAvatar(
                    name: user.fullName,
                    photo: user.profilePhoto,
                    size: 68,
                    showVerified: user.idVerified || user.trustedHelper,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.fullName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.headlineSmall,
                        ),
                        if (locationLabel.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(
                                Icons.place_outlined,
                                size: 16,
                                color: GhColors.inkSoft,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  locationLabel,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: GhColors.inkSoft,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              if (showBio) ...[
                const SizedBox(height: 12),
                Text(
                  user.shortBio,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: GhColors.inkSoft,
                  ),
                ),
              ],
              const SizedBox(height: 18),
              Row(
                children: [
                  _HeaderStat(
                    value: '${credits.spendable}',
                    label: 'Credits',
                    color: GhColors.creditDeep,
                  ),
                  _HeaderStat(
                    value: '${stats.helpsGiven}',
                    label: 'Helped',
                    color: GhColors.brand,
                  ),
                  _HeaderStat(
                    value: '${stats.helpsReceived}',
                    label: 'Received',
                    color: GhColors.sky,
                  ),
                  _HeaderStat(
                    value: stats.reviewCount == 0
                        ? '–'
                        : stats.averageRating.toStringAsFixed(1),
                    label: 'Rating',
                    color: GhColors.ink,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _openEditProfileScreen(context, user),
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  label: const Text('Edit profile'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        CreditWalletCard(summary: credits, message: appState.creditMessage),
        const SizedBox(height: 16),
        GhCard(
          padding: const EdgeInsets.fromLTRB(16, 6, 10, 6),
          child: SwitchListTile.adaptive(
            value: user.availability,
            onChanged: (_) => appState.toggleAvailability(),
            contentPadding: EdgeInsets.zero,
            activeTrackColor: GhColors.brand,
            secondary: GhIconBadge(
              icon: user.availability
                  ? Icons.volunteer_activism_rounded
                  : Icons.pause_circle_outline_rounded,
              color: user.availability ? GhColors.brand : GhColors.inkSoft,
              size: 42,
            ),
            title: Text('Available to help', style: theme.textTheme.titleSmall),
            subtitle: Text(
              availabilitySubtitle,
              style: theme.textTheme.bodySmall,
            ),
          ),
        ),
        const SizedBox(height: 16),
        _SectionCard(
          title: 'Trust and safety',
          subtitle:
              'Ratings, verified details, and safety signals help people decide to work with you.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('Trust score', style: theme.textTheme.titleSmall),
                  const Spacer(),
                  Text(
                    '${user.trustScore.toStringAsFixed(0)} / 100',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: GhColors.brand,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: (user.trustScore / 100).clamp(0.0, 1.0),
                  minHeight: 8,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: GhStatTile(
                      value: '${appState.activeSafetyReportsAboutCurrentUser}',
                      label: 'Active reports',
                      icon: Icons.flag_outlined,
                      color: GhColors.coral,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GhStatTile(
                      value: '${appState.suspiciousReviewsAboutCurrentUser}',
                      label: 'Flagged reviews',
                      icon: Icons.rate_review_outlined,
                      color: GhColors.amber,
                    ),
                  ),
                ],
              ),
              if (trustFlags.isNotEmpty) ...[
                const SizedBox(height: 16),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: trustFlags
                      .map(
                        (flag) => GhTag(
                          icon: Icons.verified_outlined,
                          label: flag,
                          foreground: GhColors.brandDark,
                          background: GhColors.brandSoft,
                        ),
                      )
                      .toList(),
                ),
              ],
              if (activeReports.isNotEmpty) ...[
                const SizedBox(height: 16),
                for (final report in activeReports.take(3))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: GhInfoBanner(
                      icon: Icons.flag_outlined,
                      foreground: GhColors.coral,
                      background: GhColors.coralSoft,
                      title: report.reason,
                      message: report.details.trim().isEmpty
                          ? report.status.label
                          : '${report.status.label}: ${report.details}',
                    ),
                  ),
              ],
              const SizedBox(height: 12),
              const Divider(),
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
        const SizedBox(height: 16),
        _SectionCard(
          title: 'Reviews',
          subtitle: reviews.isEmpty
              ? 'Reviews from people you help or who help you appear here.'
              : '${reviews.length} ${reviews.length == 1 ? 'review' : 'reviews'} from the community.',
          child: reviews.isEmpty
              ? const _ReviewsEmpty()
              : Column(
                  children: [
                    for (final review in reviews) _ReviewTile(review: review),
                  ],
                ),
        ),
        const SizedBox(height: 16),
        const PrivacySessionControlsCard(),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
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
          ),
        ),
        const SizedBox(height: 12),
        AccountDeletionButton(
          isLoading: authProvider.isLoading,
          onDeleteConfirmed: () => _deleteAccount(context),
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
      appBar: AppBar(
        automaticallyImplyLeading: false,
        centerTitle: false,
        titleSpacing: 0,
        leading: uniformBackButton(context),
        title: uniformAppBarTitle(context, title: 'Edit profile'),
      ),
      body: SafeArea(
        top: false,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            children: [
              Center(
                child: GhAvatar(
                  name: _nameController.text.trim().isEmpty
                      ? widget.user.fullName
                      : _nameController.text,
                  photo: _photoController.text,
                  size: 84,
                ),
              ),
              const SizedBox(height: 18),
              _SectionCard(
                title: 'About you',
                subtitle: 'Shown to people you help and people who help you.',
                child: Column(
                  children: [
                    TextFormField(
                      controller: _nameController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(labelText: 'Full name'),
                      onChanged: (_) => setState(() {}),
                      validator: (value) {
                        if ((value ?? '').trim().isEmpty) {
                          return 'Enter your full name.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _bioController,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Short bio',
                        hintText: 'What kind of help do you enjoy giving?',
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _photoController,
                      decoration: const InputDecoration(
                        labelText: 'Profile photo URL',
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _SectionCard(
                title: 'Availability',
                subtitle: 'Helpers are only matched during these hours.',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _availabilityTimeController,
                      readOnly: true,
                      onTap: _selectAvailabilityWindow,
                      decoration: InputDecoration(
                        labelText: 'Available time',
                        hintText: 'Tap to set a daily time range',
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
                        'Your availability follows this window every day.',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _SectionCard(
                title: 'Location and contact',
                subtitle:
                    'Only your approximate area is shown until you agree to share more.',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: _usesDeviceLocation,
                      onChanged: _setUsesDeviceLocation,
                      title: Text(
                        'Always use my location',
                        style: theme.textTheme.titleSmall,
                      ),
                      subtitle: Text(
                        _usesDeviceLocation
                            ? 'Your road, town, state, and country follow your device location.'
                            : 'Turn this on to fill your location from the device.',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _areaController,
                      enabled: !_usesDeviceLocation,
                      decoration: const InputDecoration(labelText: 'Road'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _cityController,
                      enabled: !_usesDeviceLocation,
                      decoration: const InputDecoration(
                        labelText: 'Town, state, country',
                      ),
                    ),
                    if (_usesDeviceLocation) ...[
                      const SizedBox(height: 10),
                      TextButton.icon(
                        onPressed: _applyingDeviceLocation
                            ? null
                            : _useDeviceLocation,
                        icon: const Icon(Icons.my_location_rounded, size: 18),
                        label: Text(
                          _applyingDeviceLocation
                              ? 'Reading location...'
                              : 'Refresh device location',
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _phoneController,
                      decoration: const InputDecoration(labelText: 'Phone'),
                      keyboardType: TextInputType.phone,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          color: GhColors.surface,
          border: Border(top: BorderSide(color: GhColors.line)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: FilledButton.icon(
              onPressed: _saveProfile,
              icon: const Icon(Icons.check_rounded),
              label: const Text('Save profile'),
            ),
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

    return GhCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: GhColors.inkSoft,
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _HeaderStat extends StatelessWidget {
  const _HeaderStat({
    required this.value,
    required this.label,
    required this.color,
  });

  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(color: color),
          ),
          Text(label, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _ReviewsEmpty extends StatelessWidget {
  const _ReviewsEmpty();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const GhIconBadge(
          icon: Icons.star_outline_rounded,
          color: GhColors.credit,
          size: 40,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            'No reviews yet. Complete a help exchange to receive your first rating.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: GhColors.inkSoft),
          ),
        ),
      ],
    );
  }
}

class _ReviewTile extends StatelessWidget {
  const _ReviewTile({required this.review});

  final ReviewEntity review;

  @override
  Widget build(BuildContext context) {
    final appState = context.read<GhmeraAppState>();
    final theme = Theme.of(context);
    final reviewer = appState.userById(review.reviewerId);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: GhColors.field,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GhAvatar(
                name: reviewer.fullName,
                photo: reviewer.profilePhoto,
                size: 32,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  reviewer.fullName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall,
                ),
              ),
              GhRatingStars(rating: review.rating, size: 15),
            ],
          ),
          if (review.feedback.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              review.feedback,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: GhColors.inkSoft,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            'Helpful ${review.helpfulness}/5 · Respect ${review.respectfulness}/5 · Safety ${review.safety}/5',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
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

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            GhIconBadge(icon: icon, color: GhColors.inkSoft, size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.titleSmall),
                  const SizedBox(height: 2),
                  Text(subtitle, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            if (onTap != null)
              const Icon(Icons.chevron_right_rounded, color: GhColors.inkFaint),
          ],
        ),
      ),
    );
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
