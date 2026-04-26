import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../shared/constants/app_constants.dart';
import '../../../../shared/theme/app_theme.dart';
import '../bloc/login_bloc.dart';
import '../bloc/login_event.dart';
import '../bloc/login_state.dart';

/// Login page with a visually striking design.
///
/// Features a full-screen gradient background, a frosted-glass card,
/// ID/Password form fields with validation, and a bold login button.
///
/// Follows the 5 Pillars:
/// - Typography: Poppins headings, Inter body
/// - Color: Bold navy-to-purple gradient with amber accents
/// - Motion: Subtle entrance animation and button press
/// - Space: Generous vertical rhythm, intentional card sizing
/// - Depth: Gradient background, glass morphism card, layered shadows
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _idController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  late final AnimationController _animController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _idController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: AppTheme.loginGradient,
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppConstants.spacingMd,
                vertical: AppConstants.spacingXl,
              ),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: AppConstants.loginCardMaxWidth,
                      minWidth: AppConstants.loginCardMinWidth,
                    ),
                    child: _buildLoginCard(context),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginCard(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(AppConstants.spacingXl),
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(AppConstants.radiusXl),
        border: Border.all(
          color: colorScheme.outline.withValues(alpha: 0.15),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 40,
            offset: const Offset(0, 16),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(context),
          const SizedBox(height: AppConstants.spacingXl),
          _buildForm(context),
          const SizedBox(height: AppConstants.spacingLg),
          _buildLoginButton(context),
          const SizedBox(height: AppConstants.spacingMd),
          _buildHelperText(context),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      children: [
        // Logo / Brand icon
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            gradient: AppTheme.buttonGradient,
            borderRadius: BorderRadius.circular(AppConstants.radiusLg),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFB8860B).withValues(alpha: 0.4),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(
            Icons.trending_up_rounded,
            color: Colors.white,
            size: 32,
          ),
        ),
        const SizedBox(height: AppConstants.spacingMd),
        Text(
          'Beyondi Trading',
          style: GoogleFonts.poppins(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurface,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: AppConstants.spacingXs),
        Text(
          'Sign in to your account',
          style: GoogleFonts.inter(
            fontSize: 14,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildForm(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ID Field
          TextFormField(
            controller: _idController,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'User ID',
              hintText: 'Enter your user ID',
              prefixIcon: Icon(Icons.person_outline_rounded),
            ),
            style: GoogleFonts.inter(
              fontSize: 15,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter your user ID';
              }
              return null;
            },
            onChanged: (_) {
              // Reset error state when user starts typing
              context.read<LoginBloc>().add(const LoginReset());
            },
          ),
          const SizedBox(height: AppConstants.spacingMd),

          // Password Field
          TextFormField(
            controller: _passwordController,
            textInputAction: TextInputAction.done,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              labelText: 'Password',
              hintText: 'Enter your password',
              prefixIcon: const Icon(Icons.lock_outline_rounded),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
                onPressed: () {
                  setState(() => _obscurePassword = !_obscurePassword);
                },
              ),
            ),
            style: GoogleFonts.inter(
              fontSize: 15,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter your password';
              }
              return null;
            },
            onFieldSubmitted: (_) => _submitLogin(),
            onChanged: (_) {
              context.read<LoginBloc>().add(const LoginReset());
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLoginButton(BuildContext context) {
    return BlocConsumer<LoginBloc, LoginState>(
      listener: (context, state) {
        // Error feedback is shown via the state — no extra snackbar needed
      },
      builder: (context, state) {
        final bool isLoading = state is LoginLoading;

        return SizedBox(
          height: 52,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppConstants.radiusMd),
              gradient: AppTheme.buttonGradient,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFB8860B).withValues(alpha: 0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: isLoading ? null : _submitLogin,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.white,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                ),
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : Row(
                        key: const ValueKey('login-text'),
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Sign In',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: AppConstants.spacingSm),
                          const Icon(Icons.arrow_forward_rounded, size: 20),
                        ],
                      ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHelperText(BuildContext context) {
    return BlocBuilder<LoginBloc, LoginState>(
      builder: (context, state) {
        // Show error message if login failed
        if (state is LoginFailure) {
          return Container(
            padding: const EdgeInsets.all(AppConstants.spacingSm),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.error.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppConstants.radiusSm),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  size: 18,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(width: AppConstants.spacingXs),
                Expanded(
                  child: Text(
                    state.message,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.error,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        // Demo hint
        return Text(
          'Demo: any ID and password works',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontStyle: FontStyle.italic,
          ),
        );
      },
    );
  }

  void _submitLogin() {
    // Early Exit: validate form before dispatching
    if (!_formKey.currentState!.validate()) return;

    context.read<LoginBloc>().add(
      LoginSubmitted(
        id: _idController.text.trim(),
        password: _passwordController.text,
      ),
    );
  }
}
