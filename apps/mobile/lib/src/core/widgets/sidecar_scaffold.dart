import 'package:flutter/material.dart';
import 'package:sidecar/src/core/platform/app_haptics.dart';
import 'package:sidecar/src/theme/app_theme.dart';

class SideCarScaffold extends StatelessWidget {
  const SideCarScaffold({
    required this.child,
    super.key,
    this.bottom,
    this.showBack = false,
    this.onBack,
    this.padding = const EdgeInsets.fromLTRB(24, 16, 24, 24),
    this.resizeToAvoidBottomInset = true,
    this.fillViewport = false,
  });

  final Widget child;
  final Widget? bottom;
  final bool showBack;
  final VoidCallback? onBack;
  final EdgeInsets padding;
  final bool resizeToAvoidBottomInset;
  final bool fillViewport;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _SideCarHeaderScope(
                showBack: showBack,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return SingleChildScrollView(
                            keyboardDismissBehavior:
                                ScrollViewKeyboardDismissBehavior.onDrag,
                            padding: padding,
                            child: fillViewport
                                ? ConstrainedBox(
                                    constraints: BoxConstraints(
                                      minHeight:
                                          constraints.maxHeight -
                                          padding.vertical,
                                    ),
                                    child: IntrinsicHeight(child: child),
                                  )
                                : child,
                          );
                        },
                      ),
                    ),
                    if (showBack)
                      Positioned(
                        left: padding.left - 12,
                        top: 0,
                        child: IconButton(
                          tooltip: 'Back',
                          onPressed: AppHaptics.wrap(
                            onBack ?? () => Navigator.maybePop(context),
                          ),
                          icon: const Icon(
                            Icons.chevron_left_rounded,
                            size: 30,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (bottom != null)
              Padding(
                padding: EdgeInsets.fromLTRB(
                  padding.left,
                  12,
                  padding.right,
                  padding.bottom,
                ),
                child: bottom,
              ),
          ],
        ),
      ),
    );
  }
}

class ScreenIntro extends StatelessWidget {
  const ScreenIntro({
    required this.title,
    required this.description,
    super.key,
    this.centerTitle = false,
  });

  final String title;
  final String description;
  final bool centerTitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: centerTitle
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        if (_SideCarHeaderScope.of(context).showBack)
          const SizedBox(height: 46),
        Text(
          title,
          style: Theme.of(context).textTheme.headlineLarge,
          textAlign: centerTitle ? TextAlign.center : TextAlign.start,
        ),
        if (description.isNotEmpty) ...[
          const SizedBox(height: 9),
          Text(
            description,
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: centerTitle ? TextAlign.center : TextAlign.start,
          ),
        ],
      ],
    );
  }
}

class _SideCarHeaderScope extends InheritedWidget {
  const _SideCarHeaderScope({required this.showBack, required super.child});

  final bool showBack;

  static _SideCarHeaderScope of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<_SideCarHeaderScope>();
    return scope ??
        const _SideCarHeaderScope(showBack: false, child: SizedBox.shrink());
  }

  @override
  bool updateShouldNotify(_SideCarHeaderScope oldWidget) {
    return showBack != oldWidget.showBack;
  }
}

class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Text(text, style: Theme.of(context).textTheme.labelMedium),
    );
  }
}

class FormFieldBlock extends StatelessWidget {
  const FormFieldBlock({required this.label, required this.child, super.key});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [FieldLabel(label), child],
    );
  }
}

class SideCarInfoCard extends StatelessWidget {
  const SideCarInfoCard({
    required this.title,
    required this.message,
    super.key,
    this.icon = Icons.shield_outlined,
    this.color = AppColors.information,
  });

  final String title;
  final String message;
  final IconData? icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (icon != null) ...[
              Icon(icon!, size: 23, color: AppColors.ink),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 2),
                  Text(message, style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SideCarErrorText extends StatelessWidget {
  const SideCarErrorText(this.message, {super.key});

  final String? message;

  @override
  Widget build(BuildContext context) {
    if (message == null || message!.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Text(
        message!,
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: AppColors.danger),
      ),
    );
  }
}
