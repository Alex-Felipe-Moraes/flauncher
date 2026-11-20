import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

class WikimediaFeaturedImage {
  final Uint8List imageBytes;
  final String title;
  final String description;
  final String credit;
  final String license;
  final String licenseUrl;
  final String sourceUrl;

  const WikimediaFeaturedImage({
    required this.imageBytes,
    required this.title,
    required this.description,
    required this.credit,
    required this.license,
    required this.licenseUrl,
    required this.sourceUrl,
  });
}

class WikimediaFeaturedImageService extends ChangeNotifier {
  static const _requestTimeout = Duration(seconds: 20);

  final HttpClient _client;
  final Uri _apiEndpoint;
  final Random _random;

  int _requestId = 0;
  WikimediaFeaturedImage? _featuredImage;
  Object? _lastError;
  bool _isLoading = false;
  bool _hasAttemptedInitialLoad = false;

  WikimediaFeaturedImage? get featuredImage => _featuredImage;
  Object? get lastError => _lastError;
  bool get isLoading => _isLoading;

  WikimediaFeaturedImageService({
    HttpClient? httpClient,
    Uri? apiEndpoint,
    Random? random,
  })  : _client = httpClient ?? HttpClient(),
        _apiEndpoint =
            apiEndpoint ?? Uri.https('commons.wikimedia.org', '/w/api.php'),
        _random = random ?? Random() {
    _client.userAgent = 'FLauncher/2024.11 (Android TV launcher)';
  }

  Future<void> loadFeaturedImageForStartup() {
    if (_hasAttemptedInitialLoad) {
      return Future<void>.value();
    }

    _hasAttemptedInitialLoad = true;
    return _loadFeaturedImage();
  }

  Future<void> _loadFeaturedImage() async {
    final requestId = ++_requestId;
    _isLoading = true;
    _lastError = null;
    notifyListeners();

    try {
      final page = await _requestLandscapePage();
      if (requestId != _requestId) {
        return;
      }

      final imageBytes = await _requestImage(page.imageUrl);
      if (requestId != _requestId) {
        return;
      }

      final featuredImage = WikimediaFeaturedImage(
        imageBytes: imageBytes,
        title: page.title,
        description: page.description,
        credit: page.credit,
        license: page.license,
        licenseUrl: page.licenseUrl,
        sourceUrl: page.sourceUrl,
      );
      _featuredImage = featuredImage;
      _isLoading = false;
      notifyListeners();
    } on IOException catch (error, stackTrace) {
      _reportFailure(requestId, error, stackTrace);
    } on FormatException catch (error, stackTrace) {
      _reportFailure(requestId, error, stackTrace);
    } on TimeoutException catch (error, stackTrace) {
      _reportFailure(requestId, error, stackTrace);
    } on StateError catch (error, stackTrace) {
      _reportFailure(requestId, error, stackTrace);
    }
  }

  Future<_CommonsImagePage> _requestLandscapePage() async {
    final uri = _apiEndpoint.replace(queryParameters: {
      'action': 'query',
      'generator': 'search',
      'gsrsearch': 'landscape',
      'gsrnamespace': '6',
      'gsrlimit': '20',
      'prop': 'imageinfo',
      'iiprop': 'url|extmetadata',
      'iiurlwidth': '1280',
      'format': 'json',
      'formatversion': '2',
    });

    final response = await _get(uri);
    final body =
        await utf8.decoder.bind(response).join().timeout(_requestTimeout);
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid Wikimedia API response.');
    }

    final query = decoded['query'];
    final pages = query is Map<String, dynamic> ? query['pages'] : null;
    if (pages is! List) {
      throw StateError('Wikimedia Commons returned no landscape images.');
    }

    final candidates = pages
        .whereType<Map<String, dynamic>>()
        .map(_CommonsImagePage.fromApiPage)
        .whereType<_CommonsImagePage>()
        .where((page) => page.width >= 1280 && page.height >= 720)
        .where((page) => page.width / page.height >= 1.4)
        .toList();

    if (candidates.isEmpty) {
      throw StateError('Wikimedia Commons returned no landscape images.');
    }

    return candidates[_random.nextInt(candidates.length)];
  }

  Future<HttpClientResponse> _get(Uri uri) async {
    final request = await _client.getUrl(uri).timeout(_requestTimeout);
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    final response = await request.close().timeout(_requestTimeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
        'Wikimedia request failed with status ${response.statusCode}.',
        uri: uri,
      );
    }
    return response;
  }

  Future<Uint8List> _requestImage(String imageUrl) async {
    final uri = Uri.parse(imageUrl);
    final request = await _client.getUrl(uri).timeout(_requestTimeout);
    final response = await request.close().timeout(_requestTimeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
        'Wikimedia image request failed with status ${response.statusCode}.',
        uri: uri,
      );
    }

    final bytes = await response
        .fold<BytesBuilder>(
            BytesBuilder(), (builder, chunk) => builder..add(chunk))
        .then((builder) => builder.takeBytes())
        .timeout(_requestTimeout);
    if (bytes.isEmpty) {
      throw const FormatException('Wikimedia returned an empty image.');
    }
    return bytes;
  }

  void _reportFailure(int requestId, Object error, StackTrace stackTrace) {
    if (requestId != _requestId) {
      return;
    }

    debugPrint('Unable to load Wikimedia featured image: $error\n$stackTrace');
    _lastError = error;
    _isLoading = false;
    notifyListeners();
  }

  void reportImageFailure(Object error, StackTrace? stackTrace) {
    _requestId++;
    debugPrint(
        'Unable to decode Wikimedia featured image: $error\n$stackTrace');
    _featuredImage = null;
    _lastError = error;
    _isLoading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _client.close(force: true);
    super.dispose();
  }
}

class _CommonsImagePage {
  final String title;
  final String description;
  final String credit;
  final String license;
  final String licenseUrl;
  final String sourceUrl;
  final String imageUrl;
  final int width;
  final int height;

  const _CommonsImagePage({
    required this.title,
    required this.description,
    required this.credit,
    required this.license,
    required this.licenseUrl,
    required this.sourceUrl,
    required this.imageUrl,
    required this.width,
    required this.height,
  });

  static _CommonsImagePage? fromApiPage(Map<String, dynamic> page) {
    final imageInfoList = page['imageinfo'];
    if (imageInfoList is! List || imageInfoList.isEmpty) {
      return null;
    }

    final imageInfo = imageInfoList.first;
    if (imageInfo is! Map<String, dynamic>) {
      return null;
    }

    final imageUrl = imageInfo['thumburl'];
    final sourceUrl = imageInfo['descriptionurl'];
    final width = imageInfo['thumbwidth'];
    final height = imageInfo['thumbheight'];
    if (imageUrl is! String ||
        sourceUrl is! String ||
        width is! int ||
        height is! int ||
        width <= 0 ||
        height <= 0) {
      return null;
    }

    final metadata = imageInfo['extmetadata'];
    final metadataMap =
        metadata is Map<String, dynamic> ? metadata : const <String, dynamic>{};
    final pageTitle = page['title'];
    final title = _cleanText(_metadataValue(metadataMap, 'ObjectName'));
    final description =
        _cleanText(_metadataValue(metadataMap, 'ImageDescription'));
    final credit = _cleanText(_metadataValue(metadataMap, 'Artist'));
    final license = _cleanText(_metadataValue(metadataMap, 'LicenseShortName'));
    final licenseUrl = _metadataValue(metadataMap, 'LicenseUrl');

    return _CommonsImagePage(
      title: title.isNotEmpty
          ? title
          : pageTitle is String
              ? pageTitle.replaceFirst('File:', '').replaceAll('_', ' ')
              : 'Wikimedia Commons image',
      description: description,
      credit: credit,
      license: license,
      licenseUrl: licenseUrl,
      sourceUrl: sourceUrl,
      imageUrl: imageUrl,
      width: width,
      height: height,
    );
  }

  static String _metadataValue(Map<String, dynamic> metadata, String key) {
    final item = metadata[key];
    if (item is Map<String, dynamic> && item['value'] is String) {
      return item['value'] as String;
    }
    return '';
  }

  static String _cleanText(String value) => value
      .replaceAll(RegExp(r'<[^>]*>'), ' ')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&#160;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}
