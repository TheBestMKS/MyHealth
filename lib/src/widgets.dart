import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'localization.dart';

InputDecoration localizedInputDecoration(
  BuildContext context,
  InputDecoration decoration,
) {
  String? phrase(String? value) =>
      value == null ? null : AppText.phrase(context, value);
  return decoration.copyWith(
    labelText: phrase(decoration.labelText),
    hintText: phrase(decoration.hintText),
    helperText: phrase(decoration.helperText),
    errorText: phrase(decoration.errorText),
    prefixText: phrase(decoration.prefixText),
    suffixText: phrase(decoration.suffixText),
    counterText: phrase(decoration.counterText),
    semanticCounterText: phrase(decoration.semanticCounterText),
  );
}

class LocalizedText extends StatelessWidget {
  const LocalizedText(
    this.data, {
    super.key,
    this.style,
    this.textAlign,
    this.softWrap,
    this.overflow,
    this.maxLines,
    this.semanticsLabel,
  });

  final String data;
  final TextStyle? style;
  final TextAlign? textAlign;
  final bool? softWrap;
  final TextOverflow? overflow;
  final int? maxLines;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    return Text(
      AppText.phrase(context, data),
      style: style,
      textAlign: textAlign,
      softWrap: softWrap,
      overflow: overflow,
      maxLines: maxLines,
      semanticsLabel: semanticsLabel == null
          ? null
          : AppText.phrase(context, semanticsLabel!),
    );
  }
}

class LocalizedTextField extends StatelessWidget {
  const LocalizedTextField({
    super.key,
    this.controller,
    this.decoration = const InputDecoration(),
    this.keyboardType,
    this.inputFormatters,
    this.maxLength,
    this.maxLines = 1,
    this.minLines,
    this.obscureText = false,
    this.readOnly = false,
    this.enabled,
    this.autofocus = false,
    this.onChanged,
    this.onSubmitted,
  });

  final TextEditingController? controller;
  final InputDecoration decoration;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final int? maxLength;
  final int? maxLines;
  final int? minLines;
  final bool obscureText;
  final bool readOnly;
  final bool? enabled;
  final bool autofocus;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      decoration: localizedInputDecoration(context, decoration),
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      maxLength: maxLength,
      maxLines: maxLines,
      minLines: minLines,
      obscureText: obscureText,
      readOnly: readOnly,
      enabled: enabled,
      autofocus: autofocus,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
    );
  }
}

class LocalizedDropdownButtonFormField<T> extends StatelessWidget {
  const LocalizedDropdownButtonFormField({
    super.key,
    required this.items,
    required this.onChanged,
    this.initialValue,
    this.decoration = const InputDecoration(),
    this.isExpanded = false,
  });

  final List<DropdownMenuItem<T>>? items;
  final ValueChanged<T?>? onChanged;
  final T? initialValue;
  final InputDecoration decoration;
  final bool isExpanded;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      initialValue: initialValue,
      items: items,
      onChanged: onChanged,
      decoration: localizedInputDecoration(context, decoration),
      isExpanded: isExpanded,
    );
  }
}

class LocalizedIconButton extends StatelessWidget {
  const LocalizedIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
  }) : _variant = _IconButtonVariant.standard;

  const LocalizedIconButton.filled({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
  }) : _variant = _IconButtonVariant.filled;

  const LocalizedIconButton.filledTonal({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
  }) : _variant = _IconButtonVariant.filledTonal;

  final Widget icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final _IconButtonVariant _variant;

  @override
  Widget build(BuildContext context) {
    final localizedTooltip = tooltip == null
        ? null
        : AppText.phrase(context, tooltip!);
    final arguments = (
      icon: icon,
      onPressed: onPressed,
      tooltip: localizedTooltip,
    );
    return switch (_variant) {
      _IconButtonVariant.standard => IconButton(
        icon: arguments.icon,
        onPressed: arguments.onPressed,
        tooltip: arguments.tooltip,
      ),
      _IconButtonVariant.filled => IconButton.filled(
        icon: arguments.icon,
        onPressed: arguments.onPressed,
        tooltip: arguments.tooltip,
      ),
      _IconButtonVariant.filledTonal => IconButton.filledTonal(
        icon: arguments.icon,
        onPressed: arguments.onPressed,
        tooltip: arguments.tooltip,
      ),
    };
  }
}

enum _IconButtonVariant { standard, filled, filledTonal }

class PageBand extends StatelessWidget {
  const PageBand({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    required this.children,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final localizedTitle = AppText.phrase(context, title);
    final localizedSubtitle = subtitle == null
        ? null
        : AppText.phrase(context, subtitle!);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 96),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(localizedTitle, style: textTheme.headlineMedium),
                  if (localizedSubtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(localizedSubtitle, style: textTheme.bodyMedium),
                  ],
                ],
              ),
            ),
            ?trailing,
          ],
        ),
        const SizedBox(height: 16),
        ...children,
      ],
    );
  }
}

class ResponsiveGrid extends StatelessWidget {
  const ResponsiveGrid({
    super.key,
    required this.children,
    this.minTileWidth = 210,
    this.spacing = 12,
  });

  final List<Widget> children;
  final double minTileWidth;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final count = (width / minTileWidth).floor().clamp(1, 4).toInt();
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final child in children)
              SizedBox(
                width: (width - (spacing * (count - 1))) / count,
                child: child,
              ),
          ],
        );
      },
    );
  }
}

class MetricCard extends StatelessWidget {
  const MetricCard({
    super.key,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.progress,
    this.onTap,
  });

  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;
  final double? progress;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final progressValue = progress?.clamp(0, 1).toDouble();
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Icon(icon, color: color),
                    ),
                  ),
                  const Spacer(),
                  if (progressValue != null)
                    Text(
                      '${(progressValue * 100).round()}%',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                AppText.phrase(context, title),
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                AppText.phrase(context, subtitle),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (progressValue != null) ...[
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: progressValue,
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(8),
                  backgroundColor: scheme.surfaceContainerHighest,
                  color: color,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class MedicalDisclaimerBanner extends StatelessWidget {
  const MedicalDisclaimerBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.errorContainer.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: scheme.error.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.medical_information_outlined, color: scheme.error),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              AppText.of(context, 'medicalDisclaimer'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class ActionRow extends StatelessWidget {
  const ActionRow({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Wrap(spacing: 8, runSpacing: 8, children: children);
  }
}

class InfoTile extends StatelessWidget {
  const InfoTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
    this.onLongPress,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: onTap,
        onLongPress: onLongPress,
        leading: Icon(icon),
        title: Text(AppText.phrase(context, title)),
        subtitle: Text(AppText.phrase(context, subtitle)),
        trailing: trailing,
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.action});

  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              AppText.phrase(context, text),
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          ?action,
        ],
      ),
    );
  }
}

class Pill extends StatelessWidget {
  const Pill({super.key, required this.label, this.icon, this.color});

  final String label;
  final IconData? icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final foreground = color ?? scheme.primary;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: foreground.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: foreground.withValues(alpha: 0.18)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: foreground),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: Text(
                AppText.phrase(context, label),
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.labelMedium?.copyWith(color: foreground),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
