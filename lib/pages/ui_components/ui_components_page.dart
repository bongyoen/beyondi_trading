import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../shared/constants/app_constants.dart';
import '../../shared/theme/app_theme.dart';
import '../../widgets/common/input_field.dart';

class UiComponentsPage extends StatelessWidget {
  const UiComponentsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      type: MaterialType.transparency,
      child: ListView(
      padding: const EdgeInsets.all(AppConstants.spacingLg),
      children: [
        Text('UI Components', style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text('공통 디자인 시스템', style: GoogleFonts.inter(fontSize: 13, color: cs.onSurfaceVariant)),
        const SizedBox(height: 20),

        _section(cs, 'Colors', [
          _colorRow(cs, 'Primary', cs.primary),
          _colorRow(cs, 'Secondary', cs.secondary),
          _colorRow(cs, 'Surface', cs.surface),
          _colorRow(cs, 'Error', cs.error),
          _colorRow(cs, 'Primary Container', cs.primaryContainer),
        ]),

        _section(cs, 'Typography', [
          Text('Poppins Heading 1', style: GoogleFonts.poppins(fontSize: 28, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('Poppins Heading 2', style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text('Inter Body', style: GoogleFonts.inter(fontSize: 14)),
          const SizedBox(height: 4),
          Text('Inter Small', style: GoogleFonts.inter(fontSize: 11, color: cs.onSurfaceVariant)),
        ]),

        _section(cs, 'Buttons', [
          Wrap(spacing: 8, runSpacing: 8, children: [
            FilledButton(onPressed: null, child: const Text('Disabled')),
            FilledButton(onPressed: () {}, child: const Text('Filled')),
            FilledButton.icon(onPressed: () {}, icon: const Icon(Icons.add, size: 16), label: const Text('With Icon')),
            OutlinedButton(onPressed: () {}, child: const Text('Outlined')),
            TextButton(onPressed: () {}, child: const Text('Text')),
          ]),
        ]),

        _section(cs, 'Cards', [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: cs.outline.withValues(alpha: 0.1)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(Icons.info_rounded, size: 16, color: cs.primary),
                const SizedBox(width: 6),
                Text('Card Title', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
              ]),
              const SizedBox(height: 8),
              Text('Standard card with title, used throughout the app.', style: GoogleFonts.inter(fontSize: 13)),
            ]),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: [cs.primaryContainer, cs.primary.withValues(alpha: 0.6)],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text('Gradient card', style: GoogleFonts.inter(fontSize: 13, color: cs.onPrimaryContainer)),
          ),
        ]),

        _section(cs, 'Input Fields', [
          const CommonInputField(label: 'Label', hint: 'Placeholder text'),
          const SizedBox(height: 8),
          const CommonInputField(label: 'With Error', hint: 'Error state', errorText: 'This field is required'),
        ]),

        _section(cs, 'Gradients', [
          Container(
            height: 48, width: double.infinity,
            decoration: BoxDecoration(gradient: AppTheme.loginGradient, borderRadius: BorderRadius.circular(8)),
            child: const Center(child: Text('Login Gradient', style: TextStyle(color: Colors.white))),
          ),
          const SizedBox(height: 8),
          Container(
            height: 48, width: double.infinity,
            decoration: BoxDecoration(gradient: AppTheme.buttonGradient, borderRadius: BorderRadius.circular(8)),
            child: const Center(child: Text('Button Gradient', style: TextStyle(color: Colors.white))),
          ),
        ]),

        _section(cs, 'Spacing', [
          Wrap(spacing: 8, runSpacing: 8, children: [
            _spacingBox('xxs', AppConstants.spacingXxs),
            _spacingBox('sm', AppConstants.spacingSm),
            _spacingBox('md', AppConstants.spacingMd),
            _spacingBox('lg', AppConstants.spacingLg),
            _spacingBox('xl', AppConstants.spacingXl),
          ]),
        ]),

        _section(cs, 'Radius', [
          Wrap(spacing: 8, runSpacing: 8, children: [
            _radiusBox('sm', AppConstants.radiusSm),
            _radiusBox('md', AppConstants.radiusMd),
            _radiusBox('lg', AppConstants.radiusLg),
            _radiusBox('xl', AppConstants.radiusXl),
            _radiusBox('full', AppConstants.radiusFull),
          ]),
        ]),
      ],
      ),
    );
  }

  Widget _section(ColorScheme cs, String title, List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: cs.primary)),
        const SizedBox(height: 8),
        ...children,
      ]),
    );
  }

  Widget _colorRow(ColorScheme cs, String label, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Container(width: 32, height: 32, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6), border: Border.all(color: cs.outline.withValues(alpha: 0.2)))),
        const SizedBox(width: 12),
        Text(label, style: GoogleFonts.inter(fontSize: 13)),
        const Spacer(),
        Text(color.toARGB32().toRadixString(16).padLeft(8, '0'), style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: Colors.grey)),
      ]),
    );
  }

  Widget _spacingBox(String label, double size) {
    return Column(children: [
      Container(width: size, height: size, color: Colors.blue.withValues(alpha: 0.3)),
      Text(label, style: GoogleFonts.inter(fontSize: 10)),
    ]);
  }

  Widget _radiusBox(String label, double radius) {
    return Column(children: [
      Container(width: 32, height: 32, decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(radius))),
      Text(label, style: GoogleFonts.inter(fontSize: 10)),
    ]);
  }
}
