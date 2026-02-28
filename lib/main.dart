import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';
import 'package:intl/intl.dart';

void main() {
  runApp(const AziNewsApp());
}

class AziNewsApp extends StatelessWidget {
  const AziNewsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AziNews',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2563EB),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class NewsItem {
  final String title;
  final String description;
  final String link;
  final String? imageUrl;
  final String source;
  final DateTime? pubDate;

  NewsItem({
    required this.title,
    required this.description,
    required this.link,
    this.imageUrl,
    required this.source,
    this.pubDate,
  });
}

class NewsService {
  static const String digi24Url = 'https://www.digi24.ro/rss';
  static const String mediafaxUrl = 'https://www.mediafax.ro/rss';

  Future<List<NewsItem>> fetchNews() async {
    List<NewsItem> allNews = [];

    try {
      final digiNews = await _fetchFromRss(digi24Url, 'Digi24');
      allNews.addAll(digiNews);
    } catch (e) {
      debugPrint('Error fetching Digi24: $e');
    }

    try {
      final mediafaxNews = await _fetchFromRss(mediafaxUrl, 'Mediafax');
      allNews.addAll(mediafaxNews);
    } catch (e) {
      debugPrint('Error fetching Mediafax: $e');
    }

    return allNews;
  }

  Future<List<NewsItem>> _fetchFromRss(String url, String source) async {
    final proxyUrl = 'https://api.allorigins.win/raw?url=${Uri.encodeComponent(url)}';
    
    final response = await http.get(Uri.parse(proxyUrl));
    
    if (response.statusCode != 200) {
      throw Exception('Failed to load RSS: ${response.statusCode}');
    }

    final document = XmlDocument.parse(response.body);
    final items = document.findAllElements('item');

    List<NewsItem> news = [];
    
    for (var item in items.take(15)) {
      final title = item.findElements('title').firstOrNull?.innerText ?? '';
      final description = item.findElements('description').firstOrNull?.innerText ?? '';
      final link = item.findElements('link').firstOrNull?.innerText ?? '';
      
      DateTime? pubDate;
      final pubDateStr = item.findElements('pubDate').firstOrNull?.innerText;
      if (pubDateStr != null) {
        try {
          final parts = RegExp(r', (\d+) (\w+) (\d+) (\d+):(\d+):(\d+)').firstMatch(pubDateStr);
          if (parts != null) {
            final day = parts.group(1)!;
            final month = parts.group(2)!;
            final year = parts.group(3)!;
            final hour = parts.group(4)!;
            final minute = parts.group(5)!;
            final second = parts.group(6)!;
            final months = {
              'Jan': '01', 'Feb': '02', 'Mar': '03', 'Apr': '04',
              'May': '05', 'Jun': '06', 'Jul': '07', 'Aug': '08',
              'Sep': '09', 'Oct': '10', 'Nov': '11', 'Dec': '12'
            };
            final monthNum = months[month] ?? '01';
            pubDate = DateTime.tryParse('$year-$monthNum-${day.padLeft(2, '0')}T$hour:$minute:$second');
          }
        } catch (e) {
          debugPrint('Date parse error: $e');
        }
      }
      
      String? imageUrl;
      var mediaContent = item.findElements('media:content').firstOrNull;
      if (mediaContent != null) {
        imageUrl = mediaContent.getAttribute('url');
      }
      
      if (imageUrl == null) {
        var enclosure = item.findElements('enclosure').firstOrNull;
        if (enclosure != null && enclosure.getAttribute('type')?.startsWith('image') == true) {
          imageUrl = enclosure.getAttribute('url');
        }
      }

      final cleanDesc = description
          .replaceAll(RegExp(r'<[^>]*>'), '')
          .replaceAll('&nbsp;', ' ')
          .replaceAll('&amp;', '&')
          .replaceAll('&quot;', '"')
          .replaceAll('&#8217;', "'")
          .replaceAll('&#8220;', '"')
          .replaceAll('&#8221;', '"')
          .trim();

      if (title.isNotEmpty) {
        news.add(NewsItem(
          title: title,
          description: cleanDesc.length > 150 ? '${cleanDesc.substring(0, 150)}...' : cleanDesc,
          link: link,
          imageUrl: imageUrl,
          source: source,
          pubDate: pubDate,
        ));
      }
    }

    return news;
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final NewsService _newsService = NewsService();
  List<NewsItem> _news = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNews();
  }

  Future<void> _loadNews() async {
    setState(() => _isLoading = true);
    final news = await _newsService.fetchNews();
    setState(() {
      _news = news;
      _isLoading = false;
    });
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '';
    final now = DateTime.now();
    final diff = now.difference(date);
    
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}z';
    } else {
      return DateFormat('dd MMM').format(date);
    }
  }

  void _showNewsDetail(NewsItem item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[600],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: item.source == 'Digi24' ? Colors.blue : Colors.orange,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      item.source,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    item.title,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (item.pubDate != null)
                    Text(
                      _formatFullDate(item.pubDate!),
                      style: TextStyle(color: Colors.grey[500]),
                    ),
                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 16),
                  Text(
                    item.description.replaceAll(RegExp(r'\.\.\.$'), ''),
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        // Poți adăuga funcționalitate de deschidere în browser
                      },
                      icon: const Icon(Icons.open_in_new),
                      label: const Text('Citește mai mult'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _formatFullDate(DateTime date) {
    return DateFormat('dd MMMM yyyy, HH:mm').format(date);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.newspaper),
            SizedBox(width: 8),
            Text('AziNews'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadNews,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _news.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 64),
                      const SizedBox(height: 16),
                      const Text('Nu s-au putut încărca știrile'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadNews,
                        child: const Text('Reîncearcă'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadNews,
                  child: ListView.builder(
                    itemCount: _news.length,
                    itemBuilder: (context, index) {
                      final item = _news[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: InkWell(
                          onTap: () => _showNewsDetail(item),
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: item.source == 'Digi24'
                                            ? Colors.blue
                                            : Colors.orange,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        item.source,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const Spacer(),
                                    if (item.pubDate != null)
                                      Text(
                                        _formatDate(item.pubDate),
                                        style: Theme.of(context).textTheme.bodySmall,
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  item.title,
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (item.description.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    item.description,
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: Colors.grey[400],
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
