import "dart:convert";
import "package:http/http.dart" as http;
import "../api_exception.dart";
import "../models/highscore.dart";
import "../models/evaluation_result.dart";

class SessionRepository {
  final String baseUrl;
  final http.Client _client;

  SessionRepository({required this.baseUrl}) : _client = http.Client();

  Future<int> createSession(String username, String pdbId) async {
    final response = await _client.post(
      Uri.parse("$baseUrl/session"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"username": username, "pdb_id": pdbId})
    );
    _assertOk(response);
    return (jsonDecode(response.body) as Map<String, dynamic>)["session_id"] as int;
  }

  Future<Highscore> getHighscore() async {
    final response = await _client.get(Uri.parse("$baseUrl/highscore"));
    _assertOk(response);
    return Highscore.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<EvaluationResult> evaluate({required int sessionId, required String pdbId, required String mutant}) async {
    final response = await _client.post(
      Uri.parse("$baseUrl/evaluate"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"session_id": sessionId, "pdb_id": pdbId, "mutant": mutant}),
    );
    _assertOk(response);
    return EvaluationResult.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  void _assertOk(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(response.statusCode, response.body);
    }
  }
}