import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:ghmera_app/app/models/ghmera_models.dart';
import 'package:ghmera_app/app/providers/ghmera_app_state.dart';
import 'package:ghmera_app/app/services/help_credits.dart';
import 'package:ghmera_app/features/help_request/presentation/screens/create_request_screen.dart';

class _FakeGhmeraAppState extends ChangeNotifier implements GhmeraAppState {
  @override
  UserEntity get currentUser => const UserEntity(
    id: 'test-user',
    fullName: 'Test User',
    email: 'test@example.com',
    city: 'Accra',
    area: 'East Legon',
  );

  @override
  HelpCreditSummary get currentUserCredits =>
      const HelpCreditSummary(earned: 0, spent: 0, held: 0);

  @override
  bool get canCreateRequest => true;

  @override
  void addListener(VoidCallback listener) {}

  @override
  void removeListener(VoidCallback listener) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('invalid description scrolls back to the detail field', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ChangeNotifierProvider<GhmeraAppState>.value(
        value: _FakeGhmeraAppState(),
        child: const MaterialApp(home: CreateRequestScreen()),
      ),
    );
    await tester.pump();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Short title'),
      'Need help setting up my router',
    );
    await tester.pumpAndSettle();

    final scrollable = tester.state<ScrollableState>(
      find.byType(Scrollable).first,
    );
    scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
    await tester.pumpAndSettle();
    final positionBeforeSubmit = scrollable.position.pixels;
    expect(positionBeforeSubmit, greaterThan(0));

    await tester.tap(
      find.text('Post request · uses $requestCreditCost credits'),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Add a little more detail so helpers understand the request.'),
      findsOneWidget,
    );
    expect(scrollable.position.pixels, lessThan(positionBeforeSubmit));

    final descriptionField = find.widgetWithText(TextFormField, 'Details');
    expect(tester.getBottomLeft(descriptionField).dy, lessThan(700));
  });
}
