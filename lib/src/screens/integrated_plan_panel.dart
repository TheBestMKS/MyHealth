part of '../screens.dart';

class IntegratedPlanPanel extends StatelessWidget {
  const IntegratedPlanPanel({
    super.key,
    required this.state,
    required this.onSelect,
  });

  final HealthAppState state;
  final SectionSelected onSelect;

  @override
  Widget build(BuildContext context) {
    final plan = buildIntegratedHealthPlan(state);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(
          'Связанный план дня',
          action: LocalizedIconButton.filledTonal(
            tooltip: 'Обсудить план с помощником',
            onPressed: () => onSelect(AppSection.assistant),
            icon: const Icon(Icons.psychology_outlined),
          ),
        ),
        InfoTile(
          icon: plan.hasUrgent ? Icons.emergency_outlined : Icons.hub_outlined,
          title: plan.summary,
          subtitle:
              'План связывает симптомы, анализы, лекарства, питание, сон, работу, поездки и нагрузку.',
        ),
        ...plan.recommendations
            .take(7)
            .map(
              (item) => InfoTile(
                icon: switch (item.severity) {
                  PlanSeverity.urgent => Icons.emergency_outlined,
                  PlanSeverity.attention => Icons.warning_amber_outlined,
                  PlanSeverity.info => Icons.checklist_outlined,
                },
                title: item.title,
                subtitle: item.detail,
                onTap: () => onSelect(_assistantSection(item.section)),
                trailing: item.severity == PlanSeverity.info
                    ? null
                    : Pill(
                        label: item.severity == PlanSeverity.urgent
                            ? 'срочно'
                            : 'проверить',
                        icon: item.severity == PlanSeverity.urgent
                            ? Icons.priority_high
                            : Icons.fact_check_outlined,
                      ),
              ),
            ),
      ],
    );
  }
}
