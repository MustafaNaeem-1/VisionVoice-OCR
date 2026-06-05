import 'package:flutter_test/flutter_test.dart';
import 'package:vision_voice/main.dart';

void main() {
  testWidgets('VisionVoice app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const VisionVoiceApp());
    expect(find.byType(VisionVoiceApp), findsOneWidget);
  });
}
