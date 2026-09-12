import 'dart:convert';

class DraftModel {
  final String id;
  final String formId; // 'grid_maintenance', 'transformer_checklist', 'annual_detail_inspection'
  final String formTitle;
  final String formCode;
  final String workOrderNo;
  final String substation;
  final String stepDescription;
  final String createdAt;
  final String updatedAt;
  final Map<String, dynamic> data;

  DraftModel({
    required this.id,
    required this.formId,
    required this.formTitle,
    required this.formCode,
    required this.workOrderNo,
    required this.substation,
    required this.stepDescription,
    required this.createdAt,
    required this.updatedAt,
    required this.data,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'formId': formId,
      'formTitle': formTitle,
      'formCode': formCode,
      'workOrderNo': workOrderNo,
      'substation': substation,
      'stepDescription': stepDescription,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'data': data,
    };
  }

  factory DraftModel.fromMap(Map<String, dynamic> map) {
    return DraftModel(
      id: map['id']?.toString() ?? '',
      formId: map['formId']?.toString() ?? '',
      formTitle: map['formTitle']?.toString() ?? '',
      formCode: map['formCode']?.toString() ?? '',
      workOrderNo: map['workOrderNo']?.toString() ?? '',
      substation: map['substation']?.toString() ?? '',
      stepDescription: map['stepDescription']?.toString() ?? '',
      createdAt: map['createdAt']?.toString() ?? DateTime.now().toIso8601String(),
      updatedAt: map['updatedAt']?.toString() ?? DateTime.now().toIso8601String(),
      data: map['data'] != null ? Map<String, dynamic>.from(map['data']) : {},
    );
  }

  String toJson() => jsonEncode(toMap());

  factory DraftModel.fromJson(String source) =>
      DraftModel.fromMap(jsonDecode(source) as Map<String, dynamic>);
}
