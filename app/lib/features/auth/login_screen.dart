import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../core/auth/auth_session.dart';
import '../../core/services.dart';
import '../../core/theme/tokens.dart';

/// Tela de login: o ritual de abrir a operação do dia. Tratamento imersivo
/// (fundo pasture, foco único, zero navegação concorrente) — a mesma
/// linguagem das telas de campo (leitura, pesagem), não de uma tela de
/// gestão. O brinco é o herói: a mesma peça que identifica cada animal
/// no app passa a identificar o operador antes de qualquer registro — e
/// entra em cena como um carimbo real: bate, assenta, o resto do formulário
/// segue em cascata. Um único momento orquestrado, não decoração contínua.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  late final AnimationController _reveal;

  @override
  void initState() {
    super.initState();
    _reveal = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    final reduceMotion =
        SchedulerBinding.instance.platformDispatcher.accessibilityFeatures
            .disableAnimations;
    if (reduceMotion) {
      _reveal.value = 1;
    } else {
      _reveal.forward();
    }
  }

  Future<void> _login(AppServices services) async {
    await services.login(_email.text.trim(), _password.text);
  }

  @override
  Widget build(BuildContext context) {
    final services = Services.of(context);
    return Scaffold(
      backgroundColor: TaColors.pasture,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 900;
            return SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: wide ? TaSpace.xxl : TaSpace.lg,
                vertical: TaSpace.lg,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - TaSpace.xl,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: wide ? 920 : 420),
                    child: wide
                        ? _WideLayout(
                            reveal: _reveal,
                            services: services,
                            email: _email,
                            password: _password,
                            obscure: _obscure,
                            onToggleObscure: () =>
                                setState(() => _obscure = !_obscure),
                            onLogin: () => _login(services),
                          )
                        : _NarrowLayout(
                            reveal: _reveal,
                            services: services,
                            email: _email,
                            password: _password,
                            obscure: _obscure,
                            onToggleObscure: () =>
                                setState(() => _obscure = !_obscure),
                            onLogin: () => _login(services),
                          ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _reveal.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }
}

class _NarrowLayout extends StatelessWidget {
  const _NarrowLayout({
    required this.reveal,
    required this.services,
    required this.email,
    required this.password,
    required this.obscure,
    required this.onToggleObscure,
    required this.onLogin,
  });

  final Animation<double> reveal;
  final AppServices services;
  final TextEditingController email;
  final TextEditingController password;
  final bool obscure;
  final VoidCallback onToggleObscure;
  final Future<void> Function() onLogin;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: _TagStamp(
            animation: reveal,
            end: .55,
            child: const _BrandMark(),
          ),
        ),
        const SizedBox(height: TaSpace.xl),
        _Reveal(
          animation: reveal,
          start: .35,
          end: .7,
          child: const _Heading(),
        ),
        const SizedBox(height: TaSpace.xl),
        _AccessForm(
          reveal: reveal,
          services: services,
          email: email,
          password: password,
          obscure: obscure,
          onToggleObscure: onToggleObscure,
          onLogin: onLogin,
        ),
        const SizedBox(height: TaSpace.xl),
        _Reveal(
          animation: reveal,
          start: .8,
          end: 1,
          offsetY: 6,
          child: const _DeviceFooter(),
        ),
      ],
    );
  }
}

class _WideLayout extends StatelessWidget {
  const _WideLayout({
    required this.reveal,
    required this.services,
    required this.email,
    required this.password,
    required this.obscure,
    required this.onToggleObscure,
    required this.onLogin,
  });

  final Animation<double> reveal;
  final AppServices services;
  final TextEditingController email;
  final TextEditingController password;
  final bool obscure;
  final VoidCallback onToggleObscure;
  final Future<void> Function() onLogin;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                flex: 5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _TagStamp(
                      animation: reveal,
                      end: .55,
                      child: const _BrandMark(),
                    ),
                    const SizedBox(height: TaSpace.lg),
                    _Reveal(
                      animation: reveal,
                      start: .35,
                      end: .7,
                      child: const _Heading(),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: TaSpace.xl),
                child: SizedBox(
                  width: 1,
                  child: ColoredBox(
                    color: TaColors.paperInkSoft.withValues(alpha: .18),
                  ),
                ),
              ),
              Expanded(
                flex: 5,
                child: _AccessForm(
                  reveal: reveal,
                  services: services,
                  email: email,
                  password: password,
                  obscure: obscure,
                  onToggleObscure: onToggleObscure,
                  onLogin: onLogin,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: TaSpace.xxl),
        _Reveal(
          animation: reveal,
          start: .8,
          end: 1,
          offsetY: 6,
          child: const _DeviceFooter(),
        ),
      ],
    );
  }
}

/// Fade + leve deslocamento vertical, escalonado por um intervalo do
/// controller compartilhado — o equivalente Flutter de uma linha na
/// timeline de uma animação coreografada (stagger).
class _Reveal extends StatelessWidget {
  const _Reveal({
    required this.animation,
    required this.start,
    required this.end,
    this.offsetY = 14,
    required this.child,
  });

  final Animation<double> animation;
  final double start;
  final double end;
  final double offsetY;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) {
        final linear = ((animation.value - start) / (end - start)).clamp(
          0.0,
          1.0,
        );
        final eased = Curves.easeOutCubic.transform(linear);
        return Opacity(
          opacity: linear,
          child: Transform.translate(
            offset: Offset(0, offsetY * (1 - eased)),
            child: child,
          ),
        );
      },
    );
  }
}

/// O momento de destaque da sequência: o brinco bate na tela como um carimbo
/// de verdade — escala com leve estouro (easeOutBack) e assenta a rotação.
/// É o único elemento com esse tratamento; tudo ao redor fica quieto.
class _TagStamp extends StatelessWidget {
  const _TagStamp({required this.animation, required this.end, required this.child});

  final Animation<double> animation;
  final double end;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) {
        final linear = (animation.value / end).clamp(0.0, 1.0);
        final scale = Curves.easeOutBack.transform(linear);
        final settle = Curves.easeOut.transform(linear);
        return Opacity(
          opacity: linear,
          child: Transform.rotate(
            angle: (1 - settle) * -.1,
            child: Transform.scale(scale: scale, child: child),
          ),
        );
      },
    );
  }
}

/// Marca do login: o emblema (mesma peça do ícone do app) com o nome
/// tipografado abaixo — não a arte crua do logo em JPEG, para respeitar a
/// tipografia do design system e continuar nítido em qualquer tamanho.
class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset('assets/branding/emblem.png', width: 168),
        const SizedBox(height: TaSpace.sm),
        Text(
          'SOBERANO',
          style: t.displayMedium!.copyWith(
            color: TaColors.paperInk,
            fontSize: 32,
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Abrir a operação\nde hoje.',
          style: t.displayMedium!.copyWith(
            color: TaColors.paperInk,
            letterSpacing: -.6,
          ),
        ),
        const SizedBox(height: TaSpace.sm),
        Text(
          'Sua identidade acompanha cada registro em Fazenda Santa Rita.',
          style: t.bodyMedium!.copyWith(color: TaColors.paperInkSoft),
        ),
      ],
    );
  }
}

class _AccessForm extends StatelessWidget {
  const _AccessForm({
    required this.reveal,
    required this.services,
    required this.email,
    required this.password,
    required this.obscure,
    required this.onToggleObscure,
    required this.onLogin,
  });

  final Animation<double> reveal;
  final AppServices services;
  final TextEditingController email;
  final TextEditingController password;
  final bool obscure;
  final VoidCallback onToggleObscure;
  final Future<void> Function() onLogin;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: services.auth,
      builder: (context, _) {
        final auth = services.auth;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Reveal(
              animation: reveal,
              start: .5,
              end: .8,
              child: _LabeledField(
                label: 'E-mail de trabalho',
                child: TextField(
                  controller: email,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.username],
                  style: const TextStyle(color: TaColors.ink),
                  decoration: _fieldDecoration(icon: Icons.badge_outlined),
                ),
              ),
            ),
            const SizedBox(height: TaSpace.md),
            _Reveal(
              animation: reveal,
              start: .56,
              end: .86,
              child: _LabeledField(
                label: 'Senha',
                child: TextField(
                  controller: password,
                  obscureText: obscure,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.password],
                  style: const TextStyle(color: TaColors.ink),
                  onSubmitted: (_) {
                    if (!auth.busy) onLogin();
                  },
                  decoration: _fieldDecoration(icon: Icons.key_outlined)
                      .copyWith(
                        suffixIcon: IconButton(
                          tooltip: obscure ? 'Mostrar senha' : 'Ocultar senha',
                          color: TaColors.inkSoft,
                          onPressed: onToggleObscure,
                          icon: Icon(
                            obscure
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                ),
              ),
            ),
            if (auth.busy || auth.error != null) ...[
              const SizedBox(height: TaSpace.sm),
              _StatusLine(
                busy: auth.busy,
                message: auth.error,
                kind: auth.feedbackKind,
                onRetry: auth.feedbackKind == AuthFeedbackKind.connection
                    ? auth.bootstrap
                    : null,
              ),
            ],
            const SizedBox(height: TaSpace.md),
            _Reveal(
              animation: reveal,
              start: .68,
              end: .95,
              offsetY: 10,
              child: FilledButton.icon(
                onPressed: auth.busy ? null : onLogin,
                icon: auth.busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: TaColors.stamp,
                        ),
                      )
                    : const Icon(Icons.login_rounded),
                label: Text(
                  auth.busy ? 'Conferindo acesso…' : 'Abrir operação',
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  InputDecoration _fieldDecoration({required IconData icon}) {
    return InputDecoration(
      prefixIcon: Icon(icon, color: TaColors.inkSoft),
      filled: true,
      fillColor: TaColors.paper,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: TaSpace.md,
        vertical: 18,
      ),
      border: const OutlineInputBorder(
        borderRadius: BorderRadius.all(TaRadius.rSm),
        borderSide: BorderSide(color: TaColors.line),
      ),
      enabledBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(TaRadius.rSm),
        borderSide: BorderSide(color: TaColors.line),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(TaRadius.rSm),
        borderSide: BorderSide(color: TaColors.tagYellowDeep, width: 2),
      ),
    );
  }
}

/// Rótulo fixo acima do campo em vez do `labelText` flutuante do Material.
/// O rótulo flutuante do `OutlineInputBorder` sempre fica meio dentro/meio
/// fora do campo (a metade de dentro cai sobre o preenchimento `paper`
/// claro, a de fora sobre o fundo `pasture` escuro) — nenhuma cor única lê
/// bem nos dois ao mesmo tempo. Um rótulo estático ao lado resolve de vez.
class _LabeledField extends StatelessWidget {
  const _LabeledField({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: t.bodySmall!.copyWith(
            color: TaColors.paperInkSoft,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

/// Estado de conexão da tentativa de acesso. Discreto por padrão — offline
/// não é erro (AGENTS §2.5) — só ganha o tom de alerta quando há mesmo uma
/// falha para o operador resolver.
class _StatusLine extends StatelessWidget {
  const _StatusLine({
    required this.busy,
    required this.message,
    required this.kind,
    required this.onRetry,
  });

  final bool busy;
  final String? message;
  final AuthFeedbackKind? kind;
  final Future<void> Function()? onRetry;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    if (busy && message == null) {
      return Text(
        'Conferindo a base de campo…',
        style: t.bodySmall!.copyWith(color: TaColors.paperInkSoft),
      );
    }
    if (message == null) return const SizedBox.shrink();

    final icon = switch (kind) {
      AuthFeedbackKind.connection => Icons.cloud_off_outlined,
      AuthFeedbackKind.credentials => Icons.key_off_outlined,
      _ => Icons.info_outline,
    };
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: TaColors.clay),
        const SizedBox(width: TaSpace.sm),
        Expanded(
          child: Text(
            message!,
            style: t.bodySmall!.copyWith(color: TaColors.clay),
          ),
        ),
        if (onRetry != null)
          InkWell(
            onTap: busy ? null : onRetry,
            borderRadius: BorderRadius.circular(999),
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: Icon(
                Icons.refresh_rounded,
                size: 16,
                color: TaColors.clay.withValues(alpha: busy ? .4 : 1),
              ),
            ),
          ),
      ],
    );
  }
}

class _DeviceFooter extends StatelessWidget {
  const _DeviceFooter();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Row(
      children: [
        Icon(
          Icons.verified_user_outlined,
          size: 15,
          color: TaColors.paperInkSoft.withValues(alpha: .8),
        ),
        const SizedBox(width: TaSpace.sm),
        Expanded(
          child: Text(
            'A sessão vincula você, a propriedade e este aparelho aos '
            'registros do campo.',
            style: t.bodySmall!.copyWith(color: TaColors.paperInkSoft),
          ),
        ),
        const SizedBox(width: TaSpace.sm),
        Text(
          'TERMINAL A1',
          style: t.labelSmall!.copyWith(
            color: TaColors.paperInkSoft.withValues(alpha: .7),
          ),
        ),
      ],
    );
  }
}
