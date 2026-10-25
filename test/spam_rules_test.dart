import 'package:flutter_test/flutter_test.dart';
import 'package:phantomgram/features/antispam/spam_rules.dart';

SpamCandidate _c(
  String text, {
  bool contact = false,
  bool photo = true,
  bool scam = false,
  bool bot = false,
  bool outgoing = false,
}) => SpamCandidate(
  text: text,
  isContact: contact,
  hasProfilePhoto: photo,
  isScam: scam,
  isFake: false,
  isBot: bot,
  hasOutgoingMessages: outgoing,
);

void main() {
  final rules = SpamRules();

  test('keywords, links and scam flags', () {
    expect(evaluateSpam(_c('Пассивный ДОХОД от 100к'), rules), ['стоп-слово «пассивный доход»']);
    expect(evaluateSpam(_c('зайди на cool-bonus.xyz'), rules), ['ссылка от незнакомца']);
    expect(evaluateSpam(_c('привет', scam: true), rules), ['помечен Telegram как SCAM']);
    expect(evaluateSpam(_c('Привет, это Аня из школы'), rules), isEmpty);
  });

  test('never touches contacts, bots or people we wrote to', () {
    const spam = 'Казино https://x.top';
    expect(evaluateSpam(_c(spam, contact: true), rules), isEmpty);
    expect(evaluateSpam(_c(spam, bot: true), rules), isEmpty);
    expect(evaluateSpam(_c(spam, outgoing: true), rules), isEmpty);
    expect(evaluateSpam(_c(spam), SpamRules(enabled: false)), isEmpty);
  });

  test('no-photo rule is opt-in', () {
    expect(evaluateSpam(_c('привет', photo: false), rules), isEmpty);
    expect(evaluateSpam(_c('привет', photo: false), SpamRules(strangerNoPhoto: true)), ['незнакомец без аватарки']);
  });

  test('hidden words and JSON round-trip', () {
    final r = SpamRules(hiddenWords: ['Реклама']);
    expect(hiddenWordIn('Это РЕКЛАМА канала', r), 'реклама');
    expect(hiddenWordIn('обычный текст', r), isNull);
    final back = SpamRules.fromJson(r.toJson());
    expect(back.hiddenWords, ['Реклама']);
    expect(back.keywords, defaultSpamKeywords);
  });
}
