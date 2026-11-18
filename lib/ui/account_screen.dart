import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/account.dart';
import '../domain/subscription.dart';
import '../state/providers.dart';
import 'account_button.dart';
import 'app_logo.dart';
import 'format.dart';
import 'measurement_dialogs.dart';
import 'subscription_screen.dart';

/// Личный кабинет: данные пользователя и динамика замеров.
class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final measurements = ref.watch(measurementsProvider);
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 64,
        title: Row(mainAxisSize: MainAxisSize.min, children: [
          const AppLogo(size: 30, showTagline: false),
          const SizedBox(width: 16),
          Container(width: 1, height: 28, color: Theme.of(context).colorScheme.outlineVariant),
          const SizedBox(width: 16),
          const Flexible(child: Text('Личный кабинет', overflow: TextOverflow.ellipsis)),
        ]),
        actions: const [AppBarActions()],
      ),
      body: user == null
          ? const SizedBox.shrink()
          : switch (measurements) {
              AsyncData(:final value) => _Cabinet(user: user, measurements: value),
              AsyncError(:final error) => Center(child: Text('Ошибка загрузки замеров: $error')),
              _ => const Center(child: CircularProgressIndicator()),
            },
    );
  }
}

class _Cabinet extends ConsumerWidget {
  final AppUser user;
  final List<Measurement> measurements;
  const _Cabinet({required this.user, required this.measurements});

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final weight = ref.read(savedProfileProvider).valueOrNull?.weightKg;
    final m = await MeasurementDialog.show(context, defaultWeight: weight);
    if (m != null) await ref.read(measurementsProvider.notifier).save(m);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const gap = SizedBox(height: 16);
    return ListView(padding: const EdgeInsets.all(16), children: [
      Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _UserCard(user: user, count: measurements.length, onAdd: () => _add(context, ref)),
            gap,
            const _SubscriptionStrip(),
            gap,
            if (measurements.isEmpty)
              const _EmptyHint()
            else ...[
              _LatestCard(measurements: measurements),
              gap,
              _ChartCard(measurements: measurements),
              gap,
              _HistoryTable(measurements: measurements),
            ],
          ]),
        ),
      ),
    ]);
  }
}

class _UserCard extends StatelessWidget {
  final AppUser user;
  final int count;
  final VoidCallback onAdd;
  const _UserCard({required this.user, required this.count, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 16,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          alignment: WrapAlignment.spaceBetween,
          children: [
            Row(mainAxisSize: MainAxisSize.min, children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: theme.colorScheme.primaryContainer,
                child: Text(
                  user.name.characters.first.toUpperCase(),
                  style: theme.textTheme.titleLarge?.copyWith(color: theme.colorScheme.onPrimaryContainer),
                ),
              ),
              const SizedBox(width: 16),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(user.name, style: theme.textTheme.titleLarge),
                Text(
                  '${user.login} · с ${fmtDate(user.createdAt)} · замеров: $count',
                  style: theme.textTheme.bodySmall,
                ),
              ]),
            ]),
            FilledButton.icon(
              key: const Key('addMeasurement'),
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Добавить замер'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Статус подписки и переход к управлению ею.
class _SubscriptionStrip extends ConsumerWidget {
  const _SubscriptionStrip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sub = ref.watch(subscriptionProvider).valueOrNull;
    if (sub == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final now = ref.watch(clockProvider)();
    final status = sub.status(now);
    final until = sub.accessUntil(now);
    final color = switch (status) {
      SubscriptionStatus.active => theme.colorScheme.primary,
      SubscriptionStatus.trial => theme.colorScheme.tertiary,
      SubscriptionStatus.expired => theme.colorScheme.error,
      SubscriptionStatus.none => theme.colorScheme.onSurfaceVariant,
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Wrap(
          spacing: 16,
          runSpacing: 8,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.workspace_premium_outlined, color: color),
              const SizedBox(width: 12),
              Text(status.label, style: theme.textTheme.titleMedium?.copyWith(color: color)),
              if (until != null) Text('  ·  до ${fmtDate(until)}', style: theme.textTheme.bodyMedium),
            ]),
            OutlinedButton(
              key: const Key('openSubscription'),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SubscriptionScreen())),
              child: Text(status == SubscriptionStatus.active ? 'Управлять подпиской' : 'Оформить подписку'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint();

  @override
  Widget build(BuildContext context) => const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Замеров пока нет. Сохраните результат калиперометрии или расчёта рациона кнопкой '
            '«Сохранить замер» либо добавьте замер вручную — здесь появятся графики и таблица изменений.',
          ),
        ),
      );
}

/// Последние значения ключевых показателей и изменение к предыдущему замеру.
class _LatestCard extends StatelessWidget {
  final List<Measurement> measurements;
  const _LatestCard({required this.measurements});

  static const _metrics = [
    Metric.weight,
    Metric.bodyFat,
    Metric.leanKg,
    Metric.muscleKg,
    Metric.waist,
    Metric.targetKcal,
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tiles = <Widget>[];
    for (final metric in _metrics) {
      final i = measurements.lastIndexWhere((m) => metric.of(m) != null);
      if (i < 0) continue;
      final delta = metricDelta(measurements, i, metric);
      tiles.add(SizedBox(
        width: 148,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(metric.label, style: theme.textTheme.bodySmall),
          Text(
            '${fmt(metric.of(measurements[i])!, metric.digits)} ${metric.unit}',
            style: theme.textTheme.titleLarge?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
          ),
          Text(
            [
              fmtDate(measurements[i].date),
              if (delta != null) fmtDelta(delta, metric.digits),
            ].join(' · '),
            style: theme.textTheme.bodySmall,
          ),
        ]),
      ));
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Последние значения', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          Wrap(spacing: 24, runSpacing: 16, children: tiles),
        ]),
      ),
    );
  }
}

/// График выбранного показателя по датам.
class _ChartCard extends StatefulWidget {
  final List<Measurement> measurements;
  const _ChartCard({required this.measurements});

  @override
  State<_ChartCard> createState() => _ChartCardState();
}

class _ChartCardState extends State<_ChartCard> {
  Metric _metric = Metric.weight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final available = [
      for (final m in Metric.values)
        if (widget.measurements.any((x) => m.of(x) != null)) m,
    ];
    final metric = available.contains(_metric) ? _metric : available.first;
    final points = [
      for (final m in widget.measurements)
        if (metric.of(m) case final v?) (m.date, v),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Динамика', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final m in available)
              ChoiceChip(
                key: Key('metric-${m.name}'),
                label: Text(m.label),
                selected: m == metric,
                onSelected: (_) => setState(() => _metric = m),
              ),
          ]),
          const SizedBox(height: 20),
          SizedBox(height: 260, child: _MetricChart(metric: metric, points: points)),
        ]),
      ),
    );
  }
}

class _MetricChart extends StatelessWidget {
  final Metric metric;
  final List<(DateTime, double)> points;
  const _MetricChart({required this.metric, required this.points});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.primary;
    final first = points.first.$1;
    double x(DateTime d) => d.difference(first).inDays.toDouble();
    final spots = [for (final (d, v) in points) FlSpot(x(d), v)];

    final span = spots.last.x;
    // даты подписываются у замеров: не больше ~6 подписей и не ближе 7 % ширины друг к другу
    final labelDays = <double>{};
    for (final s in spots) {
      if (labelDays.isEmpty || s.x - labelDays.last >= math.max(1, span * 0.07)) labelDays.add(s.x);
    }
    if (labelDays.length > 6) {
      final step = (labelDays.length / 6).ceil();
      final all = labelDays.toList();
      labelDays
        ..clear()
        ..addAll([for (var i = 0; i < all.length; i += step) all[i]]);
    }
    final minY = spots.map((s) => s.y).reduce(math.min);
    final maxY = spots.map((s) => s.y).reduce(math.max);
    final pad = maxY - minY < 1e-9 ? math.max(1.0, maxY.abs() * 0.05) : (maxY - minY) * 0.15;
    final labelStyle = theme.textTheme.bodySmall;

    return LineChart(LineChartData(
      minX: span == 0 ? -1 : 0,
      maxX: span == 0 ? 1 : span,
      minY: minY - pad,
      maxY: maxY + pad,
      gridData: FlGridData(
        drawVerticalLine: false,
        getDrawingHorizontalLine: (_) => FlLine(color: theme.colorScheme.outlineVariant, strokeWidth: 1),
      ),
      borderData: FlBorderData(show: false),
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(),
        rightTitles: const AxisTitles(),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 52,
            // крайние значения не подписываем — они налезают на соседние
            getTitlesWidget: (value, meta) => value == meta.min || value == meta.max
                ? const SizedBox.shrink()
                : SideTitleWidget(meta: meta, child: Text(fmt(value, metric.digits), style: labelStyle)),
          ),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 28,
            interval: 1, // подписи — только у дней с замерами
            getTitlesWidget: (value, meta) {
              if (!labelDays.contains(value)) return const SizedBox.shrink();
              final d = first.add(Duration(days: value.round()));
              return SideTitleWidget(
                meta: meta,
                fitInside: SideTitleFitInsideData.fromTitleMeta(meta),
                child: Text(fmtDate(d).substring(0, 5), style: labelStyle),
              );
            },
          ),
        ),
      ),
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          getTooltipColor: (_) => theme.colorScheme.inverseSurface,
          getTooltipItems: (spots) => [
            for (final s in spots)
              LineTooltipItem(
                '${fmtDate(first.add(Duration(days: s.x.round())))}\n${fmt(s.y, metric.digits)} ${metric.unit}',
                TextStyle(color: theme.colorScheme.onInverseSurface),
              ),
          ],
        ),
      ),
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          color: color,
          barWidth: 3,
          dotData: const FlDotData(show: true),
          belowBarData: BarAreaData(show: true, color: color.withValues(alpha: 0.08)),
        ),
      ],
    ));
  }
}

/// Таблица замеров (новые сверху) с изменением к предыдущему замеру.
class _HistoryTable extends ConsumerWidget {
  final List<Measurement> measurements;
  const _HistoryTable({required this.measurements});

  static const _columns = [
    Metric.weight,
    Metric.bodyFat,
    Metric.fatKg,
    Metric.leanKg,
    Metric.muscleKg,
    Metric.skinfoldSum,
    Metric.waist,
    Metric.hips,
    Metric.chest,
    Metric.thigh,
    Metric.calf,
    Metric.arm,
    Metric.bmr,
    Metric.targetKcal,
  ];

  Future<void> _edit(BuildContext context, WidgetRef ref, Measurement m) async {
    final edited = await MeasurementDialog.show(context, initial: m);
    if (edited != null) await ref.read(measurementsProvider.notifier).save(edited);
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, Measurement m) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить замер?'),
        content: Text('Замер за ${fmtDate(m.date)} будет удалён без возможности восстановления.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Отмена')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Удалить')),
        ],
      ),
    );
    if (ok == true) await ref.read(measurementsProvider.notifier).delete(m.id!);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    // показываем только столбцы, в которых есть данные
    final columns = [
      for (final c in _columns)
        if (measurements.any((m) => c.of(m) != null)) c,
    ];

    DataCell cell(int i, Metric metric) {
      final v = metric.of(measurements[i]);
      if (v == null) return const DataCell(Text('—'));
      final delta = metricDelta(measurements, i, metric);
      return DataCell(Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(fmt(v, metric.digits)),
          if (delta != null) Text(fmtDelta(delta, metric.digits), style: theme.textTheme.bodySmall),
        ],
      ));
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('История замеров', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              dataRowMinHeight: 52,
              dataRowMaxHeight: 60,
              columnSpacing: 24,
              columns: [
                const DataColumn(label: Text('Дата')),
                for (final c in columns) DataColumn(label: Text('${c.label}, ${c.unit}'), numeric: true),
                const DataColumn(label: Text('Заметка')),
                const DataColumn(label: Text('')),
              ],
              rows: [
                for (var i = measurements.length - 1; i >= 0; i--)
                  DataRow(cells: [
                    DataCell(Text(fmtDate(measurements[i].date))),
                    for (final c in columns) cell(i, c),
                    DataCell(ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 200),
                      child: Text(measurements[i].note ?? '', maxLines: 2, overflow: TextOverflow.ellipsis),
                    )),
                    DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                      IconButton(
                        tooltip: 'Изменить',
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () => _edit(context, ref, measurements[i]),
                      ),
                      IconButton(
                        tooltip: 'Удалить',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _delete(context, ref, measurements[i]),
                      ),
                    ])),
                  ]),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}
