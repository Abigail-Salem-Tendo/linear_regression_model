import 'package:flutter/material.dart';

/// One model input: the API key, a plain-language label and what to type.
class InputField {
  final String key;
  final String label;
  final String hint;
  const InputField(this.key, this.label, this.hint);
}

/// A titled group of fields shown together in one card.
class FieldSection {
  final String title;
  final IconData icon;
  final List<InputField> fields;
  const FieldSection(this.title, this.icon, this.fields);
}

// Allowed values come from the API (/docs). Keys must match the API exactly.
const List<FieldSection> sections = [
  FieldSection('Outages & connection', Icons.bolt, [
    InputField('C031B', 'Outages per week', 'Whole number from 1 to 10'),
    InputField(
      'C006',
      'Years connected to the grid',
      'Whole number from 1 to 40',
    ),
  ]),
  FieldSection('Location', Icons.place_outlined, [
    InputField(
      'DISTRICT',
      'District code',
      'Two-digit code: 11–13, 21–28, 31–37, 41–45 or 51–57',
    ),
    InputField('HI04', 'Urban or rural', '1 or 2'),
  ]),
  FieldSection('Household & wiring', Icons.home_outlined, [
    InputField('TYPEHH', 'Type of household', '1 or 3'),
    InputField('C008', 'How the home is wired to the grid', '1, 2 or 3'),
    InputField('C038', 'Is the wiring insulated?', '0 or 1'),
  ]),
  FieldSection('Billing & payment', Icons.receipt_long_outlined, [
    InputField(
      'C012',
      'Who receives the payment',
      '1–7, 9, 111 (none) or 555 (other)',
    ),
    InputField(
      'C018',
      'How the household is billed',
      '1–4, 111 (none) or 555 (other)',
    ),
    InputField('C019', 'How electricity is paid', '1–5 or 555 (other)'),
  ]),
  FieldSection('Service quality', Icons.signal_cellular_alt, [
    InputField('C026', 'Same quality all year?', '1 or 2'),
    InputField('C028B', 'Told about load shedding?', '0 or 1'),
  ]),
];

/// All 12 fields in one flat list, in the same order as above.
final List<InputField> allFields = [for (final s in sections) ...s.fields];

/// Plain label for an API key, e.g. 'C031B' -> 'Outages per week'.
String labelFor(String key) => allFields
    .firstWhere((f) => f.key == key, orElse: () => InputField(key, key, ''))
    .label;
