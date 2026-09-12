import 'dart:convert';

class AnnualInspectionItemModel {
  final int number;
  final String title;
  final String nameEn;
  final String desc;
  final bool isDone;
  final String status; // 'Done', 'Check', 'Defect', 'N/A'
  final String remarks;
  final String? auxValue;

  const AnnualInspectionItemModel({
    required this.number,
    required this.title,
    required this.nameEn,
    required this.desc,
    this.isDone = false,
    this.status = '',
    this.remarks = '',
    this.auxValue,
  });

  AnnualInspectionItemModel copyWith({
    int? number,
    String? title,
    String? nameEn,
    String? desc,
    bool? isDone,
    String? status,
    String? remarks,
    String? auxValue,
  }) {
    return AnnualInspectionItemModel(
      number: number ?? this.number,
      title: title ?? this.title,
      nameEn: nameEn ?? this.nameEn,
      desc: desc ?? this.desc,
      isDone: isDone ?? this.isDone,
      status: status ?? this.status,
      remarks: remarks ?? this.remarks,
      auxValue: auxValue ?? this.auxValue,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'number': number,
      'title': title,
      'nameEn': nameEn,
      'desc': desc,
      'isDone': isDone,
      'status': status,
      'remarks': remarks,
      'auxValue': auxValue,
    };
  }

  factory AnnualInspectionItemModel.fromMap(Map<String, dynamic> map) {
    return AnnualInspectionItemModel(
      number: map['number'] as int? ?? 0,
      title: map['title'] as String? ?? '',
      nameEn: map['nameEn'] as String? ?? '',
      desc: map['desc'] as String? ?? '',
      isDone: map['isDone'] as bool? ?? false,
      status: map['status'] as String? ?? '',
      remarks: map['remarks'] as String? ?? '',
      auxValue: map['auxValue'] as String?,
    );
  }
}

class AnnualDetailInspectionModel {
  final String id;
  final String createdAt;
  final String updatedAt;
  final String status; // 'draft', 'completed'

  // Section A: General Information
  final String division;
  final String department;
  final String workOrderNo;
  final String workGroup;
  final String substation;
  final String location;
  final String transformerDesignation;
  final String manufacturer;
  final String makeType;
  final String mvaRating;
  final String voltageRatio;
  final String typeConnectionHv;
  final String typeConnectionLv;
  final String typeConnectionTv;

  // 35 Inspection Items
  final List<AnnualInspectionItemModel> items;

  // Verification & Signatures
  final String comments;
  final String inspectedByName;
  final String inspectedByBadge;
  final String inspectedDate;
  final String? inspectedBySignatureBase64;
  final String checkedByName;
  final String checkedByBadge;
  final String checkedDate;
  final String? checkedBySignatureBase64;
  final int tabIndex;

  const AnnualDetailInspectionModel({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    this.status = 'draft',
    this.division = 'EOD',
    this.department = 'Substation Maintenance Dept.',
    this.workOrderNo = '',
    this.workGroup = 'Substation Maintenance Team',
    this.substation = '',
    this.location = '',
    this.transformerDesignation = '',
    this.manufacturer = '',
    this.makeType = 'OFAF',
    this.mvaRating = '67 MVA',
    this.voltageRatio = '115/13.8 kV',
    this.typeConnectionHv = 'Air Bushing',
    this.typeConnectionLv = 'Air Cable Box',
    this.typeConnectionTv = 'Outdoor Bushings',
    this.items = const [],
    this.comments = '',
    this.inspectedByName = '',
    this.inspectedByBadge = '',
    this.inspectedDate = '',
    this.inspectedBySignatureBase64,
    this.checkedByName = '',
    this.checkedByBadge = '',
    this.checkedDate = '',
    this.checkedBySignatureBase64,
    this.tabIndex = 0,
  });

  AnnualDetailInspectionModel copyWith({
    String? id,
    String? createdAt,
    String? updatedAt,
    String? status,
    String? division,
    String? department,
    String? workOrderNo,
    String? workGroup,
    String? substation,
    String? location,
    String? transformerDesignation,
    String? manufacturer,
    String? makeType,
    String? mvaRating,
    String? voltageRatio,
    String? typeConnectionHv,
    String? typeConnectionLv,
    String? typeConnectionTv,
    List<AnnualInspectionItemModel>? items,
    String? comments,
    String? inspectedByName,
    String? inspectedByBadge,
    String? inspectedDate,
    String? inspectedBySignatureBase64,
    String? checkedByName,
    String? checkedByBadge,
    String? checkedDate,
    String? checkedBySignatureBase64,
    int? tabIndex,
  }) {
    return AnnualDetailInspectionModel(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      status: status ?? this.status,
      division: division ?? this.division,
      department: department ?? this.department,
      workOrderNo: workOrderNo ?? this.workOrderNo,
      workGroup: workGroup ?? this.workGroup,
      substation: substation ?? this.substation,
      location: location ?? this.location,
      transformerDesignation:
          transformerDesignation ?? this.transformerDesignation,
      manufacturer: manufacturer ?? this.manufacturer,
      makeType: makeType ?? this.makeType,
      mvaRating: mvaRating ?? this.mvaRating,
      voltageRatio: voltageRatio ?? this.voltageRatio,
      typeConnectionHv: typeConnectionHv ?? this.typeConnectionHv,
      typeConnectionLv: typeConnectionLv ?? this.typeConnectionLv,
      typeConnectionTv: typeConnectionTv ?? this.typeConnectionTv,
      items: items ?? this.items,
      comments: comments ?? this.comments,
      inspectedByName: inspectedByName ?? this.inspectedByName,
      inspectedByBadge: inspectedByBadge ?? this.inspectedByBadge,
      inspectedDate: inspectedDate ?? this.inspectedDate,
      inspectedBySignatureBase64:
          inspectedBySignatureBase64 ?? this.inspectedBySignatureBase64,
      checkedByName: checkedByName ?? this.checkedByName,
      checkedByBadge: checkedByBadge ?? this.checkedByBadge,
      checkedDate: checkedDate ?? this.checkedDate,
      checkedBySignatureBase64:
          checkedBySignatureBase64 ?? this.checkedBySignatureBase64,
      tabIndex: tabIndex ?? this.tabIndex,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'status': status,
      'division': division,
      'department': department,
      'workOrderNo': workOrderNo,
      'workGroup': workGroup,
      'substation': substation,
      'location': location,
      'transformerDesignation': transformerDesignation,
      'manufacturer': manufacturer,
      'makeType': makeType,
      'mvaRating': mvaRating,
      'voltageRatio': voltageRatio,
      'typeConnectionHv': typeConnectionHv,
      'typeConnectionLv': typeConnectionLv,
      'typeConnectionTv': typeConnectionTv,
      'items': items.map((x) => x.toMap()).toList(),
      'comments': comments,
      'inspectedByName': inspectedByName,
      'inspectedByBadge': inspectedByBadge,
      'inspectedDate': inspectedDate,
      'inspectedBySignatureBase64': inspectedBySignatureBase64,
      'checkedByName': checkedByName,
      'checkedByBadge': checkedByBadge,
      'checkedDate': checkedDate,
      'checkedBySignatureBase64': checkedBySignatureBase64,
      'tabIndex': tabIndex,
    };
  }

  factory AnnualDetailInspectionModel.fromMap(Map<String, dynamic> map) {
    return AnnualDetailInspectionModel(
      id: map['id'] as String? ?? '',
      createdAt: map['createdAt'] as String? ?? '',
      updatedAt: map['updatedAt'] as String? ?? '',
      status: map['status'] as String? ?? 'draft',
      division: map['division'] as String? ?? '',
      department: map['department'] as String? ?? '',
      workOrderNo: map['workOrderNo'] as String? ?? '',
      workGroup: map['workGroup'] as String? ?? '',
      substation: map['substation'] as String? ?? '',
      location: map['location'] as String? ?? '',
      transformerDesignation: map['transformerDesignation'] as String? ?? '',
      manufacturer: map['manufacturer'] as String? ?? '',
      makeType: map['makeType'] as String? ?? '',
      mvaRating: map['mvaRating'] as String? ?? '',
      voltageRatio: map['voltageRatio'] as String? ?? '',
      typeConnectionHv: map['typeConnectionHv'] as String? ?? '',
      typeConnectionLv: map['typeConnectionLv'] as String? ?? '',
      typeConnectionTv: map['typeConnectionTv'] as String? ?? '',
      items: (map['items'] as List<dynamic>?)
              ?.map((x) =>
                  AnnualInspectionItemModel.fromMap(x as Map<String, dynamic>))
              .toList() ??
          [],
      comments: map['comments'] as String? ?? '',
      inspectedByName: map['inspectedByName'] as String? ?? '',
      inspectedByBadge: map['inspectedByBadge'] as String? ?? '',
      inspectedDate: map['inspectedDate'] as String? ?? '',
      inspectedBySignatureBase64: map['inspectedBySignatureBase64'] as String?,
      checkedByName: map['checkedByName'] as String? ?? '',
      checkedByBadge: map['checkedByBadge'] as String? ?? '',
      checkedDate: map['checkedDate'] as String? ?? '',
      checkedBySignatureBase64: map['checkedBySignatureBase64'] as String?,
      tabIndex: map['tabIndex'] as int? ?? 0,
    );
  }

  String toJson() => json.encode(toMap());

  factory AnnualDetailInspectionModel.fromJson(String source) =>
      AnnualDetailInspectionModel.fromMap(
          json.decode(source) as Map<String, dynamic>);

  /// Creates default 35 inspection items directly matching the authoritative PDF
  static List<AnnualInspectionItemModel> defaultItems() {
    return [
      // Page 1: Items 1 to 15
      AnnualInspectionItemModel(
        number: 1,
        title: 'مستوى زيت الخزان الرئيسي',
        nameEn: 'Oil level Main Tank',
        desc:
            'Check oil levels and if require correct it in accordance with manufacturer\'s instructions.',
      ),
      AnnualInspectionItemModel(
        number: 2,
        title: 'مستوى زيت مغير الجهد',
        nameEn: 'Oil level Tap Changer',
        desc:
            'Check oil levels and if require correct it in accordance with manufacturer\'s instructions.',
      ),
      AnnualInspectionItemModel(
        number: 3,
        title: 'مستوى زيت العوازل',
        nameEn: 'Oil level Bushing',
        desc:
            'Check oil levels and if require correct it in accordance with manufacturer\'s instructions.',
      ),
      AnnualInspectionItemModel(
        number: 4,
        title: 'مستوى زيت خزان تمدد صندوق الكابلات',
        nameEn: 'Oil level Cable Box Conservator (if applicable)',
        desc:
            'Check oil levels and if require correct it in accordance with manufacturer\'s instructions',
      ),
      AnnualInspectionItemModel(
        number: 5,
        title: 'سيليكا جل الخزان الرئيسي',
        nameEn: 'Silica gel Main Tank',
        desc: 'check color. (replace if required).',
      ),
      AnnualInspectionItemModel(
        number: 6,
        title: 'سيليكا جل صندوق الكابلات',
        nameEn: 'Silica gel Cable Box (if applicable)',
        desc: 'check color (replace if required).',
      ),
      AnnualInspectionItemModel(
        number: 7,
        title: 'سيليكا جل مغير الجهد',
        nameEn: 'Silica gel Tap Changer',
        desc: 'check color. (replace if required).',
      ),
      AnnualInspectionItemModel(
        number: 8,
        title: 'تسريب الزيت من الخزان الرئيسي',
        nameEn: 'Oil leakage Main Tank',
        desc: 'Check from the main tank. (rectify if necessary).',
      ),
      AnnualInspectionItemModel(
        number: 9,
        title: 'تسريب الزيت من مغير الجهد',
        nameEn: 'Oil leakage Tap Changer',
        desc: 'Check from the main tank. (rectify if necessary).',
      ),
      AnnualInspectionItemModel(
        number: 10,
        title: 'تسريب الزيت من المشعات',
        nameEn: 'Oil leakage Radiators',
        desc: 'Check oil leaks from the radiators. (rectify if necessary).',
      ),
      AnnualInspectionItemModel(
        number: 11,
        title: 'تسريب الزيت من صناديق الكابلات',
        nameEn: 'Oil leakage Cable boxes',
        desc: 'Check oil leaks from the cable boxes. (rectify if necessary).',
      ),
      AnnualInspectionItemModel(
        number: 12,
        title: 'تسريب الزيت من العوازل',
        nameEn: 'Oil leakage Bushing',
        desc: 'Check oil leaks from the bushings. (rectify if necessary).',
      ),
      AnnualInspectionItemModel(
        number: 13,
        title: 'مغير الجهد - موضع الخطوة',
        nameEn: 'Tap changer',
        desc: 'Record Tap Position',
      ),
      AnnualInspectionItemModel(
        number: 14,
        title: 'مغير الجهد - قراءة العداد',
        nameEn: 'Tap changer',
        desc: 'Record Tap Counter Reading',
      ),
      AnnualInspectionItemModel(
        number: 15,
        title: 'عوازل الاختراق (Bushings)',
        nameEn: 'Bushings',
        desc:
            'Check the condition of the bushings, for any drips, cracks, dust contamination and take corrective action (earliest feasible).',
      ),

      // Page 2: Items 16 to 32
      AnnualInspectionItemModel(
        number: 16,
        title: 'مانعات الصواعق',
        nameEn: 'Surge Arresters',
        desc:
            'Check the condition of the surge arrestors, for cracks, dust contamination, record Surge Arresters counter reading. (where applicable).',
      ),
      AnnualInspectionItemModel(
        number: 17,
        title: 'مؤشر درجة حرارة الزيت (OTI)',
        nameEn: 'Oil temperature gauge',
        desc:
            'Check and record both the actual and maximum temperatures of top Oil temperature gauge. Reset peak indicator.',
      ),
      AnnualInspectionItemModel(
        number: 18,
        title: 'مؤشر حرارة ملفات الجهد العالي (HV WTI)',
        nameEn: 'HV winding temperature gauge',
        desc:
            'Check and record both the actual and maximum temperatures of HV winding temperature gauge Reset peak indicator.',
      ),
      AnnualInspectionItemModel(
        number: 19,
        title: 'مؤشر حرارة ملفات الجهد المنخفض (LV WTI)',
        nameEn: 'LV winding temperature gauge',
        desc:
            'Check and record both the actual and maximum temperatures of LV winding temperature gauge Reset peak indicator.',
      ),
      AnnualInspectionItemModel(
        number: 20,
        title: 'تشغيل مراوح ومضخات التبريد',
        nameEn: 'Cooling Fan & Pump Operation',
        desc:
            'Run the fans and pumps manually, and return to auto, report abnormal noise',
      ),
      AnnualInspectionItemModel(
        number: 21,
        title: 'صناديق التجميع ولوحات التحكم',
        nameEn: 'MK boxes/ cabinets',
        desc:
            'Check all cables entry into devices are properly sealed. Check the glanding condition of cabinet and accessories. Check and verify of the tightness and quality of the cabinet door gaskets to make sure they are securely sealed. Check the operation of lights and heaters in cabinets. Check the setting/working of thermostat of heater.',
      ),
      AnnualInspectionItemModel(
        number: 22,
        title: 'جهاز مراقبة الغازات اللحظي On-line DGA',
        nameEn: 'On line DGA Monitor',
        desc: 'Check operation',
      ),
      AnnualInspectionItemModel(
        number: 23,
        title: 'الحالة العامة وجسم المحول والتأريض',
        nameEn: 'General condition',
        desc:
            'Check if there any abnormal on and around the transformer and reactor being inspected. Check grounding connections for transformer main tank / body. Check paint and corrosion condition of main tank, radiators and cable box of transformer and take corrective action, as necessary.',
      ),
      AnnualInspectionItemModel(
        number: 24,
        title: 'محولات وحدات التوليد',
        nameEn: 'Generating Unit Transformer (for applicable units)',
        desc:
            'Check terminal connections for tightness to the required torque on both high and low sides of the generating unit transformer. (under outage condition).',
      ),
      AnnualInspectionItemModel(
        number: 25,
        title: 'أجهزة ومنظومات الحماية',
        nameEn: 'Protection Devices',
        desc:
            'Perform functional (alarm and trip) tests of all protection devices. (under outage condition).',
      ),
      AnnualInspectionItemModel(
        number: 26,
        title: 'مفاتيح الحماية الميكانيكية',
        nameEn: 'Mechanical Protection',
        desc:
            'Revert Mechanical Protection Switch from “Interlocked” to “Normal” position (where applicable). (under outage condition).',
      ),
      AnnualInspectionItemModel(
        number: 27,
        title: 'المسح الحراري للأشعة تحت الحمراء',
        nameEn: 'Thermo-Vision',
        desc:
            'Carry out thermo-vision survey to visually inspect any hot spot temperature in accordance with PR-GM-1590-001 "Thermal Imaging / Thermographic / Infrared Scanning of Power Transformers, Transformers\' Bushings and Substation Equipment.',
      ),
      AnnualInspectionItemModel(
        number: 28,
        title: 'تحليل الغازات الذائبة DGA لمحولات 230 ك.ف فأعلى',
        nameEn:
            'DGA of Oil from 230 kV and above power transformer and rector',
        desc:
            'Conduct Dissolved Gases-in-Oil Analysis (DGA) of oil from 230 kV and above power transformers and rectors (Main tank, OLTC compartment).',
      ),
      AnnualInspectionItemModel(
        number: 29,
        title: 'تشغيل المضخات 15 دقيقة قبل سحب العينة (OFAF/ODAF)',
        nameEn:
            'For OFAF and ODAF Transformers, run the pumps for at least 15 minutes before taking Oil Sample from the Main Tank',
        desc:
            'For OFAF and ODAF Transformers, run the pumps for at least 15 minutes before taking Oil Sample from the Main Tank',
      ),
      AnnualInspectionItemModel(
        number: 30,
        title: 'تحليل DGA لمحولات التوليد',
        nameEn:
            '(DGA) of oil from Generator Transformer (for Generator Transformer only)',
        desc:
            'Conduct Dissolved Gases-in-Oil Analysis (DGA) of oil from generator transformers (Main tank, OLTC compartment).',
      ),
      AnnualInspectionItemModel(
        number: 31,
        title: 'تحليل DGA لمحولات 132 ك.ف وما دون',
        nameEn:
            'DGA of Oil from 132 kV and below power transformer and rector',
        desc:
            'Conduct Dissolved Gases-in-Oil Analysis (DGA) of oil from 132 kV and below power transformers and rectors (Main tank, OLTC compartment). once two years.',
      ),
      AnnualInspectionItemModel(
        number: 32,
        title: 'تحليل DGA لصناديق الكابلات المملوءة بالزيت',
        nameEn: 'DGA of oil from oil-filled cable compartments',
        desc:
            'Conduct Dissolved Gases-in-Oil Analysis (DGA) of oil from oil-filled cable compartments of power transformers and rectors rated 132 kV and below.',
      ),

      // Page 3: Items 33 to 35
      AnnualInspectionItemModel(
        number: 33,
        title: 'فحوصات جودة الزيت (كل سنتين)',
        nameEn: 'Quality tests on Oil',
        desc:
            'Conduct quality tests on oil once every Two (2) years. Perform earlier if results indicate issues. The concerned Maintenance Division Manager should make these decisions.',
      ),
      AnnualInspectionItemModel(
        number: 34,
        title: 'فحص مركبات الفيوران بالزيت (كل سنتين)',
        nameEn: 'Furanic compound tests on oil',
        desc:
            'Conduct Furanic compound tests on oil once every Two (2) years. Perform earlier if results indicate issues. The concerned Maintenance Division Manager should make these decisions',
      ),
      AnnualInspectionItemModel(
        number: 35,
        title: 'فحص توصيلات تأريض جسم المحول',
        nameEn:
            'Check grounding connections of transformer main tank/body.',
        desc: 'Check grounding connections of transformer main tank/body.',
      ),
    ];
  }
}
