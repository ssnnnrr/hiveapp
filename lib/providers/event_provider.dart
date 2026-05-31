import 'package:flutter/material.dart';
import '../models/all_models.dart';
import '../services/api_client.dart';

class EventProvider extends ChangeNotifier {
  final ApiClient _api = ApiClient();
  List<EventResponse> _events = [];
  bool _isLoading = false;

  List<EventResponse> get events => _events;
  bool get isLoading => _isLoading;
  

  Future<void> loadEvents() async {
    _isLoading = true;
    notifyListeners();
    try {
      final response = await _api.dio.get("/Events/my");
      _events = (response.data as List).map((e) => EventResponse.fromJson(e)).toList();
    } catch (e) {
      debugPrint("Error loading events: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Создание события (Link, Location, Image - необязательные)
// Внутри EventProvider измените эти методы:

// Внутри EventProvider.dart

Future<bool> addEvent(String title, String? desc, DateTime date, String? link, String? loc, String? img) async {
  try {
    final response = await _api.dio.post("/Events", data: {
      "title": title,
      "description": desc,
      // УБРАЛИ .toUtc(), отправляем локальное время устройства
      "eventDate": date.toIso8601String(), 
      "linkUrl": link,
      "location": loc,
      "imageUrl": img
    });
    if (response.statusCode == 200 || response.statusCode == 201) {
      await loadEvents();
      return true;
    }
  } catch (e) { debugPrint(e.toString()); }
  return false;
}

Future<bool> updateEvent(int id, String title, String? desc, DateTime date, String? link, String? loc, String? img) async {
  try {
    final response = await _api.dio.put("/Events/$id", data: {
      "title": title,
      "description": desc,
      "eventDate": date.toIso8601String(), // Локальное время
      "linkUrl": link,
      "location": loc,
      "imageUrl": img
    });
    if (response.statusCode == 200) {
      await loadEvents();
      return true;
    }
  } catch (e) { debugPrint(e.toString()); }
  return false;
}

void clearData() {
  _events = [];
  _isLoading = false;
  notifyListeners();
}

  // Чекбокс выполнения
  Future<void> toggleEvent(int id) async {
    try {
      final response = await _api.dio.patch("/Events/$id/toggle");
      if (response.statusCode == 200) {
        int idx = _events.indexWhere((e) => e.id == id);
        if (idx != -1) {
          // Локально обновляем статус для мгновенного отклика UI
          final e = _events[idx];
          _events[idx] = EventResponse(
            id: e.id, title: e.title, description: e.description,
            eventDate: e.eventDate, isCompleted: !e.isCompleted,
            creatorName: e.creatorName, linkUrl: e.linkUrl, 
            location: e.location, imageUrl: e.imageUrl
          );
          notifyListeners();
        }
      }
    } catch (e) { debugPrint(e.toString()); }
  }

  Future<void> deleteEvent(int id) async {
    try {
      await _api.dio.delete("/Events/$id");
      _events.removeWhere((e) => e.id == id);
      notifyListeners();
    } catch (e) { debugPrint(e.toString()); }
  }
}