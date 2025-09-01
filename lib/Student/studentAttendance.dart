import 'dart:io';
import 'package:camsvirtusa/Student/studentDashboard.dart';
import 'package:camsvirtusa/Student/studentProfile.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:open_file/open_file.dart';

class AttendancePage extends StatefulWidget {
  final String studentId;
  const AttendancePage({Key? key, required this.studentId}) : super(key: key);

  @override
  _AttendancePageState createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  Map<String, Map<int, Map<String, String>>> attendanceData = {};
  bool loading = false;

  // Add these variables to store dynamic attendance statistics
  int presentCount = 0;
  int absentCount = 0;
  int odCount = 0;
  int totalCount = 0;
  double presentPercent = 0.0;
  double absentPercent = 0.0;
  double odPercent = 0.0;

  // Semester management
  List<String> semesters = ['I', 'II', 'III', 'IV', 'V', 'VI', 'VII', 'VIII'];
  String? selectedSemester;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    )..forward();

    // Updated to fetch student and semester info
    _fetchStudentAndAttendance();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Fetch student's current semester and attendance data
  Future<void> _fetchStudentAndAttendance() async {
    setState(() => loading = true);
    try {
      final studentDoc = await FirebaseFirestore.instance
          .collection('colleges')
          .doc('students')
          .collection('all_students')
          .doc(widget.studentId)
          .get();

      if (!studentDoc.exists) throw Exception('Student not found');

      final data = studentDoc.data();
      String currentSemester = data?['current_semester'] ?? semesters.first;

      setState(() {
        selectedSemester = currentSemester;
      });

      await _fetchAttendanceForSemester(currentSemester);
    } catch (e) {
      print('Error fetching student info: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading student info: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  /// Fetch attendance data for a specific semester
  Future<void> _fetchAttendanceForSemester(String semester) async {
    setState(() {
      loading = true;
      attendanceData.clear();
      _resetStats();
    });

    try {
      final attendanceDoc = await FirebaseFirestore.instance
          .collection('colleges')
          .doc('students')
          .collection('all_students')
          .doc(widget.studentId)
          .collection('attendance')
          .doc(semester)
          .get();

      if (!attendanceDoc.exists) {
        print('No attendance data for semester $semester');
        setState(() {
          loading = false;
        });
        return;
      }

      final data = attendanceDoc.data();
      if (data == null) {
        setState(() {
          loading = false;
        });
        return;
      }

      // Get overall percentages from document fields
      setState(() {
        presentPercent = (data['P'] ?? 0.0).toDouble();
        absentPercent = (data['A'] ?? 0.0).toDouble();
        odPercent = (data['OD'] ?? 0.0).toDouble();
      });

      // Parse daily attendance data
      Map<String, Map<int, Map<String, String>>> parsed = {};
      data.forEach((key, value) {
        // Check if key is a date (dd-MM-yyyy format)
        if (RegExp(r'^\d{2}-\d{2}-\d{4}$').hasMatch(key)) {
          Map<int, Map<String, String>> hourMap = {};

          if (value is Map) {
            value.forEach((hourStr, subjectMap) {
              try {
                int hourIndex = int.parse(hourStr.toString());
                if (subjectMap is Map) {
                  subjectMap.forEach((subject, status) {
                    hourMap[hourIndex] = {
                      'subject': subject.toString(),
                      'status': status.toString(),
                    };
                  });
                }
              } catch (e) {
                print('Error parsing hour data: $e');
              }
            });
          }

          if (hourMap.isNotEmpty) {
            parsed[key] = hourMap;
          }
        }
      });

      // Sort dates chronologically
      final sorted = Map<String, Map<int, Map<String, String>>>.fromEntries(
        parsed.entries.toList()..sort((a, b) {
          try {
            final dateParts1 = a.key.split('-');
            final dateParts2 = b.key.split('-');
            final date1 = DateTime(
              int.parse(dateParts1[2]),
              int.parse(dateParts1[1]),
              int.parse(dateParts1[0]),
            );
            final date2 = DateTime(
              int.parse(dateParts2[2]),
              int.parse(dateParts2[1]),
              int.parse(dateParts2[0]),
            );
            return date1.compareTo(date2);
          } catch (e) {
            return a.key.compareTo(b.key);
          }
        }),
      );

      setState(() {
        attendanceData = sorted;
      });

      _calculateAttendanceStats();
    } catch (e) {
      print('Error fetching attendance: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading attendance: $e')),
        );
      }
    } finally {
      setState(() => loading = false);
    }
  }

  /// Reset attendance statistics
  void _resetStats() {
    presentCount = 0;
    absentCount = 0;
    odCount = 0;
    totalCount = 0;
    presentPercent = 0.0;
    absentPercent = 0.0;
    odPercent = 0.0;
  }

  /// Calculate attendance statistics from the loaded data
  void _calculateAttendanceStats() {
    presentCount = 0;
    absentCount = 0;
    odCount = 0;
    totalCount = 0;

    for (var dateData in attendanceData.values) {
      for (var hourData in dateData.values) {
        final status = hourData['status'] ?? '';
        if (status.isNotEmpty) {
          totalCount++;
          switch (status.toUpperCase()) {
            case 'P':
              presentCount++;
              break;
            case 'A':
              absentCount++;
              break;
            case 'OD':
              odCount++;
              break;
          }
        }
      }
    }

    // Update calculated percentages if we have data
    if (totalCount > 0) {
      setState(() {
        presentPercent = (presentCount / totalCount) * 100;
        absentPercent = (absentCount / totalCount) * 100;
        odPercent = (odCount / totalCount) * 100;
      });
    }

    print("Attendance Stats:");
    print("Present: $presentCount (${presentPercent.toStringAsFixed(1)}%)");
    print("Absent: $absentCount (${absentPercent.toStringAsFixed(1)}%)");
    print("On Duty: $odCount (${odPercent.toStringAsFixed(1)}%)");
    print("Total: $totalCount");
  }

  /// Handle semester selection change
  void _onSemesterChanged(String? semester) {
    if (semester != null && semester != selectedSemester) {
      setState(() {
        selectedSemester = semester;
        attendanceData = {};
      });
      _fetchAttendanceForSemester(semester);
    }
  }

  /// Get responsive dimensions based on screen size and orientation
  Map<String, double> _getResponsiveDimensions(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final screenHeight = mediaQuery.size.height;
    final orientation = mediaQuery.orientation;

    // Determine device type
    bool isTablet = screenWidth > 600;
    bool isLargeScreen = screenWidth > 900;
    bool isPortrait = orientation == Orientation.portrait;

    // Responsive dimensions
    double headerHeight;
    double hourCellHeight;
    double hoursColumnWidth;
    double dateColumnWidth;
    double fontSize;
    double iconSize;
    double padding;

    if (isLargeScreen) {
      // Large screens (desktop/large tablets)
      headerHeight = 60;
      hourCellHeight = 70;
      hoursColumnWidth = 90;
      dateColumnWidth = isPortrait ? 140 : 160;
      fontSize = 18;
      iconSize = 28;
      padding = 24;
    } else if (isTablet) {
      // Medium screens (tablets)
      headerHeight = 50;
      hourCellHeight = 60;
      hoursColumnWidth = 75;
      dateColumnWidth = isPortrait ? 120 : 140;
      fontSize = 16;
      iconSize = 24;
      padding = 18;
    } else {
      // Small screens (phones)
      if (isPortrait) {
        headerHeight = 44;
        hourCellHeight = 56;
        hoursColumnWidth = 64;
        dateColumnWidth = 120;
        fontSize = 14;
        iconSize = 20;
        padding = 12;
      } else {
        // Landscape phone
        headerHeight = 40;
        hourCellHeight = 50;
        hoursColumnWidth = 60;
        dateColumnWidth = 110;
        fontSize = 13;
        iconSize = 18;
        padding = 10;
      }
    }

    return {
      'headerHeight': headerHeight,
      'hourCellHeight': hourCellHeight,
      'hoursColumnWidth': hoursColumnWidth,
      'dateColumnWidth': dateColumnWidth,
      'fontSize': fontSize,
      'iconSize': iconSize,
      'padding': padding,
    };
  }

  Color getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'P':
        return const Color(0xFF2ECC71);
      case 'OD':
        return const Color(0xFF1E90FF);
      case 'A':
        return const Color(0xFFE74C3C);
      default:
        return Colors.grey.shade300;
    }
  }

  // Collect a sorted list of unique hour indices across all dates
  List<int> collectHours() {
    final Set<int> s = {};
    for (final dayData in attendanceData.values) {
      s.addAll(dayData.keys);
    }
    final l = s.toList()..sort();
    return l.isEmpty ? [] : l;
  }

  // Get individual cells for each hour (no merging)
  List<Map<String, dynamic>> getIndividualCells(String date, List<int> hours) {
    final dayMap = attendanceData[date] ?? {};
    final List<Map<String, dynamic>> cells = [];

    for (final h in hours) {
      final subject = dayMap[h]?['subject'] ?? '';
      final status = dayMap[h]?['status'] ?? '';
      cells.add({
        'hour': h,
        'subject': subject,
        'status': status,
      });
    }
    return cells;
  }

  /// Ensure storage permission — tries storage first, then manageExternalStorage.
  /// Returns true if permission granted, false otherwise.
  Future<bool> _ensureStoragePermission() async {
    if (!Platform.isAndroid) return true; // iOS/macOS: saving to app dirs doesn't need these perms

    // Try the "storage" permission first (covers many devices)
    final storageStatus = await Permission.storage.status;
    if (storageStatus.isGranted) return true;

    final requestStorage = await Permission.storage.request();
    if (requestStorage.isGranted) return true;

    // If storage isn't enough, try manageExternalStorage (Android 11+)
    final manageStatus = await Permission.manageExternalStorage.status;
    if (manageStatus.isGranted) return true;

    final requestManage = await Permission.manageExternalStorage.request();
    if (requestManage.isGranted) return true;

    // If we are here, permission denied or permanently denied
    if (requestManage.isPermanentlyDenied || requestStorage.isPermanentlyDenied) {
      // Prompt user to open app settings
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Storage permission permanently denied. Please enable it in App settings.')),
      );
      await Future.delayed(const Duration(milliseconds: 400)); // allow snackbar to show
      openAppSettings();
    }

    return false;
  }

  /// Show dialog asking if user wants to open the PDF
  Future<void> _showOpenPdfDialog(String filePath) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(
                Icons.picture_as_pdf,
                color: const Color(0xFFFF7A52),
                size: 28,
              ),
              const SizedBox(width: 12),
              const Text(
                'PDF Generated',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Your attendance report has been successfully generated.',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.folder,
                      color: Colors.grey.shade600,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        filePath,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                          fontFamily: 'monospace',
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Would you like to open the PDF now?',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(
                'Later',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 16,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _openPDF(filePath);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF7A52),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
              child: const Text(
                'Open PDF',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Open the PDF file using the default PDF viewer
  Future<void> _openPDF(String filePath) async {
    try {
      final result = await OpenFile.open(filePath);

      if (result.type != ResultType.done) {
        // Handle different error types
        String errorMessage;
        switch (result.type) {
          case ResultType.noAppToOpen:
            errorMessage = 'No app available to open PDF files. Please install a PDF viewer.';
            break;
          case ResultType.fileNotFound:
            errorMessage = 'PDF file not found. It may have been moved or deleted.';
            break;
          case ResultType.permissionDenied:
            errorMessage = 'Permission denied. Unable to open the PDF file.';
            break;
          default:
            errorMessage = 'Unable to open PDF file: ${result.message}';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red.shade600,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      print("Error opening PDF: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error opening PDF: $e'),
          backgroundColor: Colors.red.shade600,
        ),
      );
    }
  }

  Future<void> _generateAttendancePDF() async {
    try {
      setState(() => loading = true);

      // Ensure we have permission to write to public Downloads if possible
      final hasPermission = await _ensureStoragePermission();
      if (!hasPermission) {
        setState(() => loading = false);
        return;
      }

      final pdf = pw.Document();

      final hours = collectHours();
      final dates = attendanceData.keys.toList();

      final studentDoc = await FirebaseFirestore.instance
          .collection('colleges')
          .doc('students')
          .collection('all_students')
          .doc(widget.studentId)
          .get();

      final name = studentDoc?['name']?.toString() ?? '';

      // Define colors similar to app theme
      final primaryColor = PdfColor.fromHex('#FF7A52');
      final headerColor = PdfColor.fromHex('#37474F');
      final presentColor = PdfColor.fromHex('#2ECC71');
      final absentColor = PdfColor.fromHex('#E74C3C');
      final odColor = PdfColor.fromHex('#1E90FF');
      final lightGray = PdfColor.fromHex('#F5F5F5');
      final darkGray = PdfColor.fromHex('#666666');

      // Create data structure with dates as rows and hours as columns
      // Create table headers with hours
      final List<String> tableHeaders = ['Date'] + hours.map((h) => 'Hour ${h + 1}').toList();

      // Create table data with dates as rows
      final List<List<String>> tableData = dates.map((date) {
        List<String> row = [date]; // Start with date

        // Add data for each hour
        for (var hour in hours) {
          final cell = attendanceData[date]?[hour];
          final subject = cell?['subject'] ?? '';
          final status = cell?['status'] ?? '';

          if (subject.isNotEmpty && status.isNotEmpty) {
            row.add('$subject ($status)');
          } else {
            row.add('-');
          }
        }

        return row;
      }).toList();

      pdf.addPage(
        pw.MultiPage(
          margin: const pw.EdgeInsets.all(40),
          pageFormat: PdfPageFormat.a4,
          build: (context) => [
            // Header Section with gradient-like effect
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(20),
              decoration: pw.BoxDecoration(
                color: primaryColor,
                borderRadius: pw.BorderRadius.circular(15),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Text(
                    'ATTENDANCE REPORT',
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white,
                    ),
                  ),
                  pw.SizedBox(height: 12),
                  pw.Text(
                    name,
                    style: pw.TextStyle(
                      fontSize: 18,
                      color: PdfColors.white,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    'Student ID: ${widget.studentId}',
                    style: pw.TextStyle(
                      fontSize: 14,
                      color: PdfColors.white,
                      fontWeight: pw.FontWeight.normal,
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    'Semester: ${selectedSemester ?? "N/A"}',
                    style: pw.TextStyle(
                      fontSize: 14,
                      color: PdfColors.white,
                      fontWeight: pw.FontWeight.normal,
                    ),
                  ),
                  pw.SizedBox(height: 5),
                  pw.Text(
                    'Generated on: ${DateTime.now().toString().split(' ')[0]}',
                    style: pw.TextStyle(
                      fontSize: 12,
                      color: PdfColors.white,
                    ),
                  ),
                ],
              ),
            ),

            pw.SizedBox(height: 30),

            // Summary Statistics Section
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(20),
              decoration: pw.BoxDecoration(
                color: lightGray,
                borderRadius: pw.BorderRadius.circular(10),
                border: pw.Border.all(color: PdfColors.black, width: 1),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'ATTENDANCE SUMMARY',
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                      color: headerColor,
                    ),
                  ),
                  pw.SizedBox(height: 15),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
                    children: [
                      // Present Stats
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(vertical: 10, horizontal: 15),
                        decoration: pw.BoxDecoration(
                          color: presentColor,
                          borderRadius: pw.BorderRadius.circular(8),
                        ),
                        child: pw.Column(
                          children: [
                            pw.Text(
                              'PRESENT',
                              style: pw.TextStyle(
                                fontSize: 10,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.white,
                              ),
                            ),
                            pw.SizedBox(height: 5),
                            pw.Text(
                              '$presentCount',
                              style: pw.TextStyle(
                                fontSize: 16,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.white,
                              ),
                            ),
                            pw.Text(
                              '${presentPercent.toStringAsFixed(1)}%',
                              style: pw.TextStyle(
                                fontSize: 12,
                                color: PdfColors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // On Duty Stats
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(vertical: 10, horizontal: 15),
                        decoration: pw.BoxDecoration(
                          color: odColor,
                          borderRadius: pw.BorderRadius.circular(8),
                        ),
                        child: pw.Column(
                          children: [
                            pw.Text(
                              'ON DUTY',
                              style: pw.TextStyle(
                                fontSize: 10,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.white,
                              ),
                            ),
                            pw.SizedBox(height: 5),
                            pw.Text(
                              '$odCount',
                              style: pw.TextStyle(
                                fontSize: 16,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.white,
                              ),
                            ),
                            pw.Text(
                              '${odPercent.toStringAsFixed(1)}%',
                              style: pw.TextStyle(
                                fontSize: 12,
                                color: PdfColors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Absent Stats
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(vertical: 10, horizontal: 15),
                        decoration: pw.BoxDecoration(
                          color: absentColor,
                          borderRadius: pw.BorderRadius.circular(8),
                        ),
                        child: pw.Column(
                          children: [
                            pw.Text(
                              'ABSENT',
                              style: pw.TextStyle(
                                fontSize: 10,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.white,
                              ),
                            ),
                            pw.SizedBox(height: 5),
                            pw.Text(
                              '$absentCount',
                              style: pw.TextStyle(
                                fontSize: 16,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.white,
                              ),
                            ),
                            pw.Text(
                              '${absentPercent.toStringAsFixed(1)}%',
                              style: pw.TextStyle(
                                fontSize: 12,
                                color: PdfColors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 15),
                  pw.Container(
                    width: double.infinity,
                    height: 2,
                    color: primaryColor,
                  ),
                  pw.SizedBox(height: 10),
                  pw.Text(
                    'Total Classes: $totalCount',
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                      color: darkGray,
                    ),
                  ),
                ],
              ),
            ),

            pw.SizedBox(height: 30),

            // Attendance Table Section Header
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.symmetric(vertical: 10, horizontal: 15),
              decoration: pw.BoxDecoration(
                color: headerColor,
                borderRadius: const pw.BorderRadius.only(
                  topLeft: pw.Radius.circular(8),
                  topRight: pw.Radius.circular(8),
                ),
              ),
              child: pw.Text(
                'DETAILED ATTENDANCE RECORD',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
                textAlign: pw.TextAlign.center,
              ),
            ),

            // Enhanced Attendance Table (Dates as rows, Hours as columns)
            pw.Table(
              border: pw.TableBorder.all(
                color: PdfColors.grey200,
                width: 1,
              ),
              columnWidths: {
                0: const pw.FixedColumnWidth(80), // Date column
                // Hour columns will auto-size
              },
              children: [
                // Header row (Hours at top)
                pw.TableRow(
                  decoration: const pw.BoxDecoration(
                    color: PdfColors.grey200,
                  ),
                  children: tableHeaders.map((header) {
                    return pw.Container(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(
                        header,
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: header == 'Date' ? 12 : 9,
                          color: headerColor,
                        ),
                        textAlign: pw.TextAlign.center,
                      ),
                    );
                  }).toList(),
                ),

                // Data rows (Dates on left)
                ...tableData.asMap().entries.map((entry) {
                  final index = entry.key;
                  final row = entry.value;
                  final isEvenRow = index % 2 == 0;

                  return pw.TableRow(
                    decoration: pw.BoxDecoration(
                      color: isEvenRow ? PdfColors.white : lightGray,
                    ),
                    children: row.asMap().entries.map((cellEntry) {
                      final cellIndex = cellEntry.key;
                      final cellValue = cellEntry.value;

                      // Determine cell background color based on status
                      PdfColor? cellColor;
                      if (cellIndex > 0 && cellValue != '-') {
                        // Not the date column and has data
                        if (cellValue.contains('(P)')) {
                          cellColor = presentColor;
                        } else if (cellValue.contains('(A)')) {
                          cellColor = absentColor;
                        } else if (cellValue.contains('(OD)')) {
                          cellColor = odColor;
                        }
                      }

                      return pw.Container(
                        padding: const pw.EdgeInsets.all(6),
                        decoration: cellColor != null ? pw.BoxDecoration(color: cellColor) : null,
                        child: pw.Text(
                          cellValue,
                          style: pw.TextStyle(
                            fontSize: cellIndex == 0 ? 10 : 8,
                            fontWeight: cellIndex == 0 ? pw.FontWeight.bold : pw.FontWeight.normal,
                            color: cellColor != null
                                ? PdfColors.white
                                : (cellIndex == 0 ? headerColor : PdfColors.black),
                          ),
                          textAlign: pw.TextAlign.center,
                        ),
                      );
                    }).toList(),
                  );
                }).toList(),
              ],
            ),

            pw.SizedBox(height: 30),

            // Footer
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(15),
              decoration: pw.BoxDecoration(
                color: lightGray,
                borderRadius: pw.BorderRadius.circular(8),
                border: pw.Border.all(color: primaryColor, width: 2),
              ),
              child: pw.Column(
                children: [
                  pw.Text(
                    'Legend: P = Present, A = Absent, OD = On Duty',
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                      color: darkGray,
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    'This report was automatically generated by the Attendance Management System',
                    style: pw.TextStyle(
                      fontSize: 10,
                      color: darkGray,
                      fontStyle: pw.FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

      // Save to Downloads folder (Android) or app documents (iOS / fallback)
      Directory? saveDir;
      String filePath = '';

      try {
        if (Platform.isAndroid) {
          // Primary attempt: public Downloads folder (visible to user)
          final downloads = Directory('/storage/emulated/0/Download');
          if (await downloads.exists()) {
            saveDir = downloads;
          } else {
            // fallback to app external storage dir
            saveDir = await getExternalStorageDirectory();
          }
        } else {
          // iOS / others: app documents
          saveDir = await getApplicationDocumentsDirectory();
        }

        final timestamp = DateTime.now().millisecondsSinceEpoch;
        filePath = '${saveDir!.path}/attendance_report_${selectedSemester}_$timestamp.pdf';

        final file = File(filePath);
        await file.writeAsBytes(await pdf.save());

        print("PDF generated at: $filePath");

        // Show dialog asking if user wants to open the PDF
        await _showOpenPdfDialog(filePath);
      } catch (writeError, stack) {
        print('Error saving PDF: $writeError\n$stack');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save PDF to Downloads. Trying app directory...')),
        );

        // Try fallback: application documents directory
        try {
          final fallbackDir = await getApplicationDocumentsDirectory();
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final fallbackPath = '${fallbackDir.path}/attendance_report_${selectedSemester}_$timestamp.pdf';
          final fallbackFile = File(fallbackPath);
          await fallbackFile.writeAsBytes(await pdf.save());

          print('PDF saved to fallback path: $fallbackPath');

          // Show dialog for fallback path too
          await _showOpenPdfDialog(fallbackPath);
        } catch (fallbackError, stack2) {
          print('Fallback save failed: $fallbackError\n$stack2');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error generating/saving PDF')),
          );
        }
      }
    } catch (e, st) {
      print("Error generating PDF: $e\n$st");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error generating PDF')),
      );
    } finally {
      setState(() => loading = false);
    }
  }

  /// Build the timetable area with static Hours column + scrollable date columns
  Widget buildTimetable(BuildContext context) {
    if (attendanceData.isEmpty) {
      return const Center(child: Text('No attendance data'));
    }

    final dimensions = _getResponsiveDimensions(context);
    final dates = attendanceData.keys.toList()
      ..sort((a, b) => b.compareTo(a)); // descending order
    // already sorted at fetch
    final hours = collectHours();
    if (hours.isEmpty) return const Center(child: Text('No hours found'));

    final totalHeight = dimensions['headerHeight']! + (hours.length * dimensions['hourCellHeight']!);

    // Outer vertical scroll to allow many hours
    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      physics: const BouncingScrollPhysics(),
      child: Container(
        margin: EdgeInsets.all(dimensions['padding']! / 50),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            height: totalHeight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Static Hours column
                Column(
                  children: [
                    // header
                    Container(
                      width: dimensions['hoursColumnWidth']!,
                      height: dimensions['headerHeight']!,
                      decoration: BoxDecoration(
                        color: const Color(0xFF37474F),
                        border: const Border(
                          right: BorderSide(color: Colors.white, width: 2.5),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Hours',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: dimensions['fontSize']! - 2,
                        ),
                      ),
                    ),
                    // hour cells
                    ...hours.map((h) {
                      return Container(
                        width: dimensions['hoursColumnWidth']!,
                        height: dimensions['hourCellHeight']!,
                        decoration: BoxDecoration(
                          color: const Color(0xFF37474F),
                          border: const Border(
                            right: BorderSide(color: Colors.white, width: 2.5),
                            top: BorderSide(color: Colors.white, width: 2.5),
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          (h + 1).toString(),
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                            fontSize: dimensions['fontSize']! - 3,
                          ),
                        ),
                      );
                    }).toList(),
                  ],
                ),

                // Scrollable Date columns section
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Container(
                      constraints: BoxConstraints(
                        minWidth: MediaQuery.of(context).size.width -
                            dimensions['hoursColumnWidth']! -
                            35,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: dates.map((date) {
                          final cells = getIndividualCells(date, hours);

                          // Build a column: header + individual cells (one for each hour)
                          List<Widget> colChildren = [];

                          // Date header
                          colChildren.add(Container(
                            width: dimensions['dateColumnWidth']! - 10,
                            height: dimensions['headerHeight']!,
                            decoration: BoxDecoration(
                              color: const Color(0xFF37474F),
                              border: const Border(
                                right: BorderSide(color: Colors.white, width: 2.5),
                              ),
                            ),
                            alignment: Alignment.center,
                            padding: EdgeInsets.symmetric(horizontal: dimensions['padding']! / 4),
                            child: Text(
                              date,
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: dimensions['fontSize']! - 4,
                              ),
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ));

                          // Add individual cell for each hour
                          for (final cell in cells) {
                            final subj = cell['subject'] as String;
                            final status = cell['status'] as String;

                            colChildren.add(Container(
                              width: dimensions['dateColumnWidth']!,
                              height: dimensions['hourCellHeight']!,
                              decoration: BoxDecoration(
                                color: status.isNotEmpty ? getStatusColor(status) : Colors.grey.shade100,
                                border: const Border(
                                  right: BorderSide(color: Colors.white, width: 2.5),
                                  top: BorderSide(color: Colors.white, width: 2.5),
                                ),
                              ),
                              alignment: Alignment.center,
                              padding: EdgeInsets.all(dimensions['padding']! / 4),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (subj.isNotEmpty)
                                    Expanded(
                                      flex: 2,
                                      child: Center(
                                        child: Text(
                                          subj,
                                          style: TextStyle(
                                            color: status.isNotEmpty ? Colors.white : Colors.black87,
                                            fontWeight: FontWeight.bold,
                                            fontSize: dimensions['fontSize']! - 3,
                                          ),
                                          textAlign: TextAlign.center,
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 2,
                                        ),
                                      ),
                                    ),
                                  if (status.isNotEmpty && subj.isNotEmpty) const SizedBox(height: 2),
                                  if (status.isNotEmpty)
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: dimensions['padding']! / 3,
                                          vertical: 1,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Center(
                                          child: Text(
                                            status,
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: dimensions['fontSize']! - 6,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  if (subj.isEmpty && status.isEmpty)
                                    Center(
                                      child: Text(
                                        '-',
                                        style: TextStyle(
                                          color: Colors.grey.shade400,
                                          fontSize: dimensions['fontSize']! - 2,
                                          fontWeight: FontWeight.w300,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ));
                          }

                          return SizedBox(
                            width: dimensions['dateColumnWidth']! - 45,
                            child: Column(children: colChildren),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Top progress UI with responsive design
  Widget buildHeaderArea(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final dimensions = _getResponsiveDimensions(context);
    final isLargeScreen = mediaQuery.size.width > 600;
    final isPortrait = mediaQuery.orientation == Orientation.portrait;

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('colleges')
          .doc('students')
          .collection('all_students')
          .doc(widget.studentId)
          .get(),
      builder: (context, snapshot) {
        final name = snapshot.hasData && snapshot.data!.exists
            ? snapshot.data!['name']?.toString() ?? ''
            : '';

        return Column(
          children: [

            SizedBox(height: dimensions['padding']!),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: dimensions['padding']!),
              child: isPortrait || !isLargeScreen
                  ? Column(
                children: [
                  // Avatar row
                  Row(
                    children: [
                      CircleAvatar(
                        radius: isLargeScreen ? 45 : 36,
                        backgroundColor: Colors.white70,
                        backgroundImage: AssetImage('assets/account.png'),
                        onBackgroundImageError: (exception, stackTrace) {
                          // Fallback to icon if image fails to load
                          print('Error loading profile image: $exception');
                        },
                        child: null, // Remove the child when using backgroundImage
                      ),

                      SizedBox(width: dimensions['padding']!),
                      Expanded(
                        child: Text(
                          name.toUpperCase(),
                          style: TextStyle(
                            fontSize: dimensions['fontSize']!,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: dimensions['padding']!),
                  // Semester selector and PDF button row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Left side - Semester selector
                      Row(
                        children: [
                          Text(
                            'Semester: ',
                            style: TextStyle(
                              fontSize: dimensions['fontSize']! - 2,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(width: 8),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Color(0xFFFF7A52)),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: selectedSemester,
                                items: semesters
                                    .map((sem) => DropdownMenuItem(
                                  value: sem,
                                  child: Text(sem),
                                ))
                                    .toList(),
                                onChanged: _onSemesterChanged,
                              ),
                            ),
                          ),
                        ],
                      ),
                      // Right side - PDF button
                      ElevatedButton.icon(
                        onPressed: attendanceData.isEmpty ? null : _generateAttendancePDF,
                        icon: Icon(Icons.picture_as_pdf, size: 18),
                        label: Text('Get PDF'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFFFF7A52),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: dimensions['padding']!),
                  // Progress bars row
                  buildProgressSection(context),
                ],
              )
                  : Row(
                children: [
                  CircleAvatar(
                    radius: 45,
                    backgroundColor: Colors.white70,
                    child: Icon(
                      Icons.person,
                      size: 40,
                      color: Colors.grey,
                    ),
                  ),
                  SizedBox(width: dimensions['padding']!),
                  Expanded(child: buildProgressSection(context)),
                ],
              ),
            ),
            SizedBox(height: dimensions['padding']!),
          ],
        );
      },
    );
  }

  Widget buildProgressSection(BuildContext context) {
    final dimensions = _getResponsiveDimensions(context);

    return Column(
      children: [
        // Progress bars - using dynamic percentages
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildProgressItem(
                presentPercent / 100, const Color(0xFF2ECC71), '${presentPercent.toStringAsFixed(1)}%', dimensions),
            _buildProgressItem(
                odPercent / 100, const Color(0xFF1E90FF), '${odPercent.toStringAsFixed(1)}%', dimensions),
            _buildProgressItem(
                absentPercent / 100, const Color(0xFFE74C3C), '${absentPercent.toStringAsFixed(1)}%', dimensions),
          ],
        ),
        SizedBox(height: dimensions['padding']! / 2),
        // Legend
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildLegendItem(
              Icons.check_circle,
              'PRESENT',
              const Color(0xFF2ECC71),
              dimensions,
            ),
            _buildLegendItem(
              Icons.work,
              'ON-DUTY',
              const Color(0xFF1E90FF),
              dimensions,
            ),
            _buildLegendItem(
              Icons.cancel,
              'ABSENT',
              const Color(0xFFE74C3C),
              dimensions,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildProgressItem(double percentage, Color color, String text, Map<String, double> dimensions) {
    return Flexible(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          buildProgressBar(percentage, color, dimensions),
          SizedBox(width: dimensions['padding']! / 3),
          Text(
            text,
            style: TextStyle(
              fontSize: dimensions['fontSize']! - 2,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(IconData icon, String text, Color color, Map<String, double> dimensions) {
    return Flexible(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: color,
            size: dimensions['iconSize']! - 6,
          ),
          SizedBox(width: dimensions['padding']! / 4),
          Text(
            text,
            style: TextStyle(
              fontSize: dimensions['fontSize']! - 4,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildProgressBar(double percentage, Color color, Map<String, double> dimensions) {
    final progressWidth = dimensions['padding']! * 2;
    return ClipPath(
      clipper: CustomClipPath(),
      child: Container(
        width: percentage * progressWidth,
        height: dimensions['padding']!,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color, color.withOpacity(0.7)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: const BorderRadius.horizontal(
            left: Radius.circular(30),
            right: Radius.circular(30),
          ),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final isLargeScreen = mediaQuery.size.width > 600;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color(0xFFFF7F50),
        title: Text(
          "ATTENDANCE",
          style: TextStyle(color: Colors.white),
        ),
        centerTitle: true, // This centers the title
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white), // White back arrow
          onPressed: () {
            Navigator.of(context).pop(); // Return to the previous page
          },
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            buildHeaderArea(context),
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isLargeScreen ? 16 : 8,
                  vertical: isLargeScreen ? 12 : 6,
                ),
                child: loading
                    ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF7A52)),
                      ),
                      SizedBox(height: 16),
                      Text('Loading attendance data...'),
                    ],
                  ),
                )
                    : attendanceData.isEmpty
                    ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.calendar_today_outlined,
                        size: isLargeScreen ? 64 : 48,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No attendance data found for semester ${selectedSemester ?? ""}',
                        style: TextStyle(
                          fontSize: isLargeScreen ? 18 : 16,
                          color: Colors.grey.shade600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
                    : buildTimetable(context),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(context),
    );
  }
  void _goToDashboard(BuildContext context) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => StudentDashboard(studentId: widget.studentId),
      ),
    );
  }

  Widget _buildBottomNavigationBar(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final double bottomSafeArea = mediaQuery.padding.bottom;
    final double screenWidth = mediaQuery.size.width;

    return Container(
      height: 70 + bottomSafeArea,
      decoration: BoxDecoration(
        color: const Color(0xFFE5E5E5),
        borderRadius: BorderRadius.vertical(top: Radius.circular(40)),
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomSafeArea),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            IconButton(
              icon: Image.asset(
                "assets/search.png",
                height: screenWidth > 600 ? 30 : 26,
              ),
              onPressed: () {},
            ),
            IconButton(
              icon: Image.asset(
                "assets/homeLogo.png",
                height: screenWidth > 600 ? 36 : 32,
              ),
              onPressed: () => _goToDashboard(context),
            ),
            IconButton(
              icon: Image.asset(
                "assets/account.png",
                height: screenWidth > 600 ? 30 : 26,
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => StudentProfile(studentId: widget.studentId),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}




/// small decorative clipper used in progress bar
class CustomClipPath extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final Path path = Path();
    path.lineTo(size.width - 6, 0);
    path.lineTo(size.width, size.height / 2);
    path.lineTo(size.width - 6, size.height);
    path.lineTo(0, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
