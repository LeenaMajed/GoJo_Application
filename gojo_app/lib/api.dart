import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'screens/place_model.dart';

class ApiService {
  
  final String baseUrl = "http://192.168.1.17:8001";
  static const _timeout = Duration(seconds: 90);

 
  Future<Map<String, dynamic>> getItinerary({
    required String category,
    required String budget,
    required int days,
    String favorites = '',
    String tags = '',
  }) async {
    final uri = Uri.parse("$baseUrl/get-itinerary").replace(queryParameters: {
      'category':  category,
      'budget':    budget,
      'days':      days.toString(),
      if (favorites.isNotEmpty) 'favorites': favorites,
      if (tags.isNotEmpty)      'tags':      tags,
    });

    http.Response response;
    try {
      response = await http.get(uri).timeout(
        _timeout,
        onTimeout: () => throw Exception(
          'Request timed out after 90s.\n'
          'Make sure your backend is running:\n'
          '  uvicorn api:app --reload --host 0.0.0.0 --port 8001\n'
          'And your IP in api.dart matches:\n'
          '  $baseUrl',
        ),
      );
    } on SocketException {
      throw Exception(
        'Cannot reach server at $baseUrl.\n'
        'Check:\n'
        '1. Backend is running (uvicorn api:app --reload --host 0.0.0.0 --port 8001)\n'
        '2. Phone and PC are on the same Wi-Fi\n'
        '3. IP in api.dart is correct (run ipconfig on your PC)',
      );
    }

    if (response.statusCode != 200) {
      throw Exception('Server error ${response.statusCode}: ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;

    // Parse itinerary: { "Day 1": [ {...}, ... ], ... }
    final raw = data['itinerary'] as Map<String, dynamic>;
    final itinerary = <String, List<Place>>{};
    raw.forEach((day, list) {
      itinerary[day] = (list as List)
          .map((p) => Place.fromJson(p as Map<String, dynamic>))
          .toList();
    });

    final rawTotals = data['totals'] as Map<String, dynamic>? ?? {};
    final totals = rawTotals.map((k, v) => MapEntry(k, (v as num).toInt()));

    return {'itinerary': itinerary, 'totals': totals};
  }

  Future<String?> uploadPlace({
    required File imageFile,
    required String name,
    required String category,
    required String description,
    required double latitude,
    required double longitude,
    required int durationMinutes,
    required String costLevel,
    required String tagIds,
  }) async {
    try {
      final request = http.MultipartRequest('POST', Uri.parse("$baseUrl/add-place"))
        ..fields['name']             = name
        ..fields['category']         = category
        ..fields['description']      = description
        ..fields['latitude']         = latitude.toString()
        ..fields['longitude']        = longitude.toString()
        ..fields['duration_minutes'] = durationMinutes.toString()
        ..fields['cost_level']       = costLevel
        ..fields['tag_ids']          = tagIds
        ..files.add(await http.MultipartFile.fromPath('image', imageFile.path));

      final streamed = await request.send().timeout(_timeout,
          onTimeout: () => throw Exception('Upload timed out'));
      final resp = await http.Response.fromStream(streamed);

      if (resp.statusCode == 200 || resp.statusCode == 201) return null;
      return 'Server error ${resp.statusCode}: ${resp.body}';
    } on SocketException {
      return 'Cannot reach server. Check backend and network.';
    } catch (e) {
      return e.toString();
    }
  }
}
