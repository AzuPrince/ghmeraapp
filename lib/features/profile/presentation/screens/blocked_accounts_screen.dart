import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../app/models/ghmera_models.dart';
import '../../../../app/providers/ghmera_app_state.dart';
import '../../../../core/ui/app_snack_bar.dart';
import '../../../../core/ui/uniform_app_bar.dart';

class BlockedAccountsScreen extends StatelessWidget {
  const BlockedAccountsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appState = context.watch<GhmeraAppState>();
    final user = appState.currentUser;
    final blockedUserIds = user.blockedUserIds;

    final blockedUsers = blockedUserIds
        .map((id) {
          try {
            return appState.userById(id);
          } catch (_) {
            return null;
          }
        })
        .whereType<UserEntity>()
        .toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        centerTitle: false,
        leading: uniformBackButton(context),
        title: uniformAppBarTitle(
          context,
          title: 'Blocked Accounts',
          subtitle: 'Manage accounts you have restricted.',
        ),
      ),
      body: blockedUsers.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF103B36).withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.block_rounded,
                        size: 48,
                        color: Color(0xFF103B36),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'No Blocked Accounts',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF103B36),
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Accounts you block will appear here. You will not see their requests, and they will not see yours.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF697774),
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: blockedUsers.length,
              itemBuilder: (context, index) {
                final blockedUser = blockedUsers[index];

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE6ECEB)),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x0A000000),
                        blurRadius: 16,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 8,
                    ),
                    leading: CircleAvatar(
                      radius: 22,
                      backgroundColor: const Color(0xFF103B36),
                      backgroundImage: blockedUser.profilePhoto != null &&
                              blockedUser.profilePhoto!.isNotEmpty
                          ? (blockedUser.profilePhoto!.startsWith('http')
                              ? NetworkImage(blockedUser.profilePhoto!)
                              : AssetImage(blockedUser.profilePhoto!) as ImageProvider)
                          : null,
                      child: blockedUser.profilePhoto == null ||
                              blockedUser.profilePhoto!.isEmpty
                          ? Text(
                              blockedUser.fullName.isNotEmpty
                                  ? blockedUser.fullName[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          : null,
                    ),
                    title: Text(
                      blockedUser.fullName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF103B36),
                      ),
                    ),
                    trailing: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF103B36),
                        side: const BorderSide(color: Color(0xFF103B36)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                      ),
                      onPressed: () {
                        final success =
                            appState.unblockUserAccount(blockedUser.id);
                        if (success && context.mounted) {
                          showGhmeraSnackBar(
                            context,
                            message: '${blockedUser.fullName} has been unblocked.',
                            type: SnackBarType.success,
                          );
                        }
                      },
                      child: const Text('Unblock'),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
