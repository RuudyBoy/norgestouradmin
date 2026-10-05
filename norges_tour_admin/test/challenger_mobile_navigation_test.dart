import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Challenger verification: Default test window size vs physicalSize', (tester) async {
    // 1. Default test window size is 800x600 (Tablet width)
    expect(MediaQueryData.fromView(tester.view).size.width, 800.0);

    // 2. Setting tester.view.physicalSize updates logical width when ratio is 1.0
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    expect(MediaQueryData.fromView(tester.view).size.width, 1200.0);
  });
}
