// Adaptador exclusivo do executor QA: permite que frames nativos usem o mesmo
// cliente ficticio dos testes; nenhuma chamada deste helper sai para a rede.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

Future<T> executar<T>(Future<T> Function() body, http.Client Function() create) async {
  final anterior = HttpOverrides.current;
  final client = create();
  HttpOverrides.global = _Override(client);
  try {
    return await http.runWithClient(body, () => client);
  } finally {
    HttpOverrides.global = anterior;
    client.close();
  }
}

class _Override extends HttpOverrides {
  final http.Client client;
  _Override(this.client);
  @override
  HttpClient createHttpClient(SecurityContext? context) => _Client(client);
}

class _Client extends Fake implements HttpClient {
  final http.Client client;
  _Client(this.client);
  @override bool autoUncompress = true;
  @override Duration? connectionTimeout;
  @override Duration idleTimeout = const Duration(seconds: 15);
  @override String? userAgent;
  @override int? maxConnectionsPerHost;
  @override Future<HttpClientRequest> openUrl(String method, Uri url) async => _Request(client,method,url);
  @override Future<HttpClientRequest> getUrl(Uri url) => openUrl('GET',url);
  @override Future<HttpClientRequest> postUrl(Uri url) => openUrl('POST',url);
  @override Future<HttpClientRequest> putUrl(Uri url) => openUrl('PUT',url);
  @override Future<HttpClientRequest> patchUrl(Uri url) => openUrl('PATCH',url);
  @override Future<HttpClientRequest> deleteUrl(Uri url) => openUrl('DELETE',url);
  @override Future<HttpClientRequest> headUrl(Uri url) => openUrl('HEAD',url);
  @override void close({bool force=false}) {}
}

class _Headers extends Fake implements HttpHeaders {
  final values = <String,List<String>>{};
  @override void add(String name,Object value,{bool preserveHeaderCase=false}) {
    values.putIfAbsent(name.toLowerCase(),()=>[]).add(value.toString());
  }
  @override void set(String name,Object value,{bool preserveHeaderCase=false}) {
    values[name.toLowerCase()] = [value.toString()];
  }
  @override List<String>? operator [](String name) => values[name.toLowerCase()];
  @override String? value(String name) => values[name.toLowerCase()]?.join(',');
  @override void forEach(void Function(String,List<String>) action) => values.forEach(action);
  @override ContentType? get contentType => ContentType.json;
}

class _Request extends Fake implements HttpClientRequest {
  final http.Client client;
  @override final String method;
  @override final Uri uri;
  _Request(this.client,this.method,this.uri);
  @override final headers = _Headers();
  final _bytes = <int>[];
  Future<HttpClientResponse>? _result;
  @override bool followRedirects = true;
  @override bool persistentConnection = false;
  @override bool bufferOutput = true;
  @override int maxRedirects = 5;
  @override int contentLength = -1;
  @override Encoding encoding = utf8;
  @override void add(List<int> bytes) => _bytes.addAll(bytes);
  @override Future<void> addStream(Stream<List<int>> stream) async {
    await for (final bytes in stream) { add(bytes); }
  }
  Future<HttpClientResponse> _send() async {
    final request = http.Request(method,uri)..bodyBytes=_bytes;
    headers.forEach((name,values)=>request.headers[name]=values.join(','));
    final response = await http.Response.fromStream(await client.send(request));
    return _Response(response);
  }
  @override Future<HttpClientResponse> close() => _result ??= _send();
  @override Future<HttpClientResponse> get done => close();
  @override void abort([Object? exception,StackTrace? stackTrace]) {}
  @override Future<void> flush() async {}
}

class _Response extends Stream<List<int>> implements HttpClientResponse {
  final http.Response response;
  _Response(this.response) {
    response.headers.forEach((name,value)=>headers.set(name,value));
  }
  @override final headers = _Headers();
  @override int get statusCode => response.statusCode;
  @override int get contentLength => response.bodyBytes.length;
  @override String get reasonPhrase => response.reasonPhrase ?? '';
  @override bool get isRedirect => false;
  @override bool get persistentConnection => false;
  @override List<RedirectInfo> get redirects => [];
  @override List<Cookie> get cookies => [];
  @override X509Certificate? get certificate => null;
  @override HttpConnectionInfo? get connectionInfo => null;
  @override HttpClientResponseCompressionState get compressionState => HttpClientResponseCompressionState.notCompressed;
  @override StreamSubscription<List<int>> listen(void Function(List<int>)? onData,{Function? onError,void Function()? onDone,bool? cancelOnError}) => Stream<List<int>>.value(response.bodyBytes).listen(onData,onError:onError,onDone:onDone,cancelOnError:cancelOnError);
  @override Future<Socket> detachSocket() => throw UnsupportedError('Somente QA');
  @override Future<HttpClientResponse> redirect([String? method,Uri? url,bool? followLoops]) => throw UnsupportedError('Somente QA');
}
