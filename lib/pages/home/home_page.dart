import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../features/counter/presentation/widgets/counter_widget.dart';
import '../../shared/constants/app_constants.dart';

/// Main dashboard page displayed within the app shell.
///
/// Features a welcome card header and the existing counter widget
/// for demo purposes, wrapped in a clean content layout.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListView(
      children: [
        // ── Welcome Header ──
        _buildWelcomeCard(context, colorScheme),
        const SizedBox(height: AppConstants.spacingLg),

        // ── Quick Stats Row ──
        _buildStatsRow(context, colorScheme),
        const SizedBox(height: AppConstants.spacingLg),

        // ── Counter Demo ──
        _buildSectionCard(
          context,
          colorScheme,
          title: 'Interactive Demo',
          icon: Icons.touch_app_rounded,
          child: const SizedBox(
            height: 200,
            child: CounterWidget(),
          ),
        ),
      ],
    );
  }

  Widget _buildWelcomeCard(BuildContext context, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(AppConstants.spacingLg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.primaryContainer,
            colorScheme.primary.withValues(alpha: 0.6),
          ],
        ),
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withValues(alpha: 0.2),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Welcome back, Trader',
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: AppConstants.spacingXs),
          Text(
            'Here\'s your market overview for today.',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: colorScheme.onPrimaryContainer.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(BuildContext context, ColorScheme colorScheme) {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            context,
            colorScheme,
            label: 'Portfolio Value',
            value: '\$12,450',
            icon: Icons.account_balance_wallet_rounded,
            trend: '+2.4%',
            isPositive: true,
          ),
        ),
        const SizedBox(width: AppConstants.spacingMd),
        Expanded(
          child: _buildStatCard(
            context,
            colorScheme,
            label: 'Today\'s P&L',
            value: '+\$325',
            icon: Icons.trending_up_rounded,
            trend: '+1.8%',
            isPositive: true,
          ),
        ),
        const SizedBox(width: AppConstants.spacingMd),
        Expanded(
          child: _buildStatCard(
            context,
            colorScheme,
            label: 'Open Positions',
            value: '7',
            icon: Icons.swap_horiz_rounded,
            trend: '2 new',
            isPositive: null,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    ColorScheme colorScheme, {
    required String label,
    required String value,
    required IconData icon,
    required String trend,
    required bool? isPositive,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppConstants.spacingMd),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        border: Border.all(
          color: colorScheme.outline.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: colorScheme.onSurfaceVariant),
              const Spacer(),
              if (isPositive != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: isPositive
                        ? Colors.green.withValues(alpha: 0.1)
                        : Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    trend,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: isPositive ? Colors.green : Colors.red,
                    ),
                  ),
                )
              else
                Text(
                  trend,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppConstants.spacingXs),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard(
    BuildContext context,
    ColorScheme colorScheme, {
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
        border: Border.all(
          color: colorScheme.outline.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppConstants.spacingMd,
              AppConstants.spacingMd,
              AppConstants.spacingMd,
              0,
            ),
            child: Row(
              children: [
                Icon(icon, size: 20, color: colorScheme.primary),
                const SizedBox(width: AppConstants.spacingXs),
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppConstants.spacingSm),
            child: child,
          ),
        ],
      ),
    );
  }
}
