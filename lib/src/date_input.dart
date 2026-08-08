import 'package:flutter/services.dart';

import 'model.dart';

class DotDateInputFormatter extends TextInputFormatter {
  const DotDateInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final clipped = digits.length > 8 ? digits.substring(0, 8) : digits;
    final buffer = StringBuffer();
    for (var index = 0; index < clipped.length; index++) {
      if (index == 2 || index == 4) {
        buffer.write('.');
      }
      buffer.write(clipped[index]);
    }
    final text = buffer.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

final dateInputFormatters = <TextInputFormatter>[
  DotDateInputFormatter(),
  LengthLimitingTextInputFormatter(10),
];

String dateInputText(String isoOrDisplay) => displayDateKey(isoOrDisplay);

String dateStorageText(String input, {required String fallback}) =>
    normalizeDateKey(input, fallback: fallback);
