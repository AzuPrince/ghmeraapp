import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../app/models/ghmera_models.dart';
import '../../../../app/providers/ghmera_app_state.dart';
import '../../../../core/ui/app_snack_bar.dart';

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
      backgroundColor: const Color(0xFFF7F9F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Blocked Accounts',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: const Color(0xFF1D3037),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1D3037)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: blockedUsers.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.block_rounded,
                      size: 64,
                      color: Color(0xFFDCE2E9),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No blocked accounts',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1D3037),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Accounts you block will appear here. You will not see their requests, and they will not see yours.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF697774),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: blockedUsers.length,
              separatorBuilder: (context, index) => const Divider(
                height: 1,
                color: Color(0xFFE7F0ED),
                indent: 72,
              ),
              itemBuilder: (context, index) {
                final blockedUser = blockedUsers[index];
                
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  leading: CircleAvatar(
                    radius: 20,
                    backgroundColor: const Color(0xFFE7F1EE),
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
                              color: Color(0xFF103B36),
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  ),
                  title: Text(
                    blockedUser.fullName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1D3037),
                    ),
                  ),
                  trailing: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF103B36),
                      side: const BorderSide(color: Color(0xFF103B36)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    onPressed: () {
                      final success = appState.unblockUserAccount(blockedUser.id);
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
                );
              },
            ),
    );
  }
}
