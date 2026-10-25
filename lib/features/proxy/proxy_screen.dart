import 'package:flutter/material.dart';

import '../../core/services.dart';
import '../../core/td_text.dart';
import 'proxy_link.dart';
import 'proxy_manager.dart';

class ProxyScreen extends StatelessWidget {
  const ProxyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final manager = s.proxy;
    final settings = s.settings;
    return Scaffold(
      appBar: AppBar(title: const Text('Прокси (MTProxy)')),
      body: ListenableBuilder(
        listenable: Listenable.merge([settings, manager]),
        builder: (context, _) {
          final cfg = settings.proxy;
          final last = cfg.lastRotation;
          return ListView(
            children: [
              SwitchListTile(
                title: const Text('Автоподбор лучших прокси'),
                subtitle: Text(
                  'Топ-${cfg.topCount} по пингу и стабильности, '
                  'пересчёт каждые ${cfg.intervalMinutes} мин, автопереключение при обрыве',
                ),
                value: cfg.autoEnabled,
                onChanged: manager.busy ? null : manager.setAutoEnabled,
              ),
              ListTile(
                title: const Text('Сколько держать в списке'),
                trailing: DropdownButton<int>(
                  value: cfg.topCount,
                  items: [
                    for (final n in [3, 5, 7, 10]) DropdownMenuItem(value: n, child: Text('$n')),
                  ],
                  onChanged: (v) => settings.update((st) => st.proxy.topCount = v!),
                ),
              ),
              ListTile(
                title: const Text('Пересчитывать каждые'),
                trailing: DropdownButton<int>(
                  value: cfg.intervalMinutes,
                  items: [
                    for (final m in [15, 30, 60, 120, 360])
                      DropdownMenuItem(value: m, child: Text(m < 60 ? '$m мин' : '${m ~/ 60} ч')),
                  ],
                  onChanged: (v) => settings.update((st) => st.proxy.intervalMinutes = v!),
                ),
              ),
              if (manager.busy)
                ListTile(
                  title: Text(
                    manager.progressTotal == 0
                        ? 'Сбор прокси из источников…'
                        : 'Проверка ${manager.progressDone} из ${manager.progressTotal}',
                  ),
                  subtitle: LinearProgressIndicator(
                    value: manager.progressTotal == 0 ? null : manager.progressDone / manager.progressTotal,
                  ),
                )
              else
                ListTile(
                  title: Text(
                    last == null
                        ? 'Подбор ещё не запускался'
                        : 'Последний подбор: ${formatShortDate(last.millisecondsSinceEpoch ~/ 1000)} '
                              '${formatTime(last.millisecondsSinceEpoch ~/ 1000)}'
                              '${manager.lastCandidateCount > 0 ? ' · проверено ${manager.lastCandidateCount}' : ''}',
                  ),
                  subtitle: manager.lastError == null
                      ? null
                      : Text(manager.lastError!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  trailing: FilledButton.tonal(
                    onPressed: cfg.autoEnabled ? manager.rotate : null,
                    child: const Text('Подобрать сейчас'),
                  ),
                ),
              const _Header('Текущий топ'),
              if (cfg.selected.isEmpty) const ListTile(title: Text('Пусто')),
              for (final (i, p) in cfg.selected.indexed)
                ListTile(
                  leading: Icon(i == cfg.activeIndex ? Icons.radio_button_checked : Icons.radio_button_off),
                  title: Text('${p.link.server}:${p.link.port}'),
                  subtitle: Text(
                    'пинг ${p.pingMs.round()} мс · разброс ${p.jitterMs.round()} мс · '
                    'ответил ${(p.successRate * 100).round()}%',
                  ),
                  onTap: () => manager.activate(i),
                ),
              const _Header('Источники'),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Ссылка на страницу или файл со списком tg://proxy / t.me/proxy ссылок, '
                  'или @канал, где публикуют прокси (канал читается через ваш аккаунт).',
                  style: TextStyle(fontSize: 12),
                ),
              ),
              for (final src in cfg.sources)
                ListTile(
                  leading: Icon(isChannelSource(src) ? Icons.campaign_outlined : Icons.link),
                  title: Text(src),
                  trailing: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => settings.update((st) => st.proxy.sources.remove(src)),
                  ),
                ),
              ListTile(
                leading: const Icon(Icons.add),
                title: const Text('Добавить источник'),
                onTap: () async {
                  final v = await _ask(context, 'Источник', 'https://… или @channel');
                  if (v != null && v.isNotEmpty && !cfg.sources.contains(v)) {
                    settings.update((st) => st.proxy.sources.add(v));
                  }
                },
              ),
              const _Header('Свои прокси'),
              for (final link in cfg.manualLinks)
                ListTile(
                  title: Text(parseProxyLink(link)?.toString() ?? link, maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => settings.update((st) => st.proxy.manualLinks.remove(link)),
                  ),
                ),
              ListTile(
                leading: const Icon(Icons.add),
                title: const Text('Вставить ссылки на прокси'),
                onTap: () async {
                  final v = await _ask(context, 'Ссылки', 'tg://proxy?server=…&port=…&secret=…', lines: 6);
                  if (v == null) return;
                  final links = extractProxyLinks(v);
                  if (links.isEmpty) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context)
                          .showSnackBar(const SnackBar(content: Text('Ссылок на MTProxy не найдено')));
                    }
                    return;
                  }
                  settings.update((st) {
                    for (final l in links) {
                      if (!st.proxy.manualLinks.contains(l.toLink())) st.proxy.manualLinks.add(l.toLink());
                    }
                  });
                },
              ),
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Скорость оценивается по задержке, разбросу и потерям пингов: отдельно скачать '
                  'тестовый файл через MTProxy нельзя. Владелец прокси видит ваш IP (но не переписку) '
                  'и может показывать в списке чатов спонсорский канал.',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  static Future<String?> _ask(BuildContext context, String title, String hint, {int lines = 1}) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          minLines: lines,
          maxLines: lines,
          decoration: InputDecoration(hintText: hint),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Добавить')),
        ],
      ),
    );
    controller.dispose();
    return result;
  }
}

class _Header extends StatelessWidget {
  const _Header(this.title);

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
    child: Text(
      title,
      style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w600),
    ),
  );
}
