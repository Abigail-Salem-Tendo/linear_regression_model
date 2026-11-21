import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

// Your Render URL
const String apiBaseUrl = 'https://rwanda-outage-api.onrender.com';

/// The outcome of one prediction request either minutes, or an error message.
/// If the API rejected one specific input, fieldKey says which one (e.g. 'C031B').
class PredictionResult {
  final double? minutes;
  final String? error;
  final String? fieldKey;

  const PredictionResult.success(double this.minutes)
    : error = null,
      fieldKey = null;

  const PredictionResult.failure(String this.error, {this.fieldKey})
    : minutes = null;

  bool get isSuccess => minutes != null;
}

/// Sends the 12 inputs to POST /predict and returns the prediction or an error.
Future<PredictionResult> predictOutage(Map<String, int> inputs) async {
  try {
    final response = await http
        .post(
          Uri.parse('$apiBaseUrl/predict'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(inputs),
        )
        // Render's free plan can take about a minute to wake up
        .timeout(const Duration(seconds: 90));

    if (response.statusCode == 200) {
      final minutes =
          jsonDecode(response.body)['predicted_outage_minutes'] as num;
      return PredictionResult.success(minutes.toDouble());
    }
    if (response.statusCode == 422) {
      return _readValidationError(response.body);
    }
    return PredictionResult.failure(
      'Server error (${response.statusCode}). Please try again.',
    );
  } on TimeoutException {
    return const PredictionResult.failure(
      'The server took too long. It may be waking up, so try again in a moment.',
    );
  } on http.ClientException {
    return const PredictionResult.failure(
      'Could not reach the server. Check your internet connection.',
    );
  } catch (e) {
    return PredictionResult.failure('Something went wrong: $e');
  }
}

/// Turns the API's 422 response into a short, plain message.
PredictionResult _readValidationError(String responseBody) {
  try {
    final first = (jsonDecode(responseBody)['detail'] as List).first;
    final loc = first['loc'] as List;
    String? fieldKey = loc.length > 1 ? loc.last.toString() : null;
    String message = first['msg'].toString().replaceFirst('Value error, ', '');

    // Unknown code, e.g. "DISTRICT=20 is not a valid code. Allowed: [...]"
    final codeError = RegExp(r'^(\w+)=(-?\d+) is not a valid code')
        .firstMatch(message);
    if (codeError != null) {
      fieldKey = codeError.group(1);
      message = '${codeError.group(2)} is not an allowed code';
    }

    message = message
        .replaceFirst(
          'Input should be less than or equal to',
          'must be at most',
        )
        .replaceFirst(
          'Input should be greater than or equal to',
          'must be at least',
        )
        .replaceFirst(
          'Input should be a valid integer',
          'must be a whole number',
        );

    return PredictionResult.failure(message, fieldKey: fieldKey);
  } catch (_) {
    return const PredictionResult.failure('One of the values is not valid.');
  }
}
