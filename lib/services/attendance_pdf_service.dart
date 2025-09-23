// lib/services/attendance_pdf_service.dart

import 'dart:io';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:intl/intl.dart';
import 'package:face_auth_compatible/model/attendance_model.dart';

class AttendancePdfService {

  // ✅ Generate and export attendance PDF
  static Future<bool> exportAttendanceToPdf({
    required List<AttendanceRecord> attendanceRecords,
    required String employeeName,
    required String employeeId,
    required String selectedMonth,
    required MonthlyAttendanceSummary summary,
  }) async {
    try {
      // Request storage permission
      bool hasPermission = await _requestStoragePermission();
      if (!hasPermission) {
        throw Exception('Storage permission denied');
      }

      // Generate PDF document
      final pdf = await _generatePdfDocument(
        attendanceRecords: attendanceRecords,
        employeeName: employeeName,
        employeeId: employeeId,
        selectedMonth: selectedMonth,
        summary: summary,
      );

      // Save and share PDF
      await _savePdfFile(pdf, employeeName, selectedMonth);

      return true;
    } catch (e) {
      print('Error exporting PDF: $e');
      return false;
    }
  }

  // ✅ Generate PDF document
  static Future<pw.Document> _generatePdfDocument({
    required List<AttendanceRecord> attendanceRecords,
    required String employeeName,
    required String employeeId,
    required String selectedMonth,
    required MonthlyAttendanceSummary summary,
  }) async {
    final pdf = pw.Document();

    // Format month for display
    String formattedMonth = DateFormat('MMMM yyyy').format(
        DateFormat('yyyy-MM').parse(selectedMonth)
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => _buildHeader(employeeName, employeeId, formattedMonth),
        footer: (context) => _buildFooter(context),
        build: (context) => [
          // Summary section
          _buildSummarySection(summary, formattedMonth),
          pw.SizedBox(height: 20),

          // Attendance table
          _buildAttendanceTable(attendanceRecords),

          pw.SizedBox(height: 20),

          // Overtime details
          _buildOvertimeDetails(attendanceRecords),

          pw.SizedBox(height: 20),

          // Legend
          _buildLegend(),
        ],
      ),
    );

    return pdf;
  }

  // ✅ Build PDF header
  static pw.Widget _buildHeader(String employeeName, String employeeId, String month) {
    return pw.Container(
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey400)),
      ),
      padding: const pw.EdgeInsets.only(bottom: 10),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'ATTENDANCE REPORT',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue900,
                ),
              ),
              pw.Text(
                month,
                style: pw.TextStyle(
                  fontSize: 14,
                  color: PdfColors.grey700,
                ),
              ),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                employeeName,
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(
                'ID: $employeeId',
                style: pw.TextStyle(
                  fontSize: 12,
                  color: PdfColors.grey600,
                ),
              ),
              pw.Text(
                'Generated: ${DateFormat('MMM dd, yyyy').format(DateTime.now())}',
                style: pw.TextStyle(
                  fontSize: 10,
                  color: PdfColors.grey500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ✅ Build footer
  static pw.Widget _buildFooter(pw.Context context) {
    return pw.Container(
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300)),
      ),
      padding: const pw.EdgeInsets.only(top: 5),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Company Attendance System',
            style: pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
          ),
          pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
          ),
        ],
      ),
    );
  }

  // ✅ Build summary section
  static pw.Widget _buildSummarySection(MonthlyAttendanceSummary summary, String month) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        color: PdfColors.blue50,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: PdfColors.blue200),
      ),
      padding: const pw.EdgeInsets.all(16),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Monthly Summary - $month',
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blue900,
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Row(
            children: [
              pw.Expanded(
                child: _buildSummaryCard('Total Days', '${summary.totalDays}', PdfColors.blue),
              ),
              pw.SizedBox(width: 10),
              pw.Expanded(
                child: _buildSummaryCard('Present Days', '${summary.presentDays}', PdfColors.green),
              ),
              pw.SizedBox(width: 10),
              pw.Expanded(
                child: _buildSummaryCard('Absent Days', '${summary.absentDays}', PdfColors.red),
              ),
              pw.SizedBox(width: 10),
              pw.Expanded(
                child: _buildSummaryCard('Sick Leave', '${summary.sickLeaveDays}', PdfColors.orange),
              ),
            ],
          ),
          pw.SizedBox(height: 10),
          pw.Row(
            children: [
              pw.Expanded(
                child: _buildSummaryCard('Total Hours', '${summary.totalWorkHours.toStringAsFixed(1)}h', PdfColors.indigo),
              ),
              pw.SizedBox(width: 10),
              pw.Expanded(
                child: _buildSummaryCard('Regular Hours', '${summary.totalRegularHours.toStringAsFixed(1)}h', PdfColors.teal),
              ),
              pw.SizedBox(width: 10),
              pw.Expanded(
                child: _buildSummaryCard('Overtime Hours', '${summary.totalOvertimeHours.toStringAsFixed(1)}h', PdfColors.deepOrange),
              ),
              pw.SizedBox(width: 10),
              pw.Expanded(
                child: _buildSummaryCard('Attendance %', '${summary.attendancePercentage.toStringAsFixed(1)}%', PdfColors.purple),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ✅ Build summary card
  static pw.Widget _buildSummaryCard(String title, String value, PdfColor color) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(color: color),
      ),
      child: pw.Column(
        children: [
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: color,
            ),
          ),
          pw.Text(
            title,
            style: pw.TextStyle(
              fontSize: 8,
              color: PdfColors.grey600,
            ),
            textAlign: pw.TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ✅ Build attendance table
  static pw.Widget _buildAttendanceTable(List<AttendanceRecord> records) {
    final headers = [
      'Date',
      'Day',
      'Check In',
      'Check Out',
      'Total Hours',
      'Overtime',
      'Status',
      'Location'
    ];

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Attendance Details',
          style: pw.TextStyle(
            fontSize: 16,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.blue900,
          ),
        ),
        pw.SizedBox(height: 10),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300),
          columnWidths: {
            0: const pw.FixedColumnWidth(60),
            1: const pw.FixedColumnWidth(40),
            2: const pw.FixedColumnWidth(50),
            3: const pw.FixedColumnWidth(50),
            4: const pw.FixedColumnWidth(50),
            5: const pw.FixedColumnWidth(50),
            6: const pw.FixedColumnWidth(80),
            7: const pw.FlexColumnWidth(),
          },
          children: [
            // Header row
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey200),
              children: headers.map((header) => pw.Container(
                padding: const pw.EdgeInsets.all(4),
                child: pw.Text(
                  header,
                  style: pw.TextStyle(
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                  ),
                  textAlign: pw.TextAlign.center,
                ),
              )).toList(),
            ),
            // Data rows
            ...records.map((record) => _buildTableRow(record)),
          ],
        ),
      ],
    );
  }

  // ✅ Build table row
  static pw.TableRow _buildTableRow(AttendanceRecord record) {
    bool hasRecord = record.rawData['hasRecord'] ?? true;
    String attendanceStatus = 'Present';
    PdfColor rowColor = PdfColors.white;

    if (record.requiresSickLeave) {
      attendanceStatus = 'Sick Leave Required';
      rowColor = PdfColors.orange50;
    } else if (!hasRecord || (!record.hasCheckIn && !record.hasCheckOut)) {
      attendanceStatus = 'Absent';
      rowColor = PdfColors.red50;
    } else if (!record.hasCheckIn || !record.hasCheckOut) {
      attendanceStatus = 'Incomplete';
      rowColor = PdfColors.yellow50;
    }

    String formattedDate = '';
    String dayOfWeek = '';
    try {
      DateTime dateTime = DateFormat('yyyy-MM-dd').parse(record.date);
      formattedDate = DateFormat('MMM dd').format(dateTime);
      dayOfWeek = DateFormat('EEE').format(dateTime);
    } catch (e) {
      formattedDate = record.date;
    }

    return pw.TableRow(
      decoration: pw.BoxDecoration(color: rowColor),
      children: [
        pw.Container(
          padding: const pw.EdgeInsets.all(4),
          child: pw.Text(formattedDate, style: const pw.TextStyle(fontSize: 7)),
        ),
        pw.Container(
          padding: const pw.EdgeInsets.all(4),
          child: pw.Text(dayOfWeek, style: const pw.TextStyle(fontSize: 7)),
        ),
        pw.Container(
          padding: const pw.EdgeInsets.all(4),
          child: pw.Text(record.formattedCheckIn, style: const pw.TextStyle(fontSize: 7)),
        ),
        pw.Container(
          padding: const pw.EdgeInsets.all(4),
          child: pw.Text(record.formattedCheckOut, style: const pw.TextStyle(fontSize: 7)),
        ),
        pw.Container(
          padding: const pw.EdgeInsets.all(4),
          child: pw.Text(record.formattedTotalHours, style: const pw.TextStyle(fontSize: 7)),
        ),
        pw.Container(
          padding: const pw.EdgeInsets.all(4),
          child: pw.Text(
            record.formattedOvertimeHours,
            style: pw.TextStyle(
              fontSize: 7,
              color: record.hasOvertime ? PdfColors.deepOrange : PdfColors.grey,
            ),
          ),
        ),
        pw.Container(
          padding: const pw.EdgeInsets.all(4),
          child: pw.Text(attendanceStatus, style: const pw.TextStyle(fontSize: 6)),
        ),
        pw.Container(
          padding: const pw.EdgeInsets.all(4),
          child: pw.Text(record.location, style: const pw.TextStyle(fontSize: 6)),
        ),
      ],
    );
  }

  // ✅ Build overtime details
  static pw.Widget _buildOvertimeDetails(List<AttendanceRecord> records) {
    List<AttendanceRecord> overtimeRecords = records.where((record) => record.hasOvertime).toList();

    if (overtimeRecords.isEmpty) {
      return pw.Container(
        padding: const pw.EdgeInsets.all(16),
        decoration: pw.BoxDecoration(
          color: PdfColors.grey100,
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Text(
          'No overtime recorded this month',
          style: pw.TextStyle(
            fontSize: 12,
            color: PdfColors.grey600,
          ),
          textAlign: pw.TextAlign.center,
        ),
      );
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Overtime Details',
          style: pw.TextStyle(
            fontSize: 16,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.deepOrange,
          ),
        ),
        pw.SizedBox(height: 10),
        pw.Container(
          decoration: pw.BoxDecoration(
            color: PdfColors.orange50,
            borderRadius: pw.BorderRadius.circular(8),
            border: pw.Border.all(color: PdfColors.orange200),
          ),
          padding: const pw.EdgeInsets.all(12),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Note: Overtime is calculated only for work done after 6:30 PM',
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.deepOrange,
                ),
              ),
              pw.SizedBox(height: 8),
              ...overtimeRecords.map((record) => pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 4),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      '${record.formattedDate} (${record.dayOfWeek})',
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                    pw.Text(
                      record.overtimeDetails,
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                  ],
                ),
              )),
            ],
          ),
        ),
      ],
    );
  }

  // ✅ Build legend
  static pw.Widget _buildLegend() {
    return pw.Container(
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      padding: const pw.EdgeInsets.all(12),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Legend',
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Text('• Standard Work Day: 10 hours (including 1 hour break)', style: const pw.TextStyle(fontSize: 8)),
          pw.Text('• Office Hours: Until 6:00 PM', style: const pw.TextStyle(fontSize: 8)),
          pw.Text('• Overtime: Work done after 6:30 PM', style: const pw.TextStyle(fontSize: 8)),
          pw.Text('• Sick Leave Required: Days with no check-in/check-out', style: const pw.TextStyle(fontSize: 8)),
          pw.Text('• "-" indicates no data recorded', style: const pw.TextStyle(fontSize: 8)),
        ],
      ),
    );
  }

  // ✅ Request storage permission
  static Future<bool> _requestStoragePermission() async {
    if (Platform.isAndroid) {
      var status = await Permission.storage.status;
      if (!status.isGranted) {
        status = await Permission.storage.request();
      }
      return status.isGranted;
    }
    return true; // iOS doesn't need explicit storage permission for this use case
  }

  // ✅ Save and share PDF file
  static Future<void> _savePdfFile(pw.Document pdf, String employeeName, String selectedMonth) async {
    try {
      final Uint8List bytes = await pdf.save();

      // Create filename
      String monthStr = DateFormat('MMMM_yyyy').format(DateFormat('yyyy-MM').parse(selectedMonth));
      String filename = 'Attendance_${employeeName.replaceAll(' ', '_')}_$monthStr.pdf';

      // Get temporary directory
      final Directory tempDir = await getTemporaryDirectory();
      final String filePath = '${tempDir.path}/$filename';

      // Write file
      final File file = File(filePath);
      await file.writeAsBytes(bytes);

      // Share the file
      await Share.shareXFiles(
        [XFile(filePath)],
        text: 'Attendance Report for $employeeName - $monthStr',
        subject: 'Attendance Report',
      );

      print('PDF saved and shared: $filePath');
    } catch (e) {
      print('Error saving PDF: $e');
      throw e;
    }
  }
}



