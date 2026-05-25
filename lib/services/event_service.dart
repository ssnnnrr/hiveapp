import '../models/all_models.dart';
import 'api_client.dart';

class EventService {
  final ApiClient _api = ApiClient();

  Future<List<EventResponse>> getMyEvents() async {
    try {
      final response = await _api.dio.get("/Events/my");
      if (response.statusCode == 200) {
        return (response.data as List).map((e) => EventResponse.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<bool> createEvent(String title, String? desc, DateTime date, int? groupId) async {
    try {
      final response = await _api.dio.post("/Events", data: {
        "title": title,
        "description": desc,
        "eventDate": date.toIso8601String(),
        "groupId": groupId
      });
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      return false;
    }
  }

  Future<bool> updateEvent(int id, String title, DateTime date) async {
    try {
      final response = await _api.dio.put("/Events/$id", data: {
        "title": title,
        "eventDate": date.toIso8601String()
      });
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<bool> toggleEvent(int id) async {
    try {
      final response = await _api.dio.patch("/Events/$id/toggle");
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteEvent(int id) async {
    try {
      final response = await _api.dio.delete("/Events/$id");
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}