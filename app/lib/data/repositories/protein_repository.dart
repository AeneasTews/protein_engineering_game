import "dart:convert";
import "package:http/http.dart" as http;
import "../models/highscore.dart";
import "../models/protein.dart";
import "../api_exception.dart";

class ProteinRepository {
  final String baseUrl;
  final http.Client _client;

  ProteinRepository({required this.baseUrl}) : _client = http.Client();

  Future<List<Protein>> getProteins() async {
    final response = await _client.get(Uri.parse("$baseUrl/proteins"));
    _assertOk(response);
    final List<dynamic> json = jsonDecode(response.body);
    return json.map((e) => Protein.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Map<String, Highscore>> getHighscores(List<String> pdbIds) async {
    final response = await _client.post(
      Uri.parse("$baseUrl/highscores"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"pdb_ids": pdbIds}),
    );
    _assertOk(response);
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final highscoresJson = json["highscores"] as Map<String, dynamic>;
    return highscoresJson.map(
      (key, value) => MapEntry(key, Highscore.fromJson(value as Map<String, dynamic>)),
    );
  }

  Future<String> getPdb(String pdbId) async {
    final response = await _client.get(Uri.parse("https://files.rcsb.org/download/$pdbId.pdb"));
    _assertOk(response);
    return response.body;
  }

  void _assertOk(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(response.statusCode, response.body);
    }
  }
}