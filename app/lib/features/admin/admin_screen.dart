import 'package:flutter/material.dart';

import '../../core/services.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/common.dart';
import '../../data/api_client.dart';
import '../../domain/models.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  final _search = TextEditingController();
  List<ManagedUser> _users = const [];
  List<AccessRole> _roles = const [];
  bool _loading = true;
  bool _saving = false;
  bool _loadedOnce = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _search.addListener(_refreshView);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loadedOnce) return;
    _loadedOnce = true;
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    final api = Services.of(context).api;
    try {
      final results = await Future.wait([api.adminUsers(), api.adminRoles()]);
      if (!mounted) return;
      setState(() {
        _users = results[0] as List<ManagedUser>;
        _roles = results[1] as List<AccessRole>;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error is AdminApiException
            ? error.message
            : 'Não foi possível carregar os acessos. Confira a conexão.';
      });
    }
  }

  List<ManagedUser> get _filtered {
    final query = _search.text.trim().toLowerCase();
    if (query.isEmpty) return _users;
    return _users
        .where(
          (user) =>
              user.name.toLowerCase().contains(query) ||
              user.email.toLowerCase().contains(query) ||
              user.roles.any((role) => role.toLowerCase().contains(query)),
        )
        .toList();
  }

  void _refreshView() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final services = Services.of(context);
    if (!services.auth.canManageUsers) {
      return const _AccessDenied();
    }

    return Scaffold(
      backgroundColor: TaColors.paperDim,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: _AdminHeader(
              organization: services.auth.identity.propertyName,
              active: _users.where((user) => user.active).length,
              administrators: _users
                  .where((user) => user.roles.contains('ADMO'))
                  .length,
              onBack: () => Navigator.of(context).maybePop(),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(TaSpace.md),
            sliver: SliverToBoxAdapter(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1120),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _AccessToolbar(
                        controller: _search,
                        busy: _saving,
                        onAdd: _openCreate,
                        onRefresh: _load,
                      ),
                      const SizedBox(height: TaSpace.lg),
                      const SectionLabel('Equipe e perfis'),
                      const SizedBox(height: TaSpace.sm),
                      if (_loading)
                        const _LoadingAccess()
                      else if (_error != null)
                        _AccessError(message: _error!, onRetry: _load)
                      else if (_filtered.isEmpty)
                        _EmptyAccess(hasSearch: _search.text.isNotEmpty)
                      else
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final columns = constraints.maxWidth >= 760 ? 2 : 1;
                            final width = columns == 1
                                ? constraints.maxWidth
                                : (constraints.maxWidth - TaSpace.md) / 2;
                            return Wrap(
                              spacing: TaSpace.md,
                              runSpacing: TaSpace.md,
                              children: [
                                for (final user in _filtered)
                                  SizedBox(
                                    width: width,
                                    child: _UserAccessCard(
                                      user: user,
                                      roleName: _roleName,
                                      onTap: _saving
                                          ? null
                                          : () => _openEdit(user),
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                      const SizedBox(height: TaSpace.xl),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _roleName(String code) {
    for (final role in _roles) {
      if (role.code == code) return role.name;
    }
    return code;
  }

  Future<void> _openCreate() async {
    final draft = await showModalBottomSheet<_UserDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _UserAccessSheet(roles: _roles),
    );
    if (draft == null || !mounted) return;
    await _save(
      () => Services.of(context).api.createAdminUser(
        name: draft.name,
        email: draft.email,
        roles: draft.roles,
      ),
      'Pessoa adicionada à operação.',
    );
  }

  Future<void> _openEdit(ManagedUser user) async {
    final draft = await showModalBottomSheet<_UserDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _UserAccessSheet(user: user, roles: _roles),
    );
    if (draft == null || !mounted) return;
    await _save(
      () => Services.of(context).api.updateAdminUser(
        user.id,
        name: draft.name,
        email: draft.email,
        status: draft.active ? 'ACTIVE' : 'SUSPENDED',
        roles: draft.roles,
      ),
      'Acesso atualizado.',
    );
  }

  Future<void> _save(
    Future<ManagedUser> Function() operation,
    String success,
  ) async {
    setState(() => _saving = true);
    try {
      await operation();
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(success)));
    } catch (error) {
      if (!mounted) return;
      final message = error is AdminApiException
          ? error.message
          : 'Não foi possível salvar. Confira a conexão e tente novamente.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: TaColors.clay),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _search
      ..removeListener(_refreshView)
      ..dispose();
    super.dispose();
  }
}

class _AdminHeader extends StatelessWidget {
  const _AdminHeader({
    required this.organization,
    required this.active,
    required this.administrators,
    required this.onBack,
  });

  final String organization;
  final int active;
  final int administrators;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      color: TaColors.pasture,
      padding: EdgeInsets.fromLTRB(
        TaSpace.sm,
        MediaQuery.paddingOf(context).top + TaSpace.sm,
        TaSpace.md,
        TaSpace.lg,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: onBack,
                    icon: const Icon(Icons.arrow_back),
                    color: TaColors.paperInk,
                    tooltip: 'Voltar',
                  ),
                  const SizedBox(width: TaSpace.xs),
                  const Expanded(
                    child: SectionLabel('Central de acesso', onDark: true),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: TaSpace.sm,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: TaColors.pastureDeep,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: TaColors.paperInkSoft.withValues(alpha: .35),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.verified_user_outlined,
                          size: 15,
                          color: TaColors.tagYellow,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'RBAC ATIVO',
                          style: TextStyle(
                            color: TaColors.paperInk,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: .7,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(left: 52, top: TaSpace.md),
                child: Wrap(
                  spacing: TaSpace.xl,
                  runSpacing: TaSpace.md,
                  crossAxisAlignment: WrapCrossAlignment.end,
                  children: [
                    SizedBox(
                      width: 390,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Quem pode entrar\nna operação.',
                            style: t.displayMedium!.copyWith(
                              color: TaColors.paperInk,
                              height: 1.03,
                            ),
                          ),
                          const SizedBox(height: TaSpace.sm),
                          Text(
                            organization,
                            style: t.bodyMedium!.copyWith(
                              color: TaColors.paperInkSoft,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _HeaderMetric(value: '$active', label: 'ativos'),
                    _HeaderMetric(
                      value: '$administrators',
                      label: 'administradores',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderMetric extends StatelessWidget {
  const _HeaderMetric({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 112,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.displayMedium!.copyWith(color: TaColors.tagYellow),
          ),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall!.copyWith(color: TaColors.paperInkSoft),
          ),
        ],
      ),
    );
  }
}

class _AccessToolbar extends StatelessWidget {
  const _AccessToolbar({
    required this.controller,
    required this.busy,
    required this.onAdd,
    required this.onRefresh,
  });

  final TextEditingController controller;
  final bool busy;
  final VoidCallback onAdd;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 640;
        final search = TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Buscar pessoa ou perfil',
            prefixIcon: Icon(Icons.search),
            filled: true,
            fillColor: TaColors.paper,
          ),
        );
        final add = SizedBox(
          height: 56,
          child: FilledButton.icon(
            onPressed: busy ? null : onAdd,
            icon: const Icon(Icons.person_add_alt_1),
            label: const Text('Adicionar pessoa'),
          ),
        );
        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              search,
              const SizedBox(height: TaSpace.sm),
              add,
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: search),
            const SizedBox(width: TaSpace.sm),
            IconButton(
              onPressed: busy ? null : onRefresh,
              icon: const Icon(Icons.refresh),
              tooltip: 'Atualizar acessos',
            ),
            const SizedBox(width: TaSpace.sm),
            add,
          ],
        );
      },
    );
  }
}

class _UserAccessCard extends StatelessWidget {
  const _UserAccessCard({
    required this.user,
    required this.roleName,
    required this.onTap,
  });

  final ManagedUser user;
  final String Function(String) roleName;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final initial = user.name.trim().isEmpty ? '?' : user.name.trim()[0];
    return TaCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: user.active ? TaColors.tagYellow : TaColors.paperDim,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: user.active ? TaColors.tagYellowDeep : TaColors.line,
                  ),
                ),
                child: Text(
                  initial.toUpperCase(),
                  style: t.titleLarge!.copyWith(color: TaColors.stamp),
                ),
              ),
              const SizedBox(width: TaSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.name,
                      style: t.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      user.email,
                      style: t.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              _StatusPill(active: user.active),
              const SizedBox(width: TaSpace.xs),
              const Icon(Icons.chevron_right, color: TaColors.inkSoft),
            ],
          ),
          const SizedBox(height: TaSpace.md),
          Wrap(
            spacing: TaSpace.xs,
            runSpacing: TaSpace.xs,
            children: [
              for (final role in user.roles)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: TaSpace.sm,
                    vertical: 6,
                  ),
                  decoration: const BoxDecoration(
                    color: TaColors.sageBg,
                    borderRadius: BorderRadius.all(TaRadius.rSm),
                  ),
                  child: Text(
                    roleName(role),
                    style: t.labelSmall!.copyWith(
                      color: TaColors.pasture,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.active});
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: active ? TaColors.sageBg : TaColors.clayBg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        active ? 'ATIVO' : 'SUSPENSO',
        style: Theme.of(context).textTheme.labelSmall!.copyWith(
          color: active ? TaColors.sage : TaColors.clay,
          fontSize: 9,
          fontWeight: FontWeight.w900,
          letterSpacing: .5,
        ),
      ),
    );
  }
}

class _UserDraft {
  const _UserDraft({
    required this.name,
    required this.email,
    required this.roles,
    required this.active,
  });

  final String name;
  final String email;
  final List<String> roles;
  final bool active;
}

class _UserAccessSheet extends StatefulWidget {
  const _UserAccessSheet({required this.roles, this.user});

  final List<AccessRole> roles;
  final ManagedUser? user;

  @override
  State<_UserAccessSheet> createState() => _UserAccessSheetState();
}

class _UserAccessSheetState extends State<_UserAccessSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _email;
  late final Set<String> _selected;
  late bool _active;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.user?.name ?? '');
    _email = TextEditingController(text: widget.user?.email ?? '');
    _selected = {...?widget.user?.roles};
    _active = widget.user?.active ?? true;
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.user != null;
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .9,
      ),
      padding: EdgeInsets.fromLTRB(
        TaSpace.lg,
        TaSpace.sm,
        TaSpace.lg,
        MediaQuery.viewInsetsOf(context).bottom + TaSpace.lg,
      ),
      decoration: const BoxDecoration(
        color: TaColors.paper,
        borderRadius: BorderRadius.vertical(top: TaRadius.rLg),
      ),
      child: Form(
        key: _formKey,
        child: ListView(
          shrinkWrap: true,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                margin: const EdgeInsets.only(bottom: TaSpace.lg),
                decoration: BoxDecoration(
                  color: TaColors.line,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SectionLabel('Identidade de trabalho'),
            const SizedBox(height: TaSpace.xs),
            Text(
              editing ? 'Revisar acesso' : 'Adicionar à operação',
              style: Theme.of(context).textTheme.displayMedium,
            ),
            const SizedBox(height: TaSpace.lg),
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Nome completo',
                prefixIcon: Icon(Icons.badge_outlined),
              ),
              validator: (value) => value == null || value.trim().length < 2
                  ? 'Informe o nome da pessoa.'
                  : null,
            ),
            const SizedBox(height: TaSpace.sm),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'E-mail de trabalho',
                prefixIcon: Icon(Icons.alternate_email),
              ),
              validator: (value) =>
                  value == null ||
                      !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value)
                  ? 'Informe um e-mail válido.'
                  : null,
            ),
            const SizedBox(height: TaSpace.lg),
            const SectionLabel('Perfis vigentes'),
            const SizedBox(height: TaSpace.sm),
            for (final role in widget.roles)
              CheckboxListTile(
                value: _selected.contains(role.code),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(role.name),
                subtitle: Text(role.description),
                onChanged: (checked) => setState(() {
                  if (checked == true) {
                    _selected.add(role.code);
                  } else {
                    _selected.remove(role.code);
                  }
                }),
              ),
            if (_selected.isEmpty)
              Text(
                'Escolha ao menos um perfil.',
                style: Theme.of(context).textTheme.bodySmall!.copyWith(
                  color: TaColors.clay,
                  fontWeight: FontWeight.w700,
                ),
              ),
            if (editing) ...[
              const Divider(height: TaSpace.xl),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _active,
                onChanged: (value) => setState(() => _active = value),
                title: Text(_active ? 'Acesso ativo' : 'Acesso suspenso'),
                subtitle: Text(
                  _active
                      ? 'A pessoa pode iniciar uma sessão.'
                      : 'A próxima validação encerra o acesso.',
                ),
              ),
            ],
            const SizedBox(height: TaSpace.lg),
            SizedBox(
              height: 56,
              child: FilledButton.icon(
                onPressed: _submit,
                icon: const Icon(Icons.verified_user_outlined),
                label: Text(editing ? 'Salvar acesso' : 'Adicionar pessoa'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate() || _selected.isEmpty) return;
    Navigator.of(context).pop(
      _UserDraft(
        name: _name.text.trim(),
        email: _email.text.trim(),
        roles: _selected.toList()..sort(),
        active: _active,
      ),
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    super.dispose();
  }
}

class _LoadingAccess extends StatelessWidget {
  const _LoadingAccess();

  @override
  Widget build(BuildContext context) {
    return const TaCard(
      child: SizedBox(
        height: 160,
        child: Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _AccessError extends StatelessWidget {
  const _AccessError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return TaCard(
      child: Row(
        children: [
          const Icon(Icons.cloud_off_outlined, color: TaColors.clay),
          const SizedBox(width: TaSpace.md),
          Expanded(child: Text(message)),
          TextButton(onPressed: onRetry, child: const Text('Tentar novamente')),
        ],
      ),
    );
  }
}

class _EmptyAccess extends StatelessWidget {
  const _EmptyAccess({required this.hasSearch});
  final bool hasSearch;

  @override
  Widget build(BuildContext context) {
    return TaCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: TaSpace.xl),
        child: Column(
          children: [
            const Icon(Icons.group_outlined, size: 44, color: TaColors.inkSoft),
            const SizedBox(height: TaSpace.sm),
            Text(
              hasSearch ? 'Nenhuma pessoa encontrada' : 'Equipe ainda vazia',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ],
        ),
      ),
    );
  }
}

class _AccessDenied extends StatelessWidget {
  const _AccessDenied();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TaColors.paperDim,
      appBar: AppBar(title: const Text('Central de acesso')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: const TaCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_outline, size: 42, color: TaColors.clay),
                SizedBox(height: TaSpace.md),
                Text(
                  'Seu perfil não administra acessos desta organização.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
