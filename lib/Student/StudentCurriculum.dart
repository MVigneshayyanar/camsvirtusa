import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class StudentCurriculum extends StatefulWidget {
  final String studentId;

  const StudentCurriculum({Key? key, required this.studentId}) : super(key: key);

  @override
  State<StudentCurriculum> createState() => _StudentCurriculumState();
}

class _StudentCurriculumState extends State<StudentCurriculum> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  bool _isSearching = false;
  List<Map<String, dynamic>> _searchResults = [];
  bool _isLoading = false;

  // Digital Library State
  List<Map<String, dynamic>> _studyMaterials = [];
  List<Map<String, dynamic>> _questionPapers = [];
  bool _isLoadingMaterials = false;
  String _selectedSubject = 'All';
  String _selectedSemester = 'All';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _searchController.addListener(_performSearch);
    _loadSampleData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // Load sample data instead of Firebase for demonstration
  void _loadSampleData() {
    setState(() => _isLoadingMaterials = true);

    // Sample study materials
    _studyMaterials = [
      {
        'id': '1',
        'title': 'Linear Algebra - Matrix Operations',
        'subject': 'Mathematics',
        'semester': '3',
        'fileType': 'pdf',
        'uploadedBy': 'Prof. Dr. Smith',
        'uploadedAt': '2024-11-15',
        'downloadUrl': 'https://example.com/linear-algebra.pdf',
        'description': 'Comprehensive notes on matrix operations and determinants'
      },
      {
        'id': '2',
        'title': 'Quantum Mechanics - Wave Functions',
        'subject': 'Physics',
        'semester': '4',
        'fileType': 'ppt',
        'uploadedBy': 'Prof. Johnson',
        'uploadedAt': '2024-11-10',
        'downloadUrl': 'https://example.com/quantum-mechanics.ppt',
        'description': 'Detailed presentation on wave functions and probability'
      },
      {
        'id': '3',
        'title': 'Organic Chemistry Lab Manual',
        'subject': 'Chemistry',
        'semester': '2',
        'fileType': 'doc',
        'uploadedBy': 'Dr. Wilson',
        'uploadedAt': '2024-11-12',
        'downloadUrl': 'https://example.com/chemistry-lab.doc',
        'description': 'Complete lab manual for organic chemistry experiments'
      },
      {
        'id': '4',
        'title': 'Data Structures and Algorithms',
        'subject': 'Computer Science',
        'semester': '5',
        'fileType': 'pdf',
        'uploadedBy': 'Prof. Anderson',
        'uploadedAt': '2024-11-20',
        'downloadUrl': 'https://example.com/dsa.pdf',
        'description': 'Complete guide to DSA with code examples'
      },
      {
        'id': '5',
        'title': 'Digital Electronics - Logic Gates',
        'subject': 'Electronics',
        'semester': '3',
        'fileType': 'ppt',
        'uploadedBy': 'Dr. Brown',
        'uploadedAt': '2024-11-18',
        'downloadUrl': 'https://example.com/digital-electronics.ppt',
        'description': 'Comprehensive study of logic gates and circuits'
      }
    ];

    // Sample question papers
    _questionPapers = [
      {
        'id': '1',
        'title': 'Mathematics End Term 2023',
        'subject': 'Mathematics',
        'year': '2023',
        'examType': 'End Term',
        'hasSolutions': true,
        'uploadedBy': 'Admin',
        'uploadedAt': '2024-01-15',
        'downloadUrl': 'https://example.com/math-2023.pdf'
      },
      {
        'id': '2',
        'title': 'Physics Mid Term 2024',
        'subject': 'Physics',
        'year': '2024',
        'examType': 'Mid Term',
        'hasSolutions': false,
        'uploadedBy': 'Admin',
        'uploadedAt': '2024-08-10',
        'downloadUrl': 'https://example.com/physics-mid-2024.pdf'
      },
      {
        'id': '3',
        'title': 'Computer Science End Term 2023',
        'subject': 'Computer Science',
        'year': '2023',
        'examType': 'End Term',
        'hasSolutions': true,
        'uploadedBy': 'Admin',
        'uploadedAt': '2024-01-20',
        'downloadUrl': 'https://example.com/cs-2023.pdf'
      }
    ];

    setState(() => _isLoadingMaterials = false);
  }

  // Filter materials based on selected criteria
  List<Map<String, dynamic>> _getFilteredMaterials() {
    List<Map<String, dynamic>> filtered = List.from(_studyMaterials);

    if (_selectedSubject != 'All') {
      filtered = filtered.where((material) =>
      material['subject']?.toLowerCase() == _selectedSubject.toLowerCase()).toList();
    }

    if (_selectedSemester != 'All') {
      filtered = filtered.where((material) =>
      material['semester']?.toString() == _selectedSemester).toList();
    }

    return filtered;
  }

  // Filter question papers
  List<Map<String, dynamic>> _getFilteredQuestionPapers() {
    List<Map<String, dynamic>> filtered = List.from(_questionPapers);

    if (_selectedSubject != 'All') {
      filtered = filtered.where((paper) =>
      paper['subject']?.toLowerCase() == _selectedSubject.toLowerCase()).toList();
    }

    return filtered;
  }

  void _performSearch() {
    final query = _searchController.text.toLowerCase().trim();

    if (query.isEmpty) {
      setState(() {
        _isSearching = false;
        _searchResults.clear();
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _isLoading = true;
    });

    // Search in materials, papers, and other content
    Future.delayed(const Duration(milliseconds: 500), () {
      _fetchSearchResults(query);
    });
  }

  void _fetchSearchResults(String query) async {
    List<Map<String, dynamic>> results = [];

    try {
      // Search in study materials
      for (var material in _studyMaterials) {
        if (material['title']?.toString().toLowerCase().contains(query) == true ||
            material['subject']?.toString().toLowerCase().contains(query) == true ||
            material['description']?.toString().toLowerCase().contains(query) == true) {
          results.add({
            'title': material['title'],
            'type': 'Study Material',
            'icon': _getFileIcon(material['fileType'] ?? 'pdf'),
            'color': Colors.blue,
            'data': material,
          });
        }
      }

      // Search in question papers
      for (var paper in _questionPapers) {
        if (paper['title']?.toString().toLowerCase().contains(query) == true ||
            paper['subject']?.toString().toLowerCase().contains(query) == true) {
          results.add({
            'title': paper['title'],
            'type': 'Question Paper',
            'icon': Icons.quiz,
            'color': Colors.orange,
            'data': paper,
          });
        }
      }

      // Add other search results (clubs, events, etc.)
      final otherData = [
        {'title': 'Coding Club', 'type': 'Club', 'icon': Icons.code, 'color': Colors.purple},
        {'title': 'Tech Fest 2024', 'type': 'Event', 'icon': Icons.event, 'color': Colors.green},
        {'title': 'Software Developer - TCS', 'type': 'Job', 'icon': Icons.work, 'color': Colors.red},
      ];

      for (var item in otherData) {
        if (item['title'].toString().toLowerCase().contains(query)) {
          results.add(item);
        }
      }

      if (mounted) {
        setState(() {
          _searchResults = results;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _searchResults = [];
          _isLoading = false;
        });
      }
    }
  }

  IconData _getFileIcon(String fileType) {
    switch (fileType.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'ppt':
      case 'pptx':
        return Icons.slideshow;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart;
      case 'jpg':
      case 'jpeg':
      case 'png':
        return Icons.image;
      case 'mp4':
      case 'avi':
        return Icons.video_file;
      default:
        return Icons.insert_drive_file;
    }
  }

  Color _getFileColor(String fileType) {
    switch (fileType.toLowerCase()) {
      case 'pdf':
        return Colors.red;
      case 'doc':
      case 'docx':
        return Colors.blue;
      case 'ppt':
      case 'pptx':
        return Colors.orange;
      case 'xls':
      case 'xlsx':
        return Colors.green;
      case 'jpg':
      case 'jpeg':
      case 'png':
        return Colors.purple;
      case 'mp4':
      case 'avi':
        return Colors.indigo;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: _buildAppBar(screenHeight, screenWidth),
      body: _isSearching ? _buildSearchView(screenHeight, screenWidth) : _buildMainContent(screenHeight, screenWidth),
    );
  }

  PreferredSizeWidget _buildAppBar(double screenHeight, double screenWidth) {
    return AppBar(
      backgroundColor: const Color(0xFFFF7F50),
      elevation: 0,
      title: Text(
        'CURRICULUM',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: screenWidth * 0.05,
        ),
      ),
      centerTitle: true,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(120),
        child: Column(
          children: [
            // Search Bar
            Container(
              margin: EdgeInsets.fromLTRB(screenWidth * 0.04, 0, screenWidth * 0.04, screenHeight * 0.02),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search materials, papers, events...',
                  hintStyle: TextStyle(color: Colors.grey[400], fontSize: screenWidth * 0.035),
                  prefixIcon: Icon(Icons.search, color: const Color(0xFFFF7F50), size: screenWidth * 0.05),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                    icon: Icon(Icons.clear, color: const Color(0xFFFF7F50), size: screenWidth * 0.05),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _isSearching = false);
                    },
                  )
                      : null,
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05, vertical: screenHeight * 0.02),
                ),
              ),
            ),
            // Tab Bar (only show when not searching)
            if (!_isSearching)
              Container(
                color: const Color(0xFFFF7F50),
                child: TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  indicatorColor: Colors.white,
                  indicatorWeight: 3,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white70,
                  labelStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: screenWidth * 0.035),
                  unselectedLabelStyle: TextStyle(fontWeight: FontWeight.normal, fontSize: screenWidth * 0.035),
                  tabs: const [
                    Tab(text: 'Clubs'),
                    Tab(text: 'Library'),
                    Tab(text: 'Events'),
                    Tab(text: 'Tasks'),
                    Tab(text: 'Career'),
                    Tab(text: 'Feedback'),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchView(double screenHeight, double screenWidth) {
    return Container(
      padding: EdgeInsets.all(screenWidth * 0.04),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_isLoading)
            Center(
              child: Padding(
                padding: EdgeInsets.all(screenHeight * 0.04),
                child: const CircularProgressIndicator(color: Color(0xFFFF7F50)),
              ),
            )
          else if (_searchResults.isEmpty)
            _buildEmptySearch(screenHeight, screenWidth)
          else
            Expanded(child: _buildSearchResults(screenHeight, screenWidth)),
        ],
      ),
    );
  }

  Widget _buildEmptySearch(double screenHeight, double screenWidth) {
    return Expanded(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: screenWidth * 0.2,
              color: Colors.grey[300],
            ),
            SizedBox(height: screenHeight * 0.02),
            Text(
              _searchController.text.isEmpty
                  ? 'Start typing to search'
                  : 'No results found',
              style: TextStyle(
                fontSize: screenWidth * 0.045,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: screenHeight * 0.01),
            Text(
              'Try searching for study materials, papers, or events',
              style: TextStyle(
                fontSize: screenWidth * 0.035,
                color: Colors.grey[400],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResults(double screenHeight, double screenWidth) {
    return ListView.separated(
      itemCount: _searchResults.length,
      separatorBuilder: (context, index) => SizedBox(height: screenHeight * 0.01),
      itemBuilder: (context, index) {
        final result = _searchResults[index];
        return _buildSearchResultCard(result, screenHeight, screenWidth);
      },
    );
  }

  Widget _buildSearchResultCard(Map<String, dynamic> result, double screenHeight, double screenWidth) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: EdgeInsets.all(screenWidth * 0.04),
        leading: Container(
          width: screenWidth * 0.12,
          height: screenWidth * 0.12,
          decoration: BoxDecoration(
            color: (result['color'] as Color).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            result['icon'] as IconData,
            color: result['color'] as Color,
            size: screenWidth * 0.06,
          ),
        ),
        title: Text(
          result['title'] as String,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: screenWidth * 0.04,
          ),
        ),
        subtitle: Padding(
          padding: EdgeInsets.only(top: screenHeight * 0.005),
          child: Text(
            result['type'] as String,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: screenWidth * 0.035,
            ),
          ),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios_rounded,
          color: Colors.grey[400],
          size: screenWidth * 0.04,
        ),
        onTap: () => _handleSearchTap(result),
      ),
    );
  }

  Widget _buildMainContent(double screenHeight, double screenWidth) {
    return TabBarView(
      controller: _tabController,
      children: [
        _buildClubsTab(screenHeight, screenWidth),
        _buildDigitalLibraryTab(screenHeight, screenWidth),
        _buildEventsTab(screenHeight, screenWidth),
        _buildTasksTab(screenHeight, screenWidth),
        _buildCareerTab(screenHeight, screenWidth),
        _buildFeedbackTab(screenHeight, screenWidth),
      ],
    );
  }

  // Clubs Tab
  Widget _buildClubsTab(double screenHeight, double screenWidth) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(screenWidth * 0.04),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('My Clubs', screenWidth),
          SizedBox(height: screenHeight * 0.015),
          _buildMyClubsSection(screenHeight, screenWidth),
          SizedBox(height: screenHeight * 0.03),
          _buildSectionTitle('Discover More', screenWidth),
          SizedBox(height: screenHeight * 0.015),
          _buildClubCategoriesGrid(screenHeight, screenWidth),
        ],
      ),
    );
  }

  Widget _buildMyClubsSection(double screenHeight, double screenWidth) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildClubItem('Coding Club', 'Next meeting: Today 4 PM', Icons.code, Colors.blue, screenHeight, screenWidth),
          const Divider(height: 1),
          _buildClubItem('Photography Club', 'Workshop on Saturday', Icons.camera_alt, Colors.green, screenHeight, screenWidth),
          SizedBox(height: screenHeight * 0.02),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.04),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _showJoinClubDialog(screenHeight, screenWidth),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF7F50),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: screenHeight * 0.015),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  '+ Join More Clubs',
                  style: TextStyle(fontSize: screenWidth * 0.035),
                ),
              ),
            ),
          ),
          SizedBox(height: screenHeight * 0.02),
        ],
      ),
    );
  }

  Widget _buildClubItem(String title, String subtitle, IconData icon, Color color, double screenHeight, double screenWidth) {
    return ListTile(
      contentPadding: EdgeInsets.all(screenWidth * 0.04),
      leading: Container(
        width: screenWidth * 0.12,
        height: screenWidth * 0.12,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color, size: screenWidth * 0.06),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: screenWidth * 0.04,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
            color: Colors.grey[600],
            fontSize: screenWidth * 0.032
        ),
      ),
      trailing: Icon(
          Icons.arrow_forward_ios_rounded,
          color: Colors.grey[400],
          size: screenWidth * 0.04
      ),
      onTap: () => _navigateToClubDetail(title, screenHeight, screenWidth),
    );
  }

  Widget _buildClubCategoriesGrid(double screenHeight, double screenWidth) {
    final categories = [
      {'name': 'Technical', 'icon': Icons.computer, 'color': Colors.blue, 'count': 12},
      {'name': 'Cultural', 'icon': Icons.palette, 'color': Colors.purple, 'count': 8},
      {'name': 'Sports', 'icon': Icons.sports_soccer, 'color': Colors.green, 'count': 15},
      {'name': 'Academic', 'icon': Icons.school, 'color': Colors.orange, 'count': 6},
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: screenWidth * 0.03,
        mainAxisSpacing: screenHeight * 0.015,
        childAspectRatio: 1.2,
      ),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final category = categories[index];
        return _buildCategoryCard(category, screenHeight, screenWidth);
      },
    );
  }

  Widget _buildCategoryCard(Map<String, dynamic> category, double screenHeight, double screenWidth) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => _navigateToClubCategory(category['name'] as String, screenHeight, screenWidth),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: EdgeInsets.all(screenWidth * 0.04),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: screenWidth * 0.12,
                height: screenWidth * 0.12,
                decoration: BoxDecoration(
                  color: (category['color'] as Color).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  category['icon'] as IconData,
                  color: category['color'] as Color,
                  size: screenWidth * 0.06,
                ),
              ),
              SizedBox(height: screenHeight * 0.01),
              Text(
                category['name'] as String,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: screenWidth * 0.036,
                ),
              ),
              SizedBox(height: screenHeight * 0.005),
              Text(
                '${category['count']} clubs',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: screenWidth * 0.028,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Digital Library Tab
  Widget _buildDigitalLibraryTab(double screenHeight, double screenWidth) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Container(
            color: Colors.white,
            child: TabBar(
              labelColor: const Color(0xFFFF7F50),
              unselectedLabelColor: Colors.grey,
              indicatorColor: const Color(0xFFFF7F50),
              labelStyle: TextStyle(fontSize: screenWidth * 0.035),
              tabs: const [
                Tab(text: 'Study Materials'),
                Tab(text: 'Question Papers'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildStudyMaterialsView(screenHeight, screenWidth),
                _buildQuestionPapersView(screenHeight, screenWidth),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudyMaterialsView(double screenHeight, double screenWidth) {
    return RefreshIndicator(
      onRefresh: () async => _loadSampleData(),
      color: const Color(0xFFFF7F50),
      child: SingleChildScrollView(
        padding: EdgeInsets.all(screenWidth * 0.01),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            SizedBox(height: screenHeight * 0.015),
            _isLoadingMaterials ? _buildLoadingView(screenHeight) : _buildMaterialsList(screenHeight, screenWidth),
          ],
        ),
      ),
    );
  }


  Widget _buildLoadingView(double screenHeight) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(screenHeight * 0.04),
        child: const CircularProgressIndicator(color: Color(0xFFFF7F50)),
      ),
    );
  }

  Widget _buildMaterialsList(double screenHeight, double screenWidth) {
    final filteredMaterials = _getFilteredMaterials();

    if (filteredMaterials.isEmpty) {
      return _buildEmptyMaterials(screenHeight, screenWidth);
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: filteredMaterials.asMap().entries.map((entry) {
          final index = entry.key;
          final material = entry.value;
          final isLast = index == filteredMaterials.length - 1;
          return Column(
            children: [
              _buildMaterialItem(material, screenHeight, screenWidth),
              if (!isLast) const Divider(height: 1),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEmptyMaterials(double screenHeight, double screenWidth) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(screenHeight * 0.04),
        child: Column(
          children: [
            Icon(
                Icons.folder_open,
                size: screenWidth * 0.16,
                color: Colors.grey[300]
            ),
            SizedBox(height: screenHeight * 0.02),
            Text(
              'No materials found',
              style: TextStyle(
                  fontSize: screenWidth * 0.045,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500
              ),
            ),
            SizedBox(height: screenHeight * 0.01),
            Text(
              'Try changing your filter criteria',
              style: TextStyle(
                  fontSize: screenWidth * 0.035,
                  color: Colors.grey[400]
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMaterialItem(Map<String, dynamic> material, double screenHeight, double screenWidth) {
    final fileType = material['fileType']?.toString().toLowerCase() ?? 'unknown';
    final fileColor = _getFileColor(fileType);
    final fileIcon = _getFileIcon(fileType);

    return ListTile(
      contentPadding: EdgeInsets.all(screenWidth * 0.04),
      leading: Container(
        width: screenWidth * 0.12,
        height: screenWidth * 0.12,
        decoration: BoxDecoration(
          color: fileColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(fileIcon, color: fileColor, size: screenWidth * 0.06),
      ),
      title: Text(
        material['title'] ?? 'Untitled',
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: screenWidth * 0.038,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: screenHeight * 0.005),
          Text(
            'Subject: ${material['subject'] ?? 'N/A'} • Sem: ${material['semester'] ?? 'N/A'}',
            style: TextStyle(
                color: Colors.grey[600],
                fontSize: screenWidth * 0.028
            ),
          ),
          if (material['uploadedBy'] != null) ...[
            SizedBox(height: screenHeight * 0.002),
            Text(
              'Uploaded by: ${material['uploadedBy']}',
              style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: screenWidth * 0.028
              ),
            ),
          ],
          if (material['uploadedAt'] != null) ...[
            SizedBox(height: screenHeight * 0.002),
            Text(
              'Date: ${_formatDate(material['uploadedAt'])}',
              style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: screenWidth * 0.028
              ),
            ),
          ],
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.symmetric(
                horizontal: screenWidth * 0.02,
                vertical: screenHeight * 0.005
            ),
            decoration: BoxDecoration(
              color: fileColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              fileType.toUpperCase(),
              style: TextStyle(
                color: fileColor,
                fontWeight: FontWeight.w600,
                fontSize: screenWidth * 0.025,
              ),
            ),
          ),
          SizedBox(width: screenWidth * 0.02),
          Icon(
              Icons.download,
              color: Colors.grey[400],
              size: screenWidth * 0.05
          ),
        ],
      ),
      onTap: () => _downloadMaterial(material),
    );
  }

  Widget _buildQuestionPapersView(double screenHeight, double screenWidth) {
    return RefreshIndicator(
      onRefresh: () async => _loadSampleData(),
      color: const Color(0xFFFF7F50),
      child: SingleChildScrollView(
        padding: EdgeInsets.all(screenWidth * 0.01),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildQuestionPapersList(screenHeight, screenWidth),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionPapersList(double screenHeight, double screenWidth) {
    final filteredPapers = _getFilteredQuestionPapers();

    if (filteredPapers.isEmpty) {
      return _buildEmptyQuestionPapers(screenHeight, screenWidth);
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: filteredPapers.asMap().entries.map((entry) {
          final index = entry.key;
          final paper = entry.value;
          final isLast = index == filteredPapers.length - 1;
          return Column(
            children: [
              _buildQuestionPaperItem(paper, screenHeight, screenWidth),
              if (!isLast) const Divider(height: 1),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEmptyQuestionPapers(double screenHeight, double screenWidth) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(screenHeight * 0.04),
        child: Column(
          children: [
            Icon(Icons.quiz_outlined, size: screenWidth * 0.16, color: Colors.grey[300]),
            SizedBox(height: screenHeight * 0.02),
            Text(
              'No question papers found',
              style: TextStyle(fontSize: screenWidth * 0.045, color: Colors.grey[600], fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionPaperItem(Map<String, dynamic> paper, double screenHeight, double screenWidth) {
    final examType = paper['examType']?.toString() ?? 'Unknown';
    final year = paper['year']?.toString() ?? 'N/A';
    final hasSolutions = paper['hasSolutions'] ?? false;

    return ListTile(
      contentPadding: EdgeInsets.all(screenWidth * 0.04),
      leading: Container(
        width: screenWidth * 0.12,
        height: screenWidth * 0.12,
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(Icons.quiz, color: Colors.orange, size: screenWidth * 0.06),
      ),
      title: Text(
        paper['title'] ?? 'Untitled Paper',
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: screenWidth * 0.038,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: screenHeight * 0.005),
          Text(
            'Subject: ${paper['subject'] ?? 'N/A'} • $examType $year',
            style: TextStyle(color: Colors.grey[600], fontSize: screenWidth * 0.028),
          ),
          if (paper['uploadedBy'] != null) ...[
            SizedBox(height: screenHeight * 0.002),
            Text(
              'Uploaded by: ${paper['uploadedBy']}',
              style: TextStyle(color: Colors.grey[500], fontSize: screenWidth * 0.028),
            ),
          ],
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasSolutions)
            Container(
              padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.015, vertical: screenHeight * 0.003),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'SOLVED',
                style: TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.w600,
                  fontSize: screenWidth * 0.025,
                ),
              ),
            ),
          SizedBox(width: screenWidth * 0.02),
          Icon(Icons.download, color: Colors.grey[400], size: screenWidth * 0.05),
        ],
      ),
      onTap: () => _downloadQuestionPaper(paper),
    );
  }

  // Events Tab
  Widget _buildEventsTab(double screenHeight, double screenWidth) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(screenWidth * 0.04),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Upcoming Events', screenWidth),
          SizedBox(height: screenHeight * 0.015),
          _buildEventsList(screenHeight, screenWidth),
        ],
      ),
    );
  }

  Widget _buildEventsList(double screenHeight, double screenWidth) {
    final events = [
      {'title': 'Tech Fest 2024', 'date': 'Dec 15-17', 'venue': 'Main Auditorium', 'color': Colors.blue},
      {'title': 'Annual Sports Meet', 'date': 'Jan 20-22', 'venue': 'Sports Complex', 'color': Colors.green},
      {'title': 'Cultural Night', 'date': 'Feb 14', 'venue': 'Main Hall', 'color': Colors.purple},
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: events.map((event) {
          final isLast = event == events.last;
          return Column(
            children: [
              _buildEventItem(event, screenHeight, screenWidth),
              if (!isLast) const Divider(height: 1),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEventItem(Map<String, dynamic> event, double screenHeight, double screenWidth) {
    return Padding(
      padding: EdgeInsets.all(screenWidth * 0.04),
      child: Row(
        children: [
          Container(
            width: screenWidth * 0.15,
            height: screenWidth * 0.15,
            decoration: BoxDecoration(
              color: (event['color'] as Color).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.event,
              color: event['color'] as Color,
              size: screenWidth * 0.07,
            ),
          ),
          SizedBox(width: screenWidth * 0.04),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event['title'] as String,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: screenWidth * 0.04,
                  ),
                ),
                SizedBox(height: screenHeight * 0.005),
                Text(
                  '${event['date']} • ${event['venue']}',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: screenWidth * 0.035,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () => _showSuccessMessage('Registered for ${event['title']}'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF7F50),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.04, vertical: screenHeight * 0.01),
            ),
            child: Text('Link', style: TextStyle(fontSize: screenWidth * 0.032)),
          ),
        ],
      ),
    );
  }

  // Tasks Tab
  Widget _buildTasksTab(double screenHeight, double screenWidth) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(screenWidth * 0.04),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _showAddTaskDialog(screenHeight, screenWidth),
              icon: Icon(Icons.add, size: screenWidth * 0.05),
              label: Text('Add New Task', style: TextStyle(fontSize: screenWidth * 0.035)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF7F50),
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: screenHeight * 0.015),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          SizedBox(height: screenHeight * 0.03),
          _buildSectionTitle('Today\'s Tasks', screenWidth),
          SizedBox(height: screenHeight * 0.015),
          _buildTasksList(screenHeight, screenWidth),
        ],
      ),
    );
  }

  Widget _buildTasksList(double screenHeight, double screenWidth) {
    final tasks = [
      {'title': 'Complete Math Assignment', 'time': 'Due: 6 PM today', 'completed': false, 'priority': 'high'},
      {'title': 'Review Physics Notes', 'time': 'Due: Tomorrow', 'completed': false, 'priority': 'medium'},
      {'title': 'Submit Lab Report', 'time': 'Due: Next week', 'completed': true, 'priority': 'low'},
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: tasks.map((task) {
          final isLast = task == tasks.last;
          return Column(
            children: [
              _buildTaskItem(task, screenHeight, screenWidth),
              if (!isLast) const Divider(height: 1),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTaskItem(Map<String, dynamic> task, double screenHeight, double screenWidth) {
    Color priorityColor = _getPriorityColor(task['priority'] as String);

    return CheckboxListTile(
      contentPadding: EdgeInsets.all(screenWidth * 0.04),
      value: task['completed'] as bool,
      onChanged: (value) => _showSuccessMessage('Task updated'),
      activeColor: const Color(0xFFFF7F50),
      secondary: Container(
        width: screenWidth * 0.01,
        height: screenWidth * 0.1,
        decoration: BoxDecoration(
          color: priorityColor,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      title: Text(
        task['title'] as String,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: screenWidth * 0.038,
          decoration: (task['completed'] as bool) ? TextDecoration.lineThrough : null,
        ),
      ),
      subtitle: Text(
        task['time'] as String,
        style: TextStyle(color: Colors.grey[600], fontSize: screenWidth * 0.032),
      ),
    );
  }

  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'high': return Colors.red;
      case 'medium': return Colors.orange;
      case 'low': return Colors.green;
      default: return Colors.grey;
    }
  }

  // Career Tab
  Widget _buildCareerTab(double screenHeight, double screenWidth) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(screenWidth * 0.04),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Latest Opportunities', screenWidth),
          SizedBox(height: screenHeight * 0.015),
          _buildCareerList(screenHeight, screenWidth),
        ],
      ),
    );
  }

  Widget _buildCareerList(double screenHeight, double screenWidth) {
    final jobs = [
      {'title': 'Software Developer', 'company': 'TCS', 'salary': '₹6-8 LPA', 'type': 'Full-time'},
      {'title': 'Data Analyst Intern', 'company': 'Infosys', 'salary': '₹20k/month', 'type': 'Internship'},
      {'title': 'UI/UX Designer', 'company': 'Wipro', 'salary': '₹4-6 LPA', 'type': 'Full-time'},
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: jobs.map((job) {
          final isLast = job == jobs.last;
          return Column(
            children: [
              _buildCareerItem(job, screenHeight, screenWidth),
              if (!isLast) const Divider(height: 1),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCareerItem(Map<String, dynamic> job, double screenHeight, double screenWidth) {
    return Padding(
      padding: EdgeInsets.all(screenWidth * 0.04),
      child: Row(
        children: [
          Container(
            width: screenWidth * 0.15,
            height: screenWidth * 0.15,
            decoration: BoxDecoration(
              color: const Color(0xFFFF7F50).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.work,
              color: const Color(0xFFFF7F50),
              size: screenWidth * 0.07,
            ),
          ),
          SizedBox(width: screenWidth * 0.04),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  job['title'] as String,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: screenWidth * 0.04,
                  ),
                ),
                SizedBox(height: screenHeight * 0.005),
                Text(
                  '${job['company']} • ${job['salary']}',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: screenWidth * 0.035,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () => _showSuccessMessage('Applied for ${job['title']}'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF7F50),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.04, vertical: screenHeight * 0.01),
            ),
            child: Text('Apply', style: TextStyle(fontSize: screenWidth * 0.032)),
          ),
        ],
      ),
    );
  }

  // Feedback Tab
  Widget _buildFeedbackTab(double screenHeight, double screenWidth) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(screenWidth * 0.04),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Submit Feedback', screenWidth),
          SizedBox(height: screenHeight * 0.015),
          _buildFeedbackForm(screenHeight, screenWidth),
        ],
      ),
    );
  }

  Widget _buildFeedbackForm(double screenHeight, double screenWidth) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: EdgeInsets.all(screenWidth * 0.05),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<String>(
            decoration: InputDecoration(
              labelText: 'Category',
              labelStyle: TextStyle(fontSize: screenWidth * 0.035),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFFF7F50)),
              ),
            ),
            items: ['Campus Facilities', 'Curriculum', 'Events', 'Digital Services'].map((String value) {
              return DropdownMenuItem<String>(value: value, child: Text(value, style: TextStyle(fontSize: screenWidth * 0.035)));
            }).toList(),
            onChanged: (value) {},
          ),
          SizedBox(height: screenHeight * 0.02),
          TextFormField(
            maxLines: 4,
            style: TextStyle(fontSize: screenWidth * 0.035),
            decoration: InputDecoration(
              labelText: 'Your Feedback',
              labelStyle: TextStyle(fontSize: screenWidth * 0.035),
              hintText: 'Share your thoughts and suggestions...',
              hintStyle: TextStyle(fontSize: screenWidth * 0.032),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFFF7F50)),
              ),
            ),
          ),
          SizedBox(height: screenHeight * 0.025),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _showSuccessMessage('Feedback submitted successfully!'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF7F50),
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: screenHeight * 0.018),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text('Submit Feedback', style: TextStyle(fontSize: screenWidth * 0.04)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, double screenWidth) {
    return Text(
      title,
      style: TextStyle(
        fontSize: screenWidth * 0.05,
        fontWeight: FontWeight.bold,
        color: const Color(0xFF333333),
      ),
    );
  }

  // Helper Methods
  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'Unknown';

    try {
      DateTime date;
      if (timestamp is Timestamp) {
        date = timestamp.toDate();
      } else if (timestamp is String) {
        date = DateTime.parse(timestamp);
      } else {
        return 'Unknown';
      }

      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return 'Unknown';
    }
  }

  Future<void> _downloadMaterial(Map<String, dynamic> material) async {
    _showSuccessMessage('Preparing download for ${material['title']}...');

    try {
      await FirebaseFirestore.instance.collection('download_logs').add({
        'studentId': widget.studentId,
        'materialId': material['id'],
        'materialTitle': material['title'],
        'downloadedAt': FieldValue.serverTimestamp(),
      });

      if (material['downloadUrl'] != null) {
        _showDownloadDialog(material['title'], material['downloadUrl']);
      } else {
        _showSuccessMessage('Download link will be available soon!');
      }
    } catch (e) {
      print('Error logging download: $e');
      _showErrorMessage('Error processing download request');
    }
  }

  Future<void> _downloadQuestionPaper(Map<String, dynamic> paper) async {
    _showSuccessMessage('Preparing download for ${paper['title']}...');

    try {
      await FirebaseFirestore.instance.collection('download_logs').add({
        'studentId': widget.studentId,
        'paperId': paper['id'],
        'paperTitle': paper['title'],
        'downloadedAt': FieldValue.serverTimestamp(),
      });

      if (paper['downloadUrl'] != null) {
        _showDownloadDialog(paper['title'], paper['downloadUrl']);
      } else {
        _showSuccessMessage('Download link will be available soon!');
      }
    } catch (e) {
      print('Error processing download: $e');
      _showErrorMessage('Error processing download request');
    }
  }

  void _showDownloadDialog(String title, String downloadUrl) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.download, color: Color(0xFFFF7F50)),
            const SizedBox(width: 12),
            const Expanded(child: Text('Download Ready')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('File: $title'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.link, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      downloadUrl,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[700],
                        fontFamily: 'monospace',
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Copy the link above and paste it in your browser to download the file.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Colors.grey[600])),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _showSuccessMessage('Download link is ready - check the dialog above');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF7F50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('OK', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // Navigation Methods for Clubs
  void _navigateToClubDetail(String clubName, double screenHeight, double screenWidth) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ClubDetailPage(
          clubName: clubName,
          studentId: widget.studentId,
        ),
      ),
    );
  }

  void _navigateToClubCategory(String categoryName, double screenHeight, double screenWidth) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ClubCategoryPage(
          categoryName: categoryName,
          studentId: widget.studentId,
        ),
      ),
    );
  }

  // Dialog Methods
  void _showJoinClubDialog(double screenHeight, double screenWidth) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Join New Clubs', style: TextStyle(fontSize: screenWidth * 0.045)),
        content: Text('Browse available clubs and join based on your interests.',
            style: TextStyle(fontSize: screenWidth * 0.035)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Colors.grey[600], fontSize: screenWidth * 0.035)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _showSuccessMessage('Browse clubs feature coming soon!');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF7F50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('Browse', style: TextStyle(color: Colors.white, fontSize: screenWidth * 0.035)),
          ),
        ],
      ),
    );
  }

  void _showAddTaskDialog(double screenHeight, double screenWidth) {
    final TextEditingController taskController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Add New Task', style: TextStyle(fontSize: screenWidth * 0.045)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: taskController,
              style: TextStyle(fontSize: screenWidth * 0.035),
              decoration: InputDecoration(
                labelText: 'Task Title',
                labelStyle: TextStyle(fontSize: screenWidth * 0.035),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            SizedBox(height: screenHeight * 0.02),
            DropdownButtonFormField<String>(
              decoration: InputDecoration(
                labelText: 'Priority',
                labelStyle: TextStyle(fontSize: screenWidth * 0.035),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              items: ['High', 'Medium', 'Low'].map((String value) {
                return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value, style: TextStyle(fontSize: screenWidth * 0.035))
                );
              }).toList(),
              onChanged: (value) {},
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Colors.grey[600], fontSize: screenWidth * 0.035)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              if (taskController.text.isNotEmpty) {
                _showSuccessMessage('Task "${taskController.text}" added successfully!');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF7F50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('Add Task', style: TextStyle(color: Colors.white, fontSize: screenWidth * 0.035)),
          ),
        ],
      ),
    );
  }

  void _handleSearchTap(Map<String, dynamic> result) {
    if (result['data'] != null) {
      // Handle material or paper download
      if (result['type'] == 'Study Material') {
        _downloadMaterial(result['data']);
      } else if (result['type'] == 'Question Paper') {
        _downloadQuestionPaper(result['data']);
      }
    } else {
      _showSuccessMessage('Opening ${result['title']}...');
    }

    // Clear search
    setState(() {
      _isSearching = false;
      _searchController.clear();
    });
  }

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFFF7F50),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }
}

// Navigation Page Classes
class ClubDetailPage extends StatelessWidget {
  final String clubName;
  final String studentId;

  const ClubDetailPage({
    Key? key,
    required this.clubName,
    required this.studentId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFFF7F50),
        title: Text(
          clubName,
          style: TextStyle(
            color: Colors.white,
            fontSize: screenWidth * 0.045,
            fontWeight: FontWeight.bold,
          ),
        ),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(screenWidth * 0.01),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Club Header
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(screenWidth * 0.05),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    width: screenWidth * 0.2,
                    height: screenWidth * 0.2,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF7F50).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      _getClubIcon(clubName),
                      size: screenWidth * 0.1,
                      color: const Color(0xFFFF7F50),
                    ),
                  ),
                  SizedBox(height: screenHeight * 0.02),
                  Text(
                    clubName,
                    style: TextStyle(
                      fontSize: screenWidth * 0.06,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: screenHeight * 0.01),
                  Text(
                    '120 members • Active since 2018',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: screenWidth * 0.035,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: screenHeight * 0.03),

            // About Section
            _buildSection(
              'About',
              'Join our $clubName to enhance your skills and connect with like-minded peers. We organize regular workshops, competitions, and networking events.',
              screenWidth,
              screenHeight,
            ),

            // Activities Section
            _buildSection(
              'Recent Activities',
              '• Workshop on Advanced Techniques\n• Inter-college Competition\n• Guest Speaker Session\n• Project Showcase',
              screenWidth,
              screenHeight,
            ),

            // Join Button
            SizedBox(height: screenHeight * 0.03),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Successfully joined $clubName!'),
                      backgroundColor: Colors.green,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF7F50),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: screenHeight * 0.02),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  'Join Club',
                  style: TextStyle(fontSize: screenWidth * 0.04, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content, double screenWidth, double screenHeight) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: screenWidth * 0.045,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF333333),
          ),
        ),
        SizedBox(height: screenHeight * 0.015),
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(screenWidth * 0.04),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            content,
            style: TextStyle(
              fontSize: screenWidth * 0.035,
              color: Colors.grey[700],
              height: 1.5,
            ),
          ),
        ),
        SizedBox(height: screenHeight * 0.02),
      ],
    );
  }

  IconData _getClubIcon(String clubName) {
    switch (clubName.toLowerCase()) {
      case 'coding club':
        return Icons.code;
      case 'photography club':
        return Icons.camera_alt;
      default:
        return Icons.group;
    }
  }
}

class ClubCategoryPage extends StatelessWidget {
  final String categoryName;
  final String studentId;

  const ClubCategoryPage({
    Key? key,
    required this.categoryName,
    required this.studentId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    final clubs = _getClubsByCategory();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFFF7F50),
        title: Text(
          '$categoryName Clubs',
          style: TextStyle(
            color: Colors.white,
            fontSize: screenWidth * 0.045,
            fontWeight: FontWeight.bold,
          ),
        ),
        elevation: 0,
      ),
      body: ListView.builder(
        padding: EdgeInsets.all(screenWidth * 0.04),
        itemCount: clubs.length,
        itemBuilder: (context, index) {
          final club = clubs[index];
          return Container(
            margin: EdgeInsets.only(bottom: screenHeight * 0.015),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ListTile(
              contentPadding: EdgeInsets.all(screenWidth * 0.04),
              leading: Container(
                width: screenWidth * 0.12,
                height: screenWidth * 0.12,
                decoration: BoxDecoration(
                  color: club['color'].withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  club['icon'],
                  color: club['color'],
                  size: screenWidth * 0.06,
                ),
              ),
              title: Text(
                club['name'],
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: screenWidth * 0.04,
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: screenHeight * 0.005),
                  Text(
                    '${club['members']} members',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: screenWidth * 0.032,
                    ),
                  ),
                  Text(
                    club['description'],
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: screenWidth * 0.03,
                    ),
                  ),
                ],
              ),
              trailing: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ClubDetailPage(
                        clubName: club['name'],
                        studentId: studentId,
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF7F50),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(
                    horizontal: screenWidth * 0.03,
                    vertical: screenHeight * 0.008,
                  ),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: Text(
                  'View',
                  style: TextStyle(fontSize: screenWidth * 0.03),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  List<Map<String, dynamic>> _getClubsByCategory() {
    switch (categoryName.toLowerCase()) {
      case 'technical':
        return [
          {
            'name': 'Coding Club',
            'members': 120,
            'description': 'Programming and software development',
            'icon': Icons.code,
            'color': Colors.blue,
          },
          {
            'name': 'Robotics Club',
            'members': 85,
            'description': 'Build and program robots',
            'icon': Icons.smart_toy,
            'color': Colors.purple,
          },
          {
            'name': 'Web Development Club',
            'members': 95,
            'description': 'Frontend and backend development',
            'icon': Icons.web,
            'color': Colors.green,
          },
          {
            'name': 'AI/ML Club',
            'members': 65,
            'description': 'Artificial Intelligence and Machine Learning',
            'icon': Icons.psychology,
            'color': Colors.orange,
          },
        ];
      case 'cultural':
        return [
          {
            'name': 'Photography Club',
            'members': 78,
            'description': 'Capture moments and express creativity',
            'icon': Icons.camera_alt,
            'color': Colors.teal,
          },
          {
            'name': 'Music Club',
            'members': 102,
            'description': 'Instrumental and vocal performances',
            'icon': Icons.music_note,
            'color': Colors.pink,
          },
          {
            'name': 'Drama Club',
            'members': 56,
            'description': 'Theater and performing arts',
            'icon': Icons.theater_comedy,
            'color': Colors.red,
          },
        ];
      case 'sports':
        return [
          {
            'name': 'Football Club',
            'members': 45,
            'description': 'University football team',
            'icon': Icons.sports_soccer,
            'color': Colors.green,
          },
          {
            'name': 'Basketball Club',
            'members': 38,
            'description': 'Basketball training and matches',
            'icon': Icons.sports_basketball,
            'color': Colors.orange,
          },
          {
            'name': 'Cricket Club',
            'members': 52,
            'description': 'Cricket team and tournaments',
            'icon': Icons.sports_cricket,
            'color': Colors.blue,
          },
        ];
      case 'academic':
        return [
          {
            'name': 'Debate Society',
            'members': 67,
            'description': 'Public speaking and debates',
            'icon': Icons.record_voice_over,
            'color': Colors.indigo,
          },
          {
            'name': 'Quiz Club',
            'members': 89,
            'description': 'Knowledge competitions and quizzes',
            'icon': Icons.quiz,
            'color': Colors.amber,
          },
        ];
      default:
        return [];
    }
  }
}