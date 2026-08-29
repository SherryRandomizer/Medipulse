abstract class RestApiClient {
  Future<Map<String, dynamic>> get(String path);
  Future<Map<String, dynamic>> post(String path, {Map<String, dynamic>? body});
}

class UnconfiguredRestApiClient implements RestApiClient {
  @override
  Future<Map<String, dynamic>> get(String path) {
    throw UnsupportedError('REST API base URL is not configured.');
  }

  @override
  Future<Map<String, dynamic>> post(String path, {Map<String, dynamic>? body}) {
    throw UnsupportedError('REST API base URL is not configured.');
  }
}
