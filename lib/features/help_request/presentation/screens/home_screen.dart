import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../app/models/ghmera_models.dart';
import '../../../../app/providers/ghmera_app_state.dart';
import '../../../../app/services/help_credits.dart';
import '../../../../app/services/map_geocoding_service.dart';
import '../../../../core/ui/app_snack_bar.dart';
import '../../../../core/ui/ghmera_components.dart';
import '../../../../core/ui/ghmera_theme.dart';
import '../../../../core/ui/uniform_app_bar.dart';
import '../../../credits/presentation/widgets/credit_wallet_card.dart';
import '../../../credits/presentation/widgets/help_credits_sheet.dart';
import 'home_menu_screen.dart';
import '../../../profile/presentation/screens/profile_screen.dart';
import 'create_request_screen.dart';

enum _CommunityRequestMenuAction { removeFromView, reportAccount, blockAccount }

enum _MyRequestMenuAction {
  viewDetails,
  editThisRequest,
  hideThisRequest,
  deleteThisRequest,
}

enum _AcceptedRequestMenuAction {
  messageReceiver,
  helpFulfilled,
  reportHelpGiver,
  cancelRequest,
}

enum _MessageAction { copy, reply, report, delete }

enum _NotificationAction { markAsRead, markAsUnread, delete }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const int _giveHelpTabIndex = 0;
  static const int _receiveHelpTabIndex = 1;
  static const int _messagesTabIndex = 2;
  static const int _safetyTabIndex = 3;
  static const int _accountTabIndex = 4;
  static const String _createNewRequestSelection =
      '__create_new_request_selection__';

  int _currentIndex = _giveHelpTabIndex;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showCreditsIntroOnce();
    });
  }

  Future<void> _showCreditsIntroOnce() async {
    final userId = context.read<GhmeraAppState>().currentUserId;
    final key = 'ghmera_credits_intro_seen_$userId';
    final preferences = await SharedPreferences.getInstance();
    if (!mounted || (preferences.getBool(key) ?? false)) {
      return;
    }
    await preferences.setBool(key, true);
    if (!mounted) {
      return;
    }
    await showCreditsWelcomeSheet(context);
  }

  static const List<String> _titles = <String>[
    'Give help',
    'Receive help',
    'Messages',
    'Safety',
    'Account',
  ];

  static const List<String> _subtitles = <String>[
    'Browse people who need support right now.',
    'Your requests and help credits.',
    'Protected conversations inside Ghmera.',
    'Trust, wellbeing, and moderation controls.',
    'Profile, credits, privacy, and reviews.',
  ];

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<GhmeraAppState>();
    final pages = <Widget>[
      _OverviewTab(
        onReviewOpportunity: _showRequestDetailsSheet,
        onRequestLongPress: _showCommunityRequestActions,
      ),
      _RequestsTab(
        onCreateRequest: _openStandardRequest,
        onLongPressMyRequest: _showMyRequestActions,
        onManageAcceptedRequest: _showAcceptedRequestActionsSheet,
        onOpenRequest: _showRequestDetailsSheet,
        onDirectRequestHelper: _startDirectHelperRequestFlow,
        onFindPeopleToHelp: () => _selectTab(_giveHelpTabIndex),
      ),
      _MessagesTab(onOpenThread: _showThreadSheet),
      _SafetyTab(onReviewRequest: _showRequestDetailsSheet),
      const ProfileScreen(),
    ];
    final isPrimaryTab = _isPrimaryTab(_currentIndex);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        centerTitle: false,
        toolbarHeight: 64,
        leading: isPrimaryTab
            ? null
            : uniformBackButton(
                context,
                onPressed: () => _selectTab(_giveHelpTabIndex),
              ),
        titleSpacing: isPrimaryTab ? 16 : 0,
        title: _buildAppBarTitle(context, appState),
        actions: [
          if (_currentIndex == _receiveHelpTabIndex)
            _BadgedIconButton(
              tooltip: 'Hidden requests',
              icon: Icons.visibility_off_outlined,
              count: appState.hiddenMyRequestsCount,
              onPressed: _showHiddenRequestsScreen,
            ),
          if (_currentIndex != _messagesTabIndex)
            _BadgedIconButton(
              tooltip: 'Messages',
              icon: Icons.chat_bubble_outline_rounded,
              onPressed: () => _selectTab(_messagesTabIndex),
            ),
          _BadgedIconButton(
            tooltip: 'Notifications',
            icon: Icons.notifications_none_rounded,
            count: appState.unreadNotificationsCount,
            onPressed: _showNotificationsSheet,
          ),
          if (_currentIndex == _giveHelpTabIndex)
            IconButton(
              tooltip: 'Menu',
              onPressed: _openHomeMenu,
              icon: const Icon(Icons.menu_rounded),
            ),
          const SizedBox(width: 6),
        ],
      ),
      body: SafeArea(
        top: false,
        bottom: !isPrimaryTab,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          switchInCurve: Curves.easeOutCubic,
          child: KeyedSubtree(
            key: ValueKey<int>(_currentIndex),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: pages[_currentIndex],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: isPrimaryTab
          ? DecoratedBox(
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: GhColors.line)),
              ),
              child: NavigationBar(
                selectedIndex: _primaryNavigationIndexFor(_currentIndex),
                onDestinationSelected: (index) {
                  switch (index) {
                    case 0:
                      _selectTab(_giveHelpTabIndex);
                    case 1:
                      _selectTab(_receiveHelpTabIndex);
                    case 2:
                      _selectTab(_accountTabIndex);
                  }
                },
                destinations: const <NavigationDestination>[
                  NavigationDestination(
                    icon: Icon(Icons.volunteer_activism_outlined),
                    selectedIcon: Icon(Icons.volunteer_activism_rounded),
                    label: 'Give Help',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.front_hand_outlined),
                    selectedIcon: Icon(Icons.front_hand_rounded),
                    label: 'Receive Help',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.person_outline_rounded),
                    selectedIcon: Icon(Icons.person_rounded),
                    label: 'Account',
                  ),
                ],
              ),
            )
          : null,
    );
  }

  Widget _buildAppBarTitle(BuildContext context, GhmeraAppState appState) {
    if (_currentIndex != _giveHelpTabIndex) {
      return uniformAppBarTitle(
        context,
        title: _titles[_currentIndex],
        subtitle: _subtitles[_currentIndex],
      );
    }

    final user = appState.currentUser;
    final firstName = user.fullName.trim().split(RegExp(r'\s+')).first;
    final theme = Theme.of(context);
    return Row(
      children: [
        GhAvatar(name: user.fullName, photo: user.profilePhoto, size: 40),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _greetingForNow(),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: GhColors.inkSoft,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                firstName.isEmpty ? 'Welcome' : firstName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleLarge,
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _greetingForNow() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good morning';
    }
    if (hour < 17) {
      return 'Good afternoon';
    }
    return 'Good evening';
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

  Future<String?> _showRequestComposerScreen({
    RequestCategory initialCategory = RequestCategory.errands,
    bool startEmotionalMode = false,
    HelpRequestEntity? initialRequest,
  }) {
    return Navigator.of(context).push<String?>(
      MaterialPageRoute<String?>(
        builder: (_) => CreateRequestScreen(
          initialCategory: initialCategory,
          startEmotionalMode: startEmotionalMode,
          initialRequest: initialRequest,
        ),
      ),
    );
  }

  Future<void> _openRequestComposer({
    RequestCategory initialCategory = RequestCategory.errands,
    bool startEmotionalMode = false,
    HelpRequestEntity? initialRequest,
  }) async {
    final requestId = await _showRequestComposerScreen(
      initialCategory: initialCategory,
      startEmotionalMode: startEmotionalMode,
      initialRequest: initialRequest,
    );

    if (!mounted || requestId == null) {
      return;
    }

    _selectTab(_receiveHelpTabIndex);
  }

  bool _isPrimaryTab(int index) {
    return index == _giveHelpTabIndex ||
        index == _receiveHelpTabIndex ||
        index == _accountTabIndex;
  }

  int _primaryNavigationIndexFor(int index) {
    switch (index) {
      case _receiveHelpTabIndex:
        return 1;
      case _accountTabIndex:
        return 2;
      case _giveHelpTabIndex:
      case _messagesTabIndex:
      case _safetyTabIndex:
        return 0;
    }

    return 0;
  }

  Future<void> _showNotificationsSheet() {
    context.read<GhmeraAppState>().markCurrentNotificationsRead();
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const _NotificationsScreen()),
    );
  }

  Future<void> _showHiddenRequestsScreen() {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => _HiddenRequestsScreen(
          onEditRequest: _editRequest,
          onReviewAcceptedRequest: _showRequestDetailsSheet,
        ),
      ),
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

  Future<void> _startDirectHelperRequestFlow(UserEntity helper) async {
    final selectedRequestId = await _showDirectHelperRequestSheet(helper);
    if (!mounted || selectedRequestId == null) {
      return;
    }

    String? requestId = selectedRequestId;
    if (selectedRequestId == _createNewRequestSelection) {
      requestId = await _showRequestComposerScreen();
      if (!mounted || requestId == null) {
        return;
      }

      _selectTab(_receiveHelpTabIndex);
    }

    final matched = await context
        .read<GhmeraAppState>()
        .requestHelperForMyRequest(requestId: requestId, helperId: helper.id);
    if (!mounted) {
      return;
    }

    final helperFirstName = helper.fullName.trim().split(' ').first;
    showGhmeraSnackBar(
      context,
      message: matched
          ? '$helperFirstName was requested directly for your help request.'
          : 'Could not request $helperFirstName for that help request.',
      type: matched ? SnackBarType.success : SnackBarType.error,
    );
  }

  Future<String?> _showDirectHelperRequestSheet(UserEntity helper) {
    final appState = context.read<GhmeraAppState>();
    final editableRequests =
        appState.myRequests
            .where(
              (request) =>
                  request.acceptedHelperId == null &&
                  request.status != HelpRequestStatus.completed &&
                  request.status != HelpRequestStatus.canceled,
            )
            .toList()
          ..sort(
            (first, second) => second.createdAt.compareTo(first.createdAt),
          );

    return showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(GhRadius.sheet),
        ),
      ),
      builder: (sheetContext) {
        final helperFirstName = helper.fullName.trim().split(' ').first;

        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            children: [
              const _SheetDragHandle(),
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 4, 4),
                child: Text(
                  'Request help from ${helper.fullName}',
                  style: Theme.of(sheetContext).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                child: Text(
                  editableRequests.isEmpty
                      ? 'Create a new request and send it directly to. $helperFirstName.'
                      : 'Choose an existing request or create a new one for $helperFirstName.',
                  style: Theme.of(
                    sheetContext,
                  ).textTheme.bodyMedium?.copyWith(color: GhColors.inkSoft),
                ),
              ),
              if (editableRequests.isEmpty)
                const Padding(
                  padding: EdgeInsets.fromLTRB(8, 0, 8, 8),
                  child: Text(
                    'No editable requests are available yet.',
                    style: TextStyle(color: GhColors.inkSoft),
                  ),
                )
              else
                for (final request in editableRequests)
                  ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    onTap: () => Navigator.of(sheetContext).pop(request.id),
                    leading: const Icon(Icons.assignment_outlined),
                    title: Text(
                      request.displayTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(sheetContext).textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      '${request.category.label} • ${request.location}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(
                        sheetContext,
                      ).textTheme.bodySmall?.copyWith(color: GhColors.inkSoft),
                    ),
                  ),
              _MenuSheetActionTile(
                icon: Icons.add_circle_outline_rounded,
                label: 'Create new request for $helperFirstName',
                onTap: () =>
                    Navigator.of(sheetContext).pop(_createNewRequestSelection),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showAcceptedRequestActionsSheet(
    HelpRequestEntity initialRequest,
  ) async {
    final appState = context.read<GhmeraAppState>();
    final request = appState.requestById(initialRequest.id);
    final helper = appState.helperForRequest(request);
    if (helper == null) {
      await _showRequestDetailsSheet(request);
      return;
    }
    final helperFirstName = helper.fullName.trim().split(' ').first;

    final selectedAction =
        await showModalBottomSheet<_AcceptedRequestMenuAction>(
          context: context,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(GhRadius.sheet),
            ),
          ),
          builder: (sheetContext) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SheetDragHandle(),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 4, 4, 4),
                      child: Text(
                        request.displayTitle,
                        style: Theme.of(sheetContext).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                      child: Text(
                        'Actions for ${helper.fullName}',
                        style: Theme.of(sheetContext).textTheme.bodyMedium
                            ?.copyWith(color: GhColors.inkSoft),
                      ),
                    ),
                    _MenuSheetActionTile(
                      icon: Icons.chat_bubble_outline_rounded,
                      label: 'Message $helperFirstName',
                      onTap: () => Navigator.of(
                        sheetContext,
                      ).pop(_AcceptedRequestMenuAction.messageReceiver),
                    ),
                    _MenuSheetActionTile(
                      icon: Icons.task_alt_rounded,
                      label: 'Help fulfilled',
                      onTap: () => Navigator.of(
                        sheetContext,
                      ).pop(_AcceptedRequestMenuAction.helpFulfilled),
                    ),
                    _MenuSheetActionTile(
                      icon: Icons.report_outlined,
                      label: 'Report help giver',
                      foregroundColor: GhColors.coral,
                      onTap: () => Navigator.of(
                        sheetContext,
                      ).pop(_AcceptedRequestMenuAction.reportHelpGiver),
                    ),
                    _MenuSheetActionTile(
                      icon: Icons.cancel_outlined,
                      label: 'Cancel request',
                      foregroundColor: GhColors.coral,
                      onTap: () => Navigator.of(
                        sheetContext,
                      ).pop(_AcceptedRequestMenuAction.cancelRequest),
                    ),
                  ],
                ),
              ),
            );
          },
        );

    if (!mounted || selectedAction == null) {
      return;
    }

    switch (selectedAction) {
      case _AcceptedRequestMenuAction.messageReceiver:
        final protectedThread = appState.threadForRequest(request.id);
        if (protectedThread == null) {
          showGhmeraSnackBar(
            context,
            message:
                'Protected chat with $helperFirstName is not available yet.',
            type: SnackBarType.warning,
          );
          return;
        }

        await _showThreadSheet(protectedThread);
        return;
      case _AcceptedRequestMenuAction.helpFulfilled:
        await _confirmAcceptedRequestFulfilled(request);
        return;
      case _AcceptedRequestMenuAction.reportHelpGiver:
        await _showParticipantSafetyReportSheet(
          request: request,
          reportedUser: helper,
        );
        return;
      case _AcceptedRequestMenuAction.cancelRequest:
        await _cancelAcceptedRequest(request);
        return;
    }
  }

  Future<void> _confirmAcceptedRequestFulfilled(
    HelpRequestEntity initialRequest,
  ) async {
    final appState = context.read<GhmeraAppState>();
    final request = appState.requestById(initialRequest.id);
    if (!appState.canCurrentUserConfirmRequestCompletion(request)) {
      final message = request.status == HelpRequestStatus.completed
          ? 'This request is already complete.'
          : appState.hasCurrentUserConfirmedRequestCompletion(request)
          ? 'You already marked this help as fulfilled.'
          : 'This request cannot be marked fulfilled yet.';
      showGhmeraSnackBar(context, message: message, type: SnackBarType.warning);
      return;
    }

    final shouldConfirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Help fulfilled'),
        content: const Text(
          'Mark this request as fulfilled from your side. Once both sides confirm, the help giver\'s score and trust increase and the request closes.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (shouldConfirm != true || !mounted) {
      return;
    }

    final confirmed = await appState.confirmCurrentUserRequestCompletion(
      request.id,
    );
    if (!mounted) {
      return;
    }

    final refreshedRequest = appState.requestById(request.id);
    final helpGiver = appState.helperForRequest(refreshedRequest);
    int? submittedRating;
    if (confirmed &&
        helpGiver != null &&
        refreshedRequest.requesterId == appState.currentUserId &&
        appState.canCurrentUserSubmitReviewForRequest(refreshedRequest)) {
      submittedRating = await _showHelpGiverRatingSheet(
        request: refreshedRequest,
        helpGiver: helpGiver,
      );
      if (!mounted) {
        return;
      }
    }

    final helpGiverFirstName = helpGiver?.fullName.trim().split(' ').first;
    final canRateHelpGiverLater =
        helpGiver != null &&
        refreshedRequest.requesterId == appState.currentUserId &&
        appState.canCurrentUserSubmitReviewForRequest(refreshedRequest);

    showGhmeraSnackBar(
      context,
      message: !confirmed
          ? 'Help fulfillment could not be updated.'
          : submittedRating != null && helpGiverFirstName != null
          ? refreshedRequest.status == HelpRequestStatus.completed
                ? 'Completion and your $submittedRating-star rating for $helpGiverFirstName were saved. The request is now closed.'
                : 'Your help fulfillment confirmation and $submittedRating-star rating for $helpGiverFirstName were saved. The request will close once they confirm too.'
          : refreshedRequest.status == HelpRequestStatus.completed
          ? helpGiverFirstName == null
                ? 'Both participants confirmed completion. The request is now closed.'
                : 'Both participants confirmed completion. You can still rate $helpGiverFirstName from request details.'
          : canRateHelpGiverLater && helpGiverFirstName != null
          ? 'Your help fulfillment confirmation was saved. You can rate $helpGiverFirstName now or later.'
          : 'Your help fulfillment confirmation was saved. Once the helper also confirms, their score and trust will increase.',
      type: confirmed ? SnackBarType.success : SnackBarType.error,
    );
  }

  Future<int?> _showHelpGiverRatingSheet({
    required HelpRequestEntity request,
    required UserEntity helpGiver,
  }) {
    return showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(GhRadius.sheet),
        ),
      ),
      builder: (_) =>
          _HelpGiverRatingSheet(request: request, helpGiver: helpGiver),
    );
  }

  Future<void> _cancelAcceptedRequest(HelpRequestEntity initialRequest) async {
    final appState = context.read<GhmeraAppState>();
    final request = appState.requestById(initialRequest.id);
    if (request.status == HelpRequestStatus.completed) {
      showGhmeraSnackBar(
        context,
        message: 'Completed requests cannot be canceled.',
      );
      return;
    }

    if (request.status == HelpRequestStatus.canceled) {
      showGhmeraSnackBar(context, message: 'This request is already canceled.');
      return;
    }

    final shouldCancel = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancel request'),
        content: const Text(
          'Cancel this request for both you and the accepted help giver? This will close the request.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep request'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Cancel request'),
          ),
        ],
      ),
    );

    if (shouldCancel != true || !mounted) {
      return;
    }

    final canceled = await appState.cancelMyAcceptedRequest(request.id);
    if (!mounted) {
      return;
    }

    showGhmeraSnackBar(
      context,
      message: canceled
          ? isCreditFreeRequest(request)
                ? 'Request canceled.'
                : 'Request canceled. Your held credit was returned.'
          : appState.lastWorkflowError ?? 'This request could not be canceled.',
      type: canceled ? SnackBarType.success : SnackBarType.error,
    );
  }

  Future<void> _showCommunityRequestActions(HelpRequestEntity request) async {
    final appState = context.read<GhmeraAppState>();
    final requester = appState.userById(request.requesterId);
    final selectedAction =
        await showModalBottomSheet<_CommunityRequestMenuAction>(
          context: context,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(GhRadius.sheet),
            ),
          ),
          builder: (sheetContext) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SheetDragHandle(),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 4, 4, 4),
                      child: Text(
                        request.displayTitle,
                        style: Theme.of(sheetContext).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                      child: Text(
                        'Actions for ${requester.fullName}',
                        style: Theme.of(sheetContext).textTheme.bodyMedium
                            ?.copyWith(color: GhColors.inkSoft),
                      ),
                    ),
                    _MenuSheetActionTile(
                      icon: Icons.visibility_off_outlined,
                      label: 'Remove from view',
                      onTap: () => Navigator.of(
                        sheetContext,
                      ).pop(_CommunityRequestMenuAction.removeFromView),
                    ),
                    _MenuSheetActionTile(
                      icon: Icons.report_outlined,
                      label: 'Report account',
                      onTap: () => Navigator.of(
                        sheetContext,
                      ).pop(_CommunityRequestMenuAction.reportAccount),
                    ),
                    _MenuSheetActionTile(
                      icon: Icons.block_outlined,
                      label: 'Block account',
                      foregroundColor: GhColors.coral,
                      onTap: () => Navigator.of(
                        sheetContext,
                      ).pop(_CommunityRequestMenuAction.blockAccount),
                    ),
                  ],
                ),
              ),
            );
          },
        );

    if (!mounted || selectedAction == null) {
      return;
    }

    switch (selectedAction) {
      case _CommunityRequestMenuAction.removeFromView:
        final hidden = appState.hideRequestFromCurrentUser(request.id);
        showGhmeraSnackBar(
          context,
          message: hidden
              ? 'Request removed from your view.'
              : 'This request is already hidden.',
        );
        return;
      case _CommunityRequestMenuAction.reportAccount:
        await _showAccountReportSheet(
          reportedUser: requester,
          request: request,
        );
        return;
      case _CommunityRequestMenuAction.blockAccount:
        final blocked = appState.blockUserAccount(
          requester.id,
          requestId: request.id,
        );
        showGhmeraSnackBar(
          context,
          message: blocked
              ? 'Account blocked and request removed from your view.'
              : 'This account is already blocked.',
        );
        return;
    }
  }

  Future<void> _showMyRequestActions(HelpRequestEntity request) async {
    final selectedAction = await showModalBottomSheet<_MyRequestMenuAction>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(GhRadius.sheet),
        ),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SheetDragHandle(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 4, 4, 4),
                  child: Text(
                    request.displayTitle,
                    style: Theme.of(sheetContext).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                  child: Text(
                    'Request actions',
                    style: Theme.of(
                      sheetContext,
                    ).textTheme.bodyMedium?.copyWith(color: GhColors.inkSoft),
                  ),
                ),
                _MenuSheetActionTile(
                  icon: Icons.open_in_new_rounded,
                  label: 'View details',
                  onTap: () => Navigator.of(
                    sheetContext,
                  ).pop(_MyRequestMenuAction.viewDetails),
                ),
                _MenuSheetActionTile(
                  icon: Icons.edit_outlined,
                  label: 'Edit this request',
                  onTap: () => Navigator.of(
                    sheetContext,
                  ).pop(_MyRequestMenuAction.editThisRequest),
                ),
                _MenuSheetActionTile(
                  icon: Icons.visibility_off_outlined,
                  label: 'Hide this request',
                  onTap: () => Navigator.of(
                    sheetContext,
                  ).pop(_MyRequestMenuAction.hideThisRequest),
                ),
                _MenuSheetActionTile(
                  icon: Icons.delete_outline_rounded,
                  label: 'Delete this request',
                  foregroundColor: GhColors.coral,
                  onTap: () => Navigator.of(
                    sheetContext,
                  ).pop(_MyRequestMenuAction.deleteThisRequest),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted || selectedAction == null) {
      return;
    }

    final appState = context.read<GhmeraAppState>();
    switch (selectedAction) {
      case _MyRequestMenuAction.viewDetails:
        await _showRequestDetailsSheet(request);
        return;
      case _MyRequestMenuAction.editThisRequest:
        await _editRequest(request);
        return;
      case _MyRequestMenuAction.hideThisRequest:
        final hidden = appState.hideRequestFromCurrentUser(request.id);
        showGhmeraSnackBar(
          context,
          message: hidden
              ? 'Request hidden from your requests.'
              : 'This request is already hidden.',
        );
        return;
      case _MyRequestMenuAction.deleteThisRequest:
        final shouldDelete = await _confirmDeleteRequest(request);
        if (!mounted || !shouldDelete) {
          return;
        }

        final deleted = await appState.deleteMyHelpRequest(request.id);
        if (!mounted) {
          return;
        }

        showGhmeraSnackBar(
          context,
          message: deleted
              ? isCreditFreeRequest(request)
                    ? 'Request deleted.'
                    : 'Request deleted. Your held credit is available again.'
              : appState.lastWorkflowError ??
                    'This request could not be deleted.',
          type: deleted ? SnackBarType.success : SnackBarType.error,
        );
        return;
    }
  }

  Future<bool> _confirmDeleteRequest(HelpRequestEntity request) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete request'),
        content: Text(
          'Delete ${request.displayTitle}? This only works for requests that have not been accepted yet.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    return shouldDelete == true;
  }

  Future<void> _showAccountReportSheet({
    required UserEntity reportedUser,
    HelpRequestEntity? request,
  }) async {
    final submitted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(GhRadius.sheet),
        ),
      ),
      builder: (_) =>
          _AccountReportSheet(reportedUser: reportedUser, request: request),
    );

    if (submitted == true && mounted) {
      showGhmeraSnackBar(
        context,
        message: 'Account report submitted to moderators.',
      );
    }
  }

  Future<void> _showParticipantSafetyReportSheet({
    required HelpRequestEntity request,
    required UserEntity reportedUser,
  }) async {
    final submitted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(GhRadius.sheet),
        ),
      ),
      builder: (_) =>
          _SafetyReportSheet(request: request, reportedUser: reportedUser),
    );

    if (submitted == true && mounted) {
      showGhmeraSnackBar(
        context,
        message: 'Safety report submitted to moderators.',
      );
    }
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
  bool _showProtectedBanner = false;
  bool _hasShownProtectedBanner = false;
  bool _isSending = false;
  Timer? _bannerTimer;

  @override
  void initState() {
    super.initState();
    _messageController = TextEditingController();
  }

  @override
  void dispose() {
    _bannerTimer?.cancel();
    _messageController.dispose();
    super.dispose();
  }

  void _startBannerTimer() {
    _bannerTimer?.cancel();
    setState(() {
      _showProtectedBanner = true;
    });
    _bannerTimer = Timer(const Duration(seconds: 8), () {
      if (mounted) {
        setState(() {
          _showProtectedBanner = false;
        });
      }
    });
  }

  Future<void> _sendMessage(
    GhmeraAppState appState,
    MessageThreadEntity thread,
  ) async {
    final content = _messageController.text.trim();
    if (content.isEmpty || _isSending) {
      return;
    }

    setState(() {
      _isSending = true;
    });

    try {
      final sent = await appState.sendMessage(
        threadId: thread.id,
        content: content,
      );
      if (!mounted) {
        return;
      }

      if (!sent) {
        showGhmeraSnackBar(context, message: 'Message could not be sent.');
        return;
      }

      _messageController.clear();
      if (!_hasShownProtectedBanner) {
        _hasShownProtectedBanner = true;
        _startBannerTimer();
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  Future<void> _showMessageActionsSheet({
    required MessageEntity message,
    required bool isMe,
    required UserEntity? peer,
    required HelpRequestEntity request,
  }) async {
    final action = await showModalBottomSheet<_MessageAction>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(GhRadius.sheet),
        ),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SheetDragHandle(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 4, 4, 4),
                  child: Text(
                    message.content,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(sheetContext).textTheme.titleSmall
                        ?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: GhColors.brandDark,
                        ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                  child: Text(
                    isMe
                        ? 'Sent by you • ${_relativeTime(message.createdAt)}'
                        : 'From ${peer?.fullName ?? "Peer"} • ${_relativeTime(message.createdAt)}',
                    style: Theme.of(
                      sheetContext,
                    ).textTheme.bodySmall?.copyWith(color: GhColors.inkSoft),
                  ),
                ),
                _MenuSheetActionTile(
                  icon: Icons.copy_rounded,
                  label: 'Copy message text',
                  onTap: () =>
                      Navigator.of(sheetContext).pop(_MessageAction.copy),
                ),
                _MenuSheetActionTile(
                  icon: Icons.reply_rounded,
                  label: 'Reply to message',
                  onTap: () =>
                      Navigator.of(sheetContext).pop(_MessageAction.reply),
                ),
                if (isMe)
                  _MenuSheetActionTile(
                    icon: Icons.delete_outline_rounded,
                    label: 'Delete message',
                    foregroundColor: GhColors.coral,
                    onTap: () =>
                        Navigator.of(sheetContext).pop(_MessageAction.delete),
                  ),
                if (!isMe && peer != null)
                  _MenuSheetActionTile(
                    icon: Icons.report_outlined,
                    label: 'Report message / safety flag',
                    foregroundColor: GhColors.coral,
                    onTap: () =>
                        Navigator.of(sheetContext).pop(_MessageAction.report),
                  ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted || action == null) {
      return;
    }

    final appState = context.read<GhmeraAppState>();
    switch (action) {
      case _MessageAction.copy:
        await Clipboard.setData(ClipboardData(text: message.content));
        if (mounted) {
          showGhmeraSnackBar(
            context,
            message: 'Message text copied to clipboard.',
            type: SnackBarType.success,
          );
        }
        return;
      case _MessageAction.reply:
        _messageController.text = 'Replying to "${message.content}": ';
        _messageController.selection = TextSelection.fromPosition(
          TextPosition(offset: _messageController.text.length),
        );
        return;
      case _MessageAction.delete:
        final deleted = await appState.deleteMessage(
          threadId: message.threadId,
          messageId: message.id,
        );
        if (mounted) {
          showGhmeraSnackBar(
            context,
            message: deleted ? 'Message deleted.' : 'Could not delete message.',
            type: deleted ? SnackBarType.success : SnackBarType.error,
          );
        }
        return;
      case _MessageAction.report:
        if (peer != null) {
          final submitted = await showModalBottomSheet<bool>(
            context: context,
            isScrollControlled: true,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(GhRadius.sheet),
              ),
            ),
            builder: (_) =>
                _SafetyReportSheet(request: request, reportedUser: peer),
          );

          if (submitted == true && mounted) {
            showGhmeraSnackBar(
              context,
              message: 'Safety report submitted to moderators.',
            );
          }
        }
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<GhmeraAppState>(
      builder: (context, appState, _) {
        final thread =
            appState.messageThreads.firstWhereOrNull(
              (candidate) => candidate.id == widget.initialThread.id,
            ) ??
            widget.initialThread;
        final peer = appState.peerForThread(thread);
        final request = appState.requestById(thread.requestId);
        final messages = appState.messagesForThread(thread.id);
        final isMessagingBlocked = appState.isMessagingBlockedForThread(thread);
        final theme = Theme.of(context);

        return Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: false,
            centerTitle: false,
            titleSpacing: 0,
            leading: uniformBackButton(context),
            title: Row(
              children: [
                GhAvatar(
                  name: peer?.fullName ?? 'Conversation',
                  photo: peer?.profilePhoto,
                  size: 38,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        peer?.fullName ?? 'Conversation',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium,
                      ),
                      Text(
                        request.displayTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                tooltip: 'Safety info',
                onPressed: _startBannerTimer,
                icon: const Icon(Icons.shield_outlined),
              ),
              const SizedBox(width: 6),
            ],
          ),
          body: Column(
            children: [
              AnimatedSize(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                child: (_showProtectedBanner || isMessagingBlocked)
                    ? Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                        child: GhInfoBanner(
                          icon: isMessagingBlocked
                              ? Icons.block_rounded
                              : Icons.shield_outlined,
                          foreground: isMessagingBlocked
                              ? GhColors.coral
                              : GhColors.brandDark,
                          background: isMessagingBlocked
                              ? GhColors.coralSoft
                              : GhColors.brandSoft,
                          message: isMessagingBlocked
                              ? 'Messaging is disabled because one of the accounts in this conversation is blocked. You can still review the conversation history.'
                              : thread.messageRequestPending
                              ? 'This thread is still a message request. Contact details stay hidden until the match is accepted and both sides consent.'
                              : 'Protected chat is active. Contact sharing still requires explicit consent from both users.',
                          action: isMessagingBlocked
                              ? null
                              : TextButton(
                                  onPressed: () {
                                    _bannerTimer?.cancel();
                                    setState(() {
                                      _showProtectedBanner = false;
                                    });
                                  },
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    minimumSize: const Size(0, 28),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  child: const Text('Got it'),
                                ),
                        ),
                      )
                    : const SizedBox(width: double.infinity),
              ),
              Expanded(
                child: messages.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const GhIconBadge(
                                icon: Icons.waving_hand_outlined,
                                size: 56,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Say hello',
                                style: theme.textTheme.titleMedium,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Agree on a time and place here before sharing any contact details.',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: GhColors.inkSoft,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        reverse: true,
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final message = messages[messages.length - 1 - index];
                          final isMe =
                              message.senderId == appState.currentUserId;

                          return Align(
                            alignment: isMe
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: GestureDetector(
                              onLongPress: () => _showMessageActionsSheet(
                                message: message,
                                isMe: isMe,
                                peer: peer,
                                request: request,
                              ),
                              onTap: () => _showMessageActionsSheet(
                                message: message,
                                isMe: isMe,
                                peer: peer,
                                request: request,
                              ),
                              child: Container(
                                constraints: BoxConstraints(
                                  maxWidth:
                                      MediaQuery.sizeOf(context).width * 0.76,
                                ),
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.fromLTRB(
                                  14,
                                  10,
                                  14,
                                  8,
                                ),
                                decoration: BoxDecoration(
                                  color: isMe
                                      ? GhColors.brand
                                      : GhColors.surface,
                                  border: isMe
                                      ? null
                                      : Border.all(color: GhColors.line),
                                  borderRadius: BorderRadius.only(
                                    topLeft: const Radius.circular(20),
                                    topRight: const Radius.circular(20),
                                    bottomLeft: Radius.circular(isMe ? 20 : 6),
                                    bottomRight: Radius.circular(isMe ? 6 : 20),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: isMe
                                      ? CrossAxisAlignment.end
                                      : CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      message.content,
                                      style: theme.textTheme.bodyLarge
                                          ?.copyWith(
                                            color: isMe
                                                ? Colors.white
                                                : GhColors.ink,
                                            height: 1.35,
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _relativeTime(message.createdAt),
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            fontSize: 11,
                                            color: isMe
                                                ? Colors.white.withValues(
                                                    alpha: 0.7,
                                                  )
                                                : GhColors.inkFaint,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
              DecoratedBox(
                decoration: const BoxDecoration(
                  color: GhColors.surface,
                  border: Border(top: BorderSide(color: GhColors.line)),
                ),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _messageController,
                            enabled: !isMessagingBlocked,
                            minLines: 1,
                            maxLines: 4,
                            textCapitalization: TextCapitalization.sentences,
                            decoration: InputDecoration(
                              hintText: isMessagingBlocked
                                  ? 'Messaging is disabled'
                                  : 'Message ${peer?.fullName.split(' ').first ?? ''}'
                                        .trim(),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 12,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide: const BorderSide(
                                  color: GhColors.line,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide: const BorderSide(
                                  color: GhColors.line,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide: const BorderSide(
                                  color: GhColors.brand,
                                  width: 1.4,
                                ),
                              ),
                            ),
                            onSubmitted: (isMessagingBlocked || _isSending)
                                ? null
                                : (_) => _sendMessage(appState, thread),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filled(
                          tooltip: 'Send',
                          onPressed: (isMessagingBlocked || _isSending)
                              ? null
                              : () => _sendMessage(appState, thread),
                          style: IconButton.styleFrom(
                            backgroundColor: GhColors.brand,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: const Color(0xFFDCE4E2),
                            fixedSize: const Size(48, 48),
                          ),
                          icon: _isSending
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.arrow_upward_rounded),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
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

  Future<void> _handleStartRequestWork(
    BuildContext context,
    GhmeraAppState appState,
    HelpRequestEntity request,
  ) async {
    final started = await appState.startCurrentUserRequestWork(request.id);
    if (!context.mounted) {
      return;
    }

    showGhmeraSnackBar(
      context,
      message: started
          ? 'Request marked as in progress.'
          : 'This request could not be moved to in progress.',
    );
  }

  Future<void> _handleConfirmCompletion(
    BuildContext context,
    GhmeraAppState appState,
    HelpRequestEntity request,
  ) async {
    final shouldConfirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirm completion'),
        content: const Text(
          'Mark this request as complete from your side. The request closes after both participants confirm.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (shouldConfirm != true || !context.mounted) {
      return;
    }

    final confirmed = await appState.confirmCurrentUserRequestCompletion(
      request.id,
    );
    if (!context.mounted) {
      return;
    }

    final refreshedRequest = appState.requestById(request.id);
    final helpGiver = appState.helperForRequest(refreshedRequest);
    int? submittedRating;
    if (confirmed &&
        helpGiver != null &&
        refreshedRequest.requesterId == appState.currentUserId &&
        appState.canCurrentUserSubmitReviewForRequest(refreshedRequest)) {
      submittedRating = await _showHelpGiverRatingSheet(
        context,
        request: refreshedRequest,
        helpGiver: helpGiver,
      );
      if (!context.mounted) {
        return;
      }
    }

    final canReviewNow = appState.canCurrentUserSubmitReviewForRequest(
      refreshedRequest,
    );
    showGhmeraSnackBar(
      context,
      message: !confirmed
          ? 'Completion could not be updated.'
          : submittedRating != null
          ? refreshedRequest.status == HelpRequestStatus.completed
                ? 'Completion and your $submittedRating-star rating were saved. The request is now closed.'
                : 'Your completion confirmation and $submittedRating-star rating were saved. The request closes after the other participant confirms.'
          : refreshedRequest.status == HelpRequestStatus.completed
          ? 'Both participants confirmed completion. The request is now closed.'
          : canReviewNow
          ? refreshedRequest.requesterId == appState.currentUserId
                ? 'Your completion confirmation was saved. You can rate the help giver now.'
                : 'Your completion confirmation was saved. You can leave a review now.'
          : 'Your completion confirmation was saved.',
    );
  }

  Future<void> _openReviewSheet(
    BuildContext context, {
    required HelpRequestEntity request,
    required UserEntity reviewee,
  }) async {
    final appState = context.read<GhmeraAppState>();
    final useStarRatingSheet =
        request.requesterId == appState.currentUserId &&
        request.acceptedHelperId == reviewee.id;
    bool submitted;
    if (useStarRatingSheet) {
      submitted =
          await _showHelpGiverRatingSheet(
            context,
            request: request,
            helpGiver: reviewee,
          ) !=
          null;
    } else {
      submitted =
          await showModalBottomSheet<bool>(
            context: context,
            isScrollControlled: true,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(GhRadius.sheet),
              ),
            ),
            builder: (_) =>
                _ReviewSubmissionSheet(request: request, reviewee: reviewee),
          ) ==
          true;
    }

    if (submitted && context.mounted) {
      showGhmeraSnackBar(
        context,
        message: useStarRatingSheet
            ? 'Star rating submitted and saved to the help giver profile.'
            : 'Review submitted and saved to your profile metrics.',
        type: SnackBarType.success,
      );
    }
  }

  Future<int?> _showHelpGiverRatingSheet(
    BuildContext context, {
    required HelpRequestEntity request,
    required UserEntity helpGiver,
  }) {
    return showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(GhRadius.sheet),
        ),
      ),
      builder: (_) =>
          _HelpGiverRatingSheet(request: request, helpGiver: helpGiver),
    );
  }

  Future<void> _openSafetyReportSheet(
    BuildContext context, {
    required HelpRequestEntity request,
    required UserEntity reportedUser,
  }) async {
    final submitted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(GhRadius.sheet),
        ),
      ),
      builder: (_) =>
          _SafetyReportSheet(request: request, reportedUser: reportedUser),
    );

    if (submitted == true && context.mounted) {
      showGhmeraSnackBar(
        context,
        message: 'Safety report submitted to moderators.',
      );
    }
  }

  String _actionActorLabel({
    required GhmeraAppState appState,
    required UserEntity requester,
    required UserEntity? helper,
    required HelpActionLogEntry entry,
  }) {
    if (entry.actorId == appState.currentUserId) {
      return 'You';
    }
    if (entry.actorId == requester.id) {
      return requester.fullName;
    }
    if (helper != null && entry.actorId == helper.id) {
      return helper.fullName;
    }
    return 'System';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        centerTitle: false,
        titleSpacing: 0,
        leading: uniformBackButton(context),
        title: uniformAppBarTitle(context, title: 'Request details'),
      ),
      body: SafeArea(
        top: false,
        bottom: false,
        child: Consumer<GhmeraAppState>(
          builder: (context, appState, _) {
            final request =
                appState.findRequestById(initialRequest.id) ?? initialRequest;
            final requester = appState.userById(request.requesterId);
            final helper = appState.helperForRequest(request);
            final protectedThread = appState.threadForRequest(request.id);
            final helpingMatch = appState.helpingMatches.firstWhereOrNull(
              (candidate) => candidate.requestId == request.id,
            );
            final requesterMatch = appState.matchesForMyRequests
                .firstWhereOrNull(
                  (candidate) => candidate.requestId == request.id,
                );
            final activeMatch = helpingMatch ?? requesterMatch;
            final timelineEntries = request.actionLog.toList()
              ..sort(
                (first, second) => second.createdAt.compareTo(first.createdAt),
              );
            final isParticipant = appState.isCurrentUserParticipantForRequest(
              request,
            );
            final isRequester = request.requesterId == appState.currentUserId;
            final canOfferHelp = appState.canCurrentUserOfferHelp(request.id);
            final hasConfirmedCompletion = appState
                .hasCurrentUserConfirmedRequestCompletion(request);
            final hasSubmittedReview = appState
                .hasCurrentUserSubmittedReviewForRequest(request);
            final canSubmitReview = appState
                .canCurrentUserSubmitReviewForRequest(request);
            final requesterCanRateNow =
                isRequester && canSubmitReview && !hasSubmittedReview;
            final categoryStyle = GhCategoryStyle.of(request.category);
            final statusColor = ghStatusColor(request.status);
            final theme = Theme.of(context);

            final horizontalPadding = math.max(
              16.0,
              (MediaQuery.sizeOf(context).width - 760) / 2,
            );
            return ListView(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                4,
                horizontalPadding,
                28,
              ),
              children: [
                GhCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          GhIconBadge(
                            icon: categoryStyle.icon,
                            color: categoryStyle.color,
                            size: 46,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  request.category.label,
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    color: categoryStyle.color,
                                  ),
                                ),
                                Text(
                                  'Posted ${_relativeTime(request.createdAt)}',
                                  style: theme.textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          GhTag(
                            label: request.status.label,
                            foreground: statusColor,
                            background: statusColor.withValues(alpha: 0.12),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        request.displayTitle,
                        style: theme.textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        request.description,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: GhColors.inkSoft,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 6),
                      _DetailRow(
                        icon: Icons.place_outlined,
                        label: 'Location',
                        value: request.location,
                      ),
                      _DetailRow(
                        icon: Icons.schedule_rounded,
                        label: 'Preferred time',
                        value: request.preferredTime,
                      ),
                      _DetailRow(
                        icon: Icons.bolt_rounded,
                        label: 'Urgency',
                        value: request.urgency.label,
                        valueColor: ghUrgencyColor(request.urgency),
                      ),
                      if (request.attachmentLabel != null)
                        _DetailRow(
                          icon: Icons.attach_file_rounded,
                          label: 'Attachment',
                          value: request.attachmentLabel!,
                        ),
                      if (request.emotionalSupportMode ||
                          request.isHighRisk ||
                          request.safetyCheckInRequired) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            if (request.emotionalSupportMode)
                              const GhTag(
                                icon: Icons.favorite_rounded,
                                label: 'Emotional support',
                                foreground: GhColors.rose,
                                background: GhColors.roseSoft,
                              ),
                            if (request.isHighRisk)
                              const GhTag(
                                icon: Icons.shield_outlined,
                                label: 'Extra safety checks',
                                foreground: GhColors.amber,
                                background: GhColors.amberSoft,
                              ),
                            if (request.safetyCheckInRequired)
                              const GhTag(
                                icon: Icons.verified_user_outlined,
                                label: 'Safety check-in',
                                foreground: GhColors.sky,
                                background: GhColors.skySoft,
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                if (!isRequester)
                  _PersonStatsCard(
                    title: 'About the requester',
                    user: requester,
                    stats: appState.helpStatsForUser(requester.id),
                  )
                else if (helper != null)
                  _PersonStatsCard(
                    title: 'Your helper',
                    user: helper,
                    stats: appState.helpStatsForUser(helper.id),
                  ),
                if (isParticipant || canOfferHelp) ...[
                  const SizedBox(height: 14),
                  _RequestCreditNote(
                    request: request,
                    isRequester: isRequester,
                    requesterFirstName: requester.fullName.split(' ').first,
                    isCurrentUserHelper:
                        request.acceptedHelperId == appState.currentUserId,
                  ),
                ],
                if (request.isHighRisk) ...[
                  const SizedBox(height: 10),
                  const GhInfoBanner(
                    icon: Icons.health_and_safety_outlined,
                    foreground: GhColors.amber,
                    background: GhColors.amberSoft,
                    message:
                        'This request triggers stronger safety handling. Exact location and off-platform contact stay gated until trust and consent checks are complete.',
                  ),
                ],
                if (isParticipant && request.acceptedHelperId != null) ...[
                  const SizedBox(height: 22),
                  const GhSectionHeader(
                    title: 'Progress',
                    padding: EdgeInsets.fromLTRB(4, 0, 4, 10),
                  ),
                  GhCard(
                    shadow: false,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _ConfirmationRow(
                          label: isRequester
                              ? 'You confirmed help received'
                              : '${requester.fullName.split(' ').first} confirmed help received',
                          done: request.requesterCompletionConfirmed,
                        ),
                        const SizedBox(height: 10),
                        _ConfirmationRow(
                          label: isRequester
                              ? '${helper?.fullName.split(' ').first ?? 'Helper'} confirmed help given'
                              : 'You confirmed help given',
                          done: request.helperCompletionConfirmed,
                        ),
                        if (hasSubmittedReview) ...[
                          const SizedBox(height: 10),
                          const _ConfirmationRow(
                            label: 'Your review was submitted',
                            done: true,
                          ),
                        ],
                        const SizedBox(height: 12),
                        Text(
                          hasConfirmedCompletion
                              ? hasSubmittedReview
                                    ? request.status ==
                                              HelpRequestStatus.completed
                                          ? 'Your completion confirmation and rating are saved.'
                                          : 'Your confirmation and rating are saved. The request closes when the other person confirms too.'
                                    : requesterCanRateNow
                                    ? 'Your confirmation is saved. You can rate your helper now while the request waits for them to confirm.'
                                    : 'Your confirmation is saved. The request closes when the other person confirms too.'
                              : isRequester
                              ? 'When the help is done, confirm it below. You can rate your helper right after.'
                              : 'When the help is done, confirm it below. Reviews open once both of you confirm.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: GhColors.inkSoft,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (isParticipant && request.acceptedHelperId != null) ...[
                  const SizedBox(height: 22),
                  const GhSectionHeader(
                    title: 'Privacy',
                    padding: EdgeInsets.fromLTRB(4, 0, 4, 10),
                  ),
                  GhCard(
                    shadow: false,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _ConfirmationRow(
                          label:
                              '${requester.fullName.split(' ').first} ${request.contactConsentFromRequester ? 'shared' : 'has not shared'} contact details',
                          done: request.contactConsentFromRequester,
                        ),
                        if (helper != null) ...[
                          const SizedBox(height: 10),
                          _ConfirmationRow(
                            label:
                                '${helper.fullName.split(' ').first} ${request.contactConsentFromHelper ? 'shared' : 'has not shared'} contact details',
                            done: request.contactConsentFromHelper,
                          ),
                        ],
                        const SizedBox(height: 12),
                        Text(
                          protectedThread == null
                              ? 'Protected chat has not been created for this request yet.'
                              : 'Protected chat active · last message ${_relativeTime(protectedThread.lastMessageAt)}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: GhColors.inkSoft,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (activeMatch != null && activeMatch.reasons.isNotEmpty) ...[
                  const SizedBox(height: 22),
                  const GhSectionHeader(
                    title: 'Why you were matched',
                    padding: EdgeInsets.fromLTRB(4, 0, 4, 10),
                  ),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: activeMatch.reasons
                        .map(
                          (reason) => GhTag(
                            icon: Icons.check_rounded,
                            label: reason,
                            foreground: GhColors.brandDark,
                            background: GhColors.brandSoft,
                          ),
                        )
                        .toList(),
                  ),
                ],
                if (timelineEntries.isNotEmpty) ...[
                  const SizedBox(height: 22),
                  const GhSectionHeader(
                    title: 'Timeline',
                    padding: EdgeInsets.fromLTRB(4, 0, 4, 10),
                  ),
                  GhCard(
                    shadow: false,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
                    child: Column(
                      children: [
                        for (
                          var index = 0;
                          index < timelineEntries.length;
                          index++
                        )
                          _TimelineEntryRow(
                            title: timelineEntries[index].action,
                            caption:
                                '${_actionActorLabel(appState: appState, requester: requester, helper: helper, entry: timelineEntries[index])} · ${_relativeTime(timelineEntries[index].createdAt)}',
                            isFirst: index == 0,
                            isLast: index == timelineEntries.length - 1,
                          ),
                      ],
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
          final liveRequest = appState.findRequestById(initialRequest.id);
          final request = liveRequest ?? initialRequest;
          final protectedThread = appState.threadForRequest(request.id);
          final otherParticipant = appState.otherParticipantForRequest(request);
          final isParticipant = appState.isCurrentUserParticipantForRequest(
            request,
          );
          final chatLabel = otherParticipant == null
              ? 'Chat'
              : 'Chat with ${otherParticipant.fullName.split(' ').first}';
          final canStartRequest = appState.canCurrentUserStartRequest(request);
          final canConfirmCompletion = appState
              .canCurrentUserConfirmRequestCompletion(request);
          final canSubmitReview = appState.canCurrentUserSubmitReviewForRequest(
            request,
          );
          final isHelpGiverRating =
              request.requesterId == appState.currentUserId &&
              request.acceptedHelperId == otherParticipant?.id;
          final canOfferHelp = appState.canCurrentUserOfferHelp(request.id);
          final showChat =
              isParticipant &&
              (protectedThread != null || request.acceptedHelperId != null);
          final String? settledNotice;
          if (isParticipant) {
            settledNotice = null;
          } else if (liveRequest == null) {
            settledNotice = 'This request is no longer available.';
          } else if (request.acceptedHelperId != null) {
            settledNotice = 'Someone is already helping with this request.';
          } else if (!appState.isRequestOpenForHelp(request)) {
            settledNotice = 'This request is no longer open for help.';
          } else if (appState.currentUserNeedsVerificationToHelp(request)) {
            settledNotice =
                'This request needs extra safety checks, so only ID-verified or trusted helpers can take it.';
          } else {
            settledNotice = null;
          }

          return DecoratedBox(
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
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (settledNotice != null)
                          GhInfoBanner(
                            icon: Icons.volunteer_activism_outlined,
                            message: settledNotice,
                          ),
                        if (canOfferHelp || showChat)
                          Row(
                            children: [
                              if (showChat)
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () {
                                      if (protectedThread != null) {
                                        onOpenThread(protectedThread);
                                        return;
                                      }

                                      showGhmeraSnackBar(
                                        context,
                                        message: otherParticipant == null
                                            ? 'Chat opens after a helper match is confirmed.'
                                            : 'Chat with ${otherParticipant.fullName.split(' ').first} opens after the protected thread is ready.',
                                      );
                                    },
                                    icon: const Icon(
                                      Icons.chat_bubble_outline_rounded,
                                    ),
                                    label: Text(
                                      chatLabel,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              if (showChat && canOfferHelp)
                                const SizedBox(width: 10),
                              if (canOfferHelp)
                                Expanded(
                                  child: FilledButton.icon(
                                    onPressed: () async {
                                      if (!appState.canCurrentUserOfferHelp(
                                        request.id,
                                      )) {
                                        return;
                                      }
                                      final matched = await appState
                                          .volunteerForHelpRequest(request.id);
                                      if (!context.mounted) {
                                        return;
                                      }

                                      if (!matched) {
                                        showGhmeraSnackBar(
                                          context,
                                          message:
                                              appState.lastWorkflowError ??
                                              'This request is no longer available for matching.',
                                          type: SnackBarType.error,
                                        );
                                        return;
                                      }

                                      showGhmeraSnackBar(
                                        context,
                                        message:
                                            'You are now helping. Protected chat is open.',
                                        type: SnackBarType.success,
                                      );
                                    },
                                    icon: const Icon(
                                      Icons.volunteer_activism_rounded,
                                    ),
                                    label: const Text('I can help'),
                                  ),
                                ),
                            ],
                          ),
                        if (isParticipant &&
                            request.acceptedHelperId != null) ...[
                          if (canStartRequest) ...[
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: () => _handleStartRequestWork(
                                  context,
                                  appState,
                                  request,
                                ),
                                icon: const Icon(
                                  Icons.play_circle_outline_rounded,
                                ),
                                label: const Text('Mark help as in progress'),
                              ),
                            ),
                          ],
                          if (canConfirmCompletion) ...[
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: () => _handleConfirmCompletion(
                                  context,
                                  appState,
                                  request,
                                ),
                                icon: const Icon(Icons.task_alt_rounded),
                                label: Text(
                                  request.requesterId == appState.currentUserId
                                      ? 'Confirm help received'
                                      : 'Confirm help given',
                                ),
                              ),
                            ),
                          ],
                          if (canSubmitReview && otherParticipant != null) ...[
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.tonalIcon(
                                onPressed: () => _openReviewSheet(
                                  context,
                                  request: request,
                                  reviewee: otherParticipant,
                                ),
                                style: FilledButton.styleFrom(
                                  backgroundColor: GhColors.creditSoft,
                                  foregroundColor: GhColors.creditDeep,
                                ),
                                icon: Icon(
                                  isHelpGiverRating
                                      ? Icons.star_rate_rounded
                                      : Icons.rate_review_outlined,
                                ),
                                label: Text(
                                  isHelpGiverRating
                                      ? 'Rate ${otherParticipant.fullName.split(' ').first}'
                                      : 'Review ${otherParticipant.fullName.split(' ').first}',
                                ),
                              ),
                            ),
                          ],
                        ],
                        if (otherParticipant != null)
                          TextButton.icon(
                            onPressed: () => _openSafetyReportSheet(
                              context,
                              request: request,
                              reportedUser: otherParticipant,
                            ),
                            style: TextButton.styleFrom(
                              foregroundColor: GhColors.coral,
                            ),
                            icon: const Icon(Icons.flag_outlined, size: 18),
                            label: Text(
                              'Report ${otherParticipant.fullName.split(' ').first}',
                            ),
                          ),
                        if (settledNotice == null &&
                            !canOfferHelp &&
                            !showChat &&
                            otherParticipant == null)
                          Text(
                            request.requesterId == appState.currentUserId
                                ? 'Chat unlocks as soon as someone offers to help.'
                                : 'This request is no longer open.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: GhColors.inkSoft),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (value.trim().isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: GhColors.inkFaint),
          const SizedBox(width: 12),
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: GhColors.inkSoft,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: valueColor ?? GhColors.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PersonStatsCard extends StatelessWidget {
  const _PersonStatsCard({
    required this.title,
    required this.user,
    required this.stats,
  });

  final String title;
  final UserEntity user;
  final UserHelpStats stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isVerified = user.idVerified || user.trustedHelper;
    return GhCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: theme.textTheme.labelMedium?.copyWith(
              color: GhColors.inkFaint,
              letterSpacing: 1.1,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              GhAvatar(
                name: user.fullName,
                photo: user.profilePhoto,
                size: 52,
                showVerified: isVerified,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.fullName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        GhRatingStars(rating: stats.averageRating, size: 16),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            stats.reviewCount == 0
                                ? 'No ratings yet'
                                : '${stats.averageRating.toStringAsFixed(1)} · ${stats.reviewCount} ${stats.reviewCount == 1 ? 'rating' : 'ratings'}',
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          GhHelpStatsStrip(stats: stats, compact: false),
          const SizedBox(height: 14),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              GhTag(
                icon: stats.helpsGiven >= stats.helpsReceived
                    ? Icons.trending_up_rounded
                    : Icons.balance_rounded,
                label: stats.giveBackLabel,
                foreground: GhColors.brandDark,
                background: GhColors.brandSoft,
              ),
              for (final badge in user.verificationBadges)
                GhTag(
                  icon: Icons.verified_outlined,
                  label: badge.label,
                  foreground: GhColors.sky,
                  background: GhColors.skySoft,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RequestCreditNote extends StatelessWidget {
  const _RequestCreditNote({
    required this.request,
    required this.isRequester,
    required this.isCurrentUserHelper,
    required this.requesterFirstName,
  });

  final HelpRequestEntity request;
  final bool isRequester;
  final bool isCurrentUserHelper;
  final String requesterFirstName;

  @override
  Widget build(BuildContext context) {
    final completed = request.status == HelpRequestStatus.completed;
    final canceled = request.status == HelpRequestStatus.canceled;
    final String message;
    if (isCreditFreeRequest(request)) {
      message = 'Emergency requests are free. No credits are used.';
    } else if (isRequester) {
      message = completed
          ? '${creditCountLabel(requestCreditCost)} was used when this help was completed.'
          : canceled
          ? 'This request was canceled, so your held credit was returned to you.'
          : '${creditCountLabel(requestCreditCost)} is on hold for this request. It is used once you confirm the help is done, or returned if you cancel.';
    } else if (isCurrentUserHelper) {
      message = completed
          ? 'You earned $helpEarnedCredits credit for this help. Thank you!'
          : 'You will earn $helpEarnedCredits credit once you and $requesterFirstName both confirm the help is done.';
    } else {
      message =
          'Help $requesterFirstName and earn $helpEarnedCredits credit once you both confirm the help is done.';
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: GhColors.creditSoft,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const GhCoin(size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
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

class _ConfirmationRow extends StatelessWidget {
  const _ConfirmationRow({required this.label, required this.done});

  final String label;
  final bool done;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          done ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
          size: 22,
          color: done ? GhColors.brand : const Color(0xFFC3CECB),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: done ? GhColors.ink : GhColors.inkSoft,
            ),
          ),
        ),
      ],
    );
  }
}

class _TimelineEntryRow extends StatelessWidget {
  const _TimelineEntryRow({
    required this.title,
    required this.caption,
    required this.isFirst,
    required this.isLast,
  });

  final String title;
  final String caption;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 20,
            child: Column(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  margin: const EdgeInsets.only(top: 4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isFirst ? GhColors.brand : GhColors.surface,
                    border: Border.all(
                      color: isFirst ? GhColors.brand : const Color(0xFFC3CECB),
                      width: 2,
                    ),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 2),
                      color: GhColors.line,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.titleSmall),
                  const SizedBox(height: 2),
                  Text(caption, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewSubmissionSheet extends StatefulWidget {
  const _ReviewSubmissionSheet({required this.request, required this.reviewee});

  final HelpRequestEntity request;
  final UserEntity reviewee;

  @override
  State<_ReviewSubmissionSheet> createState() => _ReviewSubmissionSheetState();
}

class _ReviewSubmissionSheetState extends State<_ReviewSubmissionSheet> {
  late final TextEditingController _feedbackController;
  int _helpfulness = 5;
  int _respectfulness = 5;
  int _safety = 5;
  int _reliability = 5;
  int _accuracy = 5;

  @override
  void initState() {
    super.initState();
    _feedbackController = TextEditingController();
  }

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, bottomInset + 16),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Review ${widget.reviewee.fullName}',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'These scores update trust and review metrics immediately.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: GhColors.inkSoft,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 16),
            _RatingDropdown(
              label: 'Helpfulness',
              value: _helpfulness,
              onChanged: (value) => setState(() => _helpfulness = value),
            ),
            const SizedBox(height: 10),
            _RatingDropdown(
              label: 'Respectfulness',
              value: _respectfulness,
              onChanged: (value) => setState(() => _respectfulness = value),
            ),
            const SizedBox(height: 10),
            _RatingDropdown(
              label: 'Safety',
              value: _safety,
              onChanged: (value) => setState(() => _safety = value),
            ),
            const SizedBox(height: 10),
            _RatingDropdown(
              label: 'Reliability',
              value: _reliability,
              onChanged: (value) => setState(() => _reliability = value),
            ),
            const SizedBox(height: 10),
            _RatingDropdown(
              label: 'Accuracy',
              value: _accuracy,
              onChanged: (value) => setState(() => _accuracy = value),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _feedbackController,
              minLines: 3,
              maxLines: 5,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Feedback',
                hintText: 'Share what went well or what needs attention.',
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () async {
                  final review = await context
                      .read<GhmeraAppState>()
                      .submitReviewForRequest(
                        requestId: widget.request.id,
                        helpfulness: _helpfulness,
                        respectfulness: _respectfulness,
                        safety: _safety,
                        reliability: _reliability,
                        accuracy: _accuracy,
                        feedback: _feedbackController.text,
                      );
                  if (!context.mounted) {
                    return;
                  }

                  if (review == null) {
                    showGhmeraSnackBar(
                      context,
                      message: 'Review could not be submitted.',
                    );
                    return;
                  }

                  Navigator.of(context).pop(true);
                },
                icon: const Icon(Icons.save_outlined),
                label: const Text('Submit review'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HelpGiverRatingSheet extends StatefulWidget {
  const _HelpGiverRatingSheet({required this.request, required this.helpGiver});

  final HelpRequestEntity request;
  final UserEntity helpGiver;

  @override
  State<_HelpGiverRatingSheet> createState() => _HelpGiverRatingSheetState();
}

class _HelpGiverRatingSheetState extends State<_HelpGiverRatingSheet> {
  int _selectedRating = 0;
  bool _isSubmitting = false;

  Future<void> _submitRating() async {
    if (_selectedRating == 0 || _isSubmitting) {
      return;
    }

    setState(() => _isSubmitting = true);
    final review = await context.read<GhmeraAppState>().submitReviewForRequest(
      requestId: widget.request.id,
      helpfulness: _selectedRating,
      respectfulness: _selectedRating,
      safety: _selectedRating,
      reliability: _selectedRating,
      accuracy: _selectedRating,
      feedback:
          'Rated ${widget.helpGiver.fullName} $_selectedRating out of 5 stars after the help was fulfilled.',
    );
    if (!mounted) {
      return;
    }

    setState(() => _isSubmitting = false);
    if (review == null) {
      showGhmeraSnackBar(context, message: 'Star rating could not be saved.');
      return;
    }

    Navigator.of(context).pop(_selectedRating);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final firstName = widget.helpGiver.fullName.trim().split(' ').first;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, bottomInset + 16),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Rate $firstName',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'Select up to 5 stars for the help giver. This rating updates their average review immediately.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: GhColors.inkSoft,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List<Widget>.generate(5, (index) {
                final starValue = index + 1;
                final isSelected = starValue <= _selectedRating;
                return IconButton(
                  onPressed: _isSubmitting
                      ? null
                      : () => setState(() => _selectedRating = starValue),
                  iconSize: 38,
                  tooltip: 'Rate $starValue out of 5',
                  icon: Icon(
                    isSelected ? Icons.star_rounded : Icons.star_border_rounded,
                    color: isSelected
                        ? const Color(0xFFF2B33D)
                        : const Color(0xFFC8D0CE),
                  ),
                );
              }),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                _selectedRating == 0
                    ? 'Tap a star to save the rating.'
                    : '$_selectedRating / 5 stars selected',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: GhColors.inkSoft),
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _selectedRating == 0 || _isSubmitting
                    ? null
                    : _submitRating,
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.star_outline_rounded),
                label: Text(
                  _isSubmitting ? 'Saving rating...' : 'Save star rating',
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: _isSubmitting
                    ? null
                    : () => Navigator.of(context).pop(),
                child: const Text('Not now'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountReportSheet extends StatefulWidget {
  const _AccountReportSheet({required this.reportedUser, this.request});

  final UserEntity reportedUser;
  final HelpRequestEntity? request;

  @override
  State<_AccountReportSheet> createState() => _AccountReportSheetState();
}

class _AccountReportSheetState extends State<_AccountReportSheet> {
  static const List<String> _reasons = <String>[
    'Safety concern',
    'Harassment',
    'Spam',
    'Fraud or deception',
    'Suspicious behavior',
    'Other',
  ];

  late final TextEditingController _detailsController;
  String _selectedReason = _reasons.first;

  @override
  void initState() {
    super.initState();
    _detailsController = TextEditingController();
  }

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, bottomInset + 16),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Report ${widget.reportedUser.fullName}',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              widget.request == null
                  ? 'This sends an account report to moderators.'
                  : 'This sends an account report linked to ${widget.request!.displayTitle}.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: GhColors.inkSoft,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _selectedReason,
              decoration: const InputDecoration(labelText: 'Reason'),
              items: _reasons
                  .map(
                    (reason) => DropdownMenuItem<String>(
                      value: reason,
                      child: Text(reason),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null) {
                  return;
                }
                setState(() => _selectedReason = value);
              },
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _detailsController,
              minLines: 3,
              maxLines: 5,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Details',
                hintText:
                    'Describe what happened and what moderators should review.',
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () async {
                  final report = await context
                      .read<GhmeraAppState>()
                      .reportUserAccount(
                        userId: widget.reportedUser.id,
                        reason: _selectedReason,
                        details: _detailsController.text,
                        requestId: widget.request?.id,
                      );
                  if (!context.mounted) {
                    return;
                  }

                  if (report == null) {
                    showGhmeraSnackBar(
                      context,
                      message: 'Account report could not be submitted.',
                    );
                    return;
                  }

                  Navigator.of(context).pop(true);
                },
                icon: const Icon(Icons.report_outlined),
                label: const Text('Submit account report'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SafetyReportSheet extends StatefulWidget {
  const _SafetyReportSheet({required this.request, required this.reportedUser});

  final HelpRequestEntity request;
  final UserEntity reportedUser;

  @override
  State<_SafetyReportSheet> createState() => _SafetyReportSheetState();
}

class _SafetyReportSheetState extends State<_SafetyReportSheet> {
  static const List<String> _reasons = <String>[
    'Safety concern',
    'Harassment',
    'Pressure to move off-platform',
    'Fraud or deception',
    'Spam',
    'Other',
  ];

  late final TextEditingController _detailsController;
  String _selectedReason = _reasons.first;

  @override
  void initState() {
    super.initState();
    _detailsController = TextEditingController();
  }

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, bottomInset + 16),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Report ${widget.reportedUser.fullName}',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'This creates a moderator-visible safety report and updates safety signals immediately.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: GhColors.inkSoft,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _selectedReason,
              decoration: const InputDecoration(labelText: 'Reason'),
              items: _reasons
                  .map(
                    (reason) => DropdownMenuItem<String>(
                      value: reason,
                      child: Text(reason),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null) {
                  return;
                }
                setState(() => _selectedReason = value);
              },
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _detailsController,
              minLines: 3,
              maxLines: 5,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Details',
                hintText: 'Describe what happened and any immediate risk.',
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () async {
                  final report = await context
                      .read<GhmeraAppState>()
                      .submitParticipantSafetyReportForRequest(
                        requestId: widget.request.id,
                        reason: _selectedReason,
                        details: _detailsController.text,
                      );
                  if (!context.mounted) {
                    return;
                  }

                  if (report == null) {
                    showGhmeraSnackBar(
                      context,
                      message: 'Safety report could not be submitted.',
                    );
                    return;
                  }

                  Navigator.of(context).pop(true);
                },
                icon: const Icon(Icons.report_outlined),
                label: const Text('Submit safety report'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RatingDropdown extends StatelessWidget {
  const _RatingDropdown({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<int>(
      initialValue: value,
      decoration: InputDecoration(labelText: label),
      items: List<DropdownMenuItem<int>>.generate(5, (index) {
        final score = index + 1;
        return DropdownMenuItem<int>(value: score, child: Text('$score / 5'));
      }),
      onChanged: (selected) {
        if (selected == null) {
          return;
        }
        onChanged(selected);
      },
    );
  }
}

class _NotificationsScreen extends StatelessWidget {
  const _NotificationsScreen();

  Future<void> _confirmClearAllNotifications(
    BuildContext context,
    GhmeraAppState appState,
  ) async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(GhRadius.sheet),
        ),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SheetDragHandle(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 4, 4, 4),
                  child: Text(
                    'Clear all notifications?',
                    style: Theme.of(sheetContext).textTheme.titleSmall
                        ?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: GhColors.brandDark,
                        ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
                  child: Text(
                    'This will remove all notifications from your list. This action cannot be undone.',
                    style: Theme.of(
                      sheetContext,
                    ).textTheme.bodySmall?.copyWith(color: GhColors.inkSoft),
                  ),
                ),
                _MenuSheetActionTile(
                  icon: Icons.delete_sweep_outlined,
                  label: 'Clear all notifications',
                  foregroundColor: GhColors.coral,
                  onTap: () => Navigator.of(sheetContext).pop(true),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (confirmed == true && context.mounted) {
      appState.clearAllCurrentNotifications();
      showGhmeraSnackBar(
        context,
        message: 'All notifications cleared.',
        type: SnackBarType.success,
      );
    }
  }

  Future<void> _showNotificationActionsSheet(
    BuildContext context,
    GhmeraAppState appState,
    NotificationEntity notification,
  ) async {
    final action = await showModalBottomSheet<_NotificationAction>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(GhRadius.sheet),
        ),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SheetDragHandle(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 4, 4, 4),
                  child: Text(
                    notification.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(sheetContext).textTheme.titleSmall
                        ?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: GhColors.brandDark,
                        ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                  child: Text(
                    'Received ${_relativeTime(notification.createdAt)}',
                    style: Theme.of(
                      sheetContext,
                    ).textTheme.bodySmall?.copyWith(color: GhColors.inkSoft),
                  ),
                ),
                if (!notification.isRead)
                  _MenuSheetActionTile(
                    icon: Icons.mark_email_read_outlined,
                    label: 'Mark as read',
                    onTap: () => Navigator.of(
                      sheetContext,
                    ).pop(_NotificationAction.markAsRead),
                  )
                else
                  _MenuSheetActionTile(
                    icon: Icons.mark_email_unread_outlined,
                    label: 'Mark as unread',
                    onTap: () => Navigator.of(
                      sheetContext,
                    ).pop(_NotificationAction.markAsUnread),
                  ),
                _MenuSheetActionTile(
                  icon: Icons.delete_outline_rounded,
                  label: 'Delete notification',
                  foregroundColor: GhColors.coral,
                  onTap: () => Navigator.of(
                    sheetContext,
                  ).pop(_NotificationAction.delete),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (action == null || !context.mounted) {
      return;
    }

    switch (action) {
      case _NotificationAction.markAsRead:
        appState.markNotificationRead(notification.id);
        return;
      case _NotificationAction.markAsUnread:
        appState.markNotificationUnread(notification.id);
        return;
      case _NotificationAction.delete:
        appState.deleteNotification(notification.id);
        showGhmeraSnackBar(
          context,
          message: 'Notification deleted.',
          type: SnackBarType.success,
        );
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<GhmeraAppState>(
      builder: (context, appState, _) {
        final notifications = appState.currentNotifications;

        return Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: false,
            centerTitle: false,
            titleSpacing: 0,
            leading: uniformBackButton(context),
            title: uniformAppBarTitle(
              context,
              title: 'Notifications',
              subtitle: notifications.isEmpty
                  ? 'You are all caught up.'
                  : '${notifications.length} ${notifications.length == 1 ? 'update' : 'updates'}',
            ),
            actions: [
              if (notifications.isNotEmpty)
                IconButton(
                  tooltip: 'Clear all notifications',
                  onPressed: () =>
                      _confirmClearAllNotifications(context, appState),
                  icon: const Icon(Icons.delete_sweep_outlined),
                ),
              const SizedBox(width: 6),
            ],
          ),
          body: SafeArea(
            top: false,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
              children: [
                if (notifications.isEmpty)
                  const GhEmptyState(
                    icon: Icons.notifications_none_rounded,
                    title: 'No notifications yet',
                    message:
                        'Matches, messages, credits, and safety updates will appear here.',
                  )
                else
                  for (final notification in notifications)
                    _NotificationCard(
                      notification: notification,
                      onTap: () => _showNotificationActionsSheet(
                        context,
                        appState,
                        notification,
                      ),
                    ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({
    required this.onReviewOpportunity,
    required this.onRequestLongPress,
  });

  final ValueChanged<HelpRequestEntity> onReviewOpportunity;
  final ValueChanged<HelpRequestEntity> onRequestLongPress;

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<GhmeraAppState>();
    final allHelpRequests = appState.requestsNeedingMyHelp;
    final acceptedRequests = allHelpRequests
        .where((request) => request.acceptedHelperId == appState.currentUserId)
        .toList();
    final pendingHelpRequests = allHelpRequests
        .where((request) => request.acceptedHelperId == null)
        .toList();
    final requestLocationEntries = pendingHelpRequests
        .map((request) {
          final requester = appState.otherParticipantForRequest(request);
          if (requester == null) {
            return null;
          }

          return _RequestLocationEntry(request: request, requester: requester);
        })
        .whereType<_RequestLocationEntry>()
        .toList();
    final credits = appState.currentUserCredits;
    final myStats = appState.helpStatsForUser(appState.currentUserId);

    return RefreshIndicator(
      onRefresh: () => context.read<GhmeraAppState>().refreshHelpRequests(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          _GiveHelpHero(
            waitingCount: pendingHelpRequests.length,
            availableCredits: credits.available,
            helpsGiven: myStats.helpsGiven,
            onTapCredits: () => showHelpCreditsSheet(context),
          ),
          if (acceptedRequests.isNotEmpty) ...[
            const SizedBox(height: 22),
            GhSectionHeader(
              title: 'You are helping',
              subtitle: 'People counting on you right now.',
              count: acceptedRequests.length,
            ),
            for (final request in acceptedRequests)
              _CommunityRequestCard(
                request: request,
                isAcceptedByMe: true,
                onTap: () => onReviewOpportunity(request),
                onLongPress: () => onRequestLongPress(request),
              ),
          ],
          const SizedBox(height: 22),
          GhSectionHeader(
            title: 'People who need help',
            subtitle: pendingHelpRequests.isEmpty
                ? null
                : 'Tap a request to see who is asking.',
            count: pendingHelpRequests.isEmpty
                ? null
                : pendingHelpRequests.length,
            trailing: OutlinedButton.icon(
              onPressed: () => _showRequestLocationsMapSheet(
                context,
                currentUser: appState.currentUser,
                requestEntries: requestLocationEntries,
              ),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 38),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                textStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              icon: const Icon(Icons.map_outlined, size: 18),
              label: const Text('Map'),
            ),
          ),
          if (pendingHelpRequests.isEmpty)
            const GhEmptyState(
              icon: Icons.spa_outlined,
              title: 'All caught up',
              message:
                  'No one nearby needs help right now. New requests that match what you offer will appear here.',
            )
          else
            for (final request in pendingHelpRequests)
              _CommunityRequestCard(
                request: request,
                onTap: () => onReviewOpportunity(request),
                onLongPress: () => onRequestLongPress(request),
              ),
        ],
      ),
    );
  }

  Future<void> _showRequestLocationsMapSheet(
    BuildContext context, {
    required UserEntity currentUser,
    required List<_RequestLocationEntry> requestEntries,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      clipBehavior: Clip.antiAlias,
      backgroundColor: Theme.of(context).colorScheme.surface,
      enableDrag: false,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.78,
        minChildSize: 0.35,
        maxChildSize: 1.0,
        shouldCloseOnMinExtent: true,
        builder: (context, scrollController) => _RequestLocationsMapSheet(
          currentUser: currentUser,
          requestEntries: requestEntries,
          onSelectRequest: onReviewOpportunity,
          scrollController: scrollController,
        ),
      ),
    );
  }
}

class _GiveHelpHero extends StatelessWidget {
  const _GiveHelpHero({
    required this.waitingCount,
    required this.availableCredits,
    required this.helpsGiven,
    required this.onTapCredits,
  });

  final int waitingCount;
  final int availableCredits;
  final int helpsGiven;
  final VoidCallback onTapCredits;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final headline = waitingCount == 0
        ? 'Your community is doing well'
        : waitingCount == 1
        ? '1 person needs a hand'
        : '$waitingCount people need a hand';

    return Container(
      decoration: BoxDecoration(
        gradient: ghBrandGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x330F6B5C),
            blurRadius: 28,
            offset: Offset(0, 14),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 18, 16, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  headline,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    height: 1.2,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              GhCreditChip(
                credits: availableCredits < 0 ? 0 : availableCredits,
                onTap: onTapCredits,
                onDark: true,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Every help you complete earns you $helpEarnedCredits credit to use when you need support.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _HeroStat(
                icon: Icons.volunteer_activism_rounded,
                value: '$helpsGiven',
                label: helpsGiven == 1 ? 'person helped' : 'people helped',
              ),
              const SizedBox(width: 10),
              _HeroStat(
                icon: Icons.add_circle_outline_rounded,
                value: '+$helpEarnedCredits',
                label: 'credit per help',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(icon, color: GhColors.mint, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.75),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CommunityRequestCard extends StatelessWidget {
  const _CommunityRequestCard({
    required this.request,
    required this.onTap,
    required this.onLongPress,
    this.isAcceptedByMe = false,
  });

  final HelpRequestEntity request;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final bool isAcceptedByMe;

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<GhmeraAppState>();
    final requester = appState.userById(request.requesterId);
    final stats = appState.helpStatsForUser(requester.id);
    final theme = Theme.of(context);
    final categoryStyle = GhCategoryStyle.of(request.category);
    final urgencyColor = ghUrgencyColor(request.urgency);
    final statusColor = ghStatusColor(request.status);
    final location = request.location.trim();

    return GhCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      onTap: onTap,
      onLongPress: onLongPress,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GhAvatar(
                name: requester.fullName,
                photo: requester.profilePhoto,
                size: 44,
                showVerified: requester.idVerified || requester.trustedHelper,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      requester.fullName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        if (location.isNotEmpty) location,
                        _relativeTime(request.createdAt),
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              isAcceptedByMe
                  ? GhTag(
                      dense: true,
                      label: request.status.label,
                      foreground: statusColor,
                      background: statusColor.withValues(alpha: 0.12),
                    )
                  : GhTag(
                      dense: true,
                      icon: Icons.bolt_rounded,
                      label: request.urgency.label,
                      foreground: urgencyColor,
                      background: urgencyColor.withValues(alpha: 0.12),
                    ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GhIconBadge(
                icon: categoryStyle.icon,
                color: categoryStyle.color,
                size: 40,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.category.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: categoryStyle.color,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      request.displayTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium,
                    ),
                    if (request.description.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        request.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: GhColors.inkSoft,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          GhHelpStatsStrip(stats: stats),
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 10),
          Row(
            children: [
              if (request.isHighRisk)
                const GhTag(
                  dense: true,
                  icon: Icons.shield_outlined,
                  label: 'Safety checks',
                  foreground: GhColors.amber,
                  background: GhColors.amberSoft,
                )
              else if (request.emotionalSupportMode)
                const GhTag(
                  dense: true,
                  icon: Icons.favorite_rounded,
                  label: 'Listener needed',
                  foreground: GhColors.rose,
                  background: GhColors.roseSoft,
                )
              else
                Text(
                  isAcceptedByMe ? 'Open to continue' : 'View details',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: GhColors.brand,
                  ),
                ),
              const Spacer(),
              const GhCoin(size: 18),
              const SizedBox(width: 4),
              Text(
                isAcceptedByMe
                    ? 'Earn +$helpEarnedCredits'
                    : '+$helpEarnedCredits credit',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: GhColors.creditDeep,
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: GhColors.inkFaint),
            ],
          ),
        ],
      ),
    );
  }
}

class _RequestsTab extends StatelessWidget {
  const _RequestsTab({
    required this.onCreateRequest,
    required this.onLongPressMyRequest,
    required this.onManageAcceptedRequest,
    required this.onOpenRequest,
    required this.onDirectRequestHelper,
    required this.onFindPeopleToHelp,
  });

  final VoidCallback onCreateRequest;
  final ValueChanged<HelpRequestEntity> onLongPressMyRequest;
  final ValueChanged<HelpRequestEntity> onManageAcceptedRequest;
  final ValueChanged<HelpRequestEntity> onOpenRequest;
  final ValueChanged<UserEntity> onDirectRequestHelper;
  final VoidCallback onFindPeopleToHelp;

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<GhmeraAppState>();
    final currentUser = appState.currentUser;
    final nearbyHelpers = _nearbyHelpers(appState);
    final credits = appState.currentUserCredits;
    final myRequests = appState.myRequests.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final matchedRequests = myRequests
        .where(
          (request) =>
              request.acceptedHelperId != null &&
              request.status != HelpRequestStatus.canceled &&
              request.status != HelpRequestStatus.completed,
        )
        .toList();
    final waitingRequests = myRequests
        .where(
          (request) =>
              request.acceptedHelperId == null &&
              request.status != HelpRequestStatus.canceled &&
              request.status != HelpRequestStatus.completed,
        )
        .toList();
    final completedRequests = myRequests
        .where((request) => request.status == HelpRequestStatus.completed)
        .toList();
    final outOfCredits =
        !credits.canAffordRequest && !currentUser.canBypassReciprocity;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            children: [
              CreditWalletCard(
                summary: credits,
                message: appState.creditMessage,
                action: outOfCredits
                    ? FilledButton.icon(
                        onPressed: onFindPeopleToHelp,
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: GhColors.brandDark,
                          minimumSize: const Size(double.infinity, 48),
                        ),
                        icon: const Icon(Icons.volunteer_activism_rounded),
                        label: const Text('Find someone to help'),
                      )
                    : null,
              ),
              const SizedBox(height: 22),
              GhSectionHeader(
                title: 'Matched with a helper',
                count: matchedRequests.isEmpty ? null : matchedRequests.length,
              ),
              if (matchedRequests.isEmpty)
                const GhEmptyState(
                  icon: Icons.handshake_outlined,
                  title: 'No helpers yet',
                  message:
                      'When someone offers to help with one of your requests, they will appear here.',
                )
              else
                for (final request in matchedRequests)
                  if (appState.helperForRequest(request) case final helper?)
                    _MatchedRequestCard(
                      request: request,
                      helper: helper,
                      onTap: () => onOpenRequest(request),
                      onMore: () => onManageAcceptedRequest(request),
                    ),
              const SizedBox(height: 22),
              GhSectionHeader(
                title: 'Waiting for a helper',
                subtitle: waitingRequests.isEmpty
                    ? null
                    : 'Each open request keeps ${creditCountLabel(requestCreditCost)} on hold.',
                count: waitingRequests.isEmpty ? null : waitingRequests.length,
              ),
              if (waitingRequests.isEmpty)
                GhEmptyState(
                  icon: Icons.campaign_outlined,
                  title: 'No open requests',
                  message:
                      'Post what you need and nearby helpers who offer that kind of help will be notified.',
                  actionLabel: outOfCredits ? null : 'Ask for help',
                  onAction: outOfCredits ? null : onCreateRequest,
                )
              else
                for (final request in waitingRequests)
                  _MyRequestCard(
                    request: request,
                    onTap: () => onLongPressMyRequest(request),
                  ),
              if (completedRequests.isNotEmpty) ...[
                const SizedBox(height: 22),
                GhSectionHeader(
                  title: 'Completed',
                  count: completedRequests.length,
                ),
                for (final request in completedRequests)
                  if (appState.helperForRequest(request) case final helper?)
                    _MatchedRequestCard(
                      request: request,
                      helper: helper,
                      onTap: () => onOpenRequest(request),
                    ),
              ],
            ],
          ),
        ),
        DecoratedBox(
          decoration: const BoxDecoration(
            color: GhColors.surface,
            border: Border(top: BorderSide(color: GhColors.line)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: FilledButton.icon(
                    onPressed: onCreateRequest,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('New request'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: OutlinedButton.icon(
                    onPressed: () => _showNeighborhoodHelpersMapSheet(
                      context,
                      currentUser: currentUser,
                      helpers: nearbyHelpers,
                      onSelectHelper: onDirectRequestHelper,
                    ),
                    icon: const Icon(Icons.near_me_outlined),
                    label: const Text('Nearby'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showNeighborhoodHelpersMapSheet(
    BuildContext context, {
    required UserEntity currentUser,
    required List<UserEntity> helpers,
    required ValueChanged<UserEntity> onSelectHelper,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      clipBehavior: Clip.antiAlias,
      backgroundColor: Theme.of(context).colorScheme.surface,
      enableDrag: false,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.78,
        minChildSize: 0.35,
        maxChildSize: 1.0,
        shouldCloseOnMinExtent: true,
        builder: (context, scrollController) => _NeighborhoodHelpersMapSheet(
          currentUser: currentUser,
          helpers: helpers,
          onSelectHelper: onSelectHelper,
          scrollController: scrollController,
        ),
      ),
    );
  }

  List<UserEntity> _nearbyHelpers(GhmeraAppState appState) {
    final currentUser = appState.currentUser;
    if (!_hasApproximateLocation(currentUser)) {
      return const <UserEntity>[];
    }

    final helperById = <String, UserEntity>{};
    for (final request in appState.myOpenRequests) {
      for (final helper in appState.helperCandidatesForRequest(request)) {
        helperById[helper.id] = helper;
      }
    }

    if (helperById.isEmpty) {
      for (final helper in appState.potentialHelpers) {
        helperById[helper.id] = helper;
      }
    }

    final helpers =
        helperById.values.where((helper) {
          if (helper.id == currentUser.id) {
            return false;
          }

          if (!_hasApproximateLocation(helper) ||
              !helper.privacySettings.showApproximateLocation) {
            return false;
          }

          if (currentUser.blockedUserIds.contains(helper.id) ||
              helper.blockedUserIds.contains(currentUser.id)) {
            return false;
          }

          return _matchesNeighborhood(helper.area, currentUser.area) ||
              _matchesNeighborhood(helper.city, currentUser.city) ||
              _matchesNeighborhood(helper.area, currentUser.city) ||
              _matchesNeighborhood(helper.city, currentUser.area);
        }).toList()..sort((first, second) {
          final neighborhoodComparison = _helperNeighborhoodScore(
            second,
            currentUser,
          ).compareTo(_helperNeighborhoodScore(first, currentUser));
          if (neighborhoodComparison != 0) {
            return neighborhoodComparison;
          }

          return (second.trustScore + second.averageRating * 10).compareTo(
            first.trustScore + first.averageRating * 10,
          );
        });

    return helpers.take(12).toList();
  }

  int _helperNeighborhoodScore(UserEntity helper, UserEntity currentUser) {
    var score = 0;
    if (_matchesNeighborhood(helper.area, currentUser.area)) {
      score += 2;
    }
    if (_matchesNeighborhood(helper.city, currentUser.city)) {
      score += 1;
    }
    return score;
  }

  bool _hasApproximateLocation(UserEntity user) {
    return user.area.trim().isNotEmpty || user.city.trim().isNotEmpty;
  }

  bool _matchesNeighborhood(String left, String right) {
    final normalizedLeft = _normalizeLocation(left);
    final normalizedRight = _normalizeLocation(right);
    if (normalizedLeft.isEmpty || normalizedRight.isEmpty) {
      return false;
    }

    return normalizedLeft == normalizedRight ||
        normalizedLeft.contains(normalizedRight) ||
        normalizedRight.contains(normalizedLeft);
  }

  String _normalizeLocation(String value) {
    return value.trim().toLowerCase();
  }
}

class _MatchedRequestCard extends StatelessWidget {
  const _MatchedRequestCard({
    required this.request,
    required this.helper,
    required this.onTap,
    this.onMore,
  });

  final HelpRequestEntity request;
  final UserEntity helper;
  final VoidCallback onTap;
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<GhmeraAppState>();
    final stats = appState.helpStatsForUser(helper.id);
    final theme = Theme.of(context);
    final statusColor = ghStatusColor(request.status);
    final isCompleted = request.status == HelpRequestStatus.completed;

    return GhCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
      onTap: onTap,
      onLongPress: onMore,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GhAvatar(
                name: helper.fullName,
                photo: helper.profilePhoto,
                size: 44,
                showVerified: helper.idVerified || helper.trustedHelper,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      helper.fullName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall,
                    ),
                    Text(
                      isCompleted ? 'Helped you' : 'Is helping you',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              GhTag(
                dense: true,
                label: request.status.label,
                foreground: statusColor,
                background: statusColor.withValues(alpha: 0.12),
              ),
              if (onMore != null)
                IconButton(
                  tooltip: 'Request actions',
                  onPressed: onMore,
                  icon: const Icon(Icons.more_horiz_rounded),
                )
              else
                const SizedBox(width: 8),
            ],
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Text(
              request.displayTitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium,
            ),
          ),
          const SizedBox(height: 10),
          GhHelpStatsStrip(stats: stats),
          if (!isCompleted) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                GhTag(
                  dense: true,
                  icon: request.requesterCompletionConfirmed
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked,
                  label: request.requesterCompletionConfirmed
                      ? 'You confirmed'
                      : 'Your confirmation pending',
                  foreground: request.requesterCompletionConfirmed
                      ? GhColors.brand
                      : GhColors.inkSoft,
                ),
                GhTag(
                  dense: true,
                  icon: request.helperCompletionConfirmed
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked,
                  label: request.helperCompletionConfirmed
                      ? 'Helper confirmed'
                      : 'Helper pending',
                  foreground: request.helperCompletionConfirmed
                      ? GhColors.brand
                      : GhColors.inkSoft,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _MyRequestCard extends StatelessWidget {
  const _MyRequestCard({required this.request, required this.onTap});

  final HelpRequestEntity request;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final categoryStyle = GhCategoryStyle.of(request.category);
    final statusColor = ghStatusColor(request.status);
    final urgencyColor = ghUrgencyColor(request.urgency);
    final isFree = isCreditFreeRequest(request);

    return GhCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
      onTap: onTap,
      onLongPress: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GhIconBadge(
                icon: categoryStyle.icon,
                color: categoryStyle.color,
                size: 42,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.displayTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${request.category.label} · ${_relativeTime(request.createdAt)}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Request actions',
                onPressed: onTap,
                icon: const Icon(Icons.more_horiz_rounded),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              GhTag(
                dense: true,
                label: request.status == HelpRequestStatus.matching
                    ? 'Finding helpers'
                    : request.status.label,
                foreground: statusColor,
                background: statusColor.withValues(alpha: 0.12),
              ),
              GhTag(
                dense: true,
                icon: Icons.bolt_rounded,
                label: '${request.urgency.label} urgency',
                foreground: urgencyColor,
                background: urgencyColor.withValues(alpha: 0.12),
              ),
              GhTag(
                dense: true,
                icon: isFree
                    ? Icons.emergency_outlined
                    : Icons.hourglass_top_rounded,
                label: isFree
                    ? 'Free emergency request'
                    : '${creditCountLabel(requestCreditCost)} on hold',
                foreground: isFree ? GhColors.coral : GhColors.creditDeep,
                background: isFree ? GhColors.coralSoft : GhColors.creditSoft,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NeighborhoodHelpersMapSheet extends StatefulWidget {
  const _NeighborhoodHelpersMapSheet({
    required this.currentUser,
    required this.helpers,
    required this.onSelectHelper,
    required this.scrollController,
  });

  final UserEntity currentUser;
  final List<UserEntity> helpers;
  final ValueChanged<UserEntity> onSelectHelper;
  final ScrollController scrollController;

  @override
  State<_NeighborhoodHelpersMapSheet> createState() =>
      _NeighborhoodHelpersMapSheetState();
}

class _NeighborhoodHelpersMapSheetState
    extends State<_NeighborhoodHelpersMapSheet> {
  late final Future<_NeighborhoodHelpersMapData> _mapDataFuture;

  @override
  void initState() {
    super.initState();
    _mapDataFuture = _loadNeighborhoodMapData();
  }

  void _handleHelperTap(UserEntity helper) {
    Navigator.of(context).pop();
    widget.onSelectHelper(helper);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FutureBuilder<_NeighborhoodHelpersMapData>(
      future: _mapDataFuture,
      builder: (context, snapshot) {
        final data = snapshot.data;
        final children = <Widget>[
          SizedBox(
            height: 40,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Align(
                  alignment: Alignment.topCenter,
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD0D7DF),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                Positioned(
                  top: -6,
                  right: -6,
                  child: IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ),
              ],
            ),
          ),
          Text(
            'Help giver near you',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _sheetSubtitle(),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF5C6A67),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 12),
        ];

        if (snapshot.connectionState != ConnectionState.done) {
          children.add(
            const SizedBox(
              height: 280,
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        } else if (snapshot.hasError) {
          children.add(
            const _EmptyStateCard(
              title: 'Map unavailable',
              message:
                  'The neighborhood map could not be loaded right now. Try again in a moment.',
            ),
          );
        } else if (data == null || !data.hasMap) {
          children.add(
            _EmptyStateCard(
              title: 'No mappable helpers yet',
              message: _emptyStateMessage(),
            ),
          );
        } else {
          children.addAll([
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                height: 320,
                child: FlutterMap(
                  options: MapOptions(
                    initialCameraFit: CameraFit.coordinates(
                      coordinates: <LatLng>[
                        ?data.currentUserPoint,
                        for (final marker in data.helperMarkers) marker.point,
                      ],
                      padding: const EdgeInsets.all(48),
                      maxZoom: 13,
                    ),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.peatech.ghmera',
                    ),
                    MarkerLayer(
                      markers: [
                        if (data.currentUserPoint != null)
                          Marker(
                            point: data.currentUserPoint!,
                            width: 72,
                            height: 72,
                            child: const _CurrentNeighborhoodMarker(),
                          ),
                        for (final marker in data.helperMarkers)
                          Marker(
                            point: marker.point,
                            width: 88,
                            height: 84,
                            child: _NeighborhoodHelperMapMarker(
                              marker: marker,
                              onTap: () => _handleHelperTap(marker.helper),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Approximate locations only. Map data © OpenStreetMap contributors.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: GhColors.inkSoft,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Helpers on the map',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            for (var index = 0; index < data.helperMarkers.length; index++) ...[
              _NeighborhoodHelperListTile(
                marker: data.helperMarkers[index],
                onTap: () => _handleHelperTap(data.helperMarkers[index].helper),
              ),
              if (index < data.helperMarkers.length - 1)
                const SizedBox(height: 10),
            ],
          ]);
        }

        return ListView(
          controller: widget.scrollController,
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
          children: children,
        );
      },
    );
  }

  Future<_NeighborhoodHelpersMapData> _loadNeighborhoodMapData() async {
    final cache = <String, LatLng>{};
    final duplicateCounts = <String, int>{};
    final currentUserExactPoint = _exactPointForUser(widget.currentUser);
    final currentUserApproximatePoint = await _resolveApproximatePoint(
      widget.currentUser.area,
      widget.currentUser.city,
      cache: cache,
    );
    final currentUserDistancePoint =
        currentUserExactPoint ?? currentUserApproximatePoint;
    final currentUserPoint =
        currentUserApproximatePoint ?? currentUserExactPoint;

    final markers = <_NeighborhoodHelperMarkerData>[];
    for (final helper in widget.helpers) {
      final locationLabel = _buildLocationLabel(helper.area, helper.city);
      if (locationLabel.isEmpty) {
        continue;
      }

      final approximatePoint =
          await _resolveApproximatePoint(
            helper.area,
            helper.city,
            cache: cache,
          ) ??
          _approximatePointFromExactLocation(helper);
      if (approximatePoint == null) {
        continue;
      }

      final helperExactPoint = _exactPointForUser(helper);
      final helperDistancePoint = helperExactPoint ?? approximatePoint;
      final isDistanceApproximate =
          currentUserExactPoint == null || helperExactPoint == null;
      final distanceKm = currentUserDistancePoint == null
          ? null
          : const Distance().as(
              LengthUnit.Kilometer,
              currentUserDistancePoint,
              helperDistancePoint,
            );

      final duplicateIndex = duplicateCounts.update(
        locationLabel,
        (value) => value + 1,
        ifAbsent: () => 0,
      );

      markers.add(
        _NeighborhoodHelperMarkerData(
          helper: helper,
          point: _offsetPoint(approximatePoint, duplicateIndex),
          locationLabel: locationLabel,
          distanceKm: distanceKm,
          isDistanceApproximate: distanceKm != null && isDistanceApproximate,
        ),
      );
    }

    return _NeighborhoodHelpersMapData(
      currentUserPoint: currentUserPoint,
      mapCenter:
          currentUserPoint ?? (markers.isNotEmpty ? markers.first.point : null),
      helperMarkers: markers,
    );
  }

  LatLng? _exactPointForUser(UserEntity user) {
    final exactLatitude = user.exactLatitude;
    final exactLongitude = user.exactLongitude;
    if (exactLatitude == null || exactLongitude == null) {
      return null;
    }

    if (exactLatitude < -90 ||
        exactLatitude > 90 ||
        exactLongitude < -180 ||
        exactLongitude > 180) {
      return null;
    }

    return LatLng(exactLatitude, exactLongitude);
  }

  Future<LatLng?> _resolveApproximatePoint(
    String area,
    String city, {
    required Map<String, LatLng> cache,
  }) async {
    final query = _buildLocationLabel(area, city);
    if (query.isEmpty) {
      return null;
    }

    final cachedPoint = cache[query];
    if (cachedPoint != null) {
      return cachedPoint;
    }

    try {
      final point = await MapGeocodingService.instance.resolveAddress(query);
      if (point == null) {
        return null;
      }
      cache[query] = point;
      return point;
    } catch (_) {
      return null;
    }
  }

  LatLng _offsetPoint(LatLng point, int index) {
    const offsets = <Offset>[
      Offset(0, 0),
      Offset(0.0024, 0.0012),
      Offset(-0.0022, 0.0012),
      Offset(0.0024, -0.0012),
      Offset(-0.0022, -0.0012),
      Offset(0.0036, 0),
    ];

    final offset = offsets[index % offsets.length];
    return LatLng(point.latitude + offset.dy, point.longitude + offset.dx);
  }

  String _sheetSubtitle() {
    if (!_hasLocation(widget.currentUser)) {
      return 'Add your city or area to view help givers near you.';
    }

    return 'Tap a helper on the map to send a direct help request.';
  }

  String _emptyStateMessage() {
    if (!_hasLocation(widget.currentUser)) {
      return 'Add your area or city in Account to start seeing nearby help givers on this map.';
    }

    if (widget.helpers.isEmpty) {
      return 'No help givers are currently sharing approximate location in your neighborhood.';
    }

    return 'Nearby help givers were found, but their approximate map positions could not be resolved yet.';
  }

  bool _hasLocation(UserEntity user) {
    return user.area.trim().isNotEmpty || user.city.trim().isNotEmpty;
  }
}

class _NeighborhoodHelpersMapData {
  const _NeighborhoodHelpersMapData({
    required this.currentUserPoint,
    required this.mapCenter,
    required this.helperMarkers,
  });

  final LatLng? currentUserPoint;
  final LatLng? mapCenter;
  final List<_NeighborhoodHelperMarkerData> helperMarkers;

  bool get hasMap => helperMarkers.isNotEmpty && mapCenter != null;
}

class _NeighborhoodHelperMarkerData {
  const _NeighborhoodHelperMarkerData({
    required this.helper,
    required this.point,
    required this.locationLabel,
    required this.distanceKm,
    required this.isDistanceApproximate,
  });

  final UserEntity helper;
  final LatLng point;
  final String locationLabel;
  final double? distanceKm;
  final bool isDistanceApproximate;
}

class _CurrentNeighborhoodMarker extends StatelessWidget {
  const _CurrentNeighborhoodMarker();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF163C38),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Text(
            'You',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const Icon(
          Icons.my_location_rounded,
          color: Color(0xFF163C38),
          size: 24,
        ),
      ],
    );
  }
}

class _NeighborhoodHelperMapMarker extends StatelessWidget {
  const _NeighborhoodHelperMapMarker({
    required this.marker,
    required this.onTap,
  });

  final _NeighborhoodHelperMarkerData marker;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final firstName = marker.helper.fullName.trim().split(' ').first;
    final distanceLabel = _helperDistanceLabel(marker);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Tooltip(
        message: distanceLabel == null
            ? '${marker.helper.fullName}\n${marker.locationLabel}'
            : '${marker.helper.fullName}\n${marker.locationLabel}\n$distanceLabel',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                firstName,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: theme.colorScheme.onPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Icon(
              Icons.location_on_rounded,
              color: theme.colorScheme.primary,
              size: 28,
            ),
          ],
        ),
      ),
    );
  }
}

class _NeighborhoodHelperListTile extends StatelessWidget {
  const _NeighborhoodHelperListTile({
    required this.marker,
    required this.onTap,
  });

  final _NeighborhoodHelperMarkerData marker;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final helper = marker.helper;
    final theme = Theme.of(context);
    final distanceLabel = _helperDistanceLabel(marker);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: ListTile(
        onTap: onTap,
        isThreeLine: true,
        titleAlignment: ListTileTitleAlignment.center,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: _RequesterAvatar(requester: helper, size: 56),
        title: Text(
          helper.fullName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              marker.locationLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: GhColors.inkSoft,
              ),
            ),
            if (distanceLabel != null)
              Text(
                distanceLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: GhColors.inkSoft,
                ),
              ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              helper.trustScore.toStringAsFixed(0),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              'Trust',
              style: theme.textTheme.bodySmall?.copyWith(
                color: GhColors.inkSoft,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RequestLocationEntry {
  const _RequestLocationEntry({required this.request, required this.requester});

  final HelpRequestEntity request;
  final UserEntity requester;
}

class _RequestLocationsMapSheet extends StatefulWidget {
  const _RequestLocationsMapSheet({
    required this.currentUser,
    required this.requestEntries,
    required this.onSelectRequest,
    required this.scrollController,
  });

  final UserEntity currentUser;
  final List<_RequestLocationEntry> requestEntries;
  final ValueChanged<HelpRequestEntity> onSelectRequest;
  final ScrollController scrollController;

  @override
  State<_RequestLocationsMapSheet> createState() =>
      _RequestLocationsMapSheetState();
}

class _RequestLocationsMapSheetState extends State<_RequestLocationsMapSheet> {
  late final Future<_RequestLocationsMapData> _mapDataFuture;

  @override
  void initState() {
    super.initState();
    _mapDataFuture = _loadRequestMapData();
  }

  void _handleRequestTap(HelpRequestEntity request) {
    Navigator.of(context).pop();
    widget.onSelectRequest(request);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appState = context.watch<GhmeraAppState>();
    return FutureBuilder<_RequestLocationsMapData>(
      future: _mapDataFuture,
      builder: (context, snapshot) {
        final data = snapshot.data;
        final requestMarkers = (data?.requestMarkers ?? const [])
            .where(
              (marker) => appState.isCommunityRequestStillOpen(marker.request.id),
            )
            .toList();
        final children = <Widget>[
          SizedBox(
            height: 40,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Align(
                  alignment: Alignment.topCenter,
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD0D7DF),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                Positioned(
                  top: -6,
                  right: -6,
                  child: IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ),
              ],
            ),
          ),
          Text(
            'Request locations',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _sheetSubtitle(),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF5C6A67),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 12),
        ];

        if (snapshot.connectionState != ConnectionState.done) {
          children.add(
            const SizedBox(
              height: 280,
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        } else if (snapshot.hasError) {
          children.add(
            const _EmptyStateCard(
              title: 'Map unavailable',
              message:
                  'The request locations map could not be loaded right now. Try again in a moment.',
            ),
          );
        } else if (data == null ||
            data.mapCenter == null ||
            requestMarkers.isEmpty) {
          children.add(
            _EmptyStateCard(
              title: 'No mappable requests yet',
              message: _emptyStateMessage(
                hasOpenRequests: widget.requestEntries.any(
                  (entry) =>
                      appState.isCommunityRequestStillOpen(entry.request.id),
                ),
              ),
            ),
          );
        } else {
          children.addAll([
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                height: 320,
                child: FlutterMap(
                  options: MapOptions(
                    initialCameraFit: CameraFit.coordinates(
                      coordinates: <LatLng>[
                        ?data.currentUserPoint,
                        for (final marker in requestMarkers) marker.point,
                      ],
                      padding: const EdgeInsets.all(48),
                      maxZoom: 13,
                    ),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.peatech.ghmera',
                    ),
                    MarkerLayer(
                      markers: [
                        if (data.currentUserPoint != null)
                          Marker(
                            point: data.currentUserPoint!,
                            width: 72,
                            height: 72,
                            child: const _CurrentNeighborhoodMarker(),
                          ),
                        for (final marker in requestMarkers)
                          Marker(
                            point: marker.point,
                            width: 88,
                            height: 84,
                            child: _RequestLocationMapMarker(
                              marker: marker,
                              onTap: () => _handleRequestTap(marker.request),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Approximate locations only. Map data © OpenStreetMap contributors.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: GhColors.inkSoft,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Requests on the map',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            for (var index = 0; index < requestMarkers.length; index++) ...[
              _RequestLocationListTile(
                marker: requestMarkers[index],
                onTap: () => _handleRequestTap(requestMarkers[index].request),
              ),
              if (index < requestMarkers.length - 1) const SizedBox(height: 10),
            ],
          ]);
        }

        return ListView(
          controller: widget.scrollController,
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
          children: children,
        );
      },
    );
  }

  Future<_RequestLocationsMapData> _loadRequestMapData() async {
    final cache = <String, LatLng>{};
    final duplicateCounts = <String, int>{};
    final currentUserExactPoint = _exactPointForUser(widget.currentUser);
    final currentUserApproximatePoint = await _resolvePointFromQuery(
      _buildLocationLabel(widget.currentUser.area, widget.currentUser.city),
      cache: cache,
    );
    final currentUserDistancePoint =
        currentUserExactPoint ?? currentUserApproximatePoint;
    final currentUserPoint =
        currentUserApproximatePoint ?? currentUserExactPoint;

    final markers = <_RequestLocationMarkerData>[];
    for (final entry in widget.requestEntries) {
      final locationLabel = entry.request.location.trim();
      if (locationLabel.isEmpty) {
        continue;
      }

      final requesterCity = entry.requester.city.trim();
      final geocodingQuery =
          requesterCity.isNotEmpty &&
              !locationLabel.toLowerCase().contains(requesterCity.toLowerCase())
          ? '$locationLabel, $requesterCity'
          : locationLabel;

      final approximatePoint =
          await _resolvePointFromQuery(geocodingQuery, cache: cache) ??
          (entry.requester.privacySettings.showApproximateLocation
              ? _approximatePointFromExactLocation(entry.requester)
              : null);
      if (approximatePoint == null) {
        continue;
      }

      final distanceKm = currentUserDistancePoint == null
          ? null
          : const Distance().as(
              LengthUnit.Kilometer,
              currentUserDistancePoint,
              approximatePoint,
            );

      final duplicateIndex = duplicateCounts.update(
        locationLabel,
        (value) => value + 1,
        ifAbsent: () => 0,
      );

      markers.add(
        _RequestLocationMarkerData(
          request: entry.request,
          requester: entry.requester,
          point: _offsetPoint(approximatePoint, duplicateIndex),
          locationLabel: locationLabel,
          distanceKm: distanceKm,
          isDistanceApproximate: distanceKm != null,
        ),
      );
    }

    return _RequestLocationsMapData(
      currentUserPoint: currentUserPoint,
      mapCenter:
          currentUserPoint ?? (markers.isNotEmpty ? markers.first.point : null),
      requestMarkers: markers,
    );
  }

  LatLng? _exactPointForUser(UserEntity user) {
    final exactLatitude = user.exactLatitude;
    final exactLongitude = user.exactLongitude;
    if (exactLatitude == null || exactLongitude == null) {
      return null;
    }

    if (exactLatitude < -90 ||
        exactLatitude > 90 ||
        exactLongitude < -180 ||
        exactLongitude > 180) {
      return null;
    }

    return LatLng(exactLatitude, exactLongitude);
  }

  Future<LatLng?> _resolvePointFromQuery(
    String query, {
    required Map<String, LatLng> cache,
  }) async {
    final normalizedQuery = query.trim();
    if (normalizedQuery.isEmpty) {
      return null;
    }

    final cachedPoint = cache[normalizedQuery];
    if (cachedPoint != null) {
      return cachedPoint;
    }

    try {
      final point = await MapGeocodingService.instance.resolveAddress(
        normalizedQuery,
      );
      if (point == null) {
        return null;
      }
      cache[normalizedQuery] = point;
      return point;
    } catch (_) {
      return null;
    }
  }

  LatLng _offsetPoint(LatLng point, int index) {
    const offsets = <Offset>[
      Offset(0, 0),
      Offset(0.0024, 0.0012),
      Offset(-0.0022, 0.0012),
      Offset(0.0024, -0.0012),
      Offset(-0.0022, -0.0012),
      Offset(0.0036, 0),
    ];

    final offset = offsets[index % offsets.length];
    return LatLng(point.latitude + offset.dy, point.longitude + offset.dx);
  }

  String _sheetSubtitle() {
    if (!_hasLocation(widget.currentUser)) {
      return 'Tap a request on the map to review it. Add your city or area to compare distances.';
    }

    return 'Tap a request on the map to review it.';
  }

  String _emptyStateMessage({required bool hasOpenRequests}) {
    if (!hasOpenRequests) {
      return 'No open help requests with visible locations are ready to map right now.';
    }

    return 'Open help requests were found, but their map positions could not be resolved yet.';
  }

  bool _hasLocation(UserEntity user) {
    return user.area.trim().isNotEmpty || user.city.trim().isNotEmpty;
  }
}

class _RequestLocationsMapData {
  const _RequestLocationsMapData({
    required this.currentUserPoint,
    required this.mapCenter,
    required this.requestMarkers,
  });

  final LatLng? currentUserPoint;
  final LatLng? mapCenter;
  final List<_RequestLocationMarkerData> requestMarkers;
}

class _RequestLocationMarkerData {
  const _RequestLocationMarkerData({
    required this.request,
    required this.requester,
    required this.point,
    required this.locationLabel,
    required this.distanceKm,
    required this.isDistanceApproximate,
  });

  final HelpRequestEntity request;
  final UserEntity requester;
  final LatLng point;
  final String locationLabel;
  final double? distanceKm;
  final bool isDistanceApproximate;
}

class _RequestLocationMapMarker extends StatelessWidget {
  const _RequestLocationMapMarker({required this.marker, required this.onTap});

  final _RequestLocationMarkerData marker;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final firstName = marker.requester.fullName.trim().split(' ').first;
    final distanceLabel = _requestDistanceLabel(marker);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Tooltip(
        message: distanceLabel == null
            ? '${marker.request.displayTitle}\n${marker.requester.fullName}\n${marker.locationLabel}'
            : '${marker.request.displayTitle}\n${marker.requester.fullName}\n${marker.locationLabel}\n$distanceLabel',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                firstName,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: theme.colorScheme.onPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Icon(
              Icons.location_on_rounded,
              color: theme.colorScheme.primary,
              size: 28,
            ),
          ],
        ),
      ),
    );
  }
}

class _RequestLocationListTile extends StatelessWidget {
  const _RequestLocationListTile({required this.marker, required this.onTap});

  final _RequestLocationMarkerData marker;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final distanceLabel = _requestDistanceLabel(marker);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: ListTile(
        onTap: onTap,
        isThreeLine: true,
        titleAlignment: ListTileTitleAlignment.center,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: _RequesterAvatar(requester: marker.requester, size: 56),
        title: Text(
          marker.request.displayTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              marker.locationLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: GhColors.inkSoft,
              ),
            ),
            if (distanceLabel != null)
              Text(
                distanceLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: GhColors.inkSoft,
                ),
              ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              marker.request.urgency.label,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              'Urgency',
              style: theme.textTheme.bodySmall?.copyWith(
                color: GhColors.inkSoft,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String? _helperDistanceLabel(_NeighborhoodHelperMarkerData marker) {
  final distanceKm = marker.distanceKm;
  if (distanceKm == null) {
    return null;
  }

  final formattedDistance = '${_formatDistanceKm(distanceKm)} km away';
  if (marker.isDistanceApproximate) {
    return 'Approx. $formattedDistance';
  }

  return formattedDistance;
}

String? _requestDistanceLabel(_RequestLocationMarkerData marker) {
  final distanceKm = marker.distanceKm;
  if (distanceKm == null) {
    return null;
  }

  final formattedDistance = '${_formatDistanceKm(distanceKm)} km away';
  if (marker.isDistanceApproximate) {
    return 'Approx. $formattedDistance';
  }

  return formattedDistance;
}

LatLng? _approximatePointFromExactLocation(UserEntity user) {
  final latitude = user.exactLatitude;
  final longitude = user.exactLongitude;
  if (latitude == null ||
      longitude == null ||
      latitude < -90 ||
      latitude > 90 ||
      longitude < -180 ||
      longitude > 180) {
    return null;
  }

  const approximationScale = 100.0;
  return LatLng(
    (latitude * approximationScale).round() / approximationScale,
    (longitude * approximationScale).round() / approximationScale,
  );
}

String _buildLocationLabel(String area, String city) {
  final values = <String>[
    area.trim(),
    city.trim(),
  ].where((value) => value.isNotEmpty).toList();
  return values.join(', ');
}

String _formatDistanceKm(double distanceKm) {
  if (distanceKm >= 10) {
    return distanceKm.toStringAsFixed(0);
  }

  return distanceKm.toStringAsFixed(1);
}

class _HiddenRequestsScreen extends StatelessWidget {
  const _HiddenRequestsScreen({
    required this.onEditRequest,
    required this.onReviewAcceptedRequest,
  });

  final Future<void> Function(HelpRequestEntity request) onEditRequest;
  final ValueChanged<HelpRequestEntity> onReviewAcceptedRequest;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        centerTitle: false,
        leading: uniformBackButton(context),
        title: uniformAppBarTitle(
          context,
          title: 'Hidden requests',
          subtitle: 'Requests you hid from the main requests list.',
        ),
      ),
      body: SafeArea(
        child: Consumer<GhmeraAppState>(
          builder: (context, appState, _) {
            final hiddenRequests = appState.hiddenMyRequests;

            return ListView(
              padding: const EdgeInsets.fromLTRB(10, 12, 10, 28),
              children: [
                Text(
                  'Hidden requests stay here until you restore them. Tap a request to open it, or use the restore button to bring it back to your requests screen.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: GhColors.inkSoft,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 18),
                if (hiddenRequests.isEmpty)
                  const _EmptyStateCard(
                    title: 'No hidden requests',
                    message:
                        'Requests you hide from your created list will appear here.',
                  )
                else
                  for (final request in hiddenRequests)
                    _HiddenRequestTile(
                      request: request,
                      onTap: () async {
                        if (request.acceptedHelperId != null) {
                          onReviewAcceptedRequest(request);
                          return;
                        }

                        await onEditRequest(request);
                      },
                      onRestore: () {
                        final restored = context
                            .read<GhmeraAppState>()
                            .unhideRequestForCurrentUser(request.id);
                        if (!restored) {
                          return;
                        }

                        showGhmeraSnackBar(
                          context,
                          message:
                              '${request.displayTitle} restored to your requests.',
                        );
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

class _MessagesTab extends StatelessWidget {
  const _MessagesTab({required this.onOpenThread});

  final ValueChanged<MessageThreadEntity> onOpenThread;

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<GhmeraAppState>();
    final threads = appState.messageThreads;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
      children: [
        const GhInfoBanner(
          icon: Icons.shield_outlined,
          title: 'Protected messaging',
          message:
              'Chats stay inside Ghmera. Phone numbers, emails, and exact locations stay hidden until you both agree to share them.',
        ),
        const SizedBox(height: 16),
        if (threads.isEmpty)
          const GhEmptyState(
            icon: Icons.chat_bubble_outline_rounded,
            title: 'No conversations yet',
            message:
                'When you match with someone, your private chat will appear here.',
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
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: ghBrandGradient,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Trust, safety, and wellbeing',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Ghmera is not a therapy or emergency medical platform. It uses peer support, crisis routing, moderation, and high-risk controls to protect both sides of each interaction.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
              const SizedBox(height: 14),
              const Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
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
        const SizedBox(height: 22),
        const GhSectionHeader(
          title: 'High-risk interactions',
          subtitle:
              'Childcare, elderly support, money, home visits, and late-night support get stronger controls.',
        ),
        if (appState.highRiskRequests.isEmpty)
          const GhEmptyState(
            icon: Icons.health_and_safety_outlined,
            title: 'No high-risk requests are active',
            message:
                'High-risk requests appear here with stronger check-in and moderation prompts.',
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
        const SizedBox(height: 22),
        const GhSectionHeader(
          title: 'Moderation queue',
          subtitle: 'Reports, disputes, and harmful behavior under review.',
        ),
        if (appState.moderationQueue.isEmpty)
          const GhEmptyState(
            icon: Icons.verified_user_outlined,
            title: 'Nothing to review',
            message: 'Open reports will appear here.',
          )
        else
          for (final report in appState.moderationQueue)
            _ReportCard(report: report),
        const SizedBox(height: 22),
        const GhSectionHeader(title: 'Community health'),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.9,
          children: [
            _AdminMetricCard(label: 'Members', value: '${appState.totalUsers}'),
            _AdminMetricCard(
              label: 'Active today',
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
              label: 'High-risk',
              value: '${appState.highRiskInteractionCount}',
            ),
          ],
        ),
        const SizedBox(height: 22),
        const GhCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SafetyFeatureRow(
                icon: Icons.notification_important_outlined,
                title: 'Emergency features',
                text:
                    'Panic prompts, “I feel unsafe” paths, trusted-contact sharing, and safety check-ins.',
              ),
              SizedBox(height: 14),
              _SafetyFeatureRow(
                icon: Icons.favorite_border_rounded,
                title: 'Emotional support',
                text:
                    'Daily mood check-ins, peer listener matching, support circles, and crisis resource escalation.',
              ),
              SizedBox(height: 14),
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

class _BadgedIconButton extends StatelessWidget {
  const _BadgedIconButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.count = 0,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;
  final int count;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Badge(
        isLabelVisible: count > 0,
        backgroundColor: GhColors.coral,
        label: Text(count > 99 ? '99+' : '$count'),
        child: Icon(icon),
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({
    required this.request,
    required this.appState,
    this.showRequester = false,
    this.leadingLabel,
    this.onTap,
  });

  final HelpRequestEntity request;
  final GhmeraAppState appState;
  final bool showRequester;
  final String? leadingLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final requester = appState.userById(request.requesterId);
    final helper = appState.helperForRequest(request);
    final theme = Theme.of(context);
    final categoryStyle = GhCategoryStyle.of(request.category);
    final statusColor = ghStatusColor(request.status);

    return GhCard(
      margin: const EdgeInsets.only(bottom: 12),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (leadingLabel != null) ...[
            GhTag(
              dense: true,
              icon: Icons.shield_outlined,
              label: leadingLabel!,
              foreground: GhColors.amber,
              background: GhColors.amberSoft,
            ),
            const SizedBox(height: 12),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GhIconBadge(
                icon: categoryStyle.icon,
                color: categoryStyle.color,
                size: 40,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.displayTitle,
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      request.description,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: GhColors.inkSoft,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              GhTag(
                dense: true,
                label: request.status.label,
                foreground: statusColor,
                background: statusColor.withValues(alpha: 0.12),
              ),
              GhTag(
                dense: true,
                icon: Icons.place_outlined,
                label: request.location,
              ),
              if (showRequester)
                GhTag(
                  dense: true,
                  icon: Icons.person_outline_rounded,
                  label: requester.fullName,
                ),
              if (helper != null)
                GhTag(
                  dense: true,
                  icon: Icons.handshake_outlined,
                  label: helper.fullName,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HiddenRequestTile extends StatelessWidget {
  const _HiddenRequestTile({
    required this.request,
    required this.onTap,
    required this.onRestore,
  });

  final HelpRequestEntity request;
  final VoidCallback onTap;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final categoryStyle = GhCategoryStyle.of(request.category);
    return GhCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
      onTap: onTap,
      child: Row(
        children: [
          GhIconBadge(
            icon: categoryStyle.icon,
            color: categoryStyle.color,
            size: 42,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  request.displayTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall,
                ),
                Text(
                  '${request.category.label} · ${request.status.label}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: onRestore,
            icon: const Icon(Icons.visibility_outlined, size: 18),
            label: const Text('Restore'),
          ),
        ],
      ),
    );
  }
}

class _RequesterAvatar extends StatelessWidget {
  const _RequesterAvatar({required this.requester, this.size = 48});

  final UserEntity requester;
  final double size;

  @override
  Widget build(BuildContext context) {
    return GhAvatar(
      name: requester.fullName,
      photo: requester.profilePhoto,
      size: size,
    );
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
    final theme = Theme.of(context);
    final lastMessageIsMine = lastMessage?.senderId == appState.currentUserId;

    return GhCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GhAvatar(
            name: peer?.fullName ?? 'Unknown user',
            photo: peer?.profilePhoto,
            size: 48,
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
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall,
                      ),
                    ),
                    Text(
                      _relativeTime(thread.lastMessageAt),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: GhColors.inkFaint,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  request.displayTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: GhColors.brand,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  lastMessage == null
                      ? 'No messages yet. Say hello!'
                      : '${lastMessageIsMine ? 'You: ' : ''}${lastMessage.content}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: GhColors.inkSoft,
                  ),
                ),
                if (thread.messageRequestPending ||
                    thread.flaggedSafetyConcern) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if (thread.messageRequestPending)
                        const GhTag(
                          dense: true,
                          label: 'Message request',
                          foreground: GhColors.amber,
                          background: GhColors.amberSoft,
                        ),
                      if (thread.flaggedSafetyConcern)
                        const GhTag(
                          dense: true,
                          icon: Icons.flag_outlined,
                          label: 'Safety flag',
                          foreground: GhColors.coral,
                          background: GhColors.coralSoft,
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
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
    final theme = Theme.of(context);

    return GhCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      onTap: onTap,
      shadow: !notification.isRead,
      color: notification.isRead ? GhColors.surface : const Color(0xFFFBFEFD),
      borderColor: notification.isRead
          ? GhColors.line
          : color.withValues(alpha: 0.35),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GhIconBadge(
            icon: _notificationIcon(notification.type),
            color: color,
            size: 42,
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
                        style: theme.textTheme.titleSmall,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _relativeTime(notification.createdAt),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: GhColors.inkFaint,
                      ),
                    ),
                    if (!notification.isRead) ...[
                      const SizedBox(width: 6),
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  notification.message,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: GhColors.inkSoft,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SheetDragHandle extends StatelessWidget {
  const _SheetDragHandle();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(bottom: 4),
      child: GhSheetHandle(),
    );
  }
}

class _MenuSheetActionTile extends StatelessWidget {
  const _MenuSheetActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.foregroundColor,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? foregroundColor;

  @override
  Widget build(BuildContext context) {
    final color = foregroundColor ?? GhColors.ink;

    return GhCard(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      radius: 16,
      shadow: false,
      onTap: onTap,
      child: Row(
        children: [
          GhIconBadge(
            icon: icon,
            color: foregroundColor ?? GhColors.brand,
            size: 38,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(color: color),
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            color: color.withValues(alpha: 0.4),
            size: 22,
          ),
        ],
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({required this.report});

  final ReportEntity report;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = _reportStatusColor(report.status);
    return GhCard(
      margin: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(report.reason, style: theme.textTheme.titleSmall),
              ),
              GhTag(
                dense: true,
                label: report.status.label,
                foreground: statusColor,
                background: statusColor.withValues(alpha: 0.12),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${report.targetType.label} report · ${_relativeTime(report.createdAt)}',
            style: theme.textTheme.bodySmall,
          ),
          if (report.details.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              report.details,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: GhColors.inkSoft,
              ),
            ),
          ],
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
    return GhStatTile(value: value, label: label);
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
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GhIconBadge(icon: icon, size: 40),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.titleSmall),
              const SizedBox(height: 2),
              Text(
                text,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: GhColors.inkSoft,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HeroPill extends StatelessWidget {
  const _HeroPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 12.5,
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
    return GhEmptyState(
      icon: Icons.inbox_outlined,
      title: title,
      message: message,
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

Color _notificationColor(NotificationType type) {
  switch (type) {
    case NotificationType.matchFound:
      return GhColors.brand;
    case NotificationType.newMessage:
      return GhColors.sky;
    case NotificationType.requestAccepted:
      return GhColors.brand;
    case NotificationType.helpCompleted:
      return GhColors.credit;
    case NotificationType.reportUpdate:
      return GhColors.plum;
    case NotificationType.safetyAlert:
      return GhColors.coral;
    case NotificationType.reciprocityWarning:
      return GhColors.amber;
    case NotificationType.emotionalCheckInReminder:
      return GhColors.rose;
    case NotificationType.adminUpdate:
      return GhColors.inkSoft;
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
      return Icons.volunteer_activism_rounded;
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
      return GhColors.coral;
    case ReportStatus.investigating:
      return GhColors.amber;
    case ReportStatus.resolved:
      return GhColors.brand;
    case ReportStatus.dismissed:
      return GhColors.inkFaint;
  }
}

String _relativeTime(DateTime timestamp) => ghRelativeTime(timestamp);
