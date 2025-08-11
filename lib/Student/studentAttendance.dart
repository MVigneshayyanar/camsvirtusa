// studentAttendance.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class AttendancePage extends StatefulWidget {
  final String studentId;
  const AttendancePage({Key? key, required this.studentId}) : super(key: key);

  @override
  _AttendancePageState createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  // attendanceData structure:
  // {
  //   "07-08-2025": {
  //      0: {"JEE": "A"},
  //      1: {"JEE": "P"},
  //      ...
  //   },
  //   ...
  // }
  Map<String, Map<int, Map<String, String>>> attendanceData = {};
  bool loading = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    )..forward();

    // Optionally fetch on init. You can also call fetchAttendance() from a button.
    fetchAttendance();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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

  /// Fetch attendance document for the student.
  Future<void> fetchAttendance() async {
    setState(() => loading = true);
    try {
      final docRef = FirebaseFirestore.instance
          .collection('colleges')
          .doc('students')
          .collection('all_students')
          .doc(widget.studentId);

      final snapshot = await docRef.get();

      if (!snapshot.exists) {
        print("Document does not exist for student: ${widget.studentId}");
        setState(() {
          attendanceData = {};
          loading = false;
        });
        return;
      }

      final raw = snapshot.data() as Map<String, dynamic>? ?? {};
      print("Raw data from Firestore: $raw");

      final Map<String, Map<int, Map<String, String>>> parsed = {};

      // Process each field in the document - each field should be a date
      raw.forEach((fieldKey, fieldValue) {
        // Check if this field looks like a date (dd-MM-yyyy format)
        if (fieldKey.contains('-') && fieldKey.split('-').length == 3) {
          final Map<int, Map<String, String>> hourMap = {};

          if (fieldValue is Map<String, dynamic>) {
            fieldValue.forEach((hourStr, subjEntry) {
              try {
                final int hourIndex = int.tryParse(hourStr) ?? 0;
                if (subjEntry is Map<String, dynamic> && subjEntry.isNotEmpty) {
                  final subject = subjEntry.keys.first.toString();
                  final status = subjEntry.values.first.toString();

                  hourMap[hourIndex] = {"subject": subject, "status": status};
                }
              } catch (e) {
                print("Error parsing hour data for $hourStr: $e");
              }
            });
          }

          // Add this date if it has any hour data
          if (hourMap.isNotEmpty) {
            parsed[fieldKey] = hourMap;
          }
        } else {
          // skip non-date fields
        }
      });

      // Sort dates chronologically assuming format dd-MM-yyyy; fallback to lexical
      final sorted = Map.fromEntries(parsed.entries.toList()
        ..sort((a, b) {
          try {
            final dateParts1 = a.key.split('-');
            final dateParts2 = b.key.split('-');
            if (dateParts1.length == 3 && dateParts2.length == 3) {
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
            }
          } catch (e) {
            print("Error sorting dates: $e");
          }
          return a.key.compareTo(b.key);
        }));

      setState(() {
        attendanceData = sorted;
        loading = false;
      });

      // Debug: Print final processed data
      print("\n=== FINAL ATTENDANCE DATA ===");
      print("Number of dates found: ${sorted.length}");
      if (sorted.isEmpty) {
        print("No attendance dates found!");
      } else {
        sorted.forEach((date, hours) {
          print("Date: $date");
          hours.forEach((hour, data) {
            print("  Hour ${hour + 1}: ${data['subject']} - ${data['status']}");
          });
        });
      }
    } catch (e) {
      print("Error fetching attendance: $e");
      setState(() => loading = false);
    }
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

      // Table header
      final headers = ['Hours'] + dates;

      // Table rows
      final data = hours.map((hour) {
        List<String> row = [];
        row.add((hour + 1).toString()); // Hour number

        for (var date in dates) {
          final cell = attendanceData[date]?[hour];
          final subject = cell?['subject'] ?? '';
          final status = cell?['status'] ?? '';
          row.add(subject.isNotEmpty ? '$subject ($status)' : '-');
        }
        return row;
      }).toList();

      pdf.addPage(
        pw.MultiPage(
          build: (context) => [
            pw.Text('Attendance Report', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 20),
            pw.Table.fromTextArray(
              headers: headers,
              data: data,
              border: pw.TableBorder.all(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              cellAlignment: pw.Alignment.center,
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
        filePath = '${saveDir!.path}/attendance_report_$timestamp.pdf';

        final file = File(filePath);
        await file.writeAsBytes(await pdf.save());

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF saved at: $filePath')),
        );
        print("PDF generated at: $filePath");
      } catch (writeError, stack) {
        print('Error saving PDF: $writeError\n$stack');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save PDF to Downloads. Trying app directory...')),
        );

        // Try fallback: application documents directory
        try {
          final fallbackDir = await getApplicationDocumentsDirectory();
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final fallbackPath = '${fallbackDir.path}/attendance_report_$timestamp.pdf';
          final fallbackFile = File(fallbackPath);
          await fallbackFile.writeAsBytes(await pdf.save());

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('PDF saved at: $fallbackPath')),
          );
          print('PDF saved to fallback path: $fallbackPath');
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
    final dates = attendanceData.keys.toList(); // already sorted at fetch
    final hours = collectHours();
    if (hours.isEmpty) return const Center(child: Text('No hours found'));

    final totalHeight = dimensions['headerHeight']! +
        (hours.length * dimensions['hourCellHeight']!);

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
                            padding: EdgeInsets.symmetric(
                                horizontal: dimensions['padding']! / 4),
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
                              width: dimensions['dateColumnWidth']! - 10,
                              height: dimensions['hourCellHeight']!,
                              decoration: BoxDecoration(
                                color: status.isNotEmpty
                                    ? getStatusColor(status)
                                    : Colors.grey.shade100,
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
                                            color: status.isNotEmpty
                                                ? Colors.white
                                                : Colors.black87,
                                            fontWeight: FontWeight.bold,
                                            fontSize: dimensions['fontSize']! - 3,
                                          ),
                                          textAlign: TextAlign.center,
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 2,
                                        ),
                                      ),
                                    ),
                                  if (status.isNotEmpty && subj.isNotEmpty)
                                    const SizedBox(height: 2),
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

    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFF7A52), Color(0xFFFF6B3D)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(isLargeScreen ? 30 : 22),
              bottomRight: Radius.circular(isLargeScreen ? 30 : 22),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF7A52).withOpacity(0.3),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          padding: EdgeInsets.all(dimensions['padding']!),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(
                Icons.menu,
                color: Colors.white,
                size: dimensions['iconSize']!,
              ),
              Text(
                'ATTENDANCE',
                style: TextStyle(
                  fontSize: dimensions['fontSize']! + 2,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Stack(
                alignment: Alignment.topRight,
                children: [
                  Icon(
                    Icons.notifications,
                    color: Colors.white,
                    size: dimensions['iconSize']!,
                  ),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
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
                    child: Icon(
                      Icons.person,
                      size: isLargeScreen ? 40 : 30,
                      color: Colors.grey,
                    ),
                  ),
                  SizedBox(width: dimensions['padding']!),
                  Expanded(
                    child: Text(
                      'Student ID: ${widget.studentId}',
                      style: TextStyle(
                        fontSize: dimensions['fontSize']!,
                        fontWeight: FontWeight.w500,
                      ),
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
        ElevatedButton(
          onPressed: () async {
            await fetchAttendance();
            if (attendanceData.isNotEmpty) {
              await _generateAttendancePDF();
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFF7A52),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
            padding: EdgeInsets.symmetric(
              horizontal: _getResponsiveDimensions(context)['padding']! * 2,
              vertical: _getResponsiveDimensions(context)['padding']!,
            ),
            elevation: 8,
            shadowColor: const Color(0xFFFF7A52).withOpacity(0.4),
          ),
          child: loading
              ? SizedBox(
            height: 18,
            width: 18,
            child: const CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 2,
            ),
          )
              : Text(
            'Get Attendance',
            style: TextStyle(
              fontSize: _getResponsiveDimensions(context)['fontSize']!,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        SizedBox(height: dimensions['padding']!),
      ],
    );
  }

  Widget buildProgressSection(BuildContext context) {
    final dimensions = _getResponsiveDimensions(context);

    return Column(
      children: [
        // Progress bars
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildProgressItem(0.86, const Color(0xFF2ECC71), '86%', dimensions),
            _buildProgressItem(0.10, const Color(0xFF1E90FF), '10%', dimensions),
            _buildProgressItem(0.04, const Color(0xFFE74C3C), '4%', dimensions),
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

  Widget _buildProgressItem(double percentage, Color color, String text,
      Map<String, double> dimensions) {
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

  Widget _buildLegendItem(IconData icon, String text, Color color,
      Map<String, double> dimensions) {
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

  Widget buildProgressBar(double percentage, Color color,
      Map<String, double> dimensions) {
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
                child: attendanceData.isEmpty
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
                        'No attendance data. Tap Get Attendance.',
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
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: BottomNavigationBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          type: BottomNavigationBarType.fixed,
          items: [
            BottomNavigationBarItem(
              icon: Icon(
                Icons.search,
                size: isLargeScreen ? 28 : 24,
              ),
              label: "",
            ),
            BottomNavigationBarItem(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Color(0xFFFF7A52),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.home,
                  color: Colors.white,
                  size: isLargeScreen ? 28 : 24,
                ),
              ),
              label: "",
            ),
            BottomNavigationBarItem(
              icon: Icon(
                Icons.person,
                size: isLargeScreen ? 28 : 24,
              ),
              label: "",
            ),
          ],
          currentIndex: 1,
          selectedItemColor: const Color(0xFFFF7A52),
          unselectedItemColor: Colors.grey,
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
