import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:ghmera_app/app/models/ghmera_models.dart';
import 'package:ghmera_app/app/providers/ghmera_app_state.dart';
import 'package:ghmera_app/features/help_request/presentation/screens/create_request_screen.dart';

class _FakeGhmeraAppState implements GhmeraAppState {
  @override
  UserEntity get currentUser => const UserEntity(
    id: 'test-user',
    fullName: 'Test User',
    email: 'test@example.com',
    city: 'Accra',
    area: 'East Legon',
  );

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
      find.widgetWithText(TextFormField, 'Request title'),
      'Need help setting up my router',
    );

    final submitButton = find.text('Submit Request for Matching');
    await tester.scrollUntilVisible(
      submitButton,
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    final scrollable = tester.state<ScrollableState>(
      find.byType(Scrollable).first,
    );
    final positionBeforeSubmit = scrollable.position.pixels;

    await tester.tap(submitButton);
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Add enough detail for a trusted helper to understand the request.',
      ),
      findsOneWidget,
    );
    expect(scrollable.position.pixels, lessThan(positionBeforeSubmit));

    final descriptionField = find.widgetWithText(
      TextFormField,
      'Detailed description',
    );
    expect(tester.getBottomLeft(descriptionField).dy, lessThan(700));
  });
}
