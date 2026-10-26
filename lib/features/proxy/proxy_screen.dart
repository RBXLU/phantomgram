import 'package:flutter/cupertino.dart';

import '../../core/services.dart';
import '../../core/td_text.dart';
import '../../ui/feedback.dart';
import '../../ui/ios_list.dart';
import '../../ui/ios_page.dart';
import '../../ui/look.dart';
import 'proxy_link.dart';
import 'proxy_manager.dart';

class ProxyScreen extends StatelessWidget {
  const ProxyScreen({super.key});

  static Color pingColor(double ms) => ms < 80
      ? LookData.green
      : ms < 200
      ? LookData.orange
      : LookData.destructive;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final manager = s.proxy;
    final settings = s.settings;
    return ListenableBuilder(
      listenable: Listenable.merge([settings, manager]),
      builder: (context, _) {
        final cfg = settings.proxy;
        final last = cfg.lastRotation;
        final look = Look.of(context);

        Future<void> pickNumber(
          String title,
          List<int> options,
          String Function(int) label,
          void Function(int) set,
        ) async {
          final v = await actionSheet<int>(
            context,
            title: title,
            actions: [for (final o in options) SheetAction(label(o), o)],
          );
          if (v != null) settings.update((_) => set(v));
        }

        String interval(int m) => m < 60 ? '$m мин' : '${m ~/ 60} ч';

        return IosPage(
          title: 'Прокси',
          slivers: [
            SliverToBoxAdapter(
              child: IosSection(
                dividerInset: 16,
                footer:
                    'Собирает прокси из ваших источников, пингует каждый 3 раза, держит лучшие по задержке '
                    'и стабильности и переключается на следующий при обрыве.',
                children: [
                  IosSwitchRow(
                    title: 'Автоподбор лучших',
                    value: cfg.autoEnabled,
                    onChanged: manager.busy ? null : manager.setAutoEnabled,
                  ),
                  IosRow(
                    title: 'Держать в списке',
                    value: '${cfg.topCount}',
                    onTap: () => pickNumber(
                      'Сколько прокси держать',
                      [3, 5, 7, 10],
                      (n) => '$n',
                      (v) => settings.proxy.topCount = v,
                    ),
                  ),
                  IosRow(
                    title: 'Пересчитывать каждые',
                    value: interval(cfg.intervalMinutes),
                    onTap: () => pickNumber(
                      'Как часто пересчитывать',
                      [15, 30, 60, 120, 360],
                      interval,
                      (v) => settings.proxy.intervalMinutes = v,
                    ),
                  ),
                  if (manager.busy)
                    IosRow(
                      title: manager.progressTotal == 0
                          ? 'Сбор прокси из источников…'
                          : 'Проверено ${manager.progressDone} из ${manager.progressTotal}',
                      trailing: const CupertinoActivityIndicator(),
                    )
                  else
                    IosRow(
                      title: 'Подобрать сейчас',
                      accent: cfg.autoEnabled,
                      enabled: cfg.autoEnabled,
                      subtitle:
                          manager.lastError ??
                          (last == null
                              ? 'Подбор ещё не запускался'
                              : 'Последний: ${formatDateTime(last.millisecondsSinceEpoch ~/ 1000)}'
                                    '${manager.lastCandidateCount > 0 ? ' · проверено ${manager.lastCandidateCount}' : ''}'),
                      onTap: manager.rotate,
                      chevron: false,
                    ),
                ],
              ),
            ),
            SliverToBoxAdapter(
              child: IosSection(
                header: 'Текущий топ',
                dividerInset: 16,
                children: [
                  if (cfg.selected.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text('Пусто', style: TextStyle(color: look.secondaryLabel)),
                    ),
                  for (final (i, p) in cfg.selected.indexed)
                    IosRow(
                      title: '${p.link.server}:${p.link.port}',
                      subtitle: 'разброс ${p.jitterMs.round()} мс · ответил ${(p.successRate * 100).round()}%',
                      onTap: () => manager.activate(i),
                      chevron: false,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: pingColor(p.pingMs).withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '${p.pingMs.round()} мс',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: pingColor(p.pingMs)),
                            ),
                          ),
                          SizedBox(
                            width: 30,
                            child: i == cfg.activeIndex
                                ? Icon(CupertinoIcons.checkmark_alt, color: look.accent, size: 22)
                                : null,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            SliverToBoxAdapter(
              child: IosSection(
                header: 'Источники',
                dividerInset: 16,
                footer:
                    'Страница или файл со ссылками tg://proxy / t.me/proxy, или @канал, где публикуют прокси '
                    '(канал читается через ваш аккаунт).',
                children: [
                  for (final src in cfg.sources)
                    IosRow(
                      title: src,
                      subtitle: isChannelSource(src) ? 'Telegram-канал' : 'Ссылка',
                      trailing: _RemoveButton(onPressed: () => settings.update((st) => st.proxy.sources.remove(src))),
                    ),
                  IosRow(
                    title: 'Добавить источник',
                    accent: true,
                    chevron: false,
                    onTap: () async {
                      final v = await promptText(
                        context,
                        title: 'Источник',
                        placeholder: 'https://… или @channel',
                        action: 'Добавить',
                      );
                      if (v != null && v.isNotEmpty && !cfg.sources.contains(v)) {
                        settings.update((st) => st.proxy.sources.add(v));
                      }
                    },
                  ),
                ],
              ),
            ),
            SliverToBoxAdapter(
              child: IosSection(
                header: 'Свои прокси',
                dividerInset: 16,
                footer:
                    'Скорость оценивается по задержке, разбросу и потерям: скачать тестовый файл через MTProxy '
                    'в обход Telegram нельзя. Владелец прокси видит ваш IP (но не переписку) и может '
                    'показывать спонсорский канал.',
                children: [
                  for (final link in cfg.manualLinks)
                    IosRow(
                      title: parseProxyLink(link)?.toString() ?? link,
                      trailing: _RemoveButton(
                        onPressed: () => settings.update((st) => st.proxy.manualLinks.remove(link)),
                      ),
                    ),
                  IosRow(
                    title: 'Вставить ссылки',
                    accent: true,
                    chevron: false,
                    onTap: () async {
                      final v = await promptText(
                        context,
                        title: 'Ссылки на прокси',
                        placeholder: 'tg://proxy?server=…&port=…&secret=…',
                        lines: 5,
                        action: 'Добавить',
                      );
                      if (v == null || !context.mounted) return;
                      final links = extractProxyLinks(v);
                      if (links.isEmpty) {
                        showToast(context, 'Ссылок на MTProxy не найдено');
                        return;
                      }
                      settings.update((st) {
                        for (final l in links) {
                          if (!st.proxy.manualLinks.contains(l.toLink())) st.proxy.manualLinks.add(l.toLink());
                        }
                      });
                      showToast(context, 'Добавлено: ${links.length}');
                    },
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _RemoveButton extends StatelessWidget {
  const _RemoveButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => CupertinoButton(
    padding: EdgeInsets.zero,
    minimumSize: const Size(32, 32),
    onPressed: onPressed,
    child: const Icon(CupertinoIcons.minus_circle_fill, color: LookData.destructive),
  );
}
