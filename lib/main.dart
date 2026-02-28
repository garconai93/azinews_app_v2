import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';
import 'package:url_launcher/url_launcher.dart';

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
  final String timeAgo;

  NewsItem({
    required this.title,
    required this.description,
    required this.link,
    this.imageUrl,
    required this.source,
    required this.timeAgo,
  });
}

class NewsService {
  // Folosim RSS-ul direct de pe Digi24 și Mediafax
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

    // Sortează după dată
    allNews.sort((a, b) => b.timeAgo.compareTo(a.timeAgo));
    
    return allNews;
  }

  Future<List<NewsItem>> _fetchFromRss(String url, String source) async {
    // Folosim un proxy CORS mai rapid
    final proxyUrl = 'https://api.allorigins.win/get?url=${Uri.encodeComponent(url)}';
    
    final response = await http.get(Uri.parse(proxyUrl));
    
    if (response.statusCode != 200) {
      throw Exception('Failed to load RSS: ${response.statusCode}');
    }

    final data = response.body;
    // Parse JSON response from allorigins
    final jsonMatch = RegExp(r'"contents":"(.*)"').firstMatch(data);
    final xmlContent = jsonMatch?.group(1) ?? data;
    final decodedContent = Uri.decodeFull(xmlContent.replaceAll(r'\n', '\n'));
    
    final document = XmlDocument.parse(decodedContent);
    final items = document.findAllElements('item');

    List<NewsItem> news = [];
    
    for (var item in items.take(15)) {
      final title = item.findElements('title').firstOrNull?.innerText ?? '';
      final description = item.findElements('description').firstOrNull?.innerText ?? '';
      final link = item.findElements('link').firstOrNull?.innerText ?? '';
      
      // Extrage timpul
      String timeAgo = 'Acum';
      final pubDateStr = item.findElements('pubDate').firstOrNull?.innerText;
      if (pubDateStr != null) {
        try {
          final dateMatch = RegExp(r', (\d+) (\w+) (\d+) (\d+):(\d+):(\d+)').firstMatch(pubDateStr);
          if (dateMatch != null) {
            final months = {
              'Jan': '01', 'Feb': '02', 'Mar': '03', 'Apr': '04',
              'May': '05', 'Jun': '06', 'Jul': '07', 'Aug': '08',
              'Sep': '09', 'Oct': '10', 'Nov': '11', 'Dec': '12'
            };
            final day = dateMatch.group(1)!;
            final month = dateMatch.group(2)!;
            final year = dateMatch.group(3)!;
            final hour = dateMatch.group(4)!;
            final minute = dateMatch.group(5)!;
            
            final pubDate = DateTime.tryParse('$year-${months[month]}-${day.padLeft(2, '0')}T$hour:$minute:00');
            if (pubDate != null) {
              final diff = DateTime.now().difference(pubDate.toLocal());
              if (diff.inMinutes < 60) {
                timeAgo = '${diff.inMinutes}m';
              } else if (diff.inHours < 24) {
                timeAgo = '${diff.inHours}h';
              } else {
                timeAgo = '${diff.inDays}z';
              }
            }
          }
        } catch (e) {
          debugPrint('Date parse error: $e');
        }
      }
      
      // Extrage imagine
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

      // Curăță descrierea
      String cleanDesc = description
          .replaceAll(RegExp(r'<[^>]*>'), '')
          .replaceAll('&nbsp;', ' ')
          .replaceAll('&amp;', '&')
          .replaceAll('&quot;', '"')
          .replaceAll('&#8217;', "'")
          .replaceAll('&#8220;', '"')
          .replaceAll('&#8221;', '"')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();

      if (cleanDesc.length > 200) {
        cleanDesc = '${cleanDesc.substring(0, 200)}...';
      }

      if (title.isNotEmpty) {
        news.add(NewsItem(
          title: title,
          description: cleanDesc,
          link: link,
          imageUrl: imageUrl,
          source: source,
          timeAgo: timeAgo,
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

  String _getHeaderDate() {
    final now = DateTime.now();
    final days = ['Duminică', 'Luni', 'Marți', 'Miercuri', 'Joi', 'Vineri', 'Sâmbătă'];
    final months = ['Ianuarie', 'Februarie', 'Martie', 'Aprilie', 'Mai', 'Iunie', 'Iulie', 'August', 'Septembrie', 'Octombrie', 'Noiembrie', 'Decembrie'];
    return '${days[now.weekday % 7]}, ${now.day} ${months[now.month - 1]} ${now.year}';
  }

  void _showNewsDetail(NewsItem item) async {
    final url = Uri.parse(item.link);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  void _showTermsDialog() {
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
          maxChildSize: 0.9,
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
                  Text(
                    'Informații',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildLinkTile(
                    context,
                    'Termeni și Condiții',
                    'https://azinews.ro/terms.html',
                    Icons.description,
                  ),
                  _buildLinkTile(
                    context,
                    'Politica de Confidențialitate',
                    'https://azinews.ro/privacy.html',
                    Icons.privacy_tip,
                  ),
                  _buildLinkTile(
                    context,
                    'Contact',
                    'mailto:garconaibot@gmail.com',
                    Icons.email,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'AziNews © ${DateTime.now().year}',
                    style: TextStyle(color: Colors.grey[500]),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildLinkTile(BuildContext context, String title, String url, IconData icon) {
    return ListTile(
      leading: Icon(icon, color: Colors.blue),
      title: Text(title),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: () async {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    'AziNews',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _getHeaderDate(),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[400],
                    ),
                  ),
                ],
              ),
            ),
            // News List
            Expanded(
              child: _isLoading
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
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _news.length + 1,
                            itemBuilder: (context, index) {
                              if (index == _news.length) {
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 24),
                                  child: Column(
                                    children: [
                                      Text(
                                        'AziNews © ${DateTime.now().year}',
                                        style: TextStyle(color: Colors.grey[600]),
                                      ),
                                      const SizedBox(height: 8),
                                      Wrap(
                                        spacing: 16,
                                        children: [
                                          GestureDetector(
                                            onTap: _showTermsDialog,
                                            child: Text(
                                              'Termeni',
                                              style: TextStyle(color: Colors.grey[500], fontSize: 12),
                                            ),
                                          ),
                                          GestureDetector(
                                            onTap: _showTermsDialog,
                                            child: Text(
                                              'Confidențialitate',
                                              style: TextStyle(color: Colors.grey[500], fontSize: 12),
                                            ),
                                          ),
                                          GestureDetector(
                                            onTap: _showTermsDialog,
                                            child: Text(
                                              'Contact',
                                              style: TextStyle(color: Colors.grey[500], fontSize: 12),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                );
                              }
                              
                              final item = _news[index];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
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
                                            Text(
                                              item.timeAgo,
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
                                            maxLines: 3,
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
            ),
          ],
        ),
      ),
    );
  }
}
