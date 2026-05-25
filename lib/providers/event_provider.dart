import 'package:flutter/material.dart';
import '../models/all_models.dart';
import '../services/event_service.dart';

class EventProvider extends ChangeNotifier {
  final EventService _service = EventService();
  List<EventResponse> _events = [];
  bool _isLoading = false;

  List<EventResponse> get events => _events;
  bool get isLoading => _isLoading;

  Future<void> loadEvents() async {
    _isLoading = true;
    // Безопасное уведомление слушателей
    WidgetsBinding.instance.addPostFrameCallback((_) => notifyListeners());

    try {
      _events = await _service.getMyEvents();
    } catch (e) {
      debugPrint("Error loading events: $e");
    } finally {
      _isLoading = false;
      WidgetsBinding.instance.addPostFrameCallback((_) => notifyListeners());
    }
  }

  void clearData() {
  _events = [];
  _isLoading = false;
  notifyListeners();
}

  Future<bool> toggleEvent(int id) async {
    bool success = await _service.toggleEvent(id);
    if (success) {
      int index = _events.indexWhere((e) => e.id == id);
      if (index != -1) {
        final e = _events[index];
        _events[index] = EventResponse(
          id: e.id, title: e.title, description: e.description,
          eventDate: e.eventDate, isCompleted: !e.isCompleted,
          groupId: e.groupId, creatorName: e.creatorName
        );
        notifyListeners();
      }
    }
    return success;
  }

  Future<bool> addEvent(String title, String? desc, DateTime date, int? groupId) async {
    bool success = await _service.createEvent(title, desc, date, groupId);
    if (success) await loadEvents();
    return success;
  }

  Future<bool> updateEvent(int id, String title, DateTime date) async {
    bool success = await _service.updateEvent(id, title, date);
    if (success) await loadEvents();
    return success;
  }

   Future<bool> deleteEvent(int id) async {
    bool success = await _service.deleteEvent(id);
    if (success) {
      _events.removeWhere((e) => e.id == id);
      notifyListeners();
    }
    return success;
  }
}