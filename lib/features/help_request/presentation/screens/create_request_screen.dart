import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../app/models/ghmera_models.dart';
import '../../../../app/providers/ghmera_app_state.dart';
import '../../../../app/services/help_credits.dart';
import '../../../../core/ui/ghmera_components.dart';
import '../../../../core/ui/uniform_app_bar.dart';
import '../../../../core/ui/app_snack_bar.dart';
import '../../../../core/ui/ghmera_theme.dart';

class CreateRequestScreen extends StatefulWidget {
  const CreateRequestScreen({
    super.key,
    this.initialCategory = RequestCategory.errands,
    this.startEmotionalMode = false,
    this.initialRequest,
  });

  final RequestCategory initialCategory;
  final bool startEmotionalMode;
  final HelpRequestEntity? initialRequest;

  @override
  State<CreateRequestScreen> createState() => _CreateRequestScreenState();
}

class _CreateRequestScreenState extends State<CreateRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionFieldKey = GlobalKey();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _preferredTimeController = TextEditingController(
    text: 'Today, 6:00 PM',
  );
  final _attachmentController = TextEditingController();

  late RequestCategory _category;
  UrgencyLevel _urgency = UrgencyLevel.medium;
  late bool _emotionalSupportMode;
  bool _requiresHomeVisit = false;
  bool _lateNightSupport = false;
  bool _moneyRelated = false;
  bool _emergencyOverride = false;
  bool _useMyLocation = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final initialRequest = widget.initialRequest;
    if (initialRequest != null) {
      _titleController.text = initialRequest.title;
      _descriptionController.text = initialRequest.description;
      _locationController.text = initialRequest.location;
      _preferredTimeController.text = initialRequest.preferredTime;
      _attachmentController.text = initialRequest.attachmentLabel ?? '';
      _category = initialRequest.category;
      _urgency = initialRequest.urgency;
      _emotionalSupportMode = initialRequest.emotionalSupportMode;
      _requiresHomeVisit = initialRequest.requiresHomeVisit;
      _lateNightSupport = initialRequest.lateNightSupport;
      _moneyRelated = initialRequest.moneyRelated;
      _emergencyOverride = initialRequest.emergencyOverride;
      _useMyLocation = false;
      return;
    }

    _category = widget.initialCategory;
    _emotionalSupportMode =
        widget.startEmotionalMode ||
        widget.initialCategory == RequestCategory.emotionalSupport;

    final userLocation = _buildUserLocation(
      context.read<GhmeraAppState>().currentUser,
    );
    if (userLocation.isNotEmpty) {
      _locationController.text = userLocation;
      _useMyLocation = true;
    } else {
      _useMyLocation = false;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _preferredTimeController.dispose();
    _attachmentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appState = context.watch<GhmeraAppState>();
    final userLocation = _buildUserLocation(appState.currentUser);
    if (_useMyLocation &&
        userLocation.isNotEmpty &&
        _locationController.text.trim() != userLocation) {
      _locationController.text = userLocation;
    }
    final isEditing = widget.initialRequest != null;
    final credits = appState.currentUserCredits;
    final isFree = creditFreeCategories.contains(_category);
    final requestLocked = !isEditing && !appState.canCreateRequest && !isFree;
    final horizontalPadding = math.max(
      16.0,
      (MediaQuery.sizeOf(context).width - 760) / 2,
    );
    final showsSafetyNotice =
        _category.isHighRisk ||
        _requiresHomeVisit ||
        _lateNightSupport ||
        _moneyRelated;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        centerTitle: false,
        titleSpacing: Navigator.of(context).canPop() ? 0 : 16,
        leading: Navigator.of(context).canPop()
            ? uniformBackButton(context)
            : null,
        title: uniformAppBarTitle(
          context,
          title: isEditing ? 'Edit request' : 'Ask for help',
          subtitle: isEditing
              ? 'Update what helpers will see.'
              : 'Tell nearby helpers what you need.',
        ),
      ),
      body: SafeArea(
        top: false,
        bottom: false,
        child: Form(
          key: _formKey,
          // A lazy ListView would unmount off-screen fields, and Form.validate
          // skips unmounted fields.
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              4,
              horizontalPadding,
              24,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!isEditing) ...[
                  _CreditStatusBanner(
                    available: credits.available,
                    isFree: isFree,
                    locked: requestLocked,
                    bypass: appState.currentUser.canBypassReciprocity,
                    onChooseEmergency: () {
                      setState(() {
                        _category = RequestCategory.emergencySupport;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                ],
                _SectionCard(
                  title: 'What do you need?',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: _titleController,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          labelText: 'Short title',
                          hintText: 'Need help setting up my router tonight',
                        ),
                        validator: (value) {
                          if (value == null || value.trim().length < 6) {
                            return 'Enter a short title with enough context.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 18),
                      Text('Category', style: theme.textTheme.titleSmall),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: RequestCategory.values.map((category) {
                          final style = GhCategoryStyle.of(category);
                          final selected = _category == category;
                          return ChoiceChip(
                            showCheckmark: false,
                            selected: selected,
                            avatar: Icon(
                              style.icon,
                              size: 18,
                              color: selected ? Colors.white : style.color,
                            ),
                            label: Text(category.label),
                            labelStyle: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: selected ? Colors.white : GhColors.ink,
                            ),
                            selectedColor: style.color,
                            side: BorderSide(
                              color: selected ? style.color : GhColors.line,
                            ),
                            onSelected: (_) {
                              setState(() {
                                _category = category;
                                if (category ==
                                    RequestCategory.emotionalSupport) {
                                  _emotionalSupportMode = true;
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 18),
                      TextFormField(
                        key: _descriptionFieldKey,
                        controller: _descriptionController,
                        minLines: 4,
                        maxLines: 6,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          labelText: 'Details',
                          hintText:
                              'What kind of help is needed, what should a helper know, and any timing or safety limits?',
                          alignLabelWithHint: true,
                        ),
                        validator: (value) {
                          if (value == null || value.trim().length < 20) {
                            return 'Add a little more detail so helpers understand the request.';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _SectionCard(
                  title: 'When and where',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'How urgent is it?',
                        style: theme.textTheme.titleSmall,
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: UrgencyLevel.values.map((urgency) {
                          final selected = _urgency == urgency;
                          final color = ghUrgencyColor(urgency);
                          return Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(
                                right: urgency == UrgencyLevel.values.last
                                    ? 0
                                    : 8,
                              ),
                              child: _UrgencyOption(
                                label: urgency.label,
                                color: color,
                                selected: selected,
                                onTap: () => setState(() => _urgency = urgency),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 18),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        value: _useMyLocation,
                        onChanged: userLocation.isEmpty
                            ? null
                            : (value) {
                                setState(() {
                                  _useMyLocation = value;
                                  if (value) {
                                    _locationController.text = userLocation;
                                  }
                                });
                              },
                        title: Text(
                          'Use my location',
                          style: theme.textTheme.titleSmall,
                        ),
                        subtitle: Text(
                          userLocation.isEmpty
                              ? 'Add your area in your profile to use it here.'
                              : _useMyLocation
                              ? 'Using $userLocation'
                              : 'Enter a different location below.',
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _locationController,
                        textCapitalization: TextCapitalization.words,
                        readOnly: _useMyLocation,
                        decoration: const InputDecoration(
                          labelText: 'Location helpers will see',
                          hintText: 'East Legon',
                          prefixIcon: Icon(Icons.place_outlined),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Enter the area or neighborhood.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _preferredTimeController,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          labelText: 'Preferred time',
                          hintText: 'Tomorrow, 8:00 AM',
                          prefixIcon: Icon(Icons.schedule_rounded),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Add a time window.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _attachmentController,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          labelText:
                              'Note for a photo or screenshot (optional)',
                          prefixIcon: Icon(Icons.attach_file_rounded),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _SectionCard(
                  title: 'Safety options',
                  subtitle:
                      'These help us route your request to the right people with the right safeguards.',
                  child: Column(
                    children: [
                      _SafetyToggle(
                        icon: Icons.favorite_border_rounded,
                        title: 'Emotional support',
                        subtitle: 'Route to listener-friendly helpers.',
                        value: _emotionalSupportMode,
                        onChanged: (value) =>
                            setState(() => _emotionalSupportMode = value),
                      ),
                      _SafetyToggle(
                        icon: Icons.home_outlined,
                        title: 'Requires a home visit',
                        subtitle: 'Adds stronger safety review.',
                        value: _requiresHomeVisit,
                        onChanged: (value) =>
                            setState(() => _requiresHomeVisit = value),
                      ),
                      _SafetyToggle(
                        icon: Icons.nightlight_outlined,
                        title: 'Late-night support',
                        subtitle: 'Adds safety prompts and check-ins.',
                        value: _lateNightSupport,
                        onChanged: (value) =>
                            setState(() => _lateNightSupport = value),
                      ),
                      _SafetyToggle(
                        icon: Icons.payments_outlined,
                        title: 'Involves money',
                        subtitle: 'Adds trust and moderation controls.',
                        value: _moneyRelated,
                        onChanged: (value) =>
                            setState(() => _moneyRelated = value),
                      ),
                    ],
                  ),
                ),
                if (showsSafetyNotice) ...[
                  const SizedBox(height: 16),
                  const GhInfoBanner(
                    icon: Icons.health_and_safety_outlined,
                    foreground: GhColors.amber,
                    background: GhColors.amberSoft,
                    message:
                        'This request gets stronger moderation, safer chat defaults, and check-ins before identities are fully shared.',
                  ),
                ],
                const SizedBox(height: 12),
                Text(
                  'Helpers see the location exactly as you enter it above.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
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
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: FilledButton.icon(
                  onPressed: requestLocked || _isSubmitting ? null : _submit,
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(
                          isEditing ? Icons.check_rounded : Icons.send_rounded,
                        ),
                  label: Text(
                    isEditing
                        ? 'Save changes'
                        : requestLocked
                        ? 'You need $requestCreditCost credits to post'
                        : isFree
                        ? 'Post emergency request · free'
                        : 'Post request · uses $requestCreditCost credits',
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      if (_descriptionController.text.trim().length < 20) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) {
            return;
          }

          final descriptionContext = _descriptionFieldKey.currentContext;
          if (descriptionContext == null) {
            return;
          }

          Scrollable.ensureVisible(
            descriptionContext,
            alignment: 0.2,
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeInOut,
          );
        });
      }
      return;
    }

    final appState = context.read<GhmeraAppState>();
    final userLocation = _buildUserLocation(appState.currentUser);
    if (_useMyLocation && userLocation.isEmpty) {
      showGhmeraSnackBar(
        context,
        message:
            'Your profile location is missing. Turn off "Use my location" to enter one manually.',
        type: SnackBarType.warning,
      );
      return;
    }

    final locationValue = _useMyLocation
        ? userLocation
        : _locationController.text.trim();
    final isEditing = widget.initialRequest != null;
    final isFree = creditFreeCategories.contains(_category);
    if (!isEditing && !appState.canCreateRequest && !isFree) {
      showGhmeraSnackBar(
        context,
        message:
            'You need at least $requestCreditCost help credits to post: $askCreditCost to ask and $receiveCreditCost to receive help. Help someone in the community to earn more.',
        type: SnackBarType.error,
      );
      return;
    }

    setState(() => _isSubmitting = true);
    final savedRequest = await (isEditing
        ? appState.updateMyHelpRequest(
            requestId: widget.initialRequest!.id,
            title: _titleController.text.trim(),
            description: _descriptionController.text.trim(),
            category: _category,
            urgency: _urgency,
            location: locationValue,
            preferredTime: _preferredTimeController.text.trim(),
            visibility: HelpRequestVisibility.public,
            attachmentLabel: _attachmentController.text.trim(),
            emotionalSupportMode: _emotionalSupportMode,
            requiresHomeVisit: _requiresHomeVisit,
            lateNightSupport: _lateNightSupport,
            moneyRelated: _moneyRelated,
            emergencyOverride: _emergencyOverride,
          )
        : appState.createHelpRequest(
            title: _titleController.text.trim(),
            description: _descriptionController.text.trim(),
            category: _category,
            urgency: _urgency,
            location: locationValue,
            preferredTime: _preferredTimeController.text.trim(),
            visibility: HelpRequestVisibility.public,
            attachmentLabel: _attachmentController.text.trim(),
            emotionalSupportMode: _emotionalSupportMode,
            requiresHomeVisit: _requiresHomeVisit,
            lateNightSupport: _lateNightSupport,
            moneyRelated: _moneyRelated,
            emergencyOverride: _emergencyOverride,
          ));

    if (!mounted) {
      return;
    }
    setState(() => _isSubmitting = false);

    if (savedRequest == null) {
      showGhmeraSnackBar(
        context,
        message:
            appState.lastWorkflowError ??
            'The request could not be saved. Please try again.',
        type: SnackBarType.error,
      );
      return;
    }

    showGhmeraSnackBar(
      context,
      message: isEditing
          ? 'Your request changes were saved.'
          : isFree
          ? 'Your emergency request is live. Nearby helpers are being notified.'
          : 'Your request is live. $requestCreditCost credits are on hold until the help is done.',
      type: SnackBarType.success,
    );
    Navigator.of(context).pop(savedRequest.id);
  }

  String _buildUserLocation(UserEntity user) {
    final area = user.area.trim();
    final city = user.city.trim();
    if (area.isNotEmpty && city.isNotEmpty) {
      if (area.toLowerCase() == city.toLowerCase()) {
        return area;
      }
      return '$area, $city';
    }
    if (area.isNotEmpty) {
      return area;
    }
    return city;
  }
}

class _CreditStatusBanner extends StatelessWidget {
  const _CreditStatusBanner({
    required this.available,
    required this.isFree,
    required this.locked,
    required this.bypass,
    required this.onChooseEmergency,
  });

  final int available;
  final bool isFree;
  final bool locked;
  final bool bypass;
  final VoidCallback onChooseEmergency;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (locked) {
      final needed = requestCreditCost - available;
      return GhInfoBanner(
        icon: Icons.account_balance_wallet_outlined,
        foreground: GhColors.coral,
        background: GhColors.coralSoft,
        title: available <= 0
            ? 'You are out of help credits'
            : 'You need $requestCreditCost credits to post',
        message:
            'Each request uses $askCreditCost credit to ask and $receiveCreditCost to receive help. '
            'Help someone in the community to earn $needed more. Emergency requests are always free.',
        action: TextButton(
          onPressed: onChooseEmergency,
          style: TextButton.styleFrom(
            foregroundColor: GhColors.coral,
            padding: EdgeInsets.zero,
            minimumSize: const Size(0, 30),
            visualDensity: VisualDensity.compact,
          ),
          child: const Text('Switch to emergency support'),
        ),
      );
    }

    final message = isFree
        ? 'Emergency requests are free. No credits will be used.'
        : bypass && available < requestCreditCost
        ? 'Your account is community supported, so you can post without credits.'
        : 'Posting holds $requestCreditCost credits: $askCreditCost for asking and $receiveCreditCost for receiving help. Both are used once the help is done. You have $available available.';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: GhColors.creditSoft,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const GhCoin(size: 34),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: GhColors.creditDeep,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UrgencyOption extends StatelessWidget {
  const _UrgencyOption({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? color.withValues(alpha: 0.12) : GhColors.field,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(GhRadius.control),
        side: BorderSide(
          color: selected ? color : GhColors.line,
          width: selected ? 1.6 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(GhRadius.control),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            children: [
              Icon(Icons.bolt_rounded, color: color, size: 20),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: selected ? color : GhColors.inkSoft,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SafetyToggle extends StatelessWidget {
  const _SafetyToggle({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SwitchListTile.adaptive(
      contentPadding: EdgeInsets.zero,
      value: value,
      onChanged: onChanged,
      secondary: GhIconBadge(
        icon: icon,
        color: value ? GhColors.brand : GhColors.inkSoft,
        size: 38,
      ),
      title: Text(title, style: theme.textTheme.titleSmall),
      subtitle: Text(subtitle, style: theme.textTheme.bodySmall),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, this.subtitle, required this.child});

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GhCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleLarge),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: GhColors.inkSoft,
              ),
            ),
          ],
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}
