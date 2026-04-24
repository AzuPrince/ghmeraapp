import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../app/models/ghmera_models.dart';
import '../../../../app/providers/ghmera_app_state.dart';
import '../../../../core/ui/uniform_app_bar.dart';
import 'home_menu_screen.dart';
import '../../../profile/presentation/screens/profile_screen.dart';
import 'create_request_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  static const List<String> _titles = <String>[
    'Ghmera',
    'Requests',
    'Messages',
    'Safety',
    'Profile',
  ];

  static const List<String> _subtitles = <String>[
    'Give help, get help, and stay connected.',
    'Requests, matching, and lifecycle tracking.',
    'Protected conversations inside the platform.',
    'Trust, wellbeing, and moderation controls.',
    'Identity, privacy, sessions, and reviews.',
  ];

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<GhmeraAppState>();
    final pages = <Widget>[
      _OverviewTab(
        onReviewOpportunity: _showRequestDetailsSheet,
        onOpenProfile: () => _selectTab(4),
      ),
      _RequestsTab(
        onCreateRequest: _openStandardRequest,
        onEditRequest: _editRequest,
        onReviewAcceptedRequest: _showRequestDetailsSheet,
      ),
      _MessagesTab(onOpenThread: _showThreadSheet),
      _SafetyTab(onReviewRequest: _showRequestDetailsSheet),
      const ProfileScreen(),
    ];

    final showRequestsFab = _currentIndex == 0;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        centerTitle: false,
        leading: _currentIndex == 0
            ? null
            : uniformBackButton(context, onPressed: () => _selectTab(0)),
        titleSpacing: 10,
        title: _buildAppBarTitle(context),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                IconButton(
                  tooltip: 'Notifications',
                  onPressed: _showNotificationsSheet,
                  icon: const Icon(Icons.notifications_none_rounded),
                ),
                if (appState.unreadNotificationsCount > 0)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.tertiary,
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        '${appState.unreadNotificationsCount}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (_currentIndex == 0)
            IconButton(
              tooltip: 'Messages',
              onPressed: () => _selectTab(2),
              icon: const Icon(Icons.chat_bubble_outline_rounded),
            ),
          if (_currentIndex == 0)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: IconButton(
                tooltip: 'Menu',
                onPressed: _openHomeMenu,
                icon: const Icon(Icons.menu_rounded),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 240),
          child: KeyedSubtree(
            key: ValueKey<int>(_currentIndex),
            child: pages[_currentIndex],
          ),
        ),
      ),
      floatingActionButton: showRequestsFab
          ? FloatingActionButton.extended(
              heroTag: 'requests_fab',
              onPressed: () => _selectTab(1),
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              icon: const Icon(Icons.assignment_rounded),
              label: const Text('Your Requests'),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(5),
              ),
            )
          : null,
    );
  }

  Widget _buildAppBarTitle(BuildContext context) {
    if (_currentIndex != 0) {
      return uniformAppBarTitle(
        context,
        title: _titles[_currentIndex],
        subtitle: _subtitles[_currentIndex],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _titles[_currentIndex],
          style: uniformHeadingTextStyle(
            context,
          ).copyWith(color: Theme.of(context).colorScheme.primary),
        ),
        Text(
          _subtitles[_currentIndex],
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: const Color(0xFF596865)),
        ),
      ],
    );
  }

  void _selectTab(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  Future<void> _openStandardRequest() {
    return _openRequestComposer();
  }

  Future<void> _editRequest(HelpRequestEntity request) {
    return _openRequestComposer(initialRequest: request);
  }

  Future<void> _openRequestComposer({
    RequestCategory initialCategory = RequestCategory.errands,
    bool startEmotionalMode = false,
    HelpRequestEntity? initialRequest,
  }) async {
    final requestId = await Navigator.of(context).push<String?>(
      MaterialPageRoute<String?>(
        builder: (_) => CreateRequestScreen(
          initialCategory: initialCategory,
          startEmotionalMode: startEmotionalMode,
          initialRequest: initialRequest,
        ),
      ),
    );

    if (!mounted || requestId == null) {
      return;
    }

    _selectTab(1);
  }

  Future<void> _showNotificationsSheet() {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const _NotificationsScreen()),
    );
  }

  Future<void> _openHomeMenu() {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const HomeMenuScreen()),
    );
  }

  Future<void> _showThreadSheet(MessageThreadEntity initialThread) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => _ThreadScreen(initialThread: initialThread),
      ),
    );
  }

  Future<void> _showRequestDetailsSheet(HelpRequestEntity initialRequest) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => _RequestDetailsScreen(
          initialRequest: initialRequest,
          onOpenThread: _showThreadSheet,
        ),
      ),
    );
  }
}

class _ThreadScreen extends StatefulWidget {
  const _ThreadScreen({required this.initialThread});

  final MessageThreadEntity initialThread;

  @override
  State<_ThreadScreen> createState() => _ThreadScreenState();
}

class _ThreadScreenState extends State<_ThreadScreen> {
  late final TextEditingController _messageController;

  @override
  void initState() {
    super.initState();
    _messageController = TextEditingController();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  void _sendMessage(GhmeraAppState appState, MessageThreadEntity thread) {
    final content = _messageController.text.trim();
    if (content.isEmpty) {
      return;
    }

    appState.sendMessage(threadId: thread.id, content: content);
    _messageController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        centerTitle: false,
        leading: uniformBackButton(context),
        title: uniformAppBarTitle(
          context,
          title: 'Protected chat',
          subtitle: 'Secure conversation with your matched peer.',
        ),
      ),
      body: SafeArea(
        child: Consumer<GhmeraAppState>(
          builder: (context, appState, _) {
            final thread =
                appState.messageThreads.firstWhereOrNull(
                  (candidate) => candidate.id == widget.initialThread.id,
                ) ??
                widget.initialThread;
            final peer = appState.peerForThread(thread);
            final request = appState.requestById(thread.requestId);
            final messages = appState.messagesForThread(thread.id);
            final theme = Theme.of(context);
            final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

            return Padding(
              padding: EdgeInsets.fromLTRB(10, 12, 10, bottomInset + 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    peer?.fullName ?? 'Conversation',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    request.title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF61726F),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F1E8),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      thread.messageRequestPending
                          ? 'This thread is still a message request. Contact details stay hidden until the match is accepted and both sides consent.'
                          : 'Protected chat is active. Contact sharing still requires explicit consent from both users.',
                      style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView(
                      children: [
                        for (final message in messages)
                          Align(
                            alignment:
                                message.senderId == appState.currentUserId
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                              constraints: const BoxConstraints(maxWidth: 320),
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color:
                                    message.senderId == appState.currentUserId
                                    ? const Color(0xFF103B36)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(5),
                                boxShadow: const <BoxShadow>[
                                  BoxShadow(
                                    color: Color(0x0F000000),
                                    blurRadius: 16,
                                    offset: Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    message.content,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color:
                                          message.senderId ==
                                              appState.currentUserId
                                          ? Colors.white
                                          : const Color(0xFF223532),
                                      height: 1.4,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    _relativeTime(message.createdAt),
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color:
                                          message.senderId ==
                                              appState.currentUserId
                                          ? Colors.white.withValues(alpha: 0.68)
                                          : const Color(0xFF758481),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          minLines: 1,
                          maxLines: 4,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: const InputDecoration(
                            labelText: 'Message',
                            hintText: 'Reply inside protected chat',
                          ),
                          onSubmitted: (_) => _sendMessage(appState, thread),
                        ),
                      ),
                      const SizedBox(width: 12),
                      FilledButton(
                        onPressed: () => _sendMessage(appState, thread),
                        child: const Text('Send'),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _RequestDetailsScreen extends StatelessWidget {
  const _RequestDetailsScreen({
    required this.initialRequest,
    required this.onOpenThread,
  });

  final HelpRequestEntity initialRequest;
  final ValueChanged<MessageThreadEntity> onOpenThread;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        centerTitle: false,
        leading: uniformBackButton(context),
        title: uniformAppBarTitle(
          context,
          title: 'Request details',
          subtitle: 'Timeline, match reasons, and response actions.',
        ),
      ),
      body: SafeArea(
        child: Consumer<GhmeraAppState>(
          builder: (context, appState, _) {
            final request = appState.requestById(initialRequest.id);
            final requester = appState.userById(request.requesterId);
            final helper = appState.helperForRequest(request);
            final helpingMatch = appState.helpingMatches.firstWhereOrNull(
              (candidate) => candidate.requestId == request.id,
            );
            final requesterMatch = appState.matchesForMyRequests
                .firstWhereOrNull(
                  (candidate) => candidate.requestId == request.id,
                );
            final activeMatch = helpingMatch ?? requesterMatch;
            final theme = Theme.of(context);

            return ListView(
              padding: const EdgeInsets.fromLTRB(10, 12, 10, 28),
              children: [
                Text(
                  request.title,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${requester.fullName} • ${_relativeTime(request.createdAt)}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF61726F),
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _Pill(
                      label: request.category.label,
                      color: const Color(0xFFE5F1ED),
                    ),
                    _Pill(
                      label: request.status.label,
                      color: _statusColor(
                        request.status,
                      ).withValues(alpha: 0.14),
                      textColor: _statusColor(request.status),
                    ),
                    _Pill(
                      label: request.urgency.label,
                      color: _urgencyColor(
                        request.urgency,
                      ).withValues(alpha: 0.14),
                      textColor: _urgencyColor(request.urgency),
                    ),
                    if (request.emotionalSupportMode)
                      const _Pill(
                        label: 'Emotional support',
                        color: Color(0xFFFFE8EE),
                      ),
                    if (request.isHighRisk)
                      const _Pill(label: 'High risk', color: Color(0xFFFFE9D6)),
                    if (request.attachmentLabel != null)
                      _Pill(
                        label: request.attachmentLabel!,
                        color: const Color(0xFFF5F1E8),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(5),
                    boxShadow: const <BoxShadow>[
                      BoxShadow(
                        color: Color(0x10000000),
                        blurRadius: 20,
                        offset: Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request.description,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          height: 1.45,
                          color: const Color(0xFF233532),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.location_on_outlined, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${request.location} • ${request.preferredTime}',
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                      if (helper != null) ...[
                        const SizedBox(height: 10),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.handshake_outlined, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Accepted helper: ${helper.fullName}',
                                style: theme.textTheme.bodyMedium,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                if (activeMatch != null && activeMatch.reasons.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  Text(
                    'Why this match surfaced',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: activeMatch.reasons
                        .map(
                          (reason) => _Pill(
                            label: reason,
                            color: const Color(0xFFEAF3F0),
                          ),
                        )
                        .toList(),
                  ),
                ],
                if (request.isHighRisk) ...[
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3E6),
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(color: const Color(0xFFF2C48A)),
                    ),
                    child: Text(
                      'This request triggers stronger safety handling. Exact location and off-platform contact should remain gated until trust and consent checks are complete.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF6A5336),
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
      bottomNavigationBar: Consumer<GhmeraAppState>(
        builder: (context, appState, _) {
          final request = appState.requestById(initialRequest.id);
          final protectedThread = appState.threadForRequest(request.id);
          final helperCanVolunteer =
              request.requesterId != appState.currentUserId &&
              request.status != HelpRequestStatus.completed &&
              request.status != HelpRequestStatus.canceled &&
              (request.acceptedHelperId == null ||
                  request.acceptedHelperId == appState.currentUserId);
          final alreadyMatchedAsHelper =
              request.acceptedHelperId == appState.currentUserId;
          final colorScheme = Theme.of(context).colorScheme;
          final chatActionButtonStyle = FilledButton.styleFrom(
            backgroundColor: colorScheme.secondary,
            foregroundColor: colorScheme.onSecondary,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(5),
            ),
          );
          final helpActionButtonStyle = FilledButton.styleFrom(
            backgroundColor: colorScheme.primary,
            foregroundColor: colorScheme.onPrimary,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(5),
            ),
          );

          return SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 6, 10, 12),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () {
                        if (protectedThread != null) {
                          onOpenThread(protectedThread);
                          return;
                        }

                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Chat opens after a helper match is confirmed.',
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.chat_bubble_outline_rounded),
                      label: const Text('Chat with the person'),
                      style: chatActionButtonStyle,
                    ),
                  ),
                  if (helperCanVolunteer) const SizedBox(width: 12),
                  if (helperCanVolunteer)
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: alreadyMatchedAsHelper
                            ? null
                            : () {
                                final matched = appState
                                    .volunteerForHelpRequest(request.id);
                                if (!matched) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'This request is no longer available for matching.',
                                      ),
                                    ),
                                  );
                                  return;
                                }

                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Match confirmed. Protected chat is now available.',
                                    ),
                                  ),
                                );
                              },
                        icon: const Icon(Icons.volunteer_activism_outlined),
                        label: Text(
                          alreadyMatchedAsHelper ? 'Matched' : 'I can help',
                        ),
                        style: helpActionButtonStyle,
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _NotificationsScreen extends StatelessWidget {
  const _NotificationsScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        centerTitle: false,
        leading: uniformBackButton(context),
        title: uniformAppBarTitle(
          context,
          title: 'Notifications',
          subtitle: 'Matches, safety alerts, and key reminders.',
        ),
      ),
      body: SafeArea(
        child: Consumer<GhmeraAppState>(
          builder: (context, appState, _) {
            final notifications = appState.currentNotifications;

            return ListView(
              padding: const EdgeInsets.fromLTRB(10, 12, 10, 28),
              children: [
                Text(
                  'Matches, messages, safety alerts, reciprocity warnings, and wellbeing reminders land here.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF61726F),
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 18),
                if (notifications.isEmpty)
                  const _EmptyStateCard(
                    title: 'No notifications yet',
                    message:
                        'New alerts for matches, chat, safety, and requests will appear here.',
                  )
                else
                  for (final notification in notifications)
                    _NotificationCard(
                      notification: notification,
                      onTap: () {
                        if (!notification.isRead) {
                          appState.markNotificationRead(notification.id);
                        }
                      },
                    ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({
    required this.onReviewOpportunity,
    required this.onOpenProfile,
  });

  final ValueChanged<HelpRequestEntity> onReviewOpportunity;
  final VoidCallback onOpenProfile;

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
    final allHelpRequests = appState.requestsNeedingMyHelp;
    final acceptedRequests = allHelpRequests
        .where((request) => request.acceptedHelperId == appState.currentUserId)
        .toList();
    final pendingHelpRequests = allHelpRequests
        .where((request) => request.acceptedHelperId == null)
        .toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 28),
      children: [
        GestureDetector(
          onTap: onOpenProfile,
          child: Container(
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
                    _RequesterAvatar(requester: user, size: 68),
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
                    _HeroPill(
                      icon: Icons.workspace_premium_rounded,
                      label: 'Trust ${user.trustScore.toStringAsFixed(0)}',
                      backgroundColor: const Color(0xFFDCE2E9),
                      foregroundColor: const Color(0xFF1D3037),
                      compact: true,
                    ),
                    _HeroPill(
                      icon: Icons.sync_alt_rounded,
                      label: 'Balance ${user.helpBalance}',
                      backgroundColor: const Color(0xFFDCE2E9),
                      foregroundColor: const Color(0xFF1D3037),
                      compact: true,
                    ),
                    _HeroPill(
                      icon: Icons.notifications_active_outlined,
                      label:
                          '${appState.unreadNotificationsCount} unread alerts',
                      backgroundColor: const Color(0xFFDCE2E9),
                      foregroundColor: const Color(0xFF1D3037),
                      compact: true,
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                ClipRRect(
                  borderRadius: BorderRadius.circular(5),
                  child: LinearProgressIndicator(
                    value: appState.reciprocityProgress,
                    minHeight: 3,
                    backgroundColor: const Color(0xFFD0D7DF),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  appState.reciprocityMessage,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF53626A),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        const _SectionHeader(
          title: 'Accepted requests',
          subtitle: 'People requests you have already accepted to help with.',
        ),
        const SizedBox(height: 10),
        if (acceptedRequests.isNotEmpty)
          for (final request in acceptedRequests)
            _OpportunityCard(
              request: request,
              onReviewRequest: onReviewOpportunity,
            ),
        if (acceptedRequests.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(
              'No help requested yet.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: const Color(0xFF61726F)),
            ),
          ),
        const SizedBox(height: 14),
        const _SectionHeader(
          title: 'Help requests',
          subtitle: 'Remaining people requests you have not accepted yet.',
        ),
        const SizedBox(height: 10),
        if (pendingHelpRequests.isEmpty)
          const _EmptyStateCard(
            title: 'No help requests waiting',
            message:
                'New requests that match your help profile will appear here.',
          )
        else
          for (final request in pendingHelpRequests)
            _OpportunityCard(
              request: request,
              onReviewRequest: onReviewOpportunity,
            ),
      ],
    );
  }
}

class _RequestsTab extends StatelessWidget {
  const _RequestsTab({
    required this.onCreateRequest,
    required this.onEditRequest,
    required this.onReviewAcceptedRequest,
  });

  final VoidCallback onCreateRequest;
  final ValueChanged<HelpRequestEntity> onEditRequest;
  final ValueChanged<HelpRequestEntity> onReviewAcceptedRequest;

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<GhmeraAppState>();
    final myPastRequests = appState.myRequests.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final acceptedRequests = myPastRequests
        .where((request) => request.acceptedHelperId != null)
        .toList();
    final editableRequests = myPastRequests
        .where((request) => request.acceptedHelperId == null)
        .toList();

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
            children: [
              const _SectionHeader(
                title: 'Accepted requests',
                subtitle:
                    'People who already accepted to help with your requests.',
              ),
              const SizedBox(height: 10),
              if (acceptedRequests.isEmpty)
                const _EmptyStateCard(
                  title: 'No accepted requests yet',
                  message:
                      'When someone accepts to help with your request, they will appear here.',
                )
              else
                for (final request in acceptedRequests)
                  _AcceptedMyRequestTile(
                    request: request,
                    helper: appState.helperForRequest(request)!,
                    onTap: () => onReviewAcceptedRequest(request),
                  ),
              const SizedBox(height: 14),
              const _SectionHeader(
                title: 'Your requests',
                subtitle: 'Tap a request to edit its details.',
              ),
              const SizedBox(height: 10),
              if (editableRequests.isEmpty)
                const _EmptyStateCard(
                  title: 'No editable requests yet',
                  message: 'Requests you create will appear here for editing.',
                )
              else
                for (final request in editableRequests)
                  _MyRequestTile(
                    request: request,
                    onTap: () => onEditRequest(request),
                  ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 6, 10, 12),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onCreateRequest,
                icon: const Icon(Icons.add_circle_outline_rounded),
                label: const Text('New request'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MessagesTab extends StatelessWidget {
  const _MessagesTab({required this.onOpenThread});

  final ValueChanged<MessageThreadEntity> onOpenThread;

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<GhmeraAppState>();
    final threads = appState.messageThreads;

    return ListView(
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 28),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F1E8),
            borderRadius: BorderRadius.circular(5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Protected messaging',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                'Chats stay in-app first. Phone numbers, emails, and exact location details stay hidden until match acceptance and explicit consent.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF5C6A67),
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        if (threads.isEmpty)
          const _EmptyStateCard(
            title: 'No message threads yet',
            message: 'Accepted matches and message requests will appear here.',
          )
        else
          for (final thread in threads)
            _ThreadCard(thread: thread, onTap: () => onOpenThread(thread)),
      ],
    );
  }
}

class _SafetyTab extends StatelessWidget {
  const _SafetyTab({required this.onReviewRequest});

  final ValueChanged<HelpRequestEntity> onReviewRequest;

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<GhmeraAppState>();

    return ListView(
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 28),
      children: [
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: const Color(0xFF103B36),
            borderRadius: BorderRadius.circular(5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Trust, safety, and wellbeing',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Ghmera is not a therapy or emergency medical platform. It uses peer support, crisis routing, moderation, and high-risk controls to protect both sides of each interaction.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.82),
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: const [
                  _HeroPill(
                    icon: Icons.warning_amber_rounded,
                    label: 'Crisis prompts',
                  ),
                  _HeroPill(
                    icon: Icons.location_on_outlined,
                    label: 'Approximate location first',
                  ),
                  _HeroPill(
                    icon: Icons.admin_panel_settings_outlined,
                    label: 'Moderation queue',
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _SectionHeader(
          title: 'High-risk interactions',
          subtitle:
              'Childcare, elderly support, money-related requests, home visits, and late-night support receive stronger controls.',
        ),
        const SizedBox(height: 10),
        if (appState.highRiskRequests.isEmpty)
          const _EmptyStateCard(
            title: 'No high-risk requests are active',
            message:
                'High-risk requests would appear here with stronger check-in and moderation prompts.',
          )
        else
          for (final request in appState.highRiskRequests)
            _RequestCard(
              request: request,
              appState: appState,
              showRequester: true,
              leadingLabel: 'Safety review required',
              onTap: () => onReviewRequest(request),
            ),
        const SizedBox(height: 18),
        _SectionHeader(
          title: 'Moderation queue',
          subtitle:
              'Admin and moderator workflows for reports, disputes, and harmful behavior.',
        ),
        const SizedBox(height: 10),
        for (final report in appState.moderationQueue)
          _ReportCard(report: report),
        const SizedBox(height: 18),
        _SectionHeader(
          title: 'Admin dashboard preview',
          subtitle:
              'Core health metrics that support moderation, fairness, and product monitoring.',
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _AdminMetricCard(
              label: 'Total users',
              value: '${appState.totalUsers}',
            ),
            _AdminMetricCard(
              label: 'Daily active',
              value: '${appState.dailyActiveUsers}',
            ),
            _AdminMetricCard(
              label: 'Requests created',
              value: '${appState.helpRequestsCreated}',
            ),
            _AdminMetricCard(
              label: 'Requests completed',
              value: '${appState.helpRequestsCompleted}',
            ),
            _AdminMetricCard(
              label: 'Reports',
              value: '${appState.reportsCount}',
            ),
            _AdminMetricCard(
              label: 'High-risk interactions',
              value: '${appState.highRiskInteractionCount}',
            ),
            _AdminMetricCard(
              label: 'Emotional support usage',
              value: '${appState.emotionalSupportUsageCount}',
            ),
            _AdminMetricCard(
              label: 'Help ratio',
              value: appState.currentUserHelpRatio.toStringAsFixed(1),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Container(
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
            children: const [
              _SafetyFeatureRow(
                icon: Icons.notification_important_outlined,
                title: 'Emergency features',
                text:
                    'Panic button prompts, “I feel unsafe” paths, trusted-contact sharing, and safety check-ins.',
              ),
              SizedBox(height: 12),
              _SafetyFeatureRow(
                icon: Icons.favorite_border_rounded,
                title: 'Depression and emotional support',
                text:
                    'Daily mood check-ins, peer listener matching, support circles, and crisis resource escalation.',
              ),
              SizedBox(height: 12),
              _SafetyFeatureRow(
                icon: Icons.public_off_outlined,
                title: 'Location privacy',
                text:
                    'Only approximate location is visible at first. Exact addresses wait for need and consent.',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    this.subtitle = '',
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasSubtitle = subtitle.trim().isNotEmpty;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (hasSubtitle) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF61726F),
                    height: 1.4,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (actionLabel != null && onAction != null)
          TextButton(onPressed: onAction, child: Text(actionLabel!)),
      ],
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({
    required this.width,
    required this.icon,
    required this.title,
    required this.text,
    required this.onTap,
  });

  final double width;
  final IconData icon;
  final String title;
  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: InkWell(
        borderRadius: BorderRadius.circular(5),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(5),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Color(0x10000000),
                blurRadius: 20,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFE7F1EE),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Icon(icon),
              ),
              const SizedBox(height: 14),
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                text,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF61726F),
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({
    required this.request,
    required this.appState,
    this.showRequester = false,
    this.helperContext = false,
    this.leadingLabel,
    this.onTap,
  });

  final HelpRequestEntity request;
  final GhmeraAppState appState;
  final bool showRequester;
  final bool helperContext;
  final String? leadingLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final requester = appState.userById(request.requesterId);
    final helper = appState.helperForRequest(request);
    final helperCandidates = appState.helperCandidatesForRequest(request);
    final lastAction = request.actionLog.isNotEmpty
        ? request.actionLog.last
        : null;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(5),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x10000000),
              blurRadius: 20,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (leadingLabel != null) ...[
              Text(
                leadingLabel!,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: const Color(0xFF61726F),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
            ],
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request.title,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        request.description,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF5F6F6B),
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: _urgencyColor(
                      request.urgency,
                    ).withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    request.urgency.label,
                    style: TextStyle(
                      color: _urgencyColor(request.urgency),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _Pill(
                  label: request.category.label,
                  color: const Color(0xFFE5F1ED),
                ),
                _Pill(
                  label: request.status.label,
                  color: _statusColor(request.status).withValues(alpha: 0.14),
                  textColor: _statusColor(request.status),
                ),
                _Pill(
                  label: request.visibility.label,
                  color: const Color(0xFFF5F1E8),
                ),
                if (request.emotionalSupportMode)
                  const _Pill(
                    label: 'Emotional support',
                    color: Color(0xFFFFE8EE),
                  ),
                if (request.isHighRisk)
                  const _Pill(label: 'High risk', color: Color(0xFFFFE9D6)),
                if (request.safetyCheckInRequired)
                  const _Pill(
                    label: 'Safety check-in',
                    color: Color(0xFFE8F1FF),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.location_on_outlined, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text('${request.location} • ${request.preferredTime}'),
                ),
              ],
            ),
            if (showRequester) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.person_outline_rounded, size: 18),
                  const SizedBox(width: 6),
                  Expanded(child: Text('Requester: ${requester.fullName}')),
                ],
              ),
            ],
            if (helper != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.handshake_outlined, size: 18),
                  const SizedBox(width: 6),
                  Expanded(child: Text('Accepted by ${helper.fullName}')),
                ],
              ),
            ],
            if (helperContext &&
                helper == null &&
                helperCandidates.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                'Helper candidates',
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: helperCandidates
                    .take(3)
                    .map(
                      (candidate) => _Pill(
                        label: candidate.fullName,
                        color: const Color(0xFFE7F1EE),
                      ),
                    )
                    .toList(),
              ),
            ],
            if (lastAction != null) ...[
              const SizedBox(height: 10),
              Text(
                '${lastAction.action} • ${_relativeTime(lastAction.createdAt)}',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: const Color(0xFF7A8885)),
              ),
            ],
            if (onTap != null) ...[
              const SizedBox(height: 12),
              Text(
                'Tap to view details',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF61726F),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MyRequestTile extends StatelessWidget {
  const _MyRequestTile({required this.request, required this.onTap});

  final HelpRequestEntity request;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(5),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: ListTile(
        onTap: onTap,
        minVerticalPadding: 0,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFFE7F1EE),
            borderRadius: BorderRadius.circular(5),
          ),
          child: Icon(
            Icons.assignment_outlined,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        title: Text(
          request.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          '${request.category.label} • ${request.status.label}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: const Color(0xFF61726F)),
        ),
        trailing: const Icon(Icons.edit_outlined),
      ),
    );
  }
}

class _AcceptedMyRequestTile extends StatelessWidget {
  const _AcceptedMyRequestTile({
    required this.request,
    required this.helper,
    required this.onTap,
  });

  final HelpRequestEntity request;
  final UserEntity helper;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(5),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          ListTile(
            onTap: onTap,
            minVerticalPadding: 0,
            contentPadding: const EdgeInsets.only(
              left: 4,
              top: 0,
              right: 16,
              bottom: 0,
            ),
            leading: _RequesterAvatar(requester: helper, size: 80),
            title: Padding(
              padding: const EdgeInsets.only(right: 56),
              child: Text(
                helper.fullName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            subtitle: Text(
              request.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: const Color(0xFF61726F)),
            ),
          ),
          Positioned(
            top: 8,
            right: 16,
            child: IgnorePointer(
              child: _TrustStars(trustScore: helper.trustScore),
            ),
          ),
        ],
      ),
    );
  }
}

class _OpportunityCard extends StatelessWidget {
  const _OpportunityCard({
    required this.request,
    required this.onReviewRequest,
  });

  final HelpRequestEntity request;
  final ValueChanged<HelpRequestEntity> onReviewRequest;

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<GhmeraAppState>();
    final requester = appState.userById(request.requesterId);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(5),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          ListTile(
            onTap: () => onReviewRequest(request),
            minVerticalPadding: 0,
            contentPadding: const EdgeInsets.only(
              left: 4,
              top: 0,
              right: 16,
              bottom: 0,
            ),
            leading: _RequesterAvatar(requester: requester, size: 80),
            title: Padding(
              padding: const EdgeInsets.only(right: 56),
              child: Text(
                requester.fullName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            subtitle: Text(
              request.category.label,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: const Color(0xFF61726F)),
            ),
          ),
          Positioned(
            top: 8,
            right: 16,
            child: IgnorePointer(
              child: _TrustStars(trustScore: requester.trustScore),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrustStars extends StatelessWidget {
  const _TrustStars({required this.trustScore});

  final double trustScore;

  @override
  Widget build(BuildContext context) {
    final filledStars = ((trustScore / 20).round()).clamp(0, 5) as int;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List<Widget>.generate(5, (index) {
        final isFilled = index < filledStars;
        return Padding(
          padding: EdgeInsets.only(left: index == 0 ? 0 : 0.5),
          child: Icon(
            isFilled ? Icons.star_rounded : Icons.star_border_rounded,
            size: 10,
            color: isFilled ? const Color(0xFFF2B33D) : const Color(0xFFC8D0CE),
          ),
        );
      }),
    );
  }
}

class _RequesterAvatar extends StatelessWidget {
  const _RequesterAvatar({required this.requester, this.size = 48});

  final UserEntity requester;
  final double size;

  @override
  Widget build(BuildContext context) {
    final photoPath = requester.profilePhoto?.trim();
    final initials = _initialsForName(requester.fullName);

    if (photoPath == null || photoPath.isEmpty) {
      return _fallbackAvatar(initials);
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
                errorBuilder: (_, __, ___) => _fallbackAvatar(initials),
              )
            : Image.asset(
                photoPath,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _fallbackAvatar(initials),
              ),
      ),
    );
  }

  Widget _fallbackAvatar(String initials) {
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

class _ThreadCard extends StatelessWidget {
  const _ThreadCard({required this.thread, required this.onTap});

  final MessageThreadEntity thread;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<GhmeraAppState>();
    final peer = appState.peerForThread(thread);
    final request = appState.requestById(thread.requestId);
    final messages = appState.messagesForThread(thread.id);
    final lastMessage = messages.isNotEmpty ? messages.last : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(5),
        child: Ink(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(5),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Color(0x10000000),
                blurRadius: 20,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: const Color(0xFFE7F1EE),
                child: Text(peer?.fullName.characters.first ?? '?'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            peer?.fullName ?? 'Unknown user',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                        Text(
                          _relativeTime(thread.lastMessageAt),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: const Color(0xFF788683)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      request.title,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF61726F),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      lastMessage?.content ?? 'No messages yet.',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF526461),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (thread.messageRequestPending)
                          const _Pill(
                            label: 'Message request',
                            color: Color(0xFFFFEFD7),
                          ),
                        if (thread.contactSharedByIds.isNotEmpty)
                          const _Pill(
                            label: 'Contact sharing gated',
                            color: Color(0xFFE8F1FF),
                          ),
                        if (thread.flaggedSafetyConcern)
                          const _Pill(
                            label: 'Safety flag',
                            color: Color(0xFFFFE9D6),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.notification, this.onTap});

  final NotificationEntity notification;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = _notificationColor(notification.type);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(5),
        child: Ink(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: notification.isRead
                ? Colors.white
                : color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(5),
            border: Border.all(
              color: notification.isRead
                  ? const Color(0xFFE6ECEA)
                  : color.withValues(alpha: 0.30),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Icon(_notificationIcon(notification.type), color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                        Text(
                          _relativeTime(notification.createdAt),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: const Color(0xFF788683)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      notification.message,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF586A66),
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({required this.report});

  final ReportEntity report;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(5),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  report.reason,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              _Pill(
                label: report.status.label,
                color: _reportStatusColor(
                  report.status,
                ).withValues(alpha: 0.14),
                textColor: _reportStatusColor(report.status),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${report.targetType.label} report • ${_relativeTime(report.createdAt)}',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: const Color(0xFF788683)),
          ),
          const SizedBox(height: 10),
          Text(
            report.details,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              height: 1.45,
              color: const Color(0xFF5F6F6B),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminMetricCard extends StatelessWidget {
  const _AdminMetricCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 168,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(5),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x10000000),
              blurRadius: 18,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: const Color(0xFF6B7976)),
            ),
          ],
        ),
      ),
    );
  }
}

class _SafetyFeatureRow extends StatelessWidget {
  const _SafetyFeatureRow({
    required this.icon,
    required this.title,
    required this.text,
  });

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFE7F1EE),
            borderRadius: BorderRadius.circular(5),
          ),
          child: Icon(icon),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                text,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF61726F),
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.color, this.textColor});

  final String label;
  final Color color;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor ?? const Color(0xFF233532),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _HeroPill extends StatelessWidget {
  const _HeroPill({
    required this.icon,
    required this.label,
    this.backgroundColor = const Color(0x1FFFFFFF),
    this.foregroundColor = Colors.white,
    this.compact = false,
  });

  final IconData icon;
  final String label;
  final Color backgroundColor;
  final Color foregroundColor;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final horizontalPadding = compact ? 8.0 : 12.0;
    final verticalPadding = compact ? 7.0 : 10.0;
    final iconSize = compact ? 15.0 : 18.0;
    final gap = compact ? 6.0 : 8.0;
    final fontSize = compact ? 12.0 : 14.0;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: verticalPadding,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: iconSize, color: foregroundColor),
          SizedBox(width: gap),
          Text(
            label,
            style: TextStyle(
              color: foregroundColor,
              fontWeight: FontWeight.w600,
              fontSize: fontSize,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyStateCard extends StatelessWidget {
  const _EmptyStateCard({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(5),
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
            message,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF61726F),
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

extension _IterableLookup<T> on Iterable<T> {
  T? firstWhereOrNull(bool Function(T element) test) {
    for (final element in this) {
      if (test(element)) {
        return element;
      }
    }

    return null;
  }
}

Color _urgencyColor(UrgencyLevel urgency) {
  switch (urgency) {
    case UrgencyLevel.low:
      return const Color(0xFF4F8C62);
    case UrgencyLevel.medium:
      return const Color(0xFFD08A2E);
    case UrgencyLevel.high:
      return const Color(0xFFC45B3F);
  }
}

Color _statusColor(HelpRequestStatus status) {
  switch (status) {
    case HelpRequestStatus.open:
      return const Color(0xFF6A7A76);
    case HelpRequestStatus.matching:
      return const Color(0xFF0F6B5C);
    case HelpRequestStatus.matched:
      return const Color(0xFF2B7A78);
    case HelpRequestStatus.accepted:
      return const Color(0xFF2C7F62);
    case HelpRequestStatus.inProgress:
      return const Color(0xFFD08A2E);
    case HelpRequestStatus.completed:
      return const Color(0xFF47795D);
    case HelpRequestStatus.canceled:
      return const Color(0xFF8D6E63);
    case HelpRequestStatus.reported:
      return const Color(0xFFC45B3F);
    case HelpRequestStatus.disputed:
      return const Color(0xFFB14E5F);
  }
}

Color _notificationColor(NotificationType type) {
  switch (type) {
    case NotificationType.matchFound:
      return const Color(0xFF0F6B5C);
    case NotificationType.newMessage:
      return const Color(0xFF2B7A78);
    case NotificationType.requestAccepted:
      return const Color(0xFF3F7D59);
    case NotificationType.helpCompleted:
      return const Color(0xFF558B6E);
    case NotificationType.reportUpdate:
      return const Color(0xFF7B6FA6);
    case NotificationType.safetyAlert:
      return const Color(0xFFC45B3F);
    case NotificationType.reciprocityWarning:
      return const Color(0xFFD08A2E);
    case NotificationType.emotionalCheckInReminder:
      return const Color(0xFFB6617A);
    case NotificationType.adminUpdate:
      return const Color(0xFF5C6F90);
  }
}

IconData _notificationIcon(NotificationType type) {
  switch (type) {
    case NotificationType.matchFound:
      return Icons.handshake_outlined;
    case NotificationType.newMessage:
      return Icons.chat_bubble_outline_rounded;
    case NotificationType.requestAccepted:
      return Icons.assignment_turned_in_outlined;
    case NotificationType.helpCompleted:
      return Icons.task_alt_rounded;
    case NotificationType.reportUpdate:
      return Icons.admin_panel_settings_outlined;
    case NotificationType.safetyAlert:
      return Icons.warning_amber_rounded;
    case NotificationType.reciprocityWarning:
      return Icons.sync_problem_rounded;
    case NotificationType.emotionalCheckInReminder:
      return Icons.favorite_border_rounded;
    case NotificationType.adminUpdate:
      return Icons.campaign_outlined;
  }
}

Color _reportStatusColor(ReportStatus status) {
  switch (status) {
    case ReportStatus.open:
      return const Color(0xFFC45B3F);
    case ReportStatus.investigating:
      return const Color(0xFFD08A2E);
    case ReportStatus.resolved:
      return const Color(0xFF4F8C62);
    case ReportStatus.dismissed:
      return const Color(0xFF7A8885);
  }
}

Color _moodColor(MoodLevel mood) {
  switch (mood) {
    case MoodLevel.good:
      return const Color(0xFF4F8C62);
    case MoodLevel.okay:
      return const Color(0xFFD08A2E);
    case MoodLevel.struggling:
      return const Color(0xFFC97749);
    case MoodLevel.notOkay:
      return const Color(0xFFB14E5F);
  }
}

IconData _moodIcon(MoodLevel mood) {
  switch (mood) {
    case MoodLevel.good:
      return Icons.sentiment_satisfied_alt_rounded;
    case MoodLevel.okay:
      return Icons.sentiment_neutral_rounded;
    case MoodLevel.struggling:
      return Icons.self_improvement_rounded;
    case MoodLevel.notOkay:
      return Icons.support_rounded;
  }
}

String _moodDescription(MoodLevel mood) {
  switch (mood) {
    case MoodLevel.good:
      return 'You are doing well today.';
    case MoodLevel.okay:
      return 'You are stable but may still want lighter support.';
    case MoodLevel.struggling:
      return 'The app will highlight emotional support and support circles.';
    case MoodLevel.notOkay:
      return 'The app will surface stronger support prompts and crisis resources.';
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
