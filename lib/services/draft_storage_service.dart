import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/draft_model.dart';
import '../services/annual_detail_inspection_storage_service.dart';

class DraftStorageService {
  static const String _folderName = 'app_drafts';

  /// Maximum duration for keeping drafts: 24 hours
  static const Duration draftLifespan = Duration(hours: 24);

  /// Real-time notification trigger when drafts are saved, updated or deleted
  static final ValueNotifier<int> draftsChangeNotifier = ValueNotifier<int>(0);

  /// Triggers a refresh notification across the app
  static void notifyDraftsChanged() {
    draftsChangeNotifier.value++;
  }

  static Future<Directory> _getStorageDir() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${docsDir.path}/$_folderName');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Saves or updates a draft locally
  static Future<bool> saveDraft(DraftModel draft) async {
    try {
      final dir = await _getStorageDir();
      final file = File('${dir.path}/${draft.id}.json');
      await file.writeAsString(draft.toJson(), flush: true);
      debugPrint('Draft saved successfully: ${draft.id} (${draft.formId})');
      notifyDraftsChanged();
      return true;
    } catch (e) {
      debugPrint('Error saving draft: $e');
      return false;
    }
  }

  /// Loads a specific draft by ID, auto-purging if expired
  static Future<DraftModel?> loadDraft(String id) async {
    try {
      final dir = await _getStorageDir();
      final file = File('${dir.path}/$id.json');
      if (await file.exists()) {
        final content = await file.readAsString();
        final draft = DraftModel.fromJson(content);
        if (isDraftExpired(draft)) {
          await file.delete();
          debugPrint('Deleted expired draft upon load: $id');
          return null;
        }
        return draft;
      }
    } catch (e) {
      debugPrint('Error loading draft ($id): $e');
    }
    return null;
  }

  /// Checks whether a draft has exceeded the 24-hour lifespan
  static bool isDraftExpired(DraftModel draft) {
    final timeStr = draft.updatedAt.isNotEmpty ? draft.updatedAt : draft.createdAt;
    final timestamp = DateTime.tryParse(timeStr);
    if (timestamp == null) return false;
    return DateTime.now().difference(timestamp) >= draftLifespan;
  }

  /// Calculates remaining time before the 24-hour deadline
  static Duration getRemainingDraftTime(DraftModel draft) {
    final timeStr = draft.updatedAt.isNotEmpty ? draft.updatedAt : draft.createdAt;
    final timestamp = DateTime.tryParse(timeStr) ?? DateTime.now();
    final elapsed = DateTime.now().difference(timestamp);
    final remaining = draftLifespan - elapsed;
    return remaining.isNegative ? Duration.zero : remaining;
  }

  /// Returns friendly Arabic remaining time (e.g. 'متبقي 23 ساعة و 45 دقيقة')
  static String formatRemainingDraftTime(DraftModel draft) {
    final remaining = getRemainingDraftTime(draft);
    if (remaining == Duration.zero) return 'انتهت صلاحية المسودة';
    final hours = remaining.inHours;
    final minutes = remaining.inMinutes % 60;
    if (hours > 0) {
      return 'متبقي $hours ساعة و $minutes دقيقة';
    } else {
      return 'متبقي $minutes دقيقة';
    }
  }

  /// Retrieves all active drafts across all forms (Form 1, Form 2, Form 5, etc.)
  static Future<List<DraftModel>> getActiveDrafts() async {
    final List<DraftModel> list = [];

    // 1. Load generic drafts from app_drafts directory
    try {
      final dir = await _getStorageDir();
      final entities = dir.listSync();
      for (final entity in entities) {
        if (entity is File && entity.path.endsWith('.json')) {
          try {
            final content = await entity.readAsString();
            final draft = DraftModel.fromJson(content);

            if (isDraftExpired(draft)) {
              await entity.delete();
              debugPrint('Auto-purged expired draft (>24h): ${draft.id}');
              continue;
            }

            list.add(draft);
          } catch (e) {
            debugPrint('Error parsing draft file ${entity.path}: $e');
          }
        }
      }
    } catch (e) {
      debugPrint('Error reading generic drafts: $e');
    }

    // 2. Load Annual Detail Inspection drafts and map to DraftModel
    try {
      final annualDrafts =
          await AnnualDetailInspectionStorageService.getActiveDrafts();
      for (final annual in annualDrafts) {
        String stepName;
        switch (annual.tabIndex) {
          case 0:
            stepName = 'البيانات العامة (General Info)';
            break;
          case 1:
            stepName = 'الفحص التفصيلي (البنود 1-15)';
            break;
          case 2:
            stepName = 'الفحوصات الكهربائية (البنود 16-27)';
            break;
          case 3:
            stepName = 'فحوصات الغاز والتأريض (البنود 28-35)';
            break;
          case 4:
            stepName = 'الاعتماد والتوقيع (Sign-Off)';
            break;
          default:
            stepName = 'الخطوة ${annual.tabIndex + 1}';
        }

        list.add(DraftModel(
          id: annual.id,
          formId: 'annual_detail_inspection',
          formTitle: 'Annual Detail Inspection',
          formCode: 'CL-GM-1600-004-002',
          workOrderNo: annual.workOrderNo,
          substation: annual.substation,
          stepDescription: stepName,
          createdAt: annual.createdAt,
          updatedAt: annual.updatedAt,
          data: annual.toMap(),
        ));
      }
    } catch (e) {
      debugPrint('Error mapping annual inspection drafts: $e');
    }

    // Sort newest updated first
    list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list;
  }

  /// Deletes a draft from local storage
  static Future<bool> deleteDraft(DraftModel draft) async {
    bool deleted = false;
    if (draft.formId == 'annual_detail_inspection') {
      deleted = await AnnualDetailInspectionStorageService.deleteInspection(draft.id);
    } else {
      try {
        final dir = await _getStorageDir();
        final file = File('${dir.path}/${draft.id}.json');
        if (await file.exists()) {
          await file.delete();
          deleted = true;
        }
      } catch (e) {
        debugPrint('Error deleting draft (${draft.id}): $e');
      }
    }
    if (deleted) {
      notifyDraftsChanged();
    }
    return deleted;
  }

  /// Automatically deletes any active draft belonging to a form when it is fully completed
  static Future<void> deleteDraftForForm({
    required String formId,
    String? substation,
    String? workOrderNo,
    String? id,
  }) async {
    try {
      final drafts = await getActiveDrafts();
      for (final draft in drafts) {
        bool match = false;
        if (id != null && id.isNotEmpty && draft.id == id) {
          match = true;
        } else if (draft.formId == formId) {
          final cleanDraftWo = draft.workOrderNo.trim();
          final cleanParamWo = (workOrderNo ?? '').trim();
          final cleanDraftSub = draft.substation.trim().toLowerCase();
          final cleanParamSub = (substation ?? '').trim().toLowerCase();

          if (cleanParamWo.isNotEmpty && cleanDraftWo == cleanParamWo) {
            match = true;
          } else if (cleanParamSub.isNotEmpty &&
              cleanParamWo.isNotEmpty &&
              cleanDraftSub == cleanParamSub &&
              cleanDraftWo == cleanParamWo) {
            match = true;
          } else if (cleanParamSub.isNotEmpty &&
              cleanParamWo.isEmpty &&
              cleanDraftSub == cleanParamSub) {
            match = true;
          }
        }
        if (match) {
          await deleteDraft(draft);
          debugPrint('Draft deleted on completion: ${draft.id} (${draft.formId})');
        }
      }
      notifyDraftsChanged();
    } catch (e) {
      debugPrint('Error deleting draft on completion: $e');
    }
  }
}
