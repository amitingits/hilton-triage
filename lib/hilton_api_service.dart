import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';

class HiltonApiService {
  final String jiraUrl = "https://jira.hilton.com";

  Future<bool> validateToken(String token) async {
    try {
      final response = await http.get(
        Uri.parse("$jiraUrl/rest/api/2/myself"),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } on SocketException {
      throw Exception("VPN Error: Please connect to Hilton GlobalProtect VPN.");
    } catch (e) {
      throw Exception("Error: Check your connection: $e");
    }
  }

  Future<List<dynamic>> fetchIssues(String token, String epicId) async {
    final jql = 'parent = "$epicId" OR "Epic Link" = "$epicId"';
    final url = "$jiraUrl/rest/api/2/search?jql=${Uri.encodeComponent(jql)}&maxResults=100";
    try {
      final response = await http.get(Uri.parse(url), headers: {'Authorization': 'Bearer $token'});
      if (response.statusCode == 200) {
        return json.decode(response.body)['issues'];
      } else {
        throw Exception("Failed to fetch issues");
      }
    } catch (e) {
      throw Exception("Fetch Error: Check the Epic ID and try again.");
    }
  }
}