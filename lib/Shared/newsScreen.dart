import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class NewsScreen extends StatefulWidget {
  final int? initialNewsTimestamp;
  final bool isTab;
  const NewsScreen({Key? key, this.initialNewsTimestamp, this.isTab = false})
      : super(key: key);

  @override
  State<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends State<NewsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFFFF7F50),
        elevation: 0,
        automaticallyImplyLeading: !widget.isTab,
        leading: widget.isTab
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
        title: const Text(
          "LATEST NEWS",
          style: TextStyle(
            color: Color.fromARGB(255, 255, 255, 255),
            fontSize: 20,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore.collection('news').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFFFF7F50)),
            );
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                "No news available.",
                style: TextStyle(color: Colors.black54, fontSize: 16),
              ),
            );
          }

          var newsDocs = snapshot.data!.docs;
          // Sort locally because Firestore requires an index for compound queries (where + orderBy)
          newsDocs.sort((a, b) {
            var aData = a.data() as Map<String, dynamic>;
            var bData = b.data() as Map<String, dynamic>;
            var aTime = aData['createdAt'] ?? 0;
            var bTime = bData['createdAt'] ?? 0;
            return bTime.compareTo(aTime);
          });

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: newsDocs.length,
            itemBuilder: (context, index) {
              var data = newsDocs[index].data() as Map<String, dynamic>;
              var timestamp = data['createdAt'] as int?;
              bool isInitial = widget.initialNewsTimestamp != null &&
                  timestamp == widget.initialNewsTimestamp;

              return NewsItemCard(
                data: data,
                initialExpanded: isInitial,
              );
            },
          );
        },
      ),
    );
  }
}

class NewsItemCard extends StatefulWidget {
  final Map<String, dynamic> data;
  final bool initialExpanded;

  const NewsItemCard({
    Key? key,
    required this.data,
    this.initialExpanded = false,
  }) : super(key: key);

  @override
  State<NewsItemCard> createState() => _NewsItemCardState();
}

class _NewsItemCardState extends State<NewsItemCard> {
  late bool isExpanded;

  @override
  void initState() {
    super.initState();
    isExpanded = widget.initialExpanded;
  }

  @override
  Widget build(BuildContext context) {
    var title = widget.data['title'] ?? 'Untitled';
    var content = widget.data['content'] ?? '';
    var timestamp = widget.data['createdAt'] as int?;
    var dateStr = '';

    if (timestamp != null) {
      var date = DateTime.fromMillisecondsSinceEpoch(timestamp);
      dateStr =
          "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} ${date.hour > 12 ? date.hour - 12 : (date.hour == 0 ? 12 : date.hour)}:${date.minute.toString().padLeft(2, '0')} ${date.hour >= 12 ? 'PM' : 'AM'}";
    }

    bool isPinned =
        widget.data['type'] == 'pinned' || widget.data['type'] == 'permanent';
    bool isLongContent = content.toString().length > 150 ||
        content.toString().split('\n').length > 3;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isPinned ? const Color(0xFFFFF1F2) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: isPinned ? const Color(0xFFFECDD3) : Colors.grey.shade100,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
              if (isPinned)
                Container(
                  margin: const EdgeInsets.only(left: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF1F2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFECDD3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(PhosphorIconsFill.pushPin,
                          size: 12, color: Color(0xFFE11D48)),
                      const SizedBox(width: 4),
                      const Text(
                        "Pinned",
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFE11D48),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            content,
            maxLines: isExpanded ? null : 3,
            overflow: isExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black54,
              height: 1.4,
            ),
          ),
          if (isLongContent)
            GestureDetector(
              onTap: () {
                setState(() {
                  isExpanded = !isExpanded;
                });
              },
              child: Padding(
                padding: const EdgeInsets.only(top: 8.0, bottom: 4.0),
                child: Text(
                  isExpanded ? "Read less" : "Read more",
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFFF7F50),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(PhosphorIconsRegular.clock,
                  size: 14, color: Colors.grey.shade400),
              const SizedBox(width: 4),
              Text(
                dateStr,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade400,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
