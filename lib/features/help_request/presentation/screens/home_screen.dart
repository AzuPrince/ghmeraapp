import 'package:flutter_map/flutter_map.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../../../app/models/ghmera_models.dart';
import '../../../../app/providers/ghmera_app_state.dart';
import '../../../../core/ui/app_snack_bar.dart';
import '../../../../core/ui/uniform_app_bar.dart';
import 'home_menu_screen.dart';
import '../../../profile/presentation/screens/profile_screen.dart';
import 'create_request_screen.dart';

enum _CommunityRequestMenuAction { removeFromView, reportAccount, blockAccount }

enum _MyRequestMenuAction { hideThisRequest, deleteThisRequest }

enum _AcceptedRequestMenuAction {
  messageReceiver,
  helpFulfilled,
  reportHelpGiver,
  cancelRequest,
}

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

  static const List<String> _titles = <String>[
    'Give Help',
    'Receive Help',
    'Messages',
    'Safety',
    'Account',
  ];

  static const List<String> _subtitles = <String>[
    'Browse people who need support right now.',
    'Manage the help you have asked the community for.',
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
        onRequestLongPress: _showCommunityRequestActions,
      ),
      _RequestsTab(
        onCreateRequest: _openStandardRequest,
        onEditRequest: _editRequest,
        onLongPressMyRequest: _showMyRequestActions,
        onManageAcceptedRequest: _showAcceptedRequestActionsSheet,
        onDirectRequestHelper: _startDirectHelperRequestFlow,
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
        leading: isPrimaryTab
            ? null
            : uniformBackButton(
                context,
                onPressed: () => _selectTab(_giveHelpTabIndex),
              ),
        titleSpacing: 10,
        title: _buildAppBarTitle(context),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: _currentIndex == _receiveHelpTabIndex
                ? Stack(
                    clipBehavior: Clip.none,
                    children: [
                      IconButton(
                        tooltip: 'Hidden requests',
                        onPressed: _showHiddenRequestsScreen,
                        icon: const Icon(Icons.visibility_off_outlined),
                      ),
                      if (appState.hiddenMyRequestsCount > 0)
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
                              '${appState.hiddenMyRequestsCount}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                    ],
                  )
                : Stack(
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
          if (_currentIndex == _giveHelpTabIndex)
            IconButton(
              tooltip: 'Messages',
              onPressed: () => _selectTab(_messagesTabIndex),
              icon: const Icon(Icons.chat_bubble_outline_rounded),
            ),
          if (_currentIndex == _giveHelpTabIndex)
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
      bottomNavigationBar: isPrimaryTab
          ? NavigationBar(
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
                  icon: Icon(Icons.request_page_outlined),
                  selectedIcon: Icon(Icons.request_page_rounded),
                  label: 'Receive Help',
                ),
                NavigationDestination(
                  icon: Icon(Icons.person_outline_rounded),
                  selectedIcon: Icon(Icons.person_rounded),
                  label: 'Account',
                ),
              ],
            )
          : null,
    );
  }

  Widget _buildAppBarTitle(BuildContext context) {
    if (_currentIndex != _giveHelpTabIndex) {
      return uniformAppBarTitle(
        context,
        title: _titles[_currentIndex],
        subtitle: _subtitles[_currentIndex],
      );
    }

    return SizedBox(
      height: 50,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Image.asset(
          'assets/branding/ghmera_app_icon_foreground.png',
          width: 48,
          height: 48,
          fit: BoxFit.contain,
          color: Theme.of(context).appBarTheme.foregroundColor,
          colorBlendMode: BlendMode.srcIn,
          errorBuilder: (context, error, stackTrace) => Text(
            _titles[_currentIndex],
            style: uniformHeadingTextStyle(
              context,
            ).copyWith(color: Theme.of(context).colorScheme.primary),
          ),
        ),
      ),
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(5)),
      ),
      builder: (sheetContext) {
        final helperFirstName = helper.fullName.trim().split(' ').first;

        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
                child: Text(
                  'Request help from ${helper.fullName}',
                  style: Theme.of(sheetContext).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                child: Text(
                  editableRequests.isEmpty
                      ? 'Create a new request and send it directly to $helperFirstName.'
                      : 'Choose an existing request or create a new one for $helperFirstName.',
                  style: Theme.of(sheetContext).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF61726F),
                  ),
                ),
              ),
              if (editableRequests.isEmpty)
                const Padding(
                  padding: EdgeInsets.fromLTRB(8, 0, 8, 8),
                  child: Text(
                    'No editable requests are available yet.',
                    style: TextStyle(color: Color(0xFF61726F)),
                  ),
                )
              else
                for (final request in editableRequests)
                  ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(5),
                    ),
                    onTap: () => Navigator.of(sheetContext).pop(request.id),
                    leading: const Icon(Icons.assignment_outlined),
                    title: Text(
                      request.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(sheetContext).textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      '${request.category.label} • ${request.location}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(sheetContext).textTheme.bodySmall
                          ?.copyWith(color: const Color(0xFF61726F)),
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
            borderRadius: BorderRadius.vertical(top: Radius.circular(5)),
          ),
          builder: (sheetContext) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
                      child: Text(
                        request.title,
                        style: Theme.of(sheetContext).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                      child: Text(
                        'Actions for ${helper.fullName}',
                        style: Theme.of(sheetContext).textTheme.bodyMedium
                            ?.copyWith(color: const Color(0xFF61726F)),
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
                      foregroundColor: const Color(0xFF9A2F2F),
                      onTap: () => Navigator.of(
                        sheetContext,
                      ).pop(_AcceptedRequestMenuAction.reportHelpGiver),
                    ),
                    _MenuSheetActionTile(
                      icon: Icons.cancel_outlined,
                      label: 'Cancel request',
                      foregroundColor: const Color(0xFF9A2F2F),
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(5)),
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
          ? 'Request canceled and removed from active help.'
          : 'This request could not be canceled.',
    );
  }

  Future<void> _showCommunityRequestActions(HelpRequestEntity request) async {
    final appState = context.read<GhmeraAppState>();
    final requester = appState.userById(request.requesterId);
    final selectedAction =
        await showModalBottomSheet<_CommunityRequestMenuAction>(
          context: context,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(5)),
          ),
          builder: (sheetContext) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
                      child: Text(
                        request.title,
                        style: Theme.of(sheetContext).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                      child: Text(
                        'Actions for ${requester.fullName}',
                        style: Theme.of(sheetContext).textTheme.bodyMedium
                            ?.copyWith(color: const Color(0xFF61726F)),
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
                      foregroundColor: const Color(0xFF9A2F2F),
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(5)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
                  child: Text(
                    request.title,
                    style: Theme.of(sheetContext).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                  child: Text(
                    'Request actions',
                    style: Theme.of(sheetContext).textTheme.bodyMedium
                        ?.copyWith(color: const Color(0xFF61726F)),
                  ),
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
                  foregroundColor: const Color(0xFF9A2F2F),
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
              ? 'Request deleted.'
              : 'This request could not be deleted.',
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
          'Delete ${request.title}? This only works for requests that have not been accepted yet.',
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(5)),
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(5)),
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

  Future<void> _sendMessage(
    GhmeraAppState appState,
    MessageThreadEntity thread,
  ) async {
    final content = _messageController.text.trim();
    if (content.isEmpty) {
      return;
    }

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
    final scaffoldMessenger = ScaffoldMessenger.of(context);
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(5)),
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

  String _requestDetailsSubtitle(HelpRequestEntity request) {
    final subtitleParts = <String>[request.status.label];
    final location = request.location.trim();
    final preferredTime = request.preferredTime.trim();
    if (location.isNotEmpty) {
      subtitleParts.add(location);
    }
    if (preferredTime.isNotEmpty) {
      subtitleParts.add(preferredTime);
    }
    return subtitleParts.join(' • ');
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
    final appState = context.watch<GhmeraAppState>();
    final appBarRequest = appState.requestById(initialRequest.id);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        centerTitle: false,
        leading: uniformBackButton(context),
        title: uniformAppBarTitle(
          context,
          title: 'Request details',
          subtitle: _requestDetailsSubtitle(appBarRequest),
        ),
      ),
      body: SafeArea(
        child: Consumer<GhmeraAppState>(
          builder: (context, appState, _) {
            final request = appState.requestById(initialRequest.id);
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
            final hasConfirmedCompletion = appState
                .hasCurrentUserConfirmedRequestCompletion(request);
            final hasSubmittedReview = appState
                .hasCurrentUserSubmittedReviewForRequest(request);
            final canSubmitReview = appState
                .canCurrentUserSubmitReviewForRequest(request);
            final requesterCanRateNow =
                request.requesterId == appState.currentUserId &&
                canSubmitReview &&
                !hasSubmittedReview;
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
                if (timelineEntries.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  Text(
                    'Request timeline',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
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
                      children: [
                        for (
                          var index = 0;
                          index < timelineEntries.length;
                          index++
                        ) ...[
                          if (index > 0)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: Divider(height: 1),
                            ),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                margin: const EdgeInsets.only(top: 6),
                                decoration: const BoxDecoration(
                                  color: Color(0xFF103B36),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      timelineEntries[index].action,
                                      style: theme.textTheme.titleSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${_actionActorLabel(appState: appState, requester: requester, helper: helper, entry: timelineEntries[index])} • ${_relativeTime(timelineEntries[index].createdAt)}',
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: const Color(0xFF61726F),
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
                if (request.acceptedHelperId != null) ...[
                  const SizedBox(height: 18),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F3EB),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Contact permissions',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _Pill(
                              label:
                                  '${requester.fullName.split(' ').first}: ${request.contactConsentFromRequester ? 'Shared' : 'Pending'}',
                              color: request.contactConsentFromRequester
                                  ? const Color(0xFFE7F5ED)
                                  : const Color(0xFFFFF1D9),
                            ),
                            if (helper != null)
                              _Pill(
                                label:
                                    '${helper.fullName.split(' ').first}: ${request.contactConsentFromHelper ? 'Shared' : 'Pending'}',
                                color: request.contactConsentFromHelper
                                    ? const Color(0xFFE7F5ED)
                                    : const Color(0xFFFFF1D9),
                              ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          protectedThread == null
                              ? 'Protected chat has not been created for this request yet.'
                              : 'Protected chat active • Last message ${_relativeTime(protectedThread.lastMessageAt)}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: const Color(0xFF586965),
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
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
                if (isParticipant && request.acceptedHelperId != null) ...[
                  const SizedBox(height: 18),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F3EB),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Progress and accountability',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _Pill(
                              label: request.requesterCompletionConfirmed
                                  ? 'Requester confirmed'
                                  : 'Requester pending',
                              color: request.requesterCompletionConfirmed
                                  ? const Color(0xFFE7F5ED)
                                  : const Color(0xFFFFF1D9),
                            ),
                            _Pill(
                              label: request.helperCompletionConfirmed
                                  ? 'Helper confirmed'
                                  : 'Helper pending',
                              color: request.helperCompletionConfirmed
                                  ? const Color(0xFFE7F5ED)
                                  : const Color(0xFFFFF1D9),
                            ),
                            if (hasSubmittedReview)
                              const _Pill(
                                label: 'Your review submitted',
                                color: Color(0xFFE8F1FF),
                              ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          hasConfirmedCompletion
                              ? hasSubmittedReview
                                    ? request.status ==
                                              HelpRequestStatus.completed
                                          ? 'Your completion confirmation and rating are saved.'
                                          : 'Your completion confirmation and rating are saved. The request closes after the other participant confirms too.'
                                    : requesterCanRateNow
                                    ? 'Your completion confirmation is already saved. You can rate the help giver now while the request waits for the other participant to confirm.'
                                    : 'Your completion confirmation is already saved. The request closes after the other participant confirms too.'
                              : request.requesterId == appState.currentUserId
                              ? 'When the help is done, confirm completion here. You can rate the help giver as soon as your confirmation is saved.'
                              : 'When the help is done, confirm completion here. Reviews open once the request is fully completed.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: const Color(0xFF586965),
                            height: 1.45,
                          ),
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
          final request = appState.requestById(initialRequest.id);
          final protectedThread = appState.threadForRequest(request.id);
          final otherParticipant = appState.otherParticipantForRequest(request);
          final isParticipant = appState.isCurrentUserParticipantForRequest(
            request,
          );
          final chatLabel = otherParticipant == null
              ? 'Open protected chat'
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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
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
                          icon: const Icon(Icons.chat_bubble_outline_rounded),
                          label: Text(chatLabel),
                          style: chatActionButtonStyle,
                        ),
                      ),
                      if (helperCanVolunteer) const SizedBox(width: 12),
                      if (helperCanVolunteer)
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: alreadyMatchedAsHelper
                                ? null
                                : () async {
                                    final matched = await appState
                                        .volunteerForHelpRequest(request.id);
                                    if (!context.mounted) {
                                      return;
                                    }

                                    if (!matched) {
                                      showGhmeraSnackBar(
                                        context,
                                        message:
                                            'This request is no longer available for matching.',
                                        type: SnackBarType.error,
                                      );
                                      return;
                                    }

                                    showGhmeraSnackBar(
                                      context,
                                      message:
                                          'Match confirmed. Protected chat is now available.',
                                      type: SnackBarType.success,
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
                  if (isParticipant && request.acceptedHelperId != null) ...[
                    if (canStartRequest) const SizedBox(height: 12),
                    if (canStartRequest)
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => _handleStartRequestWork(
                            context,
                            appState,
                            request,
                          ),
                          icon: const Icon(Icons.play_circle_outline_rounded),
                          label: const Text('Mark help as in progress'),
                        ),
                      ),
                    if (canConfirmCompletion) const SizedBox(height: 12),
                    if (canConfirmCompletion)
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => _handleConfirmCompletion(
                            context,
                            appState,
                            request,
                          ),
                          icon: const Icon(Icons.task_alt_rounded),
                          label: const Text('Confirm completion'),
                        ),
                      ),
                    if (canSubmitReview && otherParticipant != null)
                      const SizedBox(height: 12),
                    if (canSubmitReview && otherParticipant != null)
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.tonalIcon(
                          onPressed: () => _openReviewSheet(
                            context,
                            request: request,
                            reviewee: otherParticipant,
                          ),
                          icon: Icon(
                            isHelpGiverRating
                                ? Icons.star_rate_rounded
                                : Icons.rate_review_outlined,
                          ),
                          label: Text(
                            isHelpGiverRating
                                ? 'Rate ${otherParticipant.fullName.split(' ').first}'
                                : 'Leave a review for ${otherParticipant.fullName.split(' ').first}',
                          ),
                        ),
                      ),
                  ],
                  if (otherParticipant != null) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _openSafetyReportSheet(
                          context,
                          request: request,
                          reportedUser: otherParticipant,
                        ),
                        icon: const Icon(Icons.report_problem_outlined),
                        label: Text(
                          'Report ${otherParticipant.fullName.split(' ').first}',
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
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
                color: const Color(0xFF61726F),
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
                color: const Color(0xFF61726F),
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
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF61726F),
                ),
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
                  : 'This sends an account report linked to ${widget.request!.title}.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF61726F),
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
                color: const Color(0xFF61726F),
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

    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: () =>
                context.read<GhmeraAppState>().refreshHelpRequests(),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
              children: [
                const _SectionHeader(
                  title: 'You accepted these requests',
                  subtitle:
                      'People requests you have already accepted to help with.',
                ),
                const SizedBox(height: 10),
                if (acceptedRequests.isNotEmpty)
                  for (final request in acceptedRequests)
                    _OpportunityCard(
                      request: request,
                      onLongPress: onRequestLongPress,
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
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF61726F),
                      ),
                    ),
                  ),
                const SizedBox(height: 14),
                const _SectionHeader(
                  title: 'Help requests',
                  subtitle:
                      'Remaining people requests you have not accepted yet.',
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
                      onLongPress: onRequestLongPress,
                      onReviewRequest: onReviewOpportunity,
                    ),
              ],
            ),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 6, 10, 12),
            child: Align(
              alignment: Alignment.centerRight,
              child: FloatingActionButton.extended(
                heroTag: 'giveHelpRequestLocationsFab',
                onPressed: () => _showRequestLocationsMapSheet(
                  context,
                  currentUser: appState.currentUser,
                  requestEntries: requestLocationEntries,
                ),
                backgroundColor: const Color(0xFF163C38),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(5),
                ),
                icon: const Icon(Icons.map_outlined),
                label: const Text('Request locations'),
              ),
            ),
          ),
        ),
      ],
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(5)),
      ),
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

class _RequestsTab extends StatelessWidget {
  const _RequestsTab({
    required this.onCreateRequest,
    required this.onEditRequest,
    required this.onLongPressMyRequest,
    required this.onManageAcceptedRequest,
    required this.onDirectRequestHelper,
  });

  final VoidCallback onCreateRequest;
  final ValueChanged<HelpRequestEntity> onEditRequest;
  final ValueChanged<HelpRequestEntity> onLongPressMyRequest;
  final ValueChanged<HelpRequestEntity> onManageAcceptedRequest;
  final ValueChanged<UserEntity> onDirectRequestHelper;

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<GhmeraAppState>();
    final currentUser = appState.currentUser;
    final nearbyHelpers = _nearbyHelpers(appState);
    final myPastRequests = appState.myRequests.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final acceptedRequests = myPastRequests
        .where(
          (request) =>
              request.acceptedHelperId != null &&
              request.status != HelpRequestStatus.canceled,
        )
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
                title: 'Your requests people accepted',
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
                  if (appState.helperForRequest(request) case final helper?)
                    _AcceptedMyRequestTile(
                      request: request,
                      helper: helper,
                      onTap: () => onManageAcceptedRequest(request),
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
                    onLongPress: () => onLongPressMyRequest(request),
                    onTap: () => onEditRequest(request),
                  ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 6, 10, 12),
            child: Row(
              children: [
                Expanded(
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
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showNeighborhoodHelpersMapSheet(
                      context,
                      currentUser: currentUser,
                      helpers: nearbyHelpers,
                      onSelectHelper: onDirectRequestHelper,
                    ),
                    icon: const Icon(Icons.map_outlined),
                    label: const Text('Nearby helpers'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(5)),
      ),
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
              borderRadius: BorderRadius.circular(5),
              child: SizedBox(
                height: 320,
                child: FlutterMap(
                  options: MapOptions(
                    initialCenter: data.mapCenter!,
                    initialZoom: data.helperMarkers.length > 5 ? 11.8 : 12.8,
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
                color: const Color(0xFF61726F),
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

      final approximatePoint = await _resolveApproximatePoint(
        helper.area,
        helper.city,
        cache: cache,
      );
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
      final locations = await locationFromAddress(query);
      if (locations.isEmpty) {
        return null;
      }

      final point = LatLng(locations.first.latitude, locations.first.longitude);
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

  bool get hasMap => mapCenter != null && helperMarkers.isNotEmpty;
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
            borderRadius: BorderRadius.circular(5),
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
                borderRadius: BorderRadius.circular(5),
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
                color: const Color(0xFF61726F),
              ),
            ),
            if (distanceLabel != null)
              Text(
                distanceLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF61726F),
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
                color: const Color(0xFF61726F),
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
    return FutureBuilder<_RequestLocationsMapData>(
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
        } else if (data == null || !data.hasMap) {
          children.add(
            _EmptyStateCard(
              title: 'No mappable requests yet',
              message: _emptyStateMessage(),
            ),
          );
        } else {
          children.addAll([
            ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: SizedBox(
                height: 320,
                child: FlutterMap(
                  options: MapOptions(
                    initialCenter: data.mapCenter!,
                    initialZoom: data.requestMarkers.length > 5 ? 11.8 : 12.8,
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
                        for (final marker in data.requestMarkers)
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
                color: const Color(0xFF61726F),
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
            for (
              var index = 0;
              index < data.requestMarkers.length;
              index++
            ) ...[
              _RequestLocationListTile(
                marker: data.requestMarkers[index],
                onTap: () =>
                    _handleRequestTap(data.requestMarkers[index].request),
              ),
              if (index < data.requestMarkers.length - 1)
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

      final approximatePoint = await _resolvePointFromQuery(
        locationLabel,
        cache: cache,
      );
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
      final locations = await locationFromAddress(normalizedQuery);
      if (locations.isEmpty) {
        return null;
      }

      final point = LatLng(locations.first.latitude, locations.first.longitude);
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

  String _emptyStateMessage() {
    if (widget.requestEntries.isEmpty) {
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

  bool get hasMap => mapCenter != null && requestMarkers.isNotEmpty;
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
            ? '${marker.request.title}\n${marker.requester.fullName}\n${marker.locationLabel}'
            : '${marker.request.title}\n${marker.requester.fullName}\n${marker.locationLabel}\n$distanceLabel',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: BorderRadius.circular(5),
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
        onTap: onTap,
        isThreeLine: true,
        titleAlignment: ListTileTitleAlignment.center,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: _RequesterAvatar(requester: marker.requester, size: 56),
        title: Text(
          marker.request.title,
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
                color: const Color(0xFF61726F),
              ),
            ),
            if (distanceLabel != null)
              Text(
                distanceLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF61726F),
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
                color: const Color(0xFF61726F),
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
                    color: const Color(0xFF61726F),
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
                              '${request.title} restored to your requests.',
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
  const _SectionHeader({required this.title, this.subtitle = ''});

  final String title;
  final String subtitle;

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
      ],
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
  const _MyRequestTile({
    required this.request,
    required this.onTap,
    required this.onLongPress,
  });

  final HelpRequestEntity request;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

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
        onLongPress: onLongPress,
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
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
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
            color: const Color(0xFFF1EADF),
            borderRadius: BorderRadius.circular(5),
          ),
          child: const Icon(Icons.visibility_off_outlined),
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
        trailing: IconButton(
          tooltip: 'Restore request',
          onPressed: onRestore,
          icon: const Icon(Icons.visibility_outlined),
        ),
      ),
    );
  }
}

class _OpportunityCard extends StatelessWidget {
  const _OpportunityCard({
    required this.request,
    required this.onLongPress,
    required this.onReviewRequest,
  });

  final HelpRequestEntity request;
  final ValueChanged<HelpRequestEntity> onLongPress;
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
            onLongPress: () => onLongPress(request),
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
    final filledStars = ((trustScore / 20).round()).clamp(0, 5);

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
                errorBuilder: (_, _, _) => _fallbackAvatar(initials),
              )
            : Image.asset(
                photoPath,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _fallbackAvatar(initials),
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
    final color = foregroundColor ?? const Color(0xFF103B36);

    return ListTile(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      onTap: onTap,
      leading: Icon(icon, color: color),
      title: Text(
        label,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: color,
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
  const _HeroPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0x1FFFFFFF),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: Colors.white),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 14,
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
