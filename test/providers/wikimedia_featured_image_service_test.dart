import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flauncher/providers/wikimedia_featured_image_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('loads one random landscape image from Commons per startup', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final requests = <HttpRequest>[];
    final subscription = server.listen((request) async {
      requests.add(request);
      if (request.uri.path == '/api.php') {
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode({
          'query': {
            'pages': [
              {
                'title': 'File:Example landscape.jpg',
                'imageinfo': [
                  {
                    'thumburl': 'http://127.0.0.1:${server.port}/landscape.jpg',
                    'descriptionurl':
                        'https://commons.wikimedia.org/wiki/File:Example_landscape.jpg',
                    'thumbwidth': 1280,
                    'thumbheight': 720,
                    'extmetadata': {
                      'ObjectName': {'value': 'Example landscape'},
                      'ImageDescription': {
                        'value': 'A <b>wide</b> landscape &amp; sky.'
                      },
                      'Artist': {
                        'value': '<a href="/wiki/User:Example">Example</a>'
                      },
                      'LicenseShortName': {'value': 'CC BY-SA 4.0'},
                      'LicenseUrl': {
                        'value':
                            'https://creativecommons.org/licenses/by-sa/4.0/'
                      },
                    },
                  },
                ],
              },
            ],
          },
        }));
      } else if (request.uri.path == '/landscape.jpg') {
        request.response.headers.contentType = ContentType('image', 'jpeg');
        request.response.add([1, 2, 3, 4]);
      } else {
        request.response.statusCode = HttpStatus.notFound;
      }
      await request.response.close();
    });

    final service = WikimediaFeaturedImageService(
      apiEndpoint: Uri.parse('http://127.0.0.1:${server.port}/api.php'),
      random: Random(0),
    );

    try {
      await service.loadFeaturedImageForStartup();

      expect(service.isLoading, isFalse);
      expect(service.lastError, isNull);
      expect(service.featuredImage?.title, 'Example landscape');
      expect(service.featuredImage?.description, 'A wide landscape & sky.');
      expect(service.featuredImage?.credit, 'Example');
      expect(service.featuredImage?.license, 'CC BY-SA 4.0');
      expect(service.featuredImage?.imageBytes, [1, 2, 3, 4]);
      expect(requests.first.uri.queryParameters['gsrsearch'], 'landscape');
      expect(requests.first.uri.queryParameters['iiurlwidth'], '1280');

      final requestCountAfterLoad = requests.length;
      await service.loadFeaturedImageForStartup();
      expect(requests, hasLength(requestCountAfterLoad));
    } finally {
      service.dispose();
      await subscription.cancel();
      await server.close(force: true);
    }
  });
}
