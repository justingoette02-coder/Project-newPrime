import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:newprime/main.dart';
import 'package:newprime/services/app_state.dart';

void main() {
  testWidgets('App startet und zeigt das Dashboard', (WidgetTester tester) async {
    // NewPrimeApp braucht einen AppState; Prefs werden gemockt, falls
    // zwischendurch gespeichert wird.
    SharedPreferences.setMockInitialValues({});
    final state = AppState();

    await tester.pumpWidget(NewPrimeApp(state: state));
    await tester.pump();

    // Dashboard ist da: Marken-Schriftzug + Start-CTA.
    expect(find.text('newPRIME'), findsOneWidget);
    expect(find.text('Session starten'), findsOneWidget);

    // Aufraeumen: Screen disposen und den selbst-planenden Blink-Timer der
    // Aura-Augen ablaufen lassen (max. ~5,2 s), damit der Test keine offenen
    // Timer meldet. pumpAndSettle scheidet aus — die Aura-Animation laeuft
    // endlos.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 6));
  });
}
