import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../shared/constants/app_constants.dart';

class BacktestPage extends StatelessWidget {
  const BacktestPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.science_rounded, size: 64,
              color: Colors.grey.withValues(alpha: 0.3)),
          const SizedBox(height: AppConstants.spacingMd),
          Text('백테스트', style: GoogleFonts.poppins(
              fontSize: 24, fontWeight: FontWeight.w600,
              color: Colors.grey.withValues(alpha: 0.5))),
          const SizedBox(height: AppConstants.spacingXs),
          Text('준비 중', style: GoogleFonts.inter(
              fontSize: 14, color: Colors.grey.withValues(alpha: 0.4))),
        ],
      ),
    );
  }
}
