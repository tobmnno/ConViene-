import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

void downloadCartImage(Uint8List bytes) {
  final blob = web.Blob(
    [bytes.toJS].toJS,
    web.BlobPropertyBag(type: 'image/png'),
  );
  final url = web.URL.createObjectURL(blob);
  final link = web.HTMLAnchorElement()
    ..href = url
    ..download = 'conviene-changuito.png';
  web.document.body?.appendChild(link);
  link.click();
  link.remove();
  unawaited(
    Future<void>.delayed(
      const Duration(seconds: 10),
      () => web.URL.revokeObjectURL(url),
    ),
  );
}
