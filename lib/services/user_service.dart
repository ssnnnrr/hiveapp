import 'package:flutter/material.dart';

import '../models/all_models.dart';
import 'api_client.dart';
import 'package:dio/dio.dart';

class UserService {
  final ApiClient _api = ApiClient();

  Future<List<SkillDto>> getAllSkills() async {
    try {
      final response = await _api.dio.get("/Skills");
      return (response.data as List).map((json) => SkillDto.fromJson(json)).toList();
    } catch (e) { return []; }
  }

  Future<UserProfileDto?> getUserProfile(int id) async {
    try {
      final response = await _api.dio.get("/Users/$id");
      return UserProfileDto.fromJson(response.data);
    } catch (e) { return null; }
  }

  Future<bool> updateProfile(String name, String? pass, String? confirm, bool isPrivate, {String? avatarUrl}) async {
    try {
      final response = await _api.dio.put("/Users/me", data: {
        "username": name, "newPassword": pass, "confirmPassword": confirm, "isPrivate": isPrivate, "avatarUrl": avatarUrl
      });
      return response.statusCode == 200;
    } catch (e) { return false; }
  }

  // МЕТОД СТАТЬ ПАРТНЕРАМИ
  Future<bool> sendRequest(int targetId) async {
    try {
      // Пробуем отправить запрос. Убедись, что на бэкенде эндпоинт: [HttpPost("request/{targetId}")]
      final response = await _api.dio.post("/Friends/request/$targetId");
      return response.statusCode == 200 || response.statusCode == 201;
    } on DioException catch (e) {
      print("DIO ERROR: ${e.response?.statusCode} - ${e.response?.data}");
      return false;
    } catch (e) {
      print("SERVICE ERROR: $e");
      return false;
    }
  }

  Future<int?> acceptRequest(int requestId) async {
    try {
      final res = await _api.dio.post("/Friends/accept/$requestId");
      return res.data['groupId'];
    } catch (e) { return null; }
  }

  Future<bool> declineRequest(int requestId) async {
    try {
      final response = await _api.dio.post("/Friends/decline/$requestId");
      return response.statusCode == 200;
    } catch (e) { return false; }
  }

  Future<List<UserDto>> getFriends() async {
    try {
      final response = await _api.dio.get("/Friends/my-friends");
      return (response.data as List).map((json) => UserDto.fromJson(json)).toList();
    } catch (e) { return []; }
  }

  Future<List<ChatRequestDto>> getPendingRequests() async {
    try {
      final response = await _api.dio.get("/Friends/pending-requests");
      return (response.data as List).map((json) => ChatRequestDto.fromJson(json)).toList();
    } catch (e) { return []; }
  }

  Future<bool> leaveReview(int targetId, int rating, String comment) async {
    try {
      await _api.dio.post("/Reviews", data: {"reviewedId": targetId, "rating": rating, "comment": comment});
      return true;
    } catch (e) { return false; }
  }

  Future<bool> deleteReview(int targetId) async {
    try {
      await _api.dio.delete("/Reviews/$targetId");
      return true;
    } catch (e) { return false; }
  }

  Future<bool> syncSkills(List<int> skillIds, String type) async {
    try {
      await _api.dio.post("/Skills/sync", data: {"skillIds": skillIds, "type": type});
      return true;
    } catch (e) { return false; }
  }

  Future<bool> addUserSkill(int skillId, String type) async {
    try {
      await _api.dio.post("/Skills/my", data: {"skillId": skillId, "type": type});
      return true;
    } catch (e) { return false; }
  }


  // Получение списка партнеров (друзей) конкретного пользователя
  Future<List<UserDto>> getPartnersOfUser(int userId) async {
    try {
      final response = await _api.dio.get("/Friends/user/$userId");
      if (response.statusCode == 200) {
        return (response.data as List).map((json) => UserDto.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      debugPrint("UserService Error [getPartnersOfUser]: $e");
      return [];
    }
  }

  // Метод для полного удаления партнера
  Future<bool> unfriend(int friendId) async {
    try {
      // Предполагаем эндпоинт DELETE /api/Friends/{id}
      final response = await _api.dio.delete("/Friends/$friendId");
      return response.statusCode == 200;
    } catch (e) {
      debugPrint("UserService Error [unfriend]: $e");
      return false;
    }
  }
  

Future<List<UserDto>> findPartners({int? skillId, required String type, String? query}) async {
    try {
      final Map<String, dynamic> params = {"type": type};
      if (skillId != null) params["skillId"] = skillId;
      if (query != null && query.isNotEmpty) params["query"] = query;
      
      final response = await _api.dio.get("/Skills/search", queryParameters: params);
      return (response.data as List).map((json) => UserDto.fromJson(json)).toList();
    } catch (e) { 
      return []; 
    }
  }
}