import 'package:flutter/material.dart';
import '../models/form_model.dart';
import '../models/substation_model.dart';
import 'oil_sampling_approval_screen.dart';

class OilSamplingScreen extends StatefulWidget {
  final FormModel form;
  final SubstationModel selectedSubstation;
  final List<TransformerInfo> selectedTransformers;
  final String initialDivision;
  final String initialDepartment;
  final String initialContactPerson;
  final String initialSampleTemp;
  final String initialWorkOrder;
  final String initialInspectionDate;

  const OilSamplingScreen({
    super.key,
    required this.form,
    required this.selectedSubstation,
    required this.selectedTransformers,
    required this.initialDivision,
    required this.initialDepartment,
    required this.initialContactPerson,
    this.initialSampleTemp = '',
    required this.initialWorkOrder,
    required this.initialInspectionDate,
  });

  @override
  State<OilSamplingScreen> createState() => _OilSamplingScreenState();
}

class _OilSamplingScreenState extends State<OilSamplingScreen> {
  // 1. نوع المعدة (Equipment Type) - Default is empty
  final Set<String> _selectedEquipmentTypes = {};

  // 2. مكان أخذ العينة (Sampling Point - Mandatory *) - Default is empty
  final Set<String> _selectedSamplingPoints = {};

  // Sub-options for "Other (أخرى)" in Sampling Point
  final Set<String> _selectedOtherSamplingPoints = {};

  // 3. الفحوصات المطلوبة (Tests Requested - Mandatory *) - Default is empty
  final Set<String> _selectedTests = {};

  // 4. سبب الفحص (Sampling Reason) - Default is empty
  final Set<String> _selectedReasons = {};

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selectedCount = widget.selectedTransformers.length;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: const Color(0xFF0F766E),
          foregroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close_rounded, size: 24),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.science_rounded, size: 20, color: Colors.white),
              SizedBox(width: 8),
              Text(
                'نموذج عينة الزيت',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          centerTitle: true,
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Prominent, Eye-Catching Equipment Count Banner Card
                      _buildProminentEquipmentBanner(isDark, selectedCount),
                      const SizedBox(height: 18),

                      // 1. نوع المعدة (اختياري)
                      _buildSectionHeader(
                        number: '1.',
                        title: 'نوع المعدة',
                        optionalTag: '(اختياري)',
                        icon: Icons.bolt_rounded,
                        iconColor: const Color(0xFFA855F7),
                        isDark: isDark,
                      ),
                      const SizedBox(height: 8),
                      _buildTwoColumnGrid(
                        itemsRow1: const ['Transformer', 'Shunt Reactor'],
                        itemsRow2: const ['New Oil', 'Load Tapchanger'],
                        itemsRow3: const ['Circuit Breaker', 'Others'],
                        selectedSet: _selectedEquipmentTypes,
                        isDark: isDark,
                      ),
                      const SizedBox(height: 22),

                      // 2. مكان أخذ العينة *
                      _buildSectionHeader(
                        number: '2.',
                        title: 'مكان أخذ العينة',
                        isRequired: true,
                        icon: Icons.opacity_rounded,
                        iconColor: const Color(0xFFF59E0B),
                        isDark: isDark,
                      ),
                      const SizedBox(height: 8),
                      _buildSamplingPointsSection(isDark),
                      const SizedBox(height: 22),

                      // 3. الفحوصات المطلوبة *
                      _buildSectionHeader(
                        number: '3.',
                        title: 'الفحوصات المطلوبة',
                        isRequired: true,
                        icon: Icons.science_outlined,
                        iconColor: const Color(0xFF3B82F6),
                        isDark: isDark,
                      ),
                      const SizedBox(height: 8),
                      _buildFullWidthList(
                        items: const [
                          'Oil Quality Test (OQ)',
                          'Dissolved Gas-in-Oil Analysis (DGA)',
                          'Furanic Compounds',
                          'Corrosive Sulfur',
                          'Passivators',
                        ],
                        selectedSet: _selectedTests,
                        isDark: isDark,
                      ),
                      const SizedBox(height: 22),

                      // 4. سبب الفحص
                      _buildSectionHeader(
                        number: '4.',
                        title: 'سبب الفحص',
                        icon: Icons.assignment_outlined,
                        iconColor: const Color(0xFF10B981),
                        isDark: isDark,
                      ),
                      const SizedBox(height: 8),
                      _buildTwoColumnGrid(
                        itemsRow1: const ['Commissioning', 'Investigate'],
                        itemsRow2: const ['Warranty', 'Failure'],
                        itemsRow3: const ['Annual', '# Processing Sample'],
                        selectedSet: _selectedReasons,
                        isDark: isDark,
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),

              // Bottom Actions Bar
              _buildBottomBar(isDark),
            ],
          ),
        ),
      ),
    );
  }

  /// Prominent, Eye-Catching Equipment Banner Card
  Widget _buildProminentEquipmentBanner(bool isDark, int selectedCount) {
    final unitWord = selectedCount == 1
        ? 'جهاز واحد'
        : selectedCount == 2
            ? '2 أجهزة'
            : '$selectedCount أجهزة';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF064E3B), const Color(0xFF0F766E)]
              : [const Color(0xFFCCFBF1), const Color(0xFFE6FFFA)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF0F766E).withValues(alpha: 0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F766E).withValues(alpha: isDark ? 0.3 : 0.12),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F766E),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0F766E).withValues(alpha: 0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.electric_bolt_rounded,
                  color: Colors.amberAccent,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'سيتم تطبيق هذه الإعدادات على ',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.grey.shade300 : const Color(0xFF134E4A),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F766E),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            unitWord,
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'المحطة: ${widget.selectedSubstation.name} (${widget.selectedSubstation.region})',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: isDark ? Colors.tealAccent.shade100 : const Color(0xFF0F766E),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (widget.selectedTransformers.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 5,
              children: widget.selectedTransformers.map((tx) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFF0F766E).withValues(alpha: 0.35),
                      width: 1.2,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle_rounded,
                          size: 13, color: Color(0xFF0F766E)),
                      const SizedBox(width: 4),
                      Text(
                        '${tx.number} ${tx.voltage.isNotEmpty ? "(${tx.voltage})" : ""}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF0F766E),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionHeader({
    required String number,
    required String title,
    String? optionalTag,
    bool isRequired = false,
    required IconData icon,
    required Color iconColor,
    required bool isDark,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: iconColor),
            const SizedBox(width: 6),
            Text(
              '$number $title',
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            if (isRequired) ...[
              const SizedBox(width: 4),
              const Text(
                '*',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
            if (optionalTag != null) ...[
              const SizedBox(width: 6),
              Text(
                optionalTag,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade500,
                  fontWeight: FontWeight.normal,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 4),
        Divider(
          height: 1,
          thickness: 0.8,
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ],
    );
  }

  Widget _buildTwoColumnGrid({
    required List<String> itemsRow1,
    required List<String> itemsRow2,
    required List<String> itemsRow3,
    required Set<String> selectedSet,
    required bool isDark,
  }) {
    return Column(
      children: [
        _buildRow(itemsRow1[0], itemsRow1[1], selectedSet, isDark),
        const SizedBox(height: 8),
        _buildRow(itemsRow2[0], itemsRow2[1], selectedSet, isDark),
        const SizedBox(height: 8),
        _buildRow(itemsRow3[0], itemsRow3[1], selectedSet, isDark),
      ],
    );
  }

  Widget _buildRow(
    String item1,
    String item2,
    Set<String> selectedSet,
    bool isDark,
  ) {
    return Row(
      children: [
        Expanded(child: _buildTile(item1, selectedSet, isDark)),
        const SizedBox(width: 10),
        Expanded(child: _buildTile(item2, selectedSet, isDark)),
      ],
    );
  }

  Widget _buildFullWidthList({
    required List<String> items,
    required Set<String> selectedSet,
    required bool isDark,
  }) {
    return Column(
      children: items.map((item) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _buildTile(item, selectedSet, isDark, isFullWidth: true),
        );
      }).toList(),
    );
  }

  /// Section 2: Sampling Points including expandable Other (أخرى) Card
  Widget _buildSamplingPointsSection(bool isDark) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _buildTile('Main Tank Bottom', _selectedSamplingPoints, isDark, isFullWidth: true),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _buildTile('Main Tank Top', _selectedSamplingPoints, isDark, isFullWidth: true),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _buildOtherSamplingPointCard(isDark),
        ),
      ],
    );
  }

  /// Expandable "Other (أخرى)" Card with 2-column sub-options
  Widget _buildOtherSamplingPointCard(bool isDark) {
    final isOtherSelected = _selectedSamplingPoints.contains('Other (أخرى)');

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: isOtherSelected
            ? const Color(0xFF0F766E).withValues(alpha: isDark ? 0.15 : 0.04)
            : (isDark ? const Color(0xFF1E293B) : Colors.white),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isOtherSelected
              ? const Color(0xFF0F766E)
              : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          width: isOtherSelected ? 1.5 : 1.0,
        ),
        boxShadow: isOtherSelected
            ? [
                BoxShadow(
                  color: const Color(0xFF0F766E).withValues(alpha: 0.12),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Row
          InkWell(
            onTap: () {
              setState(() {
                if (isOtherSelected) {
                  _selectedSamplingPoints.remove('Other (أخرى)');
                } else {
                  _selectedSamplingPoints.add('Other (أخرى)');
                }
              });
            },
            borderRadius: isOtherSelected
                ? const BorderRadius.vertical(top: Radius.circular(12))
                : BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Other (أخرى)',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: isOtherSelected ? FontWeight.bold : FontWeight.w600,
                        color: isOtherSelected
                            ? (isDark ? Colors.tealAccent : const Color(0xFF0F766E))
                            : (isDark ? Colors.white : const Color(0xFF1E293B)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(
                        color: isOtherSelected
                            ? const Color(0xFF0F766E)
                            : (isDark ? Colors.grey.shade500 : const Color(0xFF94A3B8)),
                        width: 1.5,
                      ),
                      color: isOtherSelected ? const Color(0xFF0F766E) : Colors.transparent,
                    ),
                    child: isOtherSelected
                        ? const Icon(
                            Icons.check,
                            size: 15,
                            color: Colors.white,
                          )
                        : null,
                  ),
                ],
              ),
            ),
          ),

          // Expanded Sub-Options (4 rows of 2 columns)
          if (isOtherSelected) ...[
            Divider(
              height: 1,
              thickness: 0.8,
              color: isDark
                  ? const Color(0xFF334155)
                  : const Color(0xFF0F766E).withValues(alpha: 0.2),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                children: [
                  // Row 1: CBL R | CBL Y
                  _buildOtherSubRow('CBL R', 'CBL Y', isDark),
                  const SizedBox(height: 8),
                  // Row 2: CBL B | CBL N
                  _buildOtherSubRow('CBL B', 'CBL N', isDark),
                  const SizedBox(height: 8),
                  // Row 3: ONE CBL (R-Y-B) | OLTC 1
                  _buildOtherSubRow('ONE CBL (R-Y-B)', 'OLTC 1', isDark),
                  const SizedBox(height: 8),
                  // Row 4: OLTC 2 | OLTC 3
                  _buildOtherSubRow('OLTC 2', 'OLTC 3', isDark),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOtherSubRow(String itemRight, String itemLeft, bool isDark) {
    return Row(
      children: [
        Expanded(child: _buildSubTile(itemRight, isDark)),
        const SizedBox(width: 8),
        Expanded(child: _buildSubTile(itemLeft, isDark)),
      ],
    );
  }

  Widget _buildSubTile(String title, bool isDark) {
    final isSelected = _selectedOtherSamplingPoints.contains(title);

    return InkWell(
      onTap: () {
        setState(() {
          if (isSelected) {
            _selectedOtherSamplingPoints.remove(title);
          } else {
            _selectedOtherSamplingPoints.add(title);
          }
        });
      },
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF0F766E).withValues(alpha: isDark ? 0.25 : 0.1)
              : (isDark ? const Color(0xFF0F172A) : Colors.white),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF0F766E)
                : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
            width: isSelected ? 1.3 : 1.0,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected
                      ? (isDark ? Colors.tealAccent : const Color(0xFF0F766E))
                      : (isDark ? Colors.white : const Color(0xFF1E293B)),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF0F766E)
                      : (isDark ? Colors.grey.shade500 : const Color(0xFF94A3B8)),
                  width: 1.3,
                ),
                color: isSelected ? const Color(0xFF0F766E) : Colors.transparent,
              ),
              child: isSelected
                  ? const Icon(
                      Icons.check,
                      size: 11,
                      color: Colors.white,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTile(
    String title,
    Set<String> selectedSet,
    bool isDark, {
    bool isFullWidth = false,
  }) {
    final isSelected = selectedSet.contains(title);

    return InkWell(
      onTap: () {
        setState(() {
          if (isSelected) {
            selectedSet.remove(title);
          } else {
            selectedSet.add(title);
          }
        });
      },
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF0F766E).withValues(alpha: isDark ? 0.2 : 0.08)
              : (isDark ? const Color(0xFF1E293B) : Colors.white),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF0F766E)
                : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            width: isSelected ? 1.5 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF0F766E).withValues(alpha: 0.12),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                title,
                textAlign: isFullWidth ? TextAlign.center : TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected
                      ? (isDark ? Colors.tealAccent : const Color(0xFF0F766E))
                      : (isDark ? Colors.white : const Color(0xFF1E293B)),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF0F766E)
                      : (isDark ? Colors.grey.shade500 : const Color(0xFF94A3B8)),
                  width: 1.5,
                ),
                color: isSelected ? const Color(0xFF0F766E) : Colors.transparent,
              ),
              child: isSelected
                  ? const Icon(
                      Icons.check,
                      size: 13,
                      color: Colors.white,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            width: 1.0,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Export Form Button
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F766E),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 11),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 2,
            ),
            icon: const Text(
              'تصدير النموذج',
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            label: const Icon(
              Icons.chevron_left_rounded,
              size: 22,
              color: Colors.white,
            ),
            onPressed: _handleViewForm,
          ),

          // Cancel Button
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: isDark ? Colors.grey.shade300 : const Color(0xFF334155),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
            ),
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'إلغاء',
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleViewForm() async {
    if (_selectedSamplingPoints.isEmpty) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          elevation: 0,
          backgroundColor: Colors.transparent,
          behavior: SnackBarBehavior.floating,
          padding: EdgeInsets.zero,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          duration: const Duration(seconds: 4),
          content: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.35),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFD97706).withValues(alpha: 0.4),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.45),
                      width: 1.2,
                    ),
                  ),
                  child: const Icon(
                    Icons.opacity_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'مكان أخذ العينة مطلوب',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'يرجى تحديد مكان أخذ العينة على الأقل',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      return;
    }

    if (_selectedTests.isEmpty) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          elevation: 0,
          backgroundColor: Colors.transparent,
          behavior: SnackBarBehavior.floating,
          padding: EdgeInsets.zero,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          duration: const Duration(seconds: 4),
          content: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.35),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1D4ED8).withValues(alpha: 0.4),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.45),
                      width: 1.2,
                    ),
                  ),
                  child: const Icon(
                    Icons.science_outlined,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'الفحوصات المطلوبة إلزامية',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'يرجى تحديد فحص واحد على الأقل من الفحوصات المطلوبة',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      return;
    }

    // Navigate to Oil Sampling Approval Screen
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OilSamplingApprovalScreen(
          form: widget.form,
          selectedSubstation: widget.selectedSubstation,
          selectedTransformers: widget.selectedTransformers,
          initialDivision: widget.initialDivision,
          initialDepartment: widget.initialDepartment,
          initialContactPerson: widget.initialContactPerson,
          initialSampleTemp: widget.initialSampleTemp,
          initialInspectionDate: widget.initialInspectionDate,
          equipmentTypes: _selectedEquipmentTypes,
          samplingPoints: _selectedSamplingPoints,
          otherSamplingPoints: _selectedOtherSamplingPoints,
          testsRequired: _selectedTests,
          reasonsForTest: _selectedReasons,
        ),
      ),
    );
  }
}
