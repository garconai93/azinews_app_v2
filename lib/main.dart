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

  NewsItem({
    required this.title,
    required this.description,
    required this.link,
    this.imageUrl,
    required this.source,
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
    final response = await http.get(Uri.parse(url));
    
    if (response.statusCode != 200) {
      throw Exception('Failed to load RSS');
    }

    final document = XmlDocument.parse(response.body);
    final items = document.findAllElements('item');

    List<NewsItem> news = [];
    
    for (var item in items.take(10)) {
      final title = item.findElements('title').firstOrNull?.innerText ?? '';
      final description = item.findElements('description').firstOrNull?.innerText ?? '';
      final link = item.findElements('link').firstOrNull?.innerText ?? '';
      
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
          .trim();

      if (title.isNotEmpty) {
        news.add(NewsItem(
          title: title,
          description: cleanDesc.length > 150 ? '${cleanDesc.substring(0, 150)}...' : cleanDesc,
          link: link,
          imageUrl: imageUrl,
          source: source,
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
                      const Text('Nu s-au putut incarca stirile'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadNews,
                        child: const Text('Reincearca'),
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
                                  Text(
                                    _formatDate(DateTime.now()),
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
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  String _formatDate(DateTime date) {
    return DateFormat('HH:mm').format(date);
  }
}
