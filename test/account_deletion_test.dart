import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ghmera_app/features/profile/presentation/widgets/account_deletion_button.dart';

void main() {
  testWidgets(
    'account deletion explains the impact and requires confirmation',
    (tester) async {
      var deleteAccountCalls = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AccountDeletionButton(
              isLoading: false,
              onDeleteConfirmed: () async {
                deleteAccountCalls += 1;
              },
            ),
          ),
        ),
      );

      await tester.tap(find.widgetWithText(OutlinedButton, 'Delete account'));
      await tester.pumpAndSettle();

      expect(find.text('Permanently delete account?'), findsOneWidget);
      expect(find.textContaining('This cannot be undone'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Delete account'));
      await tester.pumpAndSettle();

      expect(deleteAccountCalls, 1);
    },
  );
}
