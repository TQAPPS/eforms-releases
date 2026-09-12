import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/annual_detail_inspection_model.dart';
import 'draft_storage_service.dart';

class AnnualDetailInspectionStorageService {
  static const String _folderName = 'annual_detail_inspections';

  /// Maximum duration for keeping drafts: 24 hours
  static const Duration draftLifespan = Duration(hours: 24);

  static Future<Directory> _getStorageDir() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${docsDir.path}/$_folderName');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Saves or updates an inspection record locally
  static Future<bool> saveInspection(
      AnnualDetailInspectionModel inspection) async {
    try {
      final dir = await _getStorageDir();
      final file = File('${dir.path}/${inspection.id}.json');
      await file.writeAsString(inspection.toJson(), flush: true);
      debugPrint(
          'AnnualDetailInspection saved successfully: ${inspection.id}');
      DraftStorageService.notifyDraftsChanged();
      return true;
    } catch (e) {
      debugPrint('Error saving AnnualDetailInspection: $e');
      return false;
    }
  }

  /// Loads a specific inspection by ID, automatically pruning if expired draft
  static Future<AnnualDetailInspectionModel?> loadInspection(String id) async {
    try {
      final dir = await _getStorageDir();
      final file = File('${dir.path}/$id.json');
      if (await file.exists()) {
        final content = await file.readAsString();
        final inspection = AnnualDetailInspectionModel.fromJson(content);
        if (inspection.status == 'draft' && isDraftExpired(inspection)) {
          await file.delete();
          debugPrint('Deleted expired draft upon load: $id');
          return null;
        }
        return inspection;
      }
    } catch (e) {
      debugPrint('Error loading AnnualDetailInspection ($id): $e');
    }
    return null;
  }

  /// Checks whether a draft has exceeded the 24-hour lifespan
  static bool isDraftExpired(AnnualDetailInspectionModel inspection) {
    if (inspection.status != 'draft') return false;
    final timeStr = inspection.updatedAt.isNotEmpty
        ? inspection.updatedAt
        : inspection.createdAt;
    final timestamp = DateTime.tryParse(timeStr);
    if (timestamp == null) return false;
    return DateTime.now().difference(timestamp) >= draftLifespan;
  }

  /// Calculates remaining time before the 24-hour deadline
  static Duration getRemainingDraftTime(AnnualDetailInspectionModel inspection) {
    final timeStr = inspection.updatedAt.isNotEmpty
        ? inspection.updatedAt
        : inspection.createdAt;
    final timestamp = DateTime.tryParse(timeStr) ?? DateTime.now();
    final elapsed = DateTime.now().difference(timestamp);
    final remaining = draftLifespan - elapsed;
    return remaining.isNegative ? Duration.zero : remaining;
  }

  /// Returns friendly Arabic remaining time (e.g. 'متبقي 23 ساعة و 45 دقيقة')
  static String formatRemainingDraftTime(AnnualDetailInspectionModel inspection) {
    final remaining = getRemainingDraftTime(inspection);
    if (remaining == Duration.zero) return 'انتهت صلاحية المسودة';
    final hours = remaining.inHours;
    final minutes = remaining.inMinutes % 60;
    if (hours > 0) {
      return 'متبقي $hours ساعة و $minutes دقيقة';
    } else {
      return 'متبقي $minutes دقيقة';
    }
  }

  /// Retrieves all valid saved inspections, automatically purging expired drafts
  static Future<List<AnnualDetailInspectionModel>> getAllInspections() async {
    final List<AnnualDetailInspectionModel> list = [];
    try {
      final dir = await _getStorageDir();
      final entities = dir.listSync();
      for (final entity in entities) {
        if (entity is File && entity.path.endsWith('.json')) {
          try {
            final content = await entity.readAsString();
            final inspection = AnnualDetailInspectionModel.fromJson(content);

            // Auto-delete drafts older than 24 hours
            if (inspection.status == 'draft' && isDraftExpired(inspection)) {
              await entity.delete();
              debugPrint('Auto-purged expired draft (>24h): ${inspection.id}');
              continue;
            }

            list.add(inspection);
          } catch (e) {
            debugPrint('Error parsing file ${entity.path}: $e');
          }
        }
      }
      // Sort newest first
      list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    } catch (e) {
      debugPrint('Error reading all AnnualDetailInspections: $e');
    }
    return list;
  }

  /// Retrieves only active (unexpired) drafts
  static Future<List<AnnualDetailInspectionModel>> getActiveDrafts() async {
    final all = await getAllInspections();
    return all.where((e) => e.status == 'draft').toList();
  }

  /// Deletes a saved inspection record
  static Future<bool> deleteInspection(String id) async {
    try {
      final dir = await _getStorageDir();
      final file = File('${dir.path}/$id.json');
      if (await file.exists()) {
        await file.delete();
        DraftStorageService.notifyDraftsChanged();
        return true;
      }
    } catch (e) {
      debugPrint('Error deleting AnnualDetailInspection ($id): $e');
    }
    return false;
  }
}
