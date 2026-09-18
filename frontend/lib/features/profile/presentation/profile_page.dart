import 'package:flutter/material.dart';

import '../../../data/api/api_exception.dart';
import '../../../shared/theme/design_tokens.dart';
import '../../../shared/theme/theme_extensions.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../../../shared/widgets/app_error_state.dart';
import '../../../shared/widgets/app_loading.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../shared/widgets/responsive_container.dart';
import '../../auth/presentation/app_scope.dart';
import '../../auth/presentation/authenticated_scaffold.dart';
import '../data/profile_api.dart';
import '../domain/profile_models.dart';
import '../domain/profile_validators.dart';
import '../domain/timezone_catalog.dart';

/// Profile screen: reads the caller's profile, lets them create it on first
/// visit (PUT) and update it afterwards (PATCH with only changed fields).
///
/// Always driven through the authenticated [ApiClient] from [AppScope]
/// (bearer header + automatic session refresh); ownership comes from the
/// backend principal, never from the client.
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _displayName = TextEditingController();
  final _timezone = TextEditingController();
  final _imageUrl = TextEditingController();

  late final ProfileApi _api;
  bool _bootstrapped = false;

  List<String> _timezones = const [];
  Map<String, String?> _originals = const {};

  bool _loading = true;
  bool _creating = false;
  bool _saving = false;
  String? _loadError;

  bool _timezonesReady = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The authenticated client lives on AppScope, so grab it here (the first
    // build that has the dependency available) rather than in initState.
    if (!_bootstrapped) {
      _bootstrapped = true;
      _api = ProfileApi(AppScope.apiOf(context));
      _bootstrap();
    }
  }

  Future<void> _bootstrap() async {
    _timezones = await loadTimezoneCandidates();
    if (mounted) {
      setState(() => _timezonesReady = true);
    }
    await _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final profile = await _api.getProfile();
      if (!mounted) return;
      _applyProfile(profile);
      setState(() {
        _loading = false;
        _creating = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      if (error.code == 'PROFILE_NOT_FOUND') {
        setState(() {
          _loading = false;
          _creating = true;
          _originals = const {};
        });
      } else {
        setState(() {
          _loading = false;
          _loadError = _friendlyLoadError(error);
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = 'Could not load your profile. Please try again.';
      });
    }
  }

  void _applyProfile(ProfileResponse profile) {
    _originals = {
      'firstName': profile.firstName,
      'lastName': profile.lastName,
      'displayName': profile.displayName,
      'timezone': profile.timezone,
      'profileImageUrl': profile.profileImageUrl,
    };
    _firstName.text = profile.firstName ?? '';
    _lastName.text = profile.lastName ?? '';
    _displayName.text = profile.displayName ?? '';
    _timezone.text = profile.timezone ?? '';
    _imageUrl.text = profile.profileImageUrl ?? '';
  }

  void _resetForm() {
    _firstName.text = _originals['firstName'] ?? '';
    _lastName.text = _originals['lastName'] ?? '';
    _displayName.text = _originals['displayName'] ?? '';
    _timezone.text = _originals['timezone'] ?? '';
    _imageUrl.text = _originals['profileImageUrl'] ?? '';
    setState(() {});
  }

  bool get _hasUnsavedChanges {
    return {
          'firstName': normalizeProfileValue(_firstName.text),
          'lastName': normalizeProfileValue(_lastName.text),
          'displayName': normalizeProfileValue(_displayName.text),
          'timezone': normalizeTimezoneInput(_timezone.text),
          'profileImageUrl': normalizeProfileValue(_imageUrl.text),
        } !=
        _originals;
  }

  Map<String, String?> _currentValues() {
    return {
      'firstName': normalizeProfileValue(_firstName.text),
      'lastName': normalizeProfileValue(_lastName.text),
      'displayName': normalizeProfileValue(_displayName.text),
      'timezone': normalizeTimezoneInput(_timezone.text),
      'profileImageUrl': normalizeProfileValue(_imageUrl.text),
    };
  }

  Future<void> _save() async {
    if (_formKey.currentState?.validate() != true) return;
    if (_saving) return;

    final values = _currentValues();

    setState(() => _saving = true);
    try {
      final ProfileResponse updated;
      if (_creating) {
        // First save: PUT replaces/creates the whole profile.
        updated = await _api.updateProfile(
          ProfileUpdateRequest(
            firstName: values['firstName'],
            lastName: values['lastName'],
            displayName: values['displayName'],
            timezone: values['timezone'],
            profileImageUrl: values['profileImageUrl'],
          ),
        );
      } else {
        // Subsequent saves: PATCH only the changed fields (strings set,
        // `null` clears, untouched fields are omitted).
        final changes = <String, String?>{};
        for (final name in ProfileUpdateRequest.fieldNames) {
          final original = _originals[name];
          final current = values[name];
          if (current != original) {
            changes[name] = current;
          }
        }
        if (changes.isEmpty) {
          if (mounted) {
            setState(() => _saving = false);
            AppSnackbar.show(
              context,
              'No changes to save.',
              variant: AppFeedbackVariant.info,
            );
          }
          return;
        }
        updated = await _api.patchProfile(ProfilePatchRequest(changes));
      }

      if (!mounted) return;
      final wasCreating = _creating;
      _applyProfile(updated);
      setState(() {
        _saving = false;
        // The profile now exists, so the next save is an edit (PATCH).
        _creating = false;
      });
      AppSnackbar.show(
        context,
        wasCreating ? 'Profile created.' : 'Profile saved.',
        variant: AppFeedbackVariant.success,
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      AppSnackbar.show(
        context,
        _friendlySaveError(error),
        variant: AppFeedbackVariant.danger,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      AppSnackbar.show(
        context,
        'Profile could not be saved. Please try again.',
        variant: AppFeedbackVariant.danger,
      );
    }
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _displayName.dispose();
    _timezone.dispose();
    _imageUrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AuthenticatedScaffold(
      selectedIndex: 2,
      kicker: 'Identity',
      title: 'Profile',
      subtitle: _creating
          ? 'Tell us a little about yourself.'
          : 'Your profile powers personalisation across the app.',
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return const AppLoading(label: 'Loading your profile…');
    }
    if (_loadError != null) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.giant),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: AppErrorState(
              title: 'Could not load your profile',
              message: _loadError,
              onRetry: _load,
            ),
          ),
        ),
      );
    }

    return ResponsiveContainer(
      maxWidth: 720,
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: AppSpacing.xl),
        child: _creating ? _buildCreateView() : _buildEditor(),
      ),
    );
  }

  Widget _buildCreateView() {
    return AppCard(
      variant: AppCardVariant.elevated,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppEmptyState(
            icon: Icons.person_add_alt_1_rounded,
            title: 'Create your profile',
            message:
                'You have not created a profile yet. Add your details below — '
                'you can change them any time.',
          ),
          const SizedBox(height: AppSpacing.lg),
          _buildForm(context, editing: false),
          const SizedBox(height: AppSpacing.lg),
          _buildActions(),
        ],
      ),
    );
  }

  Widget _buildEditor() {
    return AppCard(
      variant: AppCardVariant.elevated,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildIdentity(context),
          const Divider(height: AppSpacing.xl + AppSpacing.xs),
          _buildForm(context, editing: true),
          const SizedBox(height: AppSpacing.lg),
          _buildActions(),
        ],
      ),
    );
  }

  /// Identity header strip: monogram, display name and current time zone.
  Widget _buildIdentity(BuildContext context) {
    final tokens = context.appColors;
    final textTheme = Theme.of(context).textTheme;
    final auth = AppScope.authOf(context);
    final name = _displayName.text.trim().isNotEmpty
        ? _displayName.text.trim()
        : (auth.username ?? 'Member');
    final initial = name.characters.first.toUpperCase();
    final timezone = _timezone.text.trim();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 52,
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: tokens.primary,
            borderRadius: AppRadius.mdAll,
          ),
          child: Text(
            initial,
            style: textTheme.titleLarge?.copyWith(color: tokens.onPrimary),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: textTheme.titleMedium),
              const SizedBox(height: AppSpacing.xs),
              Text(
                timezone.isNotEmpty ? timezone : 'No time zone set',
                style: textTheme.bodySmall?.copyWith(color: tokens.textMuted),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActions() {
    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.md,
      alignment: WrapAlignment.end,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (!_creating && _hasUnsavedChanges)
          AppButton(
            label: 'Reset',
            variant: AppButtonVariant.outlined,
            onPressed: _saving ? null : _resetForm,
          ),
        AppButton(
          label: 'Save profile',
          icon: Icons.save_outlined,
          loading: _saving,
          onPressed: _saving ? null : _save,
        ),
      ],
    );
  }

  Widget _buildForm(BuildContext context, {required bool editing}) {
    final empty = editing
        ? null
        : 'This can be left empty.'; // Helpful copy on the create flow.
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SectionLabel(label: 'Identity'),
          const SizedBox(height: AppSpacing.sm),
          LayoutBuilder(
            builder: (context, constraints) {
              final firstName = _TextField(
                controller: _firstName,
                label: 'First name',
                hintText: 'Ada',
                helperText: empty,
                validator: (value) =>
                    validateNameField(value, label: 'First name', max: 50),
              );
              final lastName = _TextField(
                controller: _lastName,
                label: 'Last name',
                hintText: 'Lovelace',
                helperText: empty,
                validator: (value) =>
                    validateNameField(value, label: 'Last name', max: 50),
              );
              if (constraints.maxWidth >= 520) {
                return Row(
                  children: [
                    Expanded(child: firstName),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(child: lastName),
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  firstName,
                  const SizedBox(height: AppSpacing.md),
                  lastName,
                ],
              );
            },
          ),
          const SizedBox(height: AppSpacing.md),
          _TextField(
            controller: _displayName,
            label: 'Display name',
            hintText: 'The name shown across the app',
            helperText: empty,
            validator: validateDisplayName,
          ),
          const SizedBox(height: AppSpacing.lg),
          const _SectionLabel(label: 'Preferences'),
          const SizedBox(height: AppSpacing.sm),
          _TimezoneField(
            controller: _timezone,
            timezones: _timezones,
            disabled: !_timezonesReady || _saving,
          ),
          const SizedBox(height: AppSpacing.md),
          _TextField(
            controller: _imageUrl,
            label: 'Profile image URL',
            hintText: 'https://example.com/me.png',
            helperText: 'Optional http(s) image URL.',
            validator: validateProfileImageUrl,
          ),
        ],
      ),
    );
  }

  static String _friendlyLoadError(ApiException error) {
    return error.message != null
        ? error.message!
        : 'The server could not be reached. Please try again.';
  }

  static String _friendlySaveError(ApiException error) {
    if (error.kind == ApiExceptionKind.network) {
      return 'Could not reach the server. Please check your connection.';
    }
    if (error.kind == ApiExceptionKind.timeout) {
      return 'The server took too long to respond. Please try again.';
    }
    final messages = error.details
        .map((detail) => detail.message)
        .whereType<String>()
        .where((m) => m.isNotEmpty)
        .toList();
    if (messages.isNotEmpty) {
      return messages.join(' ');
    }
    if (error.message != null && error.message!.isNotEmpty) {
      return error.message!;
    }
    return 'Profile could not be saved. Please try again.';
  }
}

/// Small mono group label used to section the form (e.g. "IDENTITY").
class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = context.appColors;
    return Text(
      label.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: tokens.textMuted,
        letterSpacing: 1.4,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

/// A themed text field for the profile form (matches the design system input
/// decoration).
class _TextField extends StatelessWidget {
  const _TextField({
    required this.controller,
    required this.label,
    this.hintText,
    this.helperText,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final String? hintText;
  final String? helperText;
  final FormFieldValidator<String>? validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      validator: validator,
      style: Theme.of(context).textTheme.bodyLarge,
      textCapitalization: TextCapitalization.words,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        helperText: helperText,
      ),
    );
  }
}

/// Searchable/selectable time zone field.
///
/// Options come from [loadTimezoneCandidates] (the runtime's own `Intl`
/// registry on the web, a curated catalog otherwise) plus free-text entry for
/// any valid IANA id. The backend stays the authority on validity.
class _TimezoneField extends StatelessWidget {
  const _TimezoneField({
    required this.controller,
    required this.timezones,
    this.disabled = false,
  });

  final TextEditingController controller;
  final List<String> timezones;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    return FormField<String>(
      validator: (value) => validateTimezone(controller.text),
      builder: (field) {
        return DropdownMenu<String>(
          controller: controller,
          enabled: !disabled,
          label: const Text('Time zone'),
          hintText: 'Search or type an IANA time zone id',
          helperText: 'Examples: America/New_York, Europe/London, UTC.',
          errorText: field.hasError ? field.errorText : null,
          requestFocusOnTap: true,
          enableFilter: true,
          trailingIcon: const Icon(Icons.expand_more_rounded),
          onSelected: (value) {
            if (value != null) {
              controller.text = value;
            }
            field.didChange(controller.text);
          },
          dropdownMenuEntries: [
            for (final timezone in timezones)
              DropdownMenuEntry<String>(value: timezone, label: timezone),
          ],
        );
      },
    );
  }
}
