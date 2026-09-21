import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:online_shop_mvp_full/l10n/app_localizations.dart';

void main() {
  test('feedback messages translate to Khmer', () {
    const km = Locale('km');
    const en = Locale('en');
    final khmer = AppLocalizations(km);
    final english = AppLocalizations(en);

    // Exact rows from the user's screenshot
    expect(khmer.feedbackMessage("It's difficult for me"), 'វាពិបាកសម្រាប់ខ្ញុំ');
    expect(khmer.feedbackMessage("It's not good for me"), contains('មិនល្អ'));
    expect(khmer.feedbackMessage('Good thanks .'), contains('អរគុណ'));
    expect(khmer.feedbackMessage('Good website.'), 'គេហទំព័រល្អ');

    // Case / punctuation tolerance
    expect(khmer.feedbackMessage('GOOD WEBSITE!'), 'គេហទំព័រល្អ');
    expect(khmer.feedbackMessage('very good'), 'ល្អណាស់');

    // English mode stays untouched
    expect(english.feedbackMessage('Good website.'), 'Good website.');
  });
}
