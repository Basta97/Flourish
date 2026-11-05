import 'package:flourish/shared/widgets/animated_list_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Rows of a lazy list are built during the viewport's first layout, before
  // the scroll extents exist; reading them there once crashed Insights.
  testWidgets('builds in a lazy list on the first frame', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ListView.builder(
          itemCount: 3,
          itemBuilder: (context, i) =>
              AnimatedListItem(index: i, child: Text('row $i')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('row 0'), findsOneWidget);
  });

  testWidgets('rows built mid-scroll skip the entrance', (tester) async {
    final controller = ScrollController();
    await tester.pumpWidget(
      MaterialApp(
        home: ListView.builder(
          controller: controller,
          itemCount: 200,
          itemExtent: 50,
          itemBuilder: (context, i) =>
              AnimatedListItem(index: i, child: Text('row $i')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    controller.jumpTo(5000);
    await tester.pump();
    // No animation is pending, so the newly built row is already settled.
    expect(tester.hasRunningAnimations, isFalse);
    expect(find.text('row 100'), findsOneWidget);
  });
}
