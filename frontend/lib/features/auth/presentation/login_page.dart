import 'package:flutter/material.dart';

import '../../../shared/theme/design_tokens.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../presentation/router/app_router.dart';
import '../domain/auth_models.dart';
import 'app_scope.dart';
import 'auth_layout.dart';
import 'auth_state.dart';

/// Sign-in screen.
///
/// Public-only route: [AuthGuard] sends authenticated callers straight into
/// the app. On a successful login the guard NAVIGATES to the caller's intended
/// destination — this page only drives the [AuthState] and presents its
/// result (spinner + friendly errors).
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _password = TextEditingController();

  bool _obscurePassword = true;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit(AuthState auth) async {
    if (_formKey.currentState?.validate() != true) return;
    if (auth.status == AuthStatus.refreshing) return;

    FocusScope.of(context).unfocus();
    await auth.login(username: _username.text.trim(), password: _password.text);
    // Navigation is owned by AuthGuard once the session becomes
    // authenticated — nothing to do here on success or failure.
  }

  @override
  Widget build(BuildContext context) {
    return AuthPageLayout(
      title: 'Welcome back',
      subtitle: 'Sign in to your workspace.',
      children: [_buildForm(context)],
    );
  }

  Widget _buildForm(BuildContext context) {
    return ListenableBuilder(
      // Rebuilds this form on every auth-state change (session resolution,
      // login attempt, refresh, logout) with zero extra dependencies.
      listenable: AppScope.authOf(context),
      builder: (context, _) {
        final auth = AppScope.authOf(context);
        final loading = auth.status == AuthStatus.refreshing;
        final error = auth.lastError;

        return AppCard(
          variant: AppCardVariant.elevated,
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AuthFormField(
                  controller: _username,
                  label: 'Username or email',
                  hintText: 'you@example.com',
                  prefixIcon: Icons.person_outline_rounded,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  enabled: !loading,
                  autofillHints: const [AutofillHints.username],
                  validator: (value) => (value?.trim().isEmpty ?? true)
                      ? 'Enter your username or email.'
                      : null,
                  onFieldSubmitted: (_) => _submit(auth),
                ),
                const SizedBox(height: AppSpacing.md),
                AuthFormField(
                  controller: _password,
                  label: 'Password',
                  prefixIcon: Icons.lock_outline_rounded,
                  obscureText: _obscurePassword,
                  enabled: !loading,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.password],
                  validator: (value) => (value == null || value.isEmpty)
                      ? 'Enter your password.'
                      : null,
                  suffix: IconButton(
                    tooltip: _obscurePassword
                        ? 'Show password'
                        : 'Hide password',
                    onPressed: loading
                        ? null
                        : () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                  onFieldSubmitted: (_) => _submit(auth),
                ),
                if (error != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  AuthErrorBanner(message: error),
                ],
                const SizedBox(height: AppSpacing.lg),
                AppButton(
                  label: 'Sign in',
                  expanded: true,
                  loading: loading,
                  onPressed: loading ? null : () => _submit(auth),
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: AppSpacing.xs,
                  children: [
                    const Text('New to the app?'),
                    TextButton(
                      onPressed: loading
                          ? null
                          : () {
                              Navigator.of(context)
                                  .pushReplacementNamed(AppRouter.register);
                            },
                      child: const Text('Create an account'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
