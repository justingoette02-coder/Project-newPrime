import 'package:flutter_test/flutter_test.dart';
import 'package:newprime/main.dart';

void main() {
  testWidgets('App startet und zeigt das Dashboard', (WidgetTester tester) async {
    await tester.pumpWidget(const NewPrimeApp());
    await tester.pump();

    // Der Marken-Schriftzug im Kopf des Dashboards muss da sein.
    expect(find.text('newPRIME'), findsOneWidget);
    // Der Name des Nutzers wird angezeigt.
    expect(find.text('Justin'), findsOneWidget);
  });
}
