import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_constants.dart';

class ApiService {
  static Future<Map<String, dynamic>> login(String phone) async {
    final url = Uri.parse('${ApiConstants.baseUrl}/login');
    final response = await http.post(url, body: {'phone': phone});
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> getUserDocuments(int userId) async {
    final url = Uri.parse(
      '${ApiConstants.baseUrl}/user-documents?user_id=$userId',
    );
    final response = await http.get(url);
    print("DOC STATUS: ${response.statusCode}");
    print("DOC BODY: ${response.body}");
    return jsonDecode(response.body);
  }

  // ✅ Feature 5: Sync API
  static Future<Map<String, dynamic>> syncDocuments(int userId, String lastSync) async {
  final url = Uri.parse(
    '${ApiConstants.baseUrl}/sync-documents?user_id=$userId&last_sync=$lastSync',
  );
    final response = await http.get(url);
    print("SYNC STATUS: ${response.statusCode}");
    print("SYNC BODY: ${response.body}");
    return jsonDecode(response.body);
  }
}