import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';

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
  static const String digi24Url = 'https://api.rss2json.com/v1/api.json?rss_url=https://www.digi24.ro/rss';
  static const String mediafaxUrl = 'https://api.rss2json.com/v1/api.json?rss_url=https://www.mediafax.ro/rss';

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
      throw Exception('Failed to load RSS: ${response.statusCode}');
    }

    final jsonData = json.decode(response.body) as Map<String, dynamic>;
    
    if (jsonData['status'] != 'ok') {
      throw Exception('RSS API error');
    }

    final items = jsonData['items'] as List<dynamic>? ?? [];
    List<NewsItem> news = [];
    
    for (var item in items.take(15)) {
      final title = item['title'] ?? '';
      final description = item['description'] ?? '';
      final link = item['link'] ?? '';
      
      String timeAgo = 'Acum';
      final pubDate = item['pubDate'];
      if (pubDate != null) {
        try {
          final date = DateTime.tryParse(pubDate);
          if (date != null) {
            final diff = DateTime.now().difference(date.toLocal());
            if (diff.inMinutes < 60) {
              timeAgo = '${diff.inMinutes}m';
            } else if (diff.inHours < 24) {
              timeAgo = '${diff.inHours}h';
            } else {
              timeAgo = '${diff.inDays}z';
            }
          }
        } catch (e) {
          debugPrint('Date parse error: $e');
        }
      }
      
      // Extrage imagine
      String? imageUrl;
      if (item['thumbnail'] != null) {
        imageUrl = item['thumbnail'];
      } else if (item['enclosure'] != null && item['enclosure']['link'] != null) {
        imageUrl = item['enclosure']['link'];
      }

      // Curăță descrierea
      String cleanDesc = description
          .toString()
          .replaceAll(RegExp(r'<[^>]*>'), '')
          .replaceAll('&nbsp;', ' ')
          .replaceAll('&amp;', '&')
          .replaceAll('&quot;', '"')
          .replaceAll('&#8217;', "'")
          .replaceAll('&#8220;', '"')
          .replaceAll('&#8221;', '"')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();

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
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Imagine în detail
                  if (item.imageUrl != null && item.imageUrl!.isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: CachedNetworkImage(
                        imageUrl: item.imageUrl!,
                        height: 200,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          height: 200,
                          color: Colors.grey[800],
                          child: const Center(child: CircularProgressIndicator()),
                        ),
                        errorWidget: (context, url, error) => Container(
                          height: 200,
                          color: Colors.grey[800],
                          child: const Icon(Icons.image_not_supported, size: 50),
                        ),
                      ),
                    ),
                  if (item.imageUrl != null && item.imageUrl!.isNotEmpty)
                    const SizedBox(height: 20),
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
                  Text(
                    item.timeAgo,
                    style: TextStyle(color: Colors.grey[500]),
                  ),
                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 16),
                  Text(
                    item.description,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final url = Uri.parse(item.link);
                        if (await canLaunchUrl(url)) {
                          await launchUrl(url, mode: LaunchMode.externalApplication);
                        }
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
                                clipBehavior: Clip.antiAlias,
                                child: InkWell(
                                  onTap: () => _showNewsDetail(item),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Poza
                                      if (item.imageUrl != null && item.imageUrl!.isNotEmpty)
                                        CachedNetworkImage(
                                          imageUrl: item.imageUrl!,
                                          height: 180,
                                          width: double.infinity,
                                          fit: BoxFit.cover,
                                          placeholder: (context, url) => Container(
                                            height: 180,
                                            color: Colors.grey[800],
                                            child: const Center(child: CircularProgressIndicator()),
                                          ),
                                          errorWidget: (context, url, error) => const SizedBox.shrink(),
                                        ),
                                      Padding(
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
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
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
                                    ],
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
