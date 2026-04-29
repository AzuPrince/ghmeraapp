import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../app/models/ghmera_models.dart';
import '../../../../app/providers/ghmera_app_state.dart';
import '../../../../core/ui/uniform_app_bar.dart';
import '../../../profile/presentation/widgets/privacy_session_controls_card.dart';

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
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _preferredTimeController = TextEditingController(
    text: 'Today, 6:00 PM',
  );
  final _attachmentController = TextEditingController();

  late RequestCategory _category;
  UrgencyLevel _urgency = UrgencyLevel.medium;
  HelpRequestVisibility _visibility = HelpRequestVisibility.restricted;
  late bool _emotionalSupportMode;
  bool _requiresHomeVisit = false;
  bool _lateNightSupport = false;
  bool _moneyRelated = false;
  bool _emergencyOverride = false;
  bool _useMyLocation = true;

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
      _visibility = initialRequest.visibility;
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
    final colorScheme = theme.colorScheme;
    final appState = context.watch<GhmeraAppState>();
    final userLocation = _buildUserLocation(appState.currentUser);
    if (_useMyLocation &&
        userLocation.isNotEmpty &&
        _locationController.text.trim() != userLocation) {
      _locationController.text = userLocation;
    }
    final isEditing = widget.initialRequest != null;
    final requestLocked =
        !isEditing && !appState.canCreateRequest && !_allowsExemption;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        centerTitle: false,
        leading: Navigator.of(context).canPop()
            ? uniformBackButton(context)
            : null,
        title: uniformAppBarTitle(
          context,
          title: isEditing ? 'Edit Help Request' : 'Create Help Request',
          subtitle: isEditing
              ? 'Update the request details shown to helpers.'
              : 'Share details so the right helper can respond.',
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(10, 12, 10, 28),
            children: [
              if (!isEditing && !appState.canCreateRequest)
                Container(
                  margin: const EdgeInsets.only(bottom: 18),
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF5E8),
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(color: const Color(0xFFF2C48A)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.balance_rounded,
                            color: colorScheme.secondary,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Reciprocity hold active',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        appState.reciprocityMessage,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          height: 1.45,
                          color: const Color(0xFF5A4B35),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Emergency requests and approved exception cases can still be submitted below.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF7A6851),
                        ),
                      ),
                    ],
                  ),
                ),
              _SectionCard(
                title: 'Request details',
                subtitle:
                    'The platform needs a clear title, category, and context so matching stays useful rather than noisy.',
                child: Column(
                  children: [
                    TextFormField(
                      controller: _titleController,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Request title',
                        hintText: 'Need help setting up my router tonight',
                      ),
                      validator: (value) {
                        if (value == null || value.trim().length < 6) {
                          return 'Enter a short title with enough context.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<RequestCategory>(
                      initialValue: _category,
                      decoration: const InputDecoration(labelText: 'Category'),
                      items: RequestCategory.values
                          .map(
                            (category) => DropdownMenuItem<RequestCategory>(
                              value: category,
                              child: Text(category.label),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) {
                          return;
                        }
                        setState(() {
                          _category = value;
                          if (value == RequestCategory.emotionalSupport) {
                            _emotionalSupportMode = true;
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _descriptionController,
                      minLines: 4,
                      maxLines: 6,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Detailed description',
                        hintText:
                            'Describe what kind of help is needed, what a helper should know, and any safety or timing limits.',
                        alignLabelWithHint: true,
                      ),
                      validator: (value) {
                        if (value == null || value.trim().length < 20) {
                          return 'Add enough detail for a trusted helper to understand the request.';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _SectionCard(
                title: 'Urgency and visibility',
                subtitle:
                    'Urgency affects ranking. Visibility controls whether the request is broadly surfaced or kept to eligible helpers only.',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Urgency',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: UrgencyLevel.values
                          .map(
                            (urgency) => ChoiceChip(
                              label: Text(urgency.label),
                              selected: _urgency == urgency,
                              onSelected: (_) {
                                setState(() {
                                  _urgency = urgency;
                                });
                              },
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Visibility',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: HelpRequestVisibility.values
                          .map(
                            (visibility) => ChoiceChip(
                              label: Text(visibility.label),
                              selected: _visibility == visibility,
                              onSelected: (_) {
                                setState(() {
                                  _visibility = visibility;
                                });
                              },
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 18),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final stacked = constraints.maxWidth < 640;
                        final useLocationToggle = SwitchListTile.adaptive(
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
                          title: const Text('Use my location by default'),
                          subtitle: Text(
                            userLocation.isEmpty
                                ? 'Add your area or city in your profile to enable this default.'
                                : _useMyLocation
                                ? 'Using $userLocation for this request location.'
                                : 'Location is unlocked. You can edit it manually.',
                          ),
                        );

                        final locationField = TextFormField(
                          controller: _locationController,
                          textCapitalization: TextCapitalization.words,
                          readOnly: _useMyLocation,
                          decoration: const InputDecoration(
                            labelText: 'Approximate location',
                            hintText: 'East Legon',
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Enter the area or neighborhood.';
                            }
                            return null;
                          },
                        );

                        final preferredTimeField = TextFormField(
                          controller: _preferredTimeController,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: const InputDecoration(
                            labelText: 'Preferred time',
                            hintText: 'Tomorrow, 8:00 AM',
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Add a time window.';
                            }
                            return null;
                          },
                        );

                        if (stacked) {
                          return Column(
                            children: [
                              useLocationToggle,
                              const SizedBox(height: 8),
                              locationField,
                              const SizedBox(height: 12),
                              preferredTimeField,
                            ],
                          );
                        }

                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                children: [
                                  useLocationToggle,
                                  const SizedBox(height: 8),
                                  locationField,
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(child: preferredTimeField),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _attachmentController,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Attachment label',
                        hintText: 'Optional note for a screenshot or photo',
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Request routing flags',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'These request-specific flags affect moderation, eligibility checks, and safety workflows.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF61726F),
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 10),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: _emotionalSupportMode,
                      onChanged: (value) {
                        setState(() {
                          _emotionalSupportMode = value;
                        });
                      },
                      title: const Text('Emotional support mode'),
                      subtitle: const Text(
                        'Use structured prompts and listener-friendly routing for emotional or wellbeing support.',
                      ),
                    ),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: _requiresHomeVisit,
                      onChanged: (value) {
                        setState(() {
                          _requiresHomeVisit = value;
                        });
                      },
                      title: const Text('Requires home visit'),
                      subtitle: const Text(
                        'Triggers stronger safety review and more limited identity exposure.',
                      ),
                    ),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: _lateNightSupport,
                      onChanged: (value) {
                        setState(() {
                          _lateNightSupport = value;
                        });
                      },
                      title: const Text('Late-night support'),
                      subtitle: const Text(
                        'Marks the request for additional safety prompts and check-ins.',
                      ),
                    ),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: _moneyRelated,
                      onChanged: (value) {
                        setState(() {
                          _moneyRelated = value;
                        });
                      },
                      title: const Text('Money-related request'),
                      subtitle: const Text(
                        'Used for higher-risk moderation and trust controls.',
                      ),
                    ),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: _emergencyOverride,
                      onChanged: (value) {
                        setState(() {
                          _emergencyOverride = value;
                        });
                      },
                      title: const Text('Emergency or admin exception'),
                      subtitle: const Text(
                        'Allows submission even during a reciprocity hold for approved edge cases.',
                      ),
                    ),
                    if (_category.isHighRisk ||
                        _requiresHomeVisit ||
                        _lateNightSupport ||
                        _moneyRelated)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(top: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8EFE8),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: const Text(
                          'This request will receive stronger moderation, safer chat defaults, and session check-ins before full identity exposure.',
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const PrivacySessionControlsCard(),
              const SizedBox(height: 22),
              FilledButton.icon(
                onPressed: requestLocked ? null : _submit,
                icon: const Icon(Icons.volunteer_activism_rounded),
                label: Text(
                  isEditing
                      ? 'Save request changes'
                      : requestLocked
                      ? 'Help someone else or use an exempt request'
                      : 'Submit request for matching',
                ),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Phone numbers, email addresses, and exact locations remain protected until matching and consent rules allow sharing.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF6D7C79),
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool get _allowsExemption {
    return _emergencyOverride || _category == RequestCategory.emergencySupport;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final appState = context.read<GhmeraAppState>();
    final userLocation = _buildUserLocation(appState.currentUser);
    if (_useMyLocation && userLocation.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Your profile location is missing. Uncheck "Use my location by default" to enter a location manually.',
          ),
        ),
      );
      return;
    }

    final locationValue = _useMyLocation
        ? userLocation
        : _locationController.text.trim();
    final isEditing = widget.initialRequest != null;
    if (!isEditing && !appState.canCreateRequest && !_allowsExemption) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'This account is on a reciprocity hold. Use an emergency exception or help someone else first.',
          ),
        ),
      );
      return;
    }

    final savedRequest = await (isEditing
        ? appState.updateMyHelpRequest(
            requestId: widget.initialRequest!.id,
            title: _titleController.text.trim(),
            description: _descriptionController.text.trim(),
            category: _category,
            urgency: _urgency,
            location: locationValue,
            preferredTime: _preferredTimeController.text.trim(),
            visibility: _visibility,
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
            visibility: _visibility,
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

    if (savedRequest == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'The request could not be saved with the current account state.',
          ),
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isEditing
              ? 'Your request changes were saved.'
              : 'Your request was submitted and routed into matching.',
        ),
      ),
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
