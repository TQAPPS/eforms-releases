import 'package:flutter/material.dart';

enum FieldType {
  text,
  number,
  date,
  dropdown,
  multiline,
  checkbox,
  rating,
}

class FormFieldModel {
  final String id;
  final String label;
  final String hint;
  final FieldType type;
  final bool isRequired;
  final List<String>? options;
  final IconData? icon;

  const FormFieldModel({
    required this.id,
    required this.label,
    required this.hint,
    required this.type,
    this.isRequired = true,
    this.options,
    this.icon,
  });
}

class FormModel {
  final String id;
  final String title;
  final String subtitle;
  final String category;
  final String code;
  final String estimatedTime;
  final IconData icon;
  final Color primaryColor;
  final Color secondaryColor;
  final List<FormFieldModel> fields;

  const FormModel({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.category,
    required this.code,
    required this.estimatedTime,
    required this.icon,
    required this.primaryColor,
    required this.secondaryColor,
    required this.fields,
  });
}

class SampleFormData {
  static final List<FormModel> defaultForms = [
    // 1. Grid Maintenance & Transformer Monthly Inspection Form (نقل الكهرباء National Grid SA)
    FormModel(
      id: 'grid_maintenance',
      title: 'Monthly Inspection Power Transformer',
      subtitle: 'الفحص الشهري التفصيلي لمحولات القدرة والمساعدات ومحولات الاحتياط - نقل الكهرباء',
      category: 'صيانة الشبكة والجهد العالي',
      code: 'GRID-MNT',
      estimatedTime: '5 دقائق',
      icon: Icons.offline_bolt_rounded,
      primaryColor: const Color(0xFF0369A1),
      secondaryColor: const Color(0xFF38BDF8),
      fields: [
        const FormFieldModel(
          id: 'substation_name',
          label: 'اسم محطة التحويل (Substation Name)',
          hint: 'مثال: محطة تحويل شمال الرياض 380/110kV',
          type: FieldType.text,
          isRequired: true,
          icon: Icons.account_balance_rounded,
        ),
        const FormFieldModel(
          id: 'work_order_no',
          label: 'رقم أمر العمل (Work Order No.)',
          hint: 'مثال: WO-2026-GRID-9901',
          type: FieldType.text,
          isRequired: true,
          icon: Icons.confirmation_number_outlined,
        ),
        const FormFieldModel(
          id: 'inspection_date',
          label: 'تاريخ الفحص الشهري (Inspection Date)',
          hint: 'اختر تاريخ إجراء الفحص',
          type: FieldType.date,
          isRequired: true,
          icon: Icons.calendar_month_rounded,
        ),
        const FormFieldModel(
          id: 'lead_engineer',
          label: 'المهندس / الفني المسؤول (Inspector Name)',
          hint: 'اسم المهندس القائم بأعمال الفحص والصيانة',
          type: FieldType.text,
          isRequired: true,
          icon: Icons.engineering_outlined,
        ),
        const FormFieldModel(
          id: 'oil_leakage_status',
          label: 'مستوى وتسريب الزيت (Oil Leakage & Level)',
          hint: 'حدد حالة الزيت',
          type: FieldType.dropdown,
          isRequired: true,
          icon: Icons.opacity_rounded,
          options: [
            'سليم تماماً - لا يوجد أي تسريب والمستوى طبيعي (Normal)',
            'ملاحظة ترشيح طفيف يحتاج متابعة (Minor Seepage)',
            'يوجد تسريب نشط يستدعي المعالجة الفورية (Active Leak)',
          ],
        ),
        const FormFieldModel(
          id: 'silica_gel_tank',
          label: 'لون السيليكا جل للخزان الرئيسي (Silica gel Color Main Tank)',
          hint: 'اختر اللون وحالة التشبع بالرطوبة',
          type: FieldType.dropdown,
          isRequired: true,
          icon: Icons.colorize_rounded,
          options: [
            'أزرق سليم - جاف وممتاز (Blue - Healthy)',
            'وردي مشبع - يحتاج استبدال عاجل (Pink - Saturated)',
            'برتقالي سليم (Orange - Healthy)',
          ],
        ),
        const FormFieldModel(
          id: 'silica_gel_tap_changer',
          label: 'لون السيليكا جل لمغير الجهد (Silica gel Tap Changer)',
          hint: 'اختر اللون وحالة التشبع بالرطوبة',
          type: FieldType.dropdown,
          isRequired: true,
          icon: Icons.water_drop_outlined,
          options: [
            'أزرق سليم - جاف وممتاز (Blue - Healthy)',
            'وردي مشبع - يحتاج استبدال عاجل (Pink - Saturated)',
            'برتقالي سليم (Orange - Healthy)',
          ],
        ),
        const FormFieldModel(
          id: 'tap_position',
          label: 'موضع مغير الجهد (Tap Position)',
          hint: 'أدخل موضع الخطوة (مثال: Tap 9)',
          type: FieldType.text,
          isRequired: true,
          icon: Icons.tune_rounded,
        ),
        const FormFieldModel(
          id: 'tap_counter_reading',
          label: 'قراءة عداد مغير الجهد (Tap Changer Counter Reading)',
          hint: 'أدخل الرقم المسجل على العداد',
          type: FieldType.number,
          isRequired: true,
          icon: Icons.pin_outlined,
        ),
        const FormFieldModel(
          id: 'oil_temperature',
          label: 'درجة حرارة الزيت (Oil Temperature °C)',
          hint: 'مثال: 48°C',
          type: FieldType.number,
          isRequired: true,
          icon: Icons.device_thermostat_rounded,
        ),
        const FormFieldModel(
          id: 'hv_winding_temp',
          label: 'حرارة ملفات الجهد العالي (HV Winding Temp °C)',
          hint: 'مثال: 55°C',
          type: FieldType.number,
          isRequired: true,
          icon: Icons.thermostat_auto_rounded,
        ),
        const FormFieldModel(
          id: 'lv_winding_temp',
          label: 'حرارة ملفات الجهد المنخفض (LV Winding Temp °C)',
          hint: 'مثال: 52°C',
          type: FieldType.number,
          isRequired: true,
          icon: Icons.thermostat_rounded,
        ),
        const FormFieldModel(
          id: 'cooling_fans_pump',
          label: 'تشغيل مراوح ومضخات التبريد (Cooling Fans & Pump Operation)',
          hint: 'حدد حالة الفحص اليدوي والأوتوماتيكي',
          type: FieldType.dropdown,
          isRequired: true,
          icon: Icons.air_rounded,
          options: [
            'تم التشغيل اليدوي والرجوع للأوتوماتيك - سليمة بدون ضجيج (Normal)',
            'يوجد صوت غير طبيعي / اهتزاز ملحوظ (Abnormal Noise)',
            'عطل في إحدى المضخات أو المراوح (Malfunction)',
          ],
        ),
        const FormFieldModel(
          id: 'control_cabinet_status',
          label: 'كابينة التحكم والسخانات (Control Cabinet & Heaters)',
          hint: 'إحكام الإغلاق وعمل السخانات والإنارة',
          type: FieldType.dropdown,
          isRequired: true,
          icon: Icons.meeting_room_outlined,
          options: [
            'الكابينة محكمة الإغلاق والسخانات والإنارة تعمل بكفاءة (OK)',
            'الكابينة سليمة ولكن السخان / الإنارة بحاجة لصيانة',
            'الكابينة غير محكمة الإغلاق أو يوجد دخول أتربة',
          ],
        ),
        const FormFieldModel(
          id: 'dga_monitor_status',
          label: 'جهاز مراقبة الغازات الذائبة (On Line DGA Monitor)',
          hint: 'حالة جهاز المراقبة المتصل',
          type: FieldType.dropdown,
          isRequired: true,
          icon: Icons.monitor_heart_outlined,
          options: [
            'يعمل بشكل طبيعي ولا توجد إنذارات غازات (Normal)',
            'يوجد إنذار ارتفاع في الغازات الذائبة (Gas Alarm)',
            'الجهاز غير متوفر في هذه المحطة (N/A)',
          ],
        ),
        const FormFieldModel(
          id: 'bushings_general_cond',
          label: 'العوازل والتأريض (Bushings, Grounding & Corrosion)',
          hint: 'فحص العوازل، الشروخ، التأريض ومقاومة الصدأ',
          type: FieldType.dropdown,
          isRequired: true,
          icon: Icons.health_and_safety_outlined,
          options: [
            'سليمة تماماً - عوازل نظيفة وتأريض محكم ولا يوجد صدأ (Good)',
            'تراكم أتربة خفيف على العوازل يحتاج تنظيف في الصيانة الدورية',
            'يوجد ملاحظات صدأ أو ترشيح عازل يستوجب التدخل',
          ],
        ),
        const FormFieldModel(
          id: 'gis_compressor_pressure',
          label: 'نظام تشغيل GIS الهوائي (Pneumatic Operation GIS - Pressure & Tanks)',
          hint: 'ضغط كمبروسرات الهواء والخزانات',
          type: FieldType.text,
          isRequired: false,
          icon: Icons.compress_rounded,
        ),
        const FormFieldModel(
          id: 'spare_transformers_notes',
          label: 'محولات الاحتياط والملاحظات العامة (Spare Transformers & Notes)',
          hint: 'حالة محولات الاحتياط وأي توصيات فنية إضافية...',
          type: FieldType.multiline,
          isRequired: false,
          icon: Icons.notes_rounded,
        ),
      ],
    ),

    // 2. Checklist for Substation Power Transformer (CL-GM-1400-002-002)
    FormModel(
      id: 'transformer_checklist',
      title: 'Checklist for Substation Power Transformer',
      subtitle: 'قائمة التدقيق والفحص الميداني لمحولات القدرة بمحطات التحويل - نقل الكهرباء',
      category: 'صيانة محطات التحويل',
      code: 'CL-GM-1400-002-002',
      estimatedTime: '4 دقائق',
      icon: Icons.checklist_rtl_rounded,
      primaryColor: const Color(0xFF0F766E),
      secondaryColor: const Color(0xFF14B8A6),
      fields: [
        const FormFieldModel(
          id: 'division',
          label: 'القطاع (Division)',
          hint: 'مثال: EOD / Eastern Operating Division',
          type: FieldType.text,
          isRequired: true,
          icon: Icons.domain_rounded,
        ),
        const FormFieldModel(
          id: 'contact_person',
          label: 'الشخص المسؤول للتواصل (Contact Person)',
          hint: 'اسم المهندس أو الفني القائم بالفحص',
          type: FieldType.text,
          isRequired: true,
          icon: Icons.person_rounded,
        ),
        const FormFieldModel(
          id: 'department',
          label: 'الإدارة / القسم (Department)',
          hint: 'مثال: Substation Maintenance Department',
          type: FieldType.text,
          isRequired: true,
          icon: Icons.business_center_rounded,
        ),
        const FormFieldModel(
          id: 'work_order_no',
          label: 'رقم أمر العمل (Work Order No.)',
          hint: 'مثال: 8842910',
          type: FieldType.number,
          isRequired: true,
          icon: Icons.confirmation_number_outlined,
        ),
        const FormFieldModel(
          id: 'substation_name',
          label: 'اسم أو رقم محطة التحويل (Substation Name/No)',
          hint: 'مثال: JIC 380/110kV Substation',
          type: FieldType.text,
          isRequired: true,
          icon: Icons.account_balance_rounded,
        ),
        const FormFieldModel(
          id: 'inspection_date',
          label: 'التاريخ (Date)',
          hint: 'اختر تاريخ الفحص',
          type: FieldType.date,
          isRequired: true,
          icon: Icons.calendar_month_rounded,
        ),
      ],
    ),

    // 3. Transformer Oil Sampling Form (نموذج عينة الزيت)
    FormModel(
      id: 'oil_sampling',
      title: 'نموذج عينة الزيت',
      subtitle: 'سحب وتوثيق عينات الزيت العازل للمحولات واختبارات الغازات الذائبة والمختبر',
      category: 'صيانة محطات التحويل',
      code: 'CL-GM-OIL-001',
      estimatedTime: '3 دقائق',
      icon: Icons.science_rounded,
      primaryColor: const Color(0xFFD97706),
      secondaryColor: const Color(0xFFF59E0B),
      fields: [
        const FormFieldModel(
          id: 'division',
          label: 'القطاع (Division)',
          hint: 'مثال: SOD / Southern Operating Division',
          type: FieldType.text,
          isRequired: true,
          icon: Icons.domain_rounded,
        ),
        const FormFieldModel(
          id: 'contact_person',
          label: 'الفني المسؤول عن سحب العينات (Sampler / Technician)',
          hint: 'اسم المهندس أو الفني القائم بسحب العينات',
          type: FieldType.text,
          isRequired: true,
          icon: Icons.person_rounded,
        ),
        const FormFieldModel(
          id: 'department',
          label: 'الإدارة / القسم (Department)',
          hint: 'مثال: Substation Maintenance Department',
          type: FieldType.text,
          isRequired: true,
          icon: Icons.business_center_rounded,
        ),
        const FormFieldModel(
          id: 'work_order_no',
          label: 'رقم أمر العمل (Work Order No.)',
          hint: 'مثال: 8842910',
          type: FieldType.number,
          isRequired: true,
          icon: Icons.confirmation_number_outlined,
        ),
        const FormFieldModel(
          id: 'substation_name',
          label: 'اسم محطة التحويل (Substation Name)',
          hint: 'مثال: JIC 380/110kV Substation',
          type: FieldType.text,
          isRequired: true,
          icon: Icons.account_balance_rounded,
        ),
        const FormFieldModel(
          id: 'sampling_date',
          label: 'تاريخ سحب العينات (Sampling Date)',
          hint: 'اختر تاريخ السحب',
          type: FieldType.date,
          isRequired: true,
          icon: Icons.calendar_month_rounded,
        ),
      ],
    ),
  ];
}
