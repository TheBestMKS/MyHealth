part of '../screens.dart';

class CalendarHubScreen extends StatefulWidget {
  const CalendarHubScreen({
    super.key,
    required this.state,
    required this.onChanged,
  });

  final HealthAppState state;
  final HealthStateChanged onChanged;

  @override
  State<CalendarHubScreen> createState() => _CalendarHubScreenState();
}

class _CalendarHubScreenState extends State<CalendarHubScreen> {
  String _mode = 'month';
  late DateTime _selected;

  @override
  void initState() {
    super.initState();
    _selected = parseDateKey(widget.state.today.date) ?? DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    return PageBand(
      title: AppText.get(widget.state.localeCode, 'calendar'),
      subtitle: 'Единый план работы, здоровья, сна, питания и поездок',
      trailing: LocalizedIconButton.filledTonal(
        tooltip: 'Добавить напоминание',
        onPressed: () => _editReminder(
          context,
          widget.state,
          widget.onChanged,
          null,
          todayKey(_selected),
        ),
        icon: const Icon(Icons.add_alert_outlined),
      ),
      children: [
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(
              value: 'day',
              label: Text('День'),
              icon: Icon(Icons.view_day_outlined),
            ),
            ButtonSegment(
              value: 'week',
              label: Text('Неделя'),
              icon: Icon(Icons.view_week_outlined),
            ),
            ButtonSegment(
              value: 'month',
              label: Text('Месяц'),
              icon: Icon(Icons.calendar_view_month_outlined),
            ),
          ],
          selected: {_mode},
          onSelectionChanged: (value) => setState(() => _mode = value.first),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            LocalizedIconButton(
              tooltip: 'Назад',
              onPressed: () => setState(() => _selected = _shiftPeriod(-1)),
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(
              child: Text(
                _periodTitle(),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            LocalizedIconButton(
              tooltip: 'Сегодня',
              onPressed: () => setState(() => _selected = DateTime.now()),
              icon: const Icon(Icons.today_outlined),
            ),
            LocalizedIconButton(
              tooltip: 'Вперёд',
              onPressed: () => setState(() => _selected = _shiftPeriod(1)),
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_mode == 'month') _monthView(context),
        if (_mode == 'week') _weekView(context),
        if (_mode == 'day') _dayView(context, _selected),
      ],
    );
  }

  DateTime _shiftPeriod(int direction) {
    return switch (_mode) {
      'day' => _selected.add(Duration(days: direction)),
      'week' => _selected.add(Duration(days: direction * 7)),
      _ => DateTime(_selected.year, _selected.month + direction, 1),
    };
  }

  String _periodTitle() {
    if (_mode == 'day') return displayDateKey(todayKey(_selected));
    if (_mode == 'week') {
      final start = _weekStart(_selected);
      final end = start.add(const Duration(days: 6));
      return '${displayDateKey(todayKey(start))}-${displayDateKey(todayKey(end))}';
    }
    const months = [
      'январь',
      'февраль',
      'март',
      'апрель',
      'май',
      'июнь',
      'июль',
      'август',
      'сентябрь',
      'октябрь',
      'ноябрь',
      'декабрь',
    ];
    return '${months[_selected.month - 1]} ${_selected.year}';
  }

  Widget _monthView(BuildContext context) {
    final first = DateTime(_selected.year, _selected.month, 1);
    final days = DateTime(_selected.year, _selected.month + 1, 0).day;
    final leading = first.weekday - 1;
    final cells = leading + days;
    return Column(
      children: [
        Row(
          children: [
            for (final value in ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'])
              Expanded(child: Center(child: Text(value))),
          ],
        ),
        const SizedBox(height: 4),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            childAspectRatio: 1.15,
            crossAxisSpacing: 4,
            mainAxisSpacing: 4,
          ),
          itemCount: ((cells + 6) ~/ 7) * 7,
          itemBuilder: (context, index) {
            final day = index - leading + 1;
            if (day < 1 || day > days) return const SizedBox.shrink();
            final date = DateTime(_selected.year, _selected.month, day);
            final events = _calendarEventsForDate(widget.state, date);
            final selected = _sameDate(date, _selected);
            final today = _sameDate(date, DateTime.now());
            return InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: () => setState(() {
                _selected = date;
                _mode = 'day';
              }),
              child: Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: selected
                      ? Theme.of(context).colorScheme.secondaryContainer
                      : null,
                  border: Border.all(
                    color: today
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.outlineVariant,
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$day'),
                    const Spacer(),
                    if (events.isNotEmpty)
                      Row(
                        children: [
                          Icon(events.first.icon, size: 14),
                          const SizedBox(width: 2),
                          Text('${events.length}'),
                        ],
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _weekView(BuildContext context) {
    final start = _weekStart(_selected);
    return Column(
      children: List.generate(7, (index) {
        final date = start.add(Duration(days: index));
        final events = _calendarEventsForDate(widget.state, date);
        return ListTile(
          leading: CircleAvatar(child: Text('${date.day}')),
          title: Text(_weekdayName(date.weekday)),
          subtitle: Text(
            events.isEmpty
                ? 'Событий нет'
                : events.take(3).map((item) => item.title).join(' · '),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: events.isEmpty ? null : Pill(label: '${events.length}'),
          onTap: () => setState(() {
            _selected = date;
            _mode = 'day';
          }),
        );
      }),
    );
  }

  Widget _dayView(BuildContext context, DateTime date) {
    final events = _calendarEventsForDate(widget.state, date);
    final key = todayKey(date);
    return Column(
      children: [
        if (events.isEmpty)
          const InfoTile(
            icon: Icons.event_available_outlined,
            title: 'Свободный день',
            subtitle: 'Нет запланированных событий и сохранённых записей.',
          ),
        ...events.map(
          (event) => InfoTile(
            icon: event.icon,
            title: event.time.isEmpty
                ? event.title
                : '${event.time} · ${event.title}',
            subtitle: event.subtitle,
          ),
        ),
        const SizedBox(height: 10),
        ActionRow(
          children: [
            FilledButton.tonalIcon(
              onPressed: () => _editReminder(
                context,
                widget.state,
                widget.onChanged,
                null,
                key,
              ),
              icon: const Icon(Icons.add_alert_outlined),
              label: const Text('Напоминание'),
            ),
            OutlinedButton.icon(
              onPressed: () =>
                  _addWorkout(context, widget.state, widget.onChanged),
              icon: const Icon(Icons.fitness_center_outlined),
              label: const Text('Тренировка'),
            ),
          ],
        ),
      ],
    );
  }
}

class _CalendarEvent {
  const _CalendarEvent({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.time = '',
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final String time;
}

List<_CalendarEvent> _calendarEventsForDate(
  HealthAppState state,
  DateTime date,
) {
  final key = todayKey(date);
  final events = <_CalendarEvent>[
    ...state.reminders
        .where((item) => item.date == key)
        .map(
          (item) => _CalendarEvent(
            title: item.title,
            subtitle: '${item.category}${item.done ? ' · выполнено' : ''}',
            icon: Icons.notifications_outlined,
            time: item.time,
          ),
        ),
    ...state.workouts
        .where((item) => item.scheduledDate == key)
        .map(
          (item) => _CalendarEvent(
            title: item.title,
            subtitle:
                '${item.minutes} мин · ${item.intensity} · ${item.status}',
            icon: Icons.fitness_center_outlined,
          ),
        ),
    ...state.meals
        .where((item) => _itemDate(item.date, state) == key)
        .map(
          (item) => _CalendarEvent(
            title: item.title,
            subtitle: '${item.kind} · ${item.calories} ккал',
            icon: Icons.restaurant_outlined,
            time: item.time,
          ),
        ),
    ...state.sleepRecords
        .where((item) => item.date == key)
        .map(
          (item) => _CalendarEvent(
            title: 'Сон ${item.durationHours.toStringAsFixed(1)} ч',
            subtitle:
                'Качество ${item.quality}/5 · пробуждений ${item.awakenings}',
            icon: Icons.bedtime_outlined,
            time: item.wakeTime,
          ),
        ),
    ...state.medicationIntakes
        .where((item) => item.date == key)
        .map(
          (item) => _CalendarEvent(
            title: item.medicationName,
            subtitle: '${item.dose} · ${item.status}',
            icon: Icons.medication_outlined,
            time: item.time,
          ),
        ),
    ...state.labResults
        .where((item) => item.date == key)
        .map(
          (item) => _CalendarEvent(
            title: item.marker,
            subtitle: '${item.value} ${item.unit}',
            icon: Icons.science_outlined,
          ),
        ),
    ...state.symptomEntries
        .where((item) => item.date == key)
        .map(
          (item) => _CalendarEvent(
            title: item.symptom,
            subtitle: 'Интенсивность ${item.intensity}/10',
            icon: Icons.monitor_heart_outlined,
            time: item.time,
          ),
        ),
  ];
  for (final duty in state.workSchedule.duties.where(
    (item) => item.date == key,
  )) {
    events.add(
      _CalendarEvent(
        title: 'Дежурство',
        subtitle: '${duty.startTime}-${duty.endTime} · ${duty.notes}',
        icon: Icons.work_history_outlined,
        time: duty.arrivalTime,
      ),
    );
  }
  for (final trip in state.trips) {
    if (_dateInRange(key, trip.startDate, trip.endDate)) {
      events.add(
        _CalendarEvent(
          title: trip.title,
          subtitle: '${trip.city} · ${trip.adjustment}',
          icon: Icons.business_center_outlined,
        ),
      );
    }
  }
  for (final vacation in state.workSchedule.vacations) {
    if (_dateInRange(key, vacation.startDate, vacation.endDate)) {
      events.add(
        _CalendarEvent(
          title: vacation.title,
          subtitle: '${vacation.country}, ${vacation.city}',
          icon: Icons.beach_access_outlined,
        ),
      );
    }
  }
  events.sort((a, b) => a.time.compareTo(b.time));
  return events;
}

bool _dateInRange(String key, String start, String end) =>
    key.compareTo(start) >= 0 && key.compareTo(end) <= 0;

DateTime _weekStart(DateTime value) => DateTime(
  value.year,
  value.month,
  value.day,
).subtract(Duration(days: value.weekday - 1));

bool _sameDate(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String _weekdayName(int weekday) => const [
  'Понедельник',
  'Вторник',
  'Среда',
  'Четверг',
  'Пятница',
  'Суббота',
  'Воскресенье',
][weekday - 1];
