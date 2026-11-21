import 'package:flutter/material.dart';

import 'api_service.dart';
import 'input_fields.dart';

void main() => runApp(const OutageApp());

class OutageApp extends StatelessWidget {
  const OutageApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Outage Predictor',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF183642),
          primary: const Color(0xFF183642), // the button uses exactly this colour
        ),
        useMaterial3: true,
      ),
      home: const PredictionPage(),
    );
  }
}

enum ResultState { idle, loading, success, error }

class PredictionPage extends StatefulWidget {
  const PredictionPage({super.key});

  @override
  State<PredictionPage> createState() => _PredictionPageState();
}

class _PredictionPageState extends State<PredictionPage> {
  final _controllers = {for (final f in allFields) f.key: TextEditingController()};
  final _scroll = ScrollController();

  ResultState _state = ResultState.idle;
  String _message = 'Fill in all 12 fields, then tap Predict.';
  String? _badField; // key of the field to mark in red, if any

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    _scroll.dispose();
    super.dispose();
  }

  /// Updates the result area, marks the bad field (if any) and scrolls down to it.
  void _show(ResultState state, String message, {String? badField}) {
    setState(() {
      _state = state;
      _message = message;
      _badField = badField;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _predict() async {
    FocusScope.of(context).unfocus();

    // 1. Check for missing values and wrong types
    final inputs = <String, int>{};
    for (final f in allFields) {
      final text = _controllers[f.key]!.text.trim();
      final code = f.toCode(text);
      if (code == null) {
        final problem = text.isEmpty ? 'is missing' : f.problemText;
        _show(ResultState.error, '${f.label} $problem.', badField: f.key);
        return;
      }
      inputs[f.key] = code;
    }

    // 2. Send the values to the API (see api_service.dart)
    _show(ResultState.loading, 'Predicting… the first request can take up to a minute.');
    final result = await predictOutage(inputs);
    if (!mounted) return;

    // 3. Show the prediction, or the API's error (e.g. a value out of range)
    if (result.isSuccess) {
      _show(ResultState.success, '${result.minutes!.toStringAsFixed(1)} minutes');
    } else if (result.fieldKey != null) {
      _show(ResultState.error, '${labelFor(result.fieldKey!)} ${result.error}.',
          badField: result.fieldKey);
    } else {
      _show(ResultState.error, result.error!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Outage Predictor'), centerTitle: true),
      body: SafeArea(
        child: ListView(
          controller: _scroll,
          padding: const EdgeInsets.all(16),
          children: [
            Text('How long will outages last?',
                style: text.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text('Estimates the total outage time in a typical week for a '
                'grid-connected household in Rwanda. Fill in all 12 fields: type a '
                'value or tap one of the options.'),
            const SizedBox(height: 16),
            for (final section in sections) _buildSection(section, colors, text),
            SizedBox(
              height: 52,
              child: FilledButton(
                onPressed: _state == ResultState.loading ? null : _predict,
                child: const Text('Predict', style: TextStyle(fontSize: 16)),
              ),
            ),
            const SizedBox(height: 16),
            _buildResult(colors, text),
          ],
        ),
      ),
    );
  }

  /// One card: a titled group of fields.
  Widget _buildSection(FieldSection section, ColorScheme colors, TextTheme text) {
    return Card(
      elevation: 0,
      color: colors.surfaceContainerLow,
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(section.icon, color: colors.primary),
              const SizedBox(width: 8),
              Text(section.title, style: text.titleMedium),
            ]),
            const SizedBox(height: 14),
            for (final f in section.fields) _buildField(f),
          ],
        ),
      ),
    );
  }

  /// One labelled text field, with its options as tappable chips underneath.
  Widget _buildField(InputField f) {
    final controller = _controllers[f.key]!;

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: controller,
            keyboardType: f.acceptsWords
                ? TextInputType.text
                : const TextInputType.numberWithOptions(signed: true, decimal: true),
            onChanged: (_) => setState(() {
              if (_badField == f.key) _badField = null;
            }),
            decoration: InputDecoration(
              labelText: f.label,
              helperText: '${f.hint}  ·  ${f.key}',
              helperMaxLines: 3,
              errorText: _badField == f.key ? 'Check this value' : null,
              filled: true,
              border: const OutlineInputBorder(),
            ),
          ),
          if (f.options.isNotEmpty && !f.wordsOnly) ...[
            const SizedBox(height: 6),
            for (final option in f.options.entries)
              Padding(
                padding: const EdgeInsets.only(left: 12, top: 2),
                child: Text('${option.key}  ${option.value}',
                    style: Theme.of(context).textTheme.bodyMedium),
              ),
          ],
        ],
      ),
    );
  }

  /// The display area: hint, spinner, prediction, or error message.
  Widget _buildResult(ColorScheme colors, TextTheme text) {
    final (background, foreground, icon) = switch (_state) {
      ResultState.success => (colors.primaryContainer, colors.onPrimaryContainer, Icons.timer_outlined),
      ResultState.error => (colors.errorContainer, colors.onErrorContainer, Icons.error_outline),
      _ => (colors.surfaceContainerHighest, colors.onSurfaceVariant, Icons.info_outline),
    };
    final isSuccess = _state == ResultState.success;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          _state == ResultState.loading
              ? const CircularProgressIndicator()
              : Icon(icon, color: foreground, size: 32),
          const SizedBox(height: 10),
          Text(
            _message,
            textAlign: TextAlign.center,
            style: (isSuccess ? text.headlineMedium : text.bodyLarge)?.copyWith(
                color: foreground, fontWeight: isSuccess ? FontWeight.bold : null),
          ),
          if (isSuccess)
            Text('Estimated total outage time in a typical week',
                textAlign: TextAlign.center,
                style: text.bodyMedium?.copyWith(color: foreground)),
        ],
      ),
    );
  }
}