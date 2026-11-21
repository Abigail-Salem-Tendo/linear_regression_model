import 'package:flutter/material.dart';

/// One model input: the API key, a plain-language label and what to type.
class InputField {
  final String key;
  final String label;
  final String hint;
  final Map<int, String> options;
  final Map<String, int> names;
  final bool wordsOnly;

const InputField(this.key, this.label,
      {this.hint = '', this.options = const {}, this.names = const {}, this.wordsOnly = false});

  /// True if the field accepts words as well as numbers.
  bool get acceptsWords => options.isNotEmpty || names.isNotEmpty;

  /// The code to send to the API, or null if the text is not valid.
  int? toCode(String text) {
    final typed = text.trim().toLowerCase();
    if (!wordsOnly) {
      final number = int.tryParse(typed);
      if (number != null) return number;
    }
    for (final option in options.entries) {
      if (option.value.toLowerCase() == typed) return option.key;
    }
    return names[typed];
  }

  /// What to tell the user when the value is not valid.
  String get problemText {
    if (wordsOnly) {
      return 'must be ${options.values.map((v) => v.toLowerCase()).join(' or ')}';
    }
    if (acceptsWords) return 'must be a number or one of the options shown';
    return 'must be a whole number';
  }
}

/// A titled group of fields shown together in one card.
class FieldSection {
  final String title;
  final IconData icon;
  final List<InputField> fields;
  const FieldSection(this.title, this.icon, this.fields);
}

const String typeNumberOrWord = 'Type the number or the word';

const Map<String, int> districts = {
  'nyarugenge': 11, 'gasabo': 12, 'kicukiro': 13,
  'nyanza': 21, 'gisagara': 22, 'nyaruguru': 23, 'huye': 24,
  'nyamagabe': 25, 'ruhango': 26, 'muhanga': 27, 'kamonyi': 28,
  'karongi': 31, 'rutsiro': 32, 'rubavu': 33, 'nyabihu': 34,
  'ngororero': 35, 'rusizi': 36, 'nyamasheke': 37,
  'rulindo': 41, 'gakenke': 42, 'musanze': 43, 'burera': 44, 'gicumbi': 45,
  'rwamagana': 51, 'nyagatare': 52, 'gatsibo': 53, 'kayonza': 54,
  'kirehe': 55, 'ngoma': 56, 'bugesera': 57,
};

// Codes come from the survey's value labels. Note: C026 uses 1 = yes, 2 = no,
// while C028B and C038 use 1 = yes, 0 = no. Keys must match the API exactly.
const List<FieldSection> sections = [
  FieldSection('Outages & connection', Icons.bolt, [
    InputField('C031B', 'Outages per week', hint: 'Whole number from 1 to 10'),
    InputField('C006', 'Years connected to the grid', hint: 'Whole number from 1 to 40'),
  ]),
  FieldSection('Location', Icons.place_outlined, [
    InputField('DISTRICT', 'District',
        hint: 'Type the name (e.g. Gasabo)',
        names: districts),
    InputField('HI04', 'Urban or rural', hint: 'Type urban or rural',
        options: {1: 'Urban', 2: 'Rural'}, wordsOnly: true),
  ]),
  FieldSection('Household & wiring', Icons.home_outlined, [
    InputField('TYPEHH', 'Type of household', hint: typeNumberOrWord,
        options: {1: 'Ordinary household', 3: 'Near a refugee camp'}),
    InputField('C008', 'How the home is wired to the grid', hint: typeNumberOrWord,
        options: {1: 'Ready-board', 2: 'Internal wiring', 3: 'Both'}),
    InputField('C038', 'Is the wiring insulated?', hint: 'Type yes or no',
        options: {1: 'Yes', 0: 'No'}, wordsOnly: true),
  ]),
  FieldSection('Billing & payment', Icons.receipt_long_outlined, [
    InputField('C012', 'Who receives the payment', hint: typeNumberOrWord, options: {
      1: 'Energy company', 2: 'Prepaid card seller', 3: 'Community/village',
      4: 'Relative', 5: 'Neighbour', 6: 'Landlord', 7: 'Local store',
      9: 'Bank', 111: 'No one', 555: 'Other',
    }),
    InputField('C018', 'How the household is billed', hint: typeNumberOrWord, options: {
      1: 'Fixed monthly fee', 2: 'By appliances used', 3: 'Utility estimate',
      4: 'Self top-up', 111: 'No bill', 555: 'Other',
    }),
    InputField('C019', 'How electricity is paid', hint: typeNumberOrWord, options: {
      1: 'Cash', 2: 'Store voucher/card', 3: 'Mobile money',
      4: 'Other credit', 5: 'Agency voucher', 555: 'Other',
    }),
  ]),
  FieldSection('Service quality', Icons.signal_cellular_alt, [
    InputField('C026', 'Same quality all year?', hint: 'Type yes or no',
        options: {1: 'Yes', 2: 'No'}, wordsOnly: true),
    InputField('C028B', 'Told about load shedding?', hint: 'Type yes or no',
        options: {1: 'Yes', 0: 'No'}, wordsOnly: true),
  ]),
];

/// All 12 fields in one flat list, in the same order as above.
final List<InputField> allFields = [for (final s in sections) ...s.fields];

/// Plain label for an API key, e.g. 'C031B' -> 'Outages per week'.
String labelFor(String key) =>
    allFields.firstWhere((f) => f.key == key, orElse: () => InputField(key, key)).label;