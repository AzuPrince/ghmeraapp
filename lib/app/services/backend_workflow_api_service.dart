import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:http/http.dart' as http;

import '../../firebase_options.dart';

class BackendWorkflowApiException implements Exception {
  const BackendWorkflowApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() {
    return statusCode == null
        ? 'BackendWorkflowApiException: $message'
        : 'BackendWorkflowApiException($statusCode): $message';
  }
}

class BackendWorkflowApiResult {
  const BackendWorkflowApiResult({required this.database, this.result});

  final Map<String, dynamic> database;
  final Map<String, dynamic>? result;
}

class BackendWorkflowApiService {
  BackendWorkflowApiService({http.Client? client}) : _client = client ?? http.Client();

  static const String _workflowApiUrl = String.fromEnvironment(
    'GHMERA_WORKFLOW_API_URL',
  );
  static const String _functionsRegion = String.fromEnvironment(
    'GHMERA_FUNCTIONS_REGION',
    defaultValue: 'us-central1',
  );

  final http.Client _client;

  Future<BackendWorkflowApiResult> applyOperation({
    required String operation,
    required String currentUserId,
    required Map<String, dynamic> database,
    Map<String, dynamic> payload = const <String, dynamic>{},
  }) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (Firebase.apps.isNotEmpty) {
      final user = FirebaseAuth.instance.currentUser;
      final token = await user?.getIdToken();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    final response = await _client
        .post(
          _workflowUri(),
          headers: headers,
          body: jsonEncode(<String, dynamic>{
            'operation': operation,
            'currentUserId': currentUserId,
            'database': database,
            'payload': payload,
          }),
        )
        .timeout(const Duration(seconds: 20));

    final body = response.body.trim();
    final decoded = body.isEmpty ? const <String, dynamic>{} : jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      throw BackendWorkflowApiException(
        'Workflow API returned an invalid response.',
        statusCode: response.statusCode,
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw BackendWorkflowApiException(
        decoded['error']?.toString() ?? 'Workflow API request failed.',
        statusCode: response.statusCode,
      );
    }

    final rawDatabase = decoded['database'];
    if (rawDatabase is! Map<String, dynamic>) {
      throw const BackendWorkflowApiException(
        'Workflow API response did not include app-state data.',
      );
    }

    final rawResult = decoded['result'];
    return BackendWorkflowApiResult(
      database: rawDatabase,
      result: rawResult is Map<String, dynamic> ? rawResult : null,
    );
  }

  Uri _workflowUri() {
    final overrideUrl = _workflowApiUrl.trim();
    if (overrideUrl.isNotEmpty) {
      return Uri.parse(overrideUrl);
    }

    final projectId = DefaultFirebaseOptions.currentPlatform.projectId.trim();
    if (projectId.isEmpty) {
      throw const BackendWorkflowApiException(
        'Firebase project ID is missing. Set GHMERA_WORKFLOW_API_URL or configure Firebase options.',
      );
    }

    return Uri.parse(
      'https://$_functionsRegion-$projectId.cloudfunctions.net/workflow_api',
    );
  }
}