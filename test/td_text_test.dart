import 'package:flutter_test/flutter_test.dart';
import 'package:phantomgram/core/settings.dart';
import 'package:phantomgram/core/td_text.dart';
import 'package:phantomgram/widgets/chat_avatar.dart';

void main() {
  test('content previews', () {
    expect(
      contentText({
        '@type': 'messageText',
        'text': {'text': 'hi'},
      }),
      'hi',
    );
    expect(
      contentText({
        '@type': 'messagePhoto',
        'caption': {'text': 'море'},
      }),
      '🖼 Фото море',
    );
    expect(
      contentText({
        '@type': 'messageVoiceNote',
        'caption': {'text': ''},
      }),
      '🎤 Голосовое сообщение',
    );
    expect(contentKind({'@type': 'messageSticker'}), 'Sticker');
  });

  test('hidden text-link targets are searchable', () {
    final content = {
      '@type': 'messageText',
      'text': {
        'text': 'Подключиться к прокси: ссылка',
        'entities': [
          {
            'offset': 23,
            'length': 6,
            'type': {'@type': 'textEntityTypeTextUrl', 'url': 'tg://proxy?server=a'},
          },
          {
            'offset': 0,
            'length': 11,
            'type': {'@type': 'textEntityTypeUrl'},
          },
        ],
      },
    };
    final text = searchableContentText(content);
    expect(text, contains('tg://proxy?server=a'));
    expect(text, contains('Подключитьс'));
  });

  test('dates and initials', () {
    final now = DateTime(2026, 10, 25, 18);
    final today = DateTime(2026, 10, 25, 9, 5).millisecondsSinceEpoch ~/ 1000;
    final older = DateTime(2026, 3, 8).millisecondsSinceEpoch ~/ 1000;
    expect(formatShortDate(today, now: now), '09:05');
    expect(formatShortDate(older, now: now), '08.03');
    expect(formatDateTime(today, now: now), '09:05');
    expect(formatDateTime(older, now: now), '08.03 00:00');
    expect(initials('иван петров'), 'ИП');
    expect(initials('😀 Party'), 'P');
    expect(initials('Работа 💼'), 'Р');
    expect(initials('Phantomgram — разработка'), 'PР');
    expect(initials('🚀'), '🚀');
    expect(initials('  '), '?');
  });

  test('settings survive a JSON round-trip', () {
    final s = AppSettings.memory()
      ..apiId = 1
      ..apiHash = 'h'
      ..localPins = [3, 1, 2];
    s.ghost.enabled = true;
    s.theme.bubbleRadius = 4;
    s.proxy.sources = ['@p'];
    s.toggleLocalPin(9);
    expect(s.localPins, [9, 3, 1, 2]);
    s.toggleLocalPin(3);
    expect(s.localPins, [9, 1, 2]);
    final json = s.toJson();
    expect(json['ghost']['enabled'], isTrue);
    expect(json['theme']['bubbleRadius'], 4);
    expect(s.ghost.shouldSkipRead, isTrue);
    s.ghost.enabled = false;
    expect(s.ghost.shouldSkipRead, isFalse);
  });
}
