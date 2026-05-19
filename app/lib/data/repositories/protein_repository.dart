import "dart:convert";
import "package:http/http.dart" as http;
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