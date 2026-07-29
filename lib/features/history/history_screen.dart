import 'dart:io';

import 'package:excel/excel.dart' as xlsx;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/gradient_header.dart';
import '../../core/providers/providers.dart';
import '../../models/app_user.dart';
import '../../models/daily_record.dart';
import '../../models/patient.dart';
import '../../models/vital_signs.dart';

const _statusConfig = {
  'normal': (
    label: 'Normal',
    dot: AppColors.alertGreen,
    text: AppColors.alertGreen,
    bg: AppColors.alertGreenBg,
  ),
  'alerta': (
    label: 'Alerta',
    dot: AppColors.alertYellow,
    text: AppColors.alertYellow,
    bg: AppColors.alertYellowBg,
  ),
  'critico': (
    label: 'Crítico',
    dot: AppColors.alertRed,
    text: AppColors.alertRed,
    bg: AppColors.alertRedBg,
  ),
};

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key, this.filterDate, this.origin});

  /// Si se prove, filtra registros de ese día (sin hora).
  final DateTime? filterDate;

  /// Origen de la navegación: 'record' para volver con icono de registro.
  final String? origin;

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  String _selectedFilter = 'Todos';
  String? _expandedId;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  final List<DailyRecord> _extraRecords = [];
  DateTime? _startDate;
  DateTime? _endDate;

  DateTime? get _activeDateFilter => widget.filterDate;

  static const _filters = [
    'Todos',
    'Normal',
    'Alerta',
    'Crítico',
  ];

  String _dateStr(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}-${d.year}';

  String _timeStr(DateTime d) {
    final h = d.hour > 12 ? d.hour - 12 : d.hour == 0 ? 12 : d.hour;
    final m = d.minute.toString().padLeft(2, '0');
    final period = d.hour >= 12 ? 'PM' : 'AM';
    return '${h.toString().padLeft(2, '0')}:$m $period';
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  bool _matchesDateFilter(DailyRecord record) {
    final dashboardDate = _activeDateFilter;
    if (dashboardDate != null && !_isSameDay(record.date, dashboardDate)) {
      return false;
    }
    final start = _startDate;
    if (start != null) {
      final startDay = DateTime(start.year, start.month, start.day);
      if (record.date.isBefore(startDay)) return false;
    }
    final end = _endDate;
    if (end != null) {
      final endExclusive = DateTime(end.year, end.month, end.day)
          .add(const Duration(days: 1));
      if (!record.date.isBefore(endExclusive)) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final recordsAsync = ref.watch(dailyRecordsProvider);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) context.pop();
      },
      child: Scaffold(
      backgroundColor: AppColors.cream,
      body: Column(
        children: [
          GradientHeader(
            showBackButton: true,
            title: 'Ver historial',
            backIcon: widget.origin == 'record'
                ? Icons.show_chart
                : Icons.home_rounded,
            onBackPressed: () => context.pop(),
          ),
          Expanded(
            child: recordsAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.goldPrimary),
              ),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: AppColors.error),
                      const SizedBox(height: 16),
                      Text(
                        'Error al cargar registros: $e',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.nunito(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              data: (records) {
                // Combinar registros del stream con los cargados por paginación
                final allRecords = [
                  ...records,
                  ..._extraRecords.where(
                    (extra) => !records.any((r) => r.id == extra.id),
                  ),
                ];

                // Filtro por fecha del día (si vino del dashboard)
                final dateFiltered = allRecords.where(_matchesDateFilter).toList();

                final filtered = _selectedFilter == 'Todos'
                    ? dateFiltered
                    : dateFiltered.where((r) {
                        final cfg = _statusConfig[r.alertLevel.name];
                        return cfg != null && cfg.label == _selectedFilter;
                      }).toList();

                if (allRecords.isEmpty) {
                  return const EmptyState(
                    icon: Icons.history,
                    title: 'No hay registros aún',
                    subtitle: 'Crea el primer registro desde el botón de abajo.',
                  );
                }

                return Column(
                  children: [
                    const SizedBox(height: 12),
                    _buildFilterChips(),
                    const SizedBox(height: 8),
                    _buildDateActions(filtered),
                    const SizedBox(height: 12),
                    Expanded(
                      child: filtered.isEmpty
                          ? const EmptyState(
                              icon: Icons.history,
                              title: 'No hay registros para este filtro.',
                              subtitle: 'Intenta con otro filtro.',
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.md,
                                vertical: 4,
                              ),
                              itemCount: filtered.length + (_hasMore ? 1 : 0),
                              separatorBuilder: (_, _) => const SizedBox(height: 8),
                              itemBuilder: (ctx, i) {
                                if (i == filtered.length) {
                                  // Botón "Cargar más"
                                  return _buildLoadMoreButton(records);
                                }
                                return _buildRecordCard(filtered[i]);
                              },
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    ));
  }

  Widget _buildFilterChips() {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        itemCount: _filters.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (ctx, i) {
          final f = _filters[i];
          final selected = _selectedFilter == f;
          return GestureDetector(
            onTap: () => setState(() => _selectedFilter = f),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: selected
                    ? const Color(0xFFE8A820)
                    : const Color(0xFFFFF4D0),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                f,
                style: GoogleFonts.nunito(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: selected
                      ? Colors.white
                      : const Color(0xFF7A6030),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDateActions(List<DailyRecord> filteredRecords) {
    final hasRange = _startDate != null || _endDate != null;
    final label = hasRange
        ? '${_startDate != null ? _dateStr(_startDate!) : 'Inicio'} - ${_endDate != null ? _dateStr(_endDate!) : 'Hoy'}'
        : 'Filtrar fecha';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _pickDateRange,
              icon: const Icon(Icons.date_range, size: 16),
              label: Text(
                label,
                overflow: TextOverflow.ellipsis,
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.goldDark,
                side: BorderSide(
                  color: AppColors.goldPrimary.withValues(alpha: 0.35),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          if (hasRange) ...[
            const SizedBox(width: 8),
            IconButton(
              onPressed: () => setState(() {
                _startDate = null;
                _endDate = null;
              }),
              icon: const Icon(Icons.close),
              color: AppColors.textSecondary,
            ),
          ],
          const SizedBox(width: 8),
          IconButton.filled(
            onPressed: filteredRecords.isEmpty
                ? null
                : () => _exportPdf(filteredRecords),
            icon: const Icon(Icons.picture_as_pdf, size: 18),
            style: IconButton.styleFrom(
              backgroundColor: AppColors.goldPrimary,
              foregroundColor: Colors.white,
              disabledBackgroundColor: AppColors.divider,
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            onPressed: filteredRecords.isEmpty
                ? null
                : () => _exportExcel(filteredRecords),
            icon: const Icon(Icons.table_chart, size: 18),
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFF217346),
              foregroundColor: Colors.white,
              disabledBackgroundColor: AppColors.divider,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
      helpText: 'Filtrar historial',
      saveText: 'Aplicar',
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
                primary: AppColors.goldPrimary,
              ),
        ),
        child: child!,
      ),
    );
    if (range == null) return;
    setState(() {
      _startDate = range.start;
      _endDate = range.end;
    });
  }

  Future<void> _exportPdf(List<DailyRecord> records) async {
    try {
      final patient = ref.read(currentPatientProvider).value;
      final user = ref.read(userProvider).value;
      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}${Platform.pathSeparator}historial_oncuidar_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
      await file.writeAsBytes(await _buildHistoryPdf(records, patient, user), flush: true);
      final result = await OpenFilex.open(file.path);
      if (result.type != ResultType.done && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.message.isNotEmpty
                  ? result.message
                  : 'No hay una aplicación para abrir PDF.',
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo generar el PDF: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _exportExcel(List<DailyRecord> records) async {
    try {
      final patient = ref.read(currentPatientProvider).value;
      final user = ref.read(userProvider).value;
      final excel = xlsx.Excel.createExcel();
      // Eliminar Sheet1 por defecto
      if (excel.sheets.containsKey('Sheet1')) {
        excel.delete('Sheet1');
      }
      final sheet = excel['Historial'];

      // Estilos
      final titleStyle = xlsx.CellStyle(
        bold: true,
        fontSize: 14,
        backgroundColorHex: xlsx.ExcelColor.fromHexString('#E8A820'),
        fontColorHex: xlsx.ExcelColor.fromHexString('#FFFFFF'),
      );
      final sectionStyle = xlsx.CellStyle(
        bold: true,
        fontSize: 11,
        backgroundColorHex: xlsx.ExcelColor.fromHexString('#FFF4D0'),
      );
      final labelStyle = xlsx.CellStyle(
        bold: true,
        fontSize: 10,
      );
      final valueStyle = xlsx.CellStyle(
        fontSize: 10,
      );
      final columnHeaderStyle = xlsx.CellStyle(
        bold: true,
        fontSize: 11,
        backgroundColorHex: xlsx.ExcelColor.fromHexString('#E8A820'),
        fontColorHex: xlsx.ExcelColor.fromHexString('#FFFFFF'),
      );

      var row = 0;

      // Título
      _setMergedCell(sheet, row, 'HISTORIAL ONCUIDAR', titleStyle);
      row++;

      // Paciente
      if (patient != null) {
        _setMergedCell(sheet, row, 'PACIENTE', sectionStyle);
        row++;
        _setLabelValue(sheet, row, 'Nombre', patient.fullName, labelStyle, valueStyle);
        row++;
        if (patient.age != null) {
          _setLabelValue(sheet, row, 'Edad', '${patient.age} años', labelStyle, valueStyle);
          row++;
        }
        if (patient.birthDate != null) {
          _setLabelValue(sheet, row, 'Fecha de nacimiento', _dateStr(patient.birthDate!), labelStyle, valueStyle);
          row++;
        }
        _setLabelValue(sheet, row, 'Diagnóstico', patient.diagnosis, labelStyle, valueStyle);
        row++;
        if (patient.treatmentPhase != null && patient.treatmentPhase!.isNotEmpty) {
          _setLabelValue(sheet, row, 'Fase del tratamiento', patient.treatmentPhase!, labelStyle, valueStyle);
          row++;
        }
        if (patient.diagnosisDate != null) {
          _setLabelValue(sheet, row, 'Fecha de diagnóstico', _dateStr(patient.diagnosisDate!), labelStyle, valueStyle);
          row++;
        }
        row++;
      }

      // Cuidador
      if (user != null) {
        _setMergedCell(sheet, row, 'CUIDADOR', sectionStyle);
        row++;
        _setLabelValue(sheet, row, 'Nombre', user.displayName, labelStyle, valueStyle);
        row++;
        if (user.relationship != null && user.relationship!.isNotEmpty) {
          _setLabelValue(sheet, row, 'Parentesco', user.relationship!, labelStyle, valueStyle);
          row++;
        }
        if (user.email != null && user.email!.isNotEmpty) {
          _setLabelValue(sheet, row, 'Email', user.email!, labelStyle, valueStyle);
          row++;
        }
        if (user.phone != null && user.phone!.isNotEmpty) {
          _setLabelValue(sheet, row, 'Teléfono', user.phone!, labelStyle, valueStyle);
          row++;
        }
        row++;
      }

      // Centro de salud
      if (patient?.healthCenterName != null &&
          patient!.healthCenterName!.isNotEmpty) {
        _setMergedCell(sheet, row, 'CENTRO DE SALUD', sectionStyle);
        row++;
        _setLabelValue(sheet, row, 'Nombre', patient.healthCenterName!, labelStyle, valueStyle);
        row++;
        if (patient.healthCenterAddress != null && patient.healthCenterAddress!.isNotEmpty) {
          _setLabelValue(sheet, row, 'Dirección', patient.healthCenterAddress!, labelStyle, valueStyle);
          row++;
        }
        if (patient.healthCenterPhone != null && patient.healthCenterPhone!.isNotEmpty) {
          _setLabelValue(sheet, row, 'Teléfono', patient.healthCenterPhone!, labelStyle, valueStyle);
          row++;
        }
        row++;
      }

      // Contacto de emergencia
      if (patient?.emergencyContactName != null &&
          patient!.emergencyContactName!.isNotEmpty) {
        _setMergedCell(sheet, row, 'CONTACTO DE EMERGENCIA', sectionStyle);
        row++;
        _setLabelValue(sheet, row, 'Nombre', patient.emergencyContactName!, labelStyle, valueStyle);
        row++;
        if (patient.emergencyContactPhone != null && patient.emergencyContactPhone!.isNotEmpty) {
          _setLabelValue(sheet, row, 'Teléfono', patient.emergencyContactPhone!, labelStyle, valueStyle);
          row++;
        }
        row++;
      }

      // Info del reporte
      _setLabelValue(sheet, row, 'Rango',
          '${_startDate != null ? _dateStr(_startDate!) : 'sin inicio'} - ${_endDate != null ? _dateStr(_endDate!) : 'sin fin'}',
          labelStyle, valueStyle);
      row++;
      _setLabelValue(sheet, row, 'Total registros', '${records.length}', labelStyle, valueStyle);
      row++;
      _setLabelValue(sheet, row, 'Generado',
          '${_dateStr(DateTime.now())} ${_timeStr(DateTime.now())}',
          labelStyle, valueStyle);
      row += 2;

      // Encabezados de columna
      final headers = [
        'Fecha',
        'Hora',
        'Tipo',
        'Estado',
        'Temp.',
        'Freq. Card.',
        'Sat. O₂',
        'Freq. Resp.',
        'Síntomas',
        'Observaciones',
      ];

      for (var i = 0; i < headers.length; i++) {
        final cell = sheet.cell(
          xlsx.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: row),
        );
        cell.value = xlsx.TextCellValue(headers[i]);
        cell.cellStyle = columnHeaderStyle;
      }
      row++;

      // Datos
      for (final rec in records) {
        final vs = rec.vitalSigns;
        sheet.cell(xlsx.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value = xlsx.TextCellValue(_dateStr(rec.date));
        sheet.cell(xlsx.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row)).value = xlsx.TextCellValue(_timeStr(rec.createdAt));
        sheet.cell(xlsx.CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row)).value = xlsx.TextCellValue(rec.recordType);
        sheet.cell(xlsx.CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row)).value = xlsx.TextCellValue(rec.alertLevel.name);
        sheet.cell(xlsx.CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row)).value = xlsx.TextCellValue(vs?.temperature != null ? '${vs!.temperature}°C' : '');
        sheet.cell(xlsx.CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: row)).value = xlsx.TextCellValue(vs?.heartRate != null ? '${vs!.heartRate} lpm' : '');
        sheet.cell(xlsx.CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: row)).value = xlsx.TextCellValue(vs?.oxygenSaturation != null ? '${vs!.oxygenSaturation}%' : '');
        sheet.cell(xlsx.CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: row)).value = xlsx.TextCellValue(vs?.respiratoryRate != null ? '${vs!.respiratoryRate} rpm' : '');
        sheet.cell(xlsx.CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: row)).value = xlsx.TextCellValue(
          rec.symptoms.map((s) => '${s.name} ${s.label} (${s.intensity}/10)').join(', '),
        );
        sheet.cell(xlsx.CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: row)).value = xlsx.TextCellValue(rec.generalNotes ?? '');
        row++;
      }

      // Auto-anchos de columnas
      for (var i = 0; i < headers.length; i++) {
        sheet.setColumnWidth(i, 18);
      }

      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}${Platform.pathSeparator}historial_oncuidar_${DateTime.now().millisecondsSinceEpoch}.xlsx',
      );
      final bytes = excel.save();
      if (bytes != null) {
        await file.writeAsBytes(bytes, flush: true);
        final result = await OpenFilex.open(file.path);
        if (result.type != ResultType.done && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                result.message.isNotEmpty
                    ? result.message
                    : 'No hay una aplicación para abrir Excel.',
              ),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo generar el Excel: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _setMergedCell(
    xlsx.Sheet sheet,
    int row,
    String value,
    xlsx.CellStyle style,
  ) {
    final start = xlsx.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row);
    final end = xlsx.CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: row);
    sheet.merge(start, end);
    final cell = sheet.cell(start);
    cell.value = xlsx.TextCellValue(value);
    cell.cellStyle = style;
  }

  void _setLabelValue(
    xlsx.Sheet sheet,
    int row,
    String label,
    String value,
    xlsx.CellStyle labelStyle,
    xlsx.CellStyle valueStyle,
  ) {
    final labelCell = sheet.cell(
      xlsx.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row),
    );
    labelCell.value = xlsx.TextCellValue(label);
    labelCell.cellStyle = labelStyle;

    final start = xlsx.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row);
    final end = xlsx.CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: row);
    sheet.merge(start, end);
    final valueCell = sheet.cell(start);
    valueCell.value = xlsx.TextCellValue(value);
    valueCell.cellStyle = valueStyle;
  }

  Future<List<int>> _buildHistoryPdf(
    List<DailyRecord> records,
    Patient? patient,
    AppUser? user,
  ) async {
    final pdf = pw.Document();
    final goldColor = PdfColor.fromHex('#E8A820');
    final lightGold = PdfColor.fromHex('#FFF4D0');
    final darkText = PdfColor.fromHex('#333333');
    final secondaryText = PdfColor.fromHex('#666666');

    final titleStyle = pw.TextStyle(
      fontSize: 20,
      fontWeight: pw.FontWeight.bold,
      color: PdfColors.white,
    );
    final sectionStyle = pw.TextStyle(
      fontSize: 13,
      fontWeight: pw.FontWeight.bold,
      color: goldColor,
    );
    final labelStyle = pw.TextStyle(
      fontSize: 10,
      fontWeight: pw.FontWeight.bold,
      color: darkText,
    );
    final valueStyle = pw.TextStyle(
      fontSize: 10,
      color: secondaryText,
    );
    final columnHeaderStyle = pw.TextStyle(
      fontSize: 9,
      fontWeight: pw.FontWeight.bold,
      color: PdfColors.white,
    );
    final cellStyle = pw.TextStyle(
      fontSize: 8,
      color: darkText,
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(30),
        header: (context) => pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: pw.BoxDecoration(
            color: goldColor,
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: pw.Row(
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('HISTORIAL ONCUIDAR', style: titleStyle),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Generado: ${_dateStr(DateTime.now())} ${_timeStr(DateTime.now())}',
                      style: pw.TextStyle(
                        fontSize: 9,
                        color: PdfColors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        footer: (context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(top: 10),
          child: pw.Text(
            'Página ${context.pageNumber} de ${context.pagesCount}',
            style: pw.TextStyle(fontSize: 8, color: secondaryText),
          ),
        ),
        build: (context) {
          final widgets = <pw.Widget>[];
          widgets.add(pw.SizedBox(height: 15));

          // ── Paciente ──
          if (patient != null) {
            widgets.add(_buildPdfSection('PACIENTE', sectionStyle, lightGold));
            widgets.add(pw.SizedBox(height: 6));
            widgets.add(_buildPdfRow('Nombre', patient.fullName, labelStyle, valueStyle));
            if (patient.age != null) {
              widgets.add(_buildPdfRow('Edad', '${patient.age} años', labelStyle, valueStyle));
            }
            if (patient.birthDate != null) {
              widgets.add(_buildPdfRow('Fecha de nacimiento', _dateStr(patient.birthDate!), labelStyle, valueStyle));
            }
            widgets.add(_buildPdfRow('Diagnóstico', patient.diagnosis, labelStyle, valueStyle));
            if (patient.treatmentPhase != null && patient.treatmentPhase!.isNotEmpty) {
              widgets.add(_buildPdfRow('Fase del tratamiento', patient.treatmentPhase!, labelStyle, valueStyle));
            }
            if (patient.diagnosisDate != null) {
              widgets.add(_buildPdfRow('Fecha de diagnóstico', _dateStr(patient.diagnosisDate!), labelStyle, valueStyle));
            }
            widgets.add(pw.SizedBox(height: 10));
          }

          // ── Cuidador ──
          if (user != null) {
            widgets.add(_buildPdfSection('CUIDADOR', sectionStyle, lightGold));
            widgets.add(pw.SizedBox(height: 6));
            widgets.add(_buildPdfRow('Nombre', user.displayName, labelStyle, valueStyle));
            if (user.relationship != null && user.relationship!.isNotEmpty) {
              widgets.add(_buildPdfRow('Parentesco', user.relationship!, labelStyle, valueStyle));
            }
            if (user.email != null && user.email!.isNotEmpty) {
              widgets.add(_buildPdfRow('Email', user.email!, labelStyle, valueStyle));
            }
            if (user.phone != null && user.phone!.isNotEmpty) {
              widgets.add(_buildPdfRow('Teléfono', user.phone!, labelStyle, valueStyle));
            }
            widgets.add(pw.SizedBox(height: 10));
          }

          // ── Centro de salud ──
          if (patient?.healthCenterName != null && patient!.healthCenterName!.isNotEmpty) {
            widgets.add(_buildPdfSection('CENTRO DE SALUD', sectionStyle, lightGold));
            widgets.add(pw.SizedBox(height: 6));
            widgets.add(_buildPdfRow('Nombre', patient.healthCenterName!, labelStyle, valueStyle));
            if (patient.healthCenterAddress != null && patient.healthCenterAddress!.isNotEmpty) {
              widgets.add(_buildPdfRow('Dirección', patient.healthCenterAddress!, labelStyle, valueStyle));
            }
            if (patient.healthCenterPhone != null && patient.healthCenterPhone!.isNotEmpty) {
              widgets.add(_buildPdfRow('Teléfono', patient.healthCenterPhone!, labelStyle, valueStyle));
            }
            widgets.add(pw.SizedBox(height: 10));
          }

          // ── Contacto de emergencia ──
          if (patient?.emergencyContactName != null && patient!.emergencyContactName!.isNotEmpty) {
            widgets.add(_buildPdfSection('CONTACTO DE EMERGENCIA', sectionStyle, lightGold));
            widgets.add(pw.SizedBox(height: 6));
            widgets.add(_buildPdfRow('Nombre', patient.emergencyContactName!, labelStyle, valueStyle));
            if (patient.emergencyContactPhone != null && patient.emergencyContactPhone!.isNotEmpty) {
              widgets.add(_buildPdfRow('Teléfono', patient.emergencyContactPhone!, labelStyle, valueStyle));
            }
            widgets.add(pw.SizedBox(height: 10));
          }

          // ── Resumen del reporte ──
          widgets.add(_buildPdfSection('RESUMEN', sectionStyle, lightGold));
          widgets.add(pw.SizedBox(height: 6));
          widgets.add(_buildPdfRow(
            'Rango',
            '${_startDate != null ? _dateStr(_startDate!) : 'sin inicio'} - ${_endDate != null ? _dateStr(_endDate!) : 'sin fin'}',
            labelStyle, valueStyle,
          ));
          widgets.add(_buildPdfRow('Total registros', '${records.length}', labelStyle, valueStyle));
          widgets.add(pw.SizedBox(height: 15));

          // ── Tabla de registros ──
          widgets.add(_buildPdfSection('REGISTROS', sectionStyle, lightGold));
          widgets.add(pw.SizedBox(height: 8));

          if (records.isEmpty) {
            widgets.add(pw.Text(
              'No hay registros para el rango seleccionado.',
              style: valueStyle,
            ));
          } else {
            // Tabla de signos vitales
            widgets.add(_buildRecordsTable(records, columnHeaderStyle, cellStyle, goldColor));
          }

          return widgets;
        },
      ),
    );

    return await pdf.save();
  }

  pw.Widget _buildPdfSection(String title, pw.TextStyle style, PdfColor bgColor) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: pw.BoxDecoration(
        color: bgColor,
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Text(title, style: style),
    );
  }

  pw.Widget _buildPdfRow(String label, String value, pw.TextStyle labelStyle, pw.TextStyle valueStyle) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 3),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 140,
            child: pw.Text(label, style: labelStyle),
          ),
          pw.Expanded(
            child: pw.Text(value, style: valueStyle),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildRecordsTable(
    List<DailyRecord> records,
    pw.TextStyle headerStyle,
    pw.TextStyle cellStyle,
    PdfColor goldColor,
  ) {
    final headers = ['Fecha', 'Hora', 'Tipo', 'Estado', 'Temp.', 'Freq. Card.', 'Sat. O\u2082', 'Freq. Resp.', 'S\u00EDntomas', 'Observaciones'];

    final data = records.map((rec) {
      final vs = rec.vitalSigns;
      return [
        _dateStr(rec.date),
        _timeStr(rec.createdAt),
        rec.recordType,
        rec.alertLevel.name,
        vs?.temperature != null ? '${vs!.temperature}\u00B0C' : '-',
        vs?.heartRate != null ? '${vs!.heartRate} lpm' : '-',
        vs?.oxygenSaturation != null ? '${vs!.oxygenSaturation}%' : '-',
        vs?.respiratoryRate != null ? '${vs!.respiratoryRate} rpm' : '-',
        rec.symptoms.map((s) => '${s.name} ${s.label} (${s.intensity}/10)').join(', '),
        rec.generalNotes ?? '-',
      ];
    }).toList();

    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: data,
      headerStyle: headerStyle,
      headerDecoration: pw.BoxDecoration(
        color: goldColor,
        borderRadius: pw.BorderRadius.only(
          topLeft: pw.Radius.circular(4),
          topRight: pw.Radius.circular(4),
        ),
      ),
      headerPadding: const pw.EdgeInsets.all(6),
      cellStyle: cellStyle,
      cellAlignment: pw.Alignment.centerLeft,
      cellPadding: const pw.EdgeInsets.all(5),
      cellHeight: 22,
      oddRowDecoration: pw.BoxDecoration(
        color: PdfColor.fromHex('#FAFAFA'),
      ),
      border: pw.TableBorder(
        horizontalInside: pw.BorderSide(
          color: PdfColor.fromHex('#E0E0E0'),
          width: 0.5,
        ),
      ),
    );
  }

  Widget _buildLoadMoreButton(List<DailyRecord> currentRecords) {
    if (_isLoadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: CircularProgressIndicator(color: AppColors.goldPrimary),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: GestureDetector(
          onTap: () => _loadMore(currentRecords),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF4D0),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.goldPrimary.withValues(alpha: 0.3),
              ),
            ),
            child: Text(
              'Cargar más registros',
              style: GoogleFonts.nunito(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.goldDark,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _loadMore(List<DailyRecord> currentRecords) async {
    if (_isLoadingMore || !_hasMore) return;

    setState(() => _isLoadingMore = true);

    try {
      final patientAsync = ref.read(currentPatientProvider);
      final patient = patientAsync.value;
      if (patient == null) {
        setState(() => _isLoadingMore = false);
        return;
      }

      // Obtener la fecha del último registro
      final allRecords = [...currentRecords, ..._extraRecords];
      if (allRecords.isEmpty) {
        setState(() {
          _isLoadingMore = false;
          _hasMore = false;
        });
        return;
      }

      final lastRecord = allRecords.last;
      final moreRecords = await ref
          .read(firestoreServiceProvider)
          .loadMoreDailyRecords(patient.id, lastRecord.createdAt);

      if (mounted) {
        setState(() {
          _isLoadingMore = false;
          if (moreRecords.isEmpty) {
            _hasMore = false;
          } else {
            _extraRecords.addAll(moreRecords);
            // Si cargamos menos del límite, no hay más
            if (moreRecords.length < 50) {
              _hasMore = false;
            }
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingMore = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar más registros: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Widget _buildRecordCard(DailyRecord rec) {
    final isOpen = _expandedId == rec.id;
    final st = _statusConfig[rec.alertLevel.name] ?? _statusConfig['normal']!;
    final vs = rec.vitalSigns;

    String recordLabel;
    if (rec.recordType == 'programado') {
      final allRecords = ref.read(dailyRecordsProvider).value ?? [];
      final patient = ref.read(currentPatientProvider).value;
      final maxPerDay = patient?.maxRecordsPerDay ?? 3;
      final sameDayScheduled = allRecords.where((r) =>
          r.recordType == 'programado' &&
          r.date.year == rec.date.year &&
          r.date.month == rec.date.month &&
          r.date.day == rec.date.day).toList();
      final position = sameDayScheduled.indexOf(rec) + 1;
      recordLabel = '· Registro ${position > 0 ? position : 1}/$maxPerDay';
    } else {
      recordLabel = '· Registro extra';
    }

    return Dismissible(
      key: Key(rec.id),
      direction: DismissDirection.horizontal,
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          // Swipe right → Editar
          context.push('/record/edit/${rec.id}');
          return false;
        } else {
          // Swipe left → Eliminar
          return await _confirmDelete(rec);
        }
      },
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        decoration: BoxDecoration(
          color: const Color(0xFFE8A820),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.edit, color: Colors.white, size: 20),
      ),
      secondaryBackground: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white, size: 20),
      ),
      child: GestureDetector(
        onTap: () {
          setState(() {
            _expandedId = isOpen ? null : rec.id;
          });
        },
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFFE8A820).withValues(alpha: 0.2),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFE8A820).withValues(alpha: 0.08),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            children: [
              // ── Header row ──
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Calendar icon
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF4D0),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.calendar_today,
                        color: Color(0xFFE8A820),
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Content
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Date + time + record type
                          Row(
                            children: [
                              Text(
                                  _dateStr(rec.date),
                                  style: GoogleFonts.nunito(
                                    fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                  _timeStr(rec.createdAt),
                                  style: GoogleFonts.nunito(
                                    fontSize: 13,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                recordLabel,
                                  style: GoogleFonts.nunito(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF8A5A05),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // Vital signs mini grid (2x2)
                          if (vs != null)
                            _buildVitalMiniGrid(vs),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // ── Bottom row: status + chevron ──
              Container(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: st.bg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: st.dot,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            st.label,
                            style: GoogleFonts.nunito(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: st.text,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      isOpen ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                      size: 18,
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
              ),
              // ── Expanded detail ──
              if (isOpen)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBF0),
                    border: Border(
                      top: BorderSide(
                        color: const Color(0xFFE8A820).withValues(alpha: 0.12),
                      ),
                    ),
                  ),
                  child: Column(
                    children: [
                      if (rec.symptoms.isNotEmpty)
                        ...rec.symptoms.map((s) => Container(
                              width: double.infinity,
                              margin: const EdgeInsets.only(top: 6),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: s.color.withValues(alpha: 0.06),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: s.color.withValues(alpha: 0.2),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Síntoma',
                                    style: GoogleFonts.nunito(
                                      fontSize: 14,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  Text(
                                    '${s.name} · ${s.label} (${s.intensity}/10)',
                                    style: GoogleFonts.nunito(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: s.color,
                                    ),
                                  ),
                                ],
                              ),
                            )),
                      if (rec.generalNotes != null && rec.generalNotes!.isNotEmpty)
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(top: 6),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFFE8A820).withValues(alpha: 0.15),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Observaciones',
                                style: GoogleFonts.nunito(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                rec.generalNotes!,
                                style: GoogleFonts.nunito(
                                  fontSize: 14,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
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
  }

  Widget _buildVitalMiniGrid(VitalSigns vs) {
    return Column(
      children: [
        Row(
          children: [
            if (vs.temperature != null)
              Expanded(child: _vitalMini(Icons.thermostat, '${vs.temperature}°C', const Color(0xFFF07830))),
            if (vs.temperature != null && vs.heartRate != null) const SizedBox(width: 8),
            if (vs.heartRate != null)
              Expanded(child: _vitalMini(Icons.favorite, '${vs.heartRate} lpm', const Color(0xFFF43F5E))),
          ],
        ),
        if (vs.oxygenSaturation != null || vs.respiratoryRate != null) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              if (vs.oxygenSaturation != null)
                Expanded(child: _vitalMini(Icons.show_chart, '${vs.oxygenSaturation}%', const Color(0xFF4EC4D4))),
              if (vs.oxygenSaturation != null && vs.respiratoryRate != null) const SizedBox(width: 8),
              if (vs.respiratoryRate != null)
                Expanded(child: _vitalMini(Icons.air, '${vs.respiratoryRate} rpm', const Color(0xFFA78BFA))),
            ],
          ),
        ],
      ],
    );
  }

  Future<bool?> _confirmDelete(DailyRecord rec) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          '¿Eliminar este registro?',
          style: GoogleFonts.nunito(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        content: Text(
          'Esta acción no se puede deshacer.',
          style: GoogleFonts.nunito(
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancelar',
              style: GoogleFonts.nunito(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx, true);
              final patientAsync = ref.read(currentPatientProvider);
              final patient = patientAsync.value;
              if (patient == null) return;
              try {
                await ref
                    .read(firestoreServiceProvider)
                    .deleteDailyRecord(patient.id, rec.id);
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error al eliminar: $e')),
                  );
                }
              }
            },
            child: Text(
              'Eliminar',
              style: GoogleFonts.nunito(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.error,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _vitalMini(IconData icon, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
      ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              value,
              style: GoogleFonts.nunito(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
    );
  }

}
