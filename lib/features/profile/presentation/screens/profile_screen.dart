import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';

import '../../../../app/models/ghmera_models.dart';
import '../../../../app/providers/ghmera_app_state.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../auth/presentation/screens/login_screen.dart';
import '../widgets/privacy_session_controls_card.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _fillLocationFromDevice(
    BuildContext context, {
    required TextEditingController cityController,
    required TextEditingController areaController,
  }) async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Enable location services to read device location.',
              ),
            ),
          );
        }
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Location permission is required to read your location.',
              ),
            ),
          );
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      final placemark = placemarks.isNotEmpty ? placemarks.first : null;
      final city = (placemark?.locality?.trim().isNotEmpty ?? false)
          ? placemark!.locality!.trim()
          : (placemark?.administrativeArea?.trim() ?? '');
      final areaCandidates = <String>[
        placemark?.subLocality ?? '',
        placemark?.street ?? '',
        placemark?.name ?? '',
      ].where((value) => value.trim().isNotEmpty).toList();
      final area = areaCandidates.isNotEmpty ? areaCandidates.first.trim() : '';

      cityController.text = city.isNotEmpty
          ? city
          : '${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}';
      areaController.text = area;

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Device location loaded.')),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to read device location right now.'),
          ),
        );
      }
    }
  }

  Future<void> _openEditProfileScreen(
    BuildContext context,
    UserEntity user,
  ) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _EditProfileScreen(
          user: user,
          onFillLocationFromDevice: _fillLocationFromDevice,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<GhmeraAppState>();
    final user = appState.currentUser;
    final theme = Theme.of(context);
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
                  user.availability
                      ? 'You are visible to matching for your chosen support categories.'
                      : 'You are hidden from new request broadcasts until you turn availability back on.',
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
                      value: appState.currentUserAverageReview.toStringAsFixed(
                        1,
                      ),
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
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: appState.reciprocityProgress,
                  minHeight: 3,
                  backgroundColor: const Color(0xFFE7EFEC),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _SectionCard(
          title: 'Support categories',
          subtitle:
              'These settings determine what kinds of support you can offer.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'You can provide',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: RequestCategory.values
                    .map(
                      (category) => FilterChip(
                        label: Text(category.label),
                        selected: user.helpCategoriesProvided.contains(
                          category,
                        ),
                        onSelected: (_) {
                          appState.toggleCurrentUserProvidedCategory(category);
                        },
                      ),
                    )
                    .toList(),
              ),
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
            children: [
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
              _InfoRow(
                icon: Icons.block_rounded,
                title: '${user.blockedUserIds.length} blocked account(s)',
                subtitle: '${user.mutedUserIds.length} muted account(s)',
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

typedef _FillLocationFromDevice =
    Future<void> Function(
      BuildContext context, {
      required TextEditingController cityController,
      required TextEditingController areaController,
    });

class _EditProfileScreen extends StatefulWidget {
  const _EditProfileScreen({
    required this.user,
    required this.onFillLocationFromDevice,
  });

  final UserEntity user;
  final _FillLocationFromDevice onFillLocationFromDevice;

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
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _cityController.dispose();
    _areaController.dispose();
    _phoneController.dispose();
    _photoController.dispose();
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
    );

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
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
                controller: _cityController,
                decoration: const InputDecoration(labelText: 'City'),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _areaController,
                decoration: const InputDecoration(labelText: 'Area'),
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: () => widget.onFillLocationFromDevice(
                    context,
                    cityController: _cityController,
                    areaController: _areaController,
                  ),
                  icon: const Icon(Icons.my_location_rounded),
                  label: const Text('Use device location'),
                ),
              ),
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
                errorBuilder: (_, __, ___) => _fallbackAvatar(initials, size),
              )
            : Image.asset(
                photoPath,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _fallbackAvatar(initials, size),
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
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
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
  }
}
