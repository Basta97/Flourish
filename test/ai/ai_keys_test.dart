import 'package:flourish/core/ai/ai_config.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('each host keeps its own key; the old single key moves once', () async {
    FlutterSecureStorage.setMockInitialValues({'ai_api_key': 'sk-old'});
    const storage = FlutterSecureStorage();
    expect(await AiKeys.read(storage, 'api.deepseek.com'), 'sk-old');
    expect(await storage.read(key: 'ai_api_key'), isNull);
    // Another provider does not receive DeepSeek's key.
    expect(await AiKeys.read(storage, 'api.groq.com'), isNull);
    await AiKeys.write(storage, 'api.groq.com', 'gsk-new');
    expect(await AiKeys.read(storage, 'api.groq.com'), 'gsk-new');
    expect(await AiKeys.read(storage, 'api.deepseek.com'), 'sk-old');
  });

  test('keys travel only over https, except to local servers', () {
    AiSettings at(String url) => AiSettings(baseUrl: url);
    expect(at('https://api.deepseek.com').secureEndpoint, isTrue);
    expect(at('http://api.deepseek.com').secureEndpoint, isFalse);
    expect(at('http://localhost:11434/v1').secureEndpoint, isTrue);
    expect(at('http://192.168.1.20:8080').secureEndpoint, isTrue);
    expect(at('http://172.40.0.1').secureEndpoint, isFalse);
    expect(at('http://api.deepseek.com').configured, isFalse);
  });
}
