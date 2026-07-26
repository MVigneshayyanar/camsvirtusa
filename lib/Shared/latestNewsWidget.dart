import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'newsScreen.dart';

class LatestNewsWidget extends StatefulWidget {
  const LatestNewsWidget({Key? key}) : super(key: key);

  @override
  State<LatestNewsWidget> createState() => _LatestNewsWidgetState();
}

class _LatestNewsWidgetState extends State<LatestNewsWidget> {
  final PageController _pageController = PageController(viewportFraction: 0.93);
  Timer? _timer;
  int _currentPage = 0;
  int _newsCount = 0;

  @override
  void initState() {
    super.initState();
    _startAutoSlide();
  }

  void _startAutoSlide() {
    _timer = Timer.periodic(const Duration(seconds: 4), (Timer timer) {
      if (_newsCount > 1) {
        _currentPage = (_currentPage + 1) % _newsCount;
        if (_pageController.hasClients) {
          _pageController.animateToPage(
            _currentPage,
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeInOut,
          );
        }
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _showNewsDetails(BuildContext context, Map<String, dynamic> news) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28.0),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFF97316).withOpacity(0.1),
                    ),
                    child: const Icon(
                      Icons.newspaper_rounded,
                      color: Color(0xFFF97316),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      news['title'] ?? 'News Details',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.4,
                ),
                child: SingleChildScrollView(
                  child: Text(
                    news['content'] ?? '',
                    style: const TextStyle(
                      fontSize: 15,
                      color: Colors.black87,
                      height: 1.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF97316),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    "Close",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('news').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }

        var allNews = snapshot.data!.docs;
        
        var pinnedNews = allNews.where((doc) {
          var data = doc.data() as Map<String, dynamic>;
          return data['type'] == 'pinned' || data['type'] == 'permanent';
        }).toList();

        var regularNews = allNews.where((doc) {
          var data = doc.data() as Map<String, dynamic>;
          return data['type'] == 'regular';
        }).toList();

        pinnedNews.sort((a, b) => ((b.data() as Map<String, dynamic>)['createdAt'] ?? 0).compareTo((a.data() as Map<String, dynamic>)['createdAt'] ?? 0));
        regularNews.sort((a, b) => ((b.data() as Map<String, dynamic>)['createdAt'] ?? 0).compareTo((a.data() as Map<String, dynamic>)['createdAt'] ?? 0));

        var combinedNews = [...pinnedNews, ...regularNews];
        // Take only the latest 3 news items for the home page
        combinedNews = combinedNews.take(3).toList();
        _newsCount = combinedNews.length;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                "Latest News",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 95,
              child: PageView.builder(
                controller: _pageController,
                itemCount: combinedNews.length,
                onPageChanged: (int page) {
                  _currentPage = page;
                },
                itemBuilder: (context, index) {
                  var data = combinedNews[index].data() as Map<String, dynamic>;
                  bool isPinned = data['type'] == 'pinned' || data['type'] == 'permanent';
                  
                  // Format the date and time
                  String timeString = '';
                  if (data['createdAt'] != null) {
                    DateTime date = DateTime.fromMillisecondsSinceEpoch(data['createdAt']);
                    timeString = "${date.day}/${date.month}/${date.year} ${date.hour > 12 ? date.hour - 12 : date.hour == 0 ? 12 : date.hour}:${date.minute.toString().padLeft(2, '0')} ${date.hour >= 12 ? 'PM' : 'AM'}";
                  }

                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => NewsScreen(
                            initialNewsTimestamp: data['createdAt'] as int?,
                          ),
                        ),
                      );
                    },
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: isPinned ? const Color(0xFFFFF1F2) : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isPinned ? const Color(0xFFFECDD3) : Colors.grey.shade200,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    isPinned ? PhosphorIconsFill.pushPin : PhosphorIconsRegular.newspaper,
                                    size: 14,
                                    color: isPinned ? const Color(0xFFE11D48) : const Color(0xFF3B82F6),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    isPinned ? "Pinned" : "Update",
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: isPinned ? const Color(0xFFE11D48) : const Color(0xFF3B82F6),
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                timeString,
                                style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            data['title'] ?? 'Untitled',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Expanded(
                            child: Text(
                              data['content'] ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.black54,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
