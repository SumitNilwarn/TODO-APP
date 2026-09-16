import 'package:flutter/material.dart';

import '../../../presentation/router/app_router.dart';
import '../../../shared/theme/design_tokens.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../domain/auth_models.dart';
import '../domain/auth_validators.dart';
import 'app_scope.dart';
import 'auth_layout.dart';
import 'auth_state.dart';

/// Create-account screen.
///
/// Public-only route. Collects the four credentials fields with client-side
/// validation that mirrors the backend contract; on success the user is
/// returned to the sign-in flow. Field-level backend errors (e.g.
/// USERNAME_ALREADY_TAKEN) surface through the [AuthErrorBanner].
class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _username.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit(AuthState auth) async {
    if (_formKey.currentState?.validate() != true) return;
    if (auth.status == AuthStatus.refreshing) return;

    FocusScope.of(context).unfocus();
    final created = await auth.register(
      username: _username.text.trim(),
      email: _email.text.trim(),
      password: _password.text,
    );

    if (created && mounted) {
      AppSnackbar.show(
        context,
        'Account created. Sign in to continue.',
        variant: AppFeedbackVariant.success,
      );
      Navigator.of(context)
          .pushNamedAndRemoveUntil(AppRouter.login, (route) => false);
    }
    // On failure the error banner renders `auth.lastError` below.
  }

  @override
  Widget build(BuildContext context) {
    return AuthPageLayout(
      title: 'Create your account',
      subtitle: 'It takes less than a minute — sign in right after.',
      children: [_buildForm(context)],
    );
  }

  Widget _buildForm(BuildContext context) {
    return ListenableBuilder(
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
                  label: 'Username',
                  hintText: 'Choose a unique username',
                  prefixIcon: Icons.person_outline_rounded,
                  textInputAction: TextInputAction.next,
                  enabled: !loading,
                  autofillHints: const [AutofillHints.newUsername],
                  validator: validateUsername,
                ),
                const SizedBox(height: AppSpacing.md),
                AuthFormField(
                  controller: _email,
                  label: 'Email',
                  hintText: 'you@example.com',
                  prefixIcon: Icons.alternate_email_rounded,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  enabled: !loading,
                  autofillHints: const [AutofillHints.email],
                  validator: validateEmail,
                ),
                const SizedBox(height: AppSpacing.md),
                AuthFormField(
                  controller: _password,
                  label: 'Password',
                  helperText: '10–100 characters, letters and numbers.',
                  prefixIcon: Icons.lock_outline_rounded,
                  obscureText: _obscurePassword,
                  enabled: !loading,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.newPassword],
                  validator: validatePassword,
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
                ),
                const SizedBox(height: AppSpacing.md),
                AuthFormField(
                  controller: _confirm,
                  label: 'Confirm password',
                  prefixIcon: Icons.lock_outline_rounded,
                  obscureText: _obscureConfirm,
                  enabled: !loading,
                  textInputAction: TextInputAction.done,
                  validator: (value) =>
                      validatePasswordConfirmation(value, _password.text),
                  onFieldSubmitted: (_) => _submit(auth),
                  suffix: IconButton(
                    tooltip: _obscureConfirm
                        ? 'Show password'
                        : 'Hide password',
                    onPressed: loading
                        ? null
                        : () => setState(
                            () => _obscureConfirm = !_obscureConfirm,
                          ),
                    icon: Icon(
                      _obscureConfirm
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
                if (error != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  AuthErrorBanner(message: error),
                ],
                const SizedBox(height: AppSpacing.lg),
                AppButton(
                  label: 'Create account',
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
                    const Text('Already have an account?'),
                    TextButton(
                      onPressed: loading
                          ? null
                          : () {
                              Navigator.of(context)
                                  .pushReplacementNamed(AppRouter.login);
                            },
                      child: const Text('Sign in'),
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
