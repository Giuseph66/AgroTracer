import 'package:flutter/material.dart';

import '../../core/auth/auth_session.dart';
import '../../core/services.dart';
import '../../core/theme/tokens.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController(text: 'joao@santarita.example');
  final _password = TextEditingController(text: 'campo');
  bool _obscure = true;

  /// Entrar com sucesso fecha a tela quando ela foi aberta por cima de outra
  /// (Ajustes, no modo em que o login é opcional). Quando é a tela raiz do
  /// app — servidor exige login — não há nada para fechar, e o AuthGate troca
  /// para o AppShell sozinho ao notificar a mudança de sessão.
  Future<void> _login(AppServices services) async {
    final ok = await services.login(_email.text.trim(), _password.text);
    if (ok && mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final services = Services.of(context);
    // Só existe algo para "voltar" quando esta tela foi aberta por cima de
    // outra — a partir de Ajustes, com login opcional. Como tela raiz do app
    // (servidor exige login), não há para onde recuar.
    final canDismiss = Navigator.of(context).canPop();
    return Scaffold(
      backgroundColor: TaColors.paperDim,
      appBar: canDismiss
          ? AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              foregroundColor: TaColors.ink,
              leading: IconButton(
                onPressed: () => Navigator.of(context).pop(false),
                icon: const Icon(Icons.close),
                tooltip: 'Cancelar',
              ),
            )
          : null,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 900;
            final content = wide
                ? Row(
                    children: [
                      const Expanded(flex: 6, child: _PropertyMapPanel()),
                      const SizedBox(width: TaSpace.lg),
                      Expanded(
                        flex: 4,
                        child: _AccessPanel(
                          services: services,
                          email: _email,
                          password: _password,
                          obscure: _obscure,
                          onToggleObscure: () =>
                              setState(() => _obscure = !_obscure),
                          onLogin: () => _login(services),
                        ),
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 292, child: _PropertyMapPanel()),
                      const SizedBox(height: TaSpace.md),
                      _AccessPanel(
                        services: services,
                        email: _email,
                        password: _password,
                        obscure: _obscure,
                        onToggleObscure: () =>
                            setState(() => _obscure = !_obscure),
                        onLogin: () => _login(services),
                      ),
                    ],
                  );

            return CustomPaint(
              painter: const _PaperGridPainter(),
              child: SingleChildScrollView(
                padding: EdgeInsets.all(wide ? TaSpace.xl : TaSpace.md),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - (wide ? 64 : 32),
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1180),
                      child: SizedBox(
                        height: wide ? 618 : null,
                        child: content,
                      ),
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
    _email.dispose();
    _password.dispose();
    super.dispose();
  }
}

class _PropertyMapPanel extends StatelessWidget {
  const _PropertyMapPanel();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxHeight < 420;
        return ClipRRect(
          borderRadius: const BorderRadius.all(TaRadius.rLg),
          child: Stack(
            fit: StackFit.expand,
            children: [
              const ColoredBox(color: TaColors.pasture),
              const CustomPaint(painter: _FieldContoursPainter()),
              Padding(
                padding: EdgeInsets.all(compact ? TaSpace.md : TaSpace.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'TRACEAGRO',
                          style: TextStyle(
                            color: TaColors.paperInk,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.4,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: TaColors.pastureDeep.withValues(alpha: .56),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: TaColors.paperInkSoft.withValues(
                                alpha: .44,
                              ),
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.my_location_rounded,
                                color: TaColors.tagYellow,
                                size: 14,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'TERMINAL A1',
                                style: TextStyle(
                                  color: TaColors.paperInk,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: .7,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (compact)
                      const SizedBox(height: TaSpace.md)
                    else
                      const Spacer(),
                    Align(
                      alignment: Alignment.center,
                      child: _PropertyPin(compact: compact),
                    ),
                    if (compact)
                      const SizedBox(height: TaSpace.md)
                    else
                      const Spacer(),
                    const Text(
                      'FAZENDA SANTA RITA',
                      style: TextStyle(
                        color: TaColors.paperInkSoft,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.3,
                      ),
                    ),
                    const SizedBox(height: TaSpace.sm),
                    Text(
                      'Sua operação começa\nonde o rebanho está.',
                      style: TextStyle(
                        color: TaColors.paperInk,
                        fontSize: compact ? 25 : 30,
                        height: 1.05,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -.8,
                      ),
                    ),
                    if (!compact) ...[
                      const SizedBox(height: TaSpace.md),
                      Row(
                        children: [
                          _MapDetail(
                            icon: Icons.landscape_outlined,
                            text: 'Operação de campo',
                          ),
                          const SizedBox(width: TaSpace.md),
                          _MapDetail(
                            icon: Icons.sensors,
                            text: 'Leitor pareado',
                          ),
                        ],
                      ),
                      const SizedBox(height: TaSpace.sm),
                    ] else
                      const SizedBox(height: TaSpace.sm),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '15°35′S  ·  56°06′W',
                          style: Theme.of(context).textTheme.labelSmall!
                              .copyWith(
                                color: TaColors.paperInkSoft,
                                letterSpacing: .45,
                              ),
                        ),
                        const _MapScale(),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AccessPanel extends StatelessWidget {
  const _AccessPanel({
    required this.services,
    required this.email,
    required this.password,
    required this.obscure,
    required this.onToggleObscure,
    required this.onLogin,
  });

  final AppServices services;
  final TextEditingController email;
  final TextEditingController password;
  final bool obscure;
  final VoidCallback onToggleObscure;
  final Future<void> Function() onLogin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(TaSpace.lg),
      decoration: const BoxDecoration(
        color: TaColors.paper,
        borderRadius: BorderRadius.all(TaRadius.rLg),
        border: Border.fromBorderSide(BorderSide(color: TaColors.line)),
      ),
      child: ListenableBuilder(
        listenable: services.auth,
        builder: (context, _) {
          final auth = services.auth;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: const BoxDecoration(
                      color: TaColors.tagYellow,
                      borderRadius: BorderRadius.all(TaRadius.rSm),
                    ),
                    child: const Icon(
                      Icons.vpn_key_outlined,
                      color: TaColors.stamp,
                    ),
                  ),
                  const SizedBox(width: TaSpace.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ACESSO DA PROPRIEDADE',
                          style: theme.textTheme.titleSmall,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '01 · identidade de trabalho',
                          style: theme.textTheme.labelSmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: TaSpace.xl),
              Text(
                'Vamos abrir\na operação.',
                style: theme.textTheme.displayMedium!.copyWith(
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: TaSpace.sm),
              Text(
                'Entre com a identidade que vai acompanhar cada manejo registrado hoje.',
                style: theme.textTheme.bodyMedium,
              ),
              if (auth.error != null) ...[
                const SizedBox(height: TaSpace.md),
                _ConnectionNotice(
                  kind: auth.feedbackKind ?? AuthFeedbackKind.service,
                  message: auth.error!,
                  busy: auth.busy,
                  onRetry: auth.bootstrap,
                ),
              ],
              const SizedBox(height: TaSpace.lg),
              TextField(
                controller: email,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.username],
                decoration: _fieldDecoration(
                  label: 'E-mail de trabalho',
                  icon: Icons.badge_outlined,
                ),
              ),
              const SizedBox(height: TaSpace.sm),
              TextField(
                controller: password,
                obscureText: obscure,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
                onSubmitted: (_) {
                  if (!auth.busy) onLogin();
                },
                decoration:
                    _fieldDecoration(
                      label: 'Senha',
                      icon: Icons.key_outlined,
                    ).copyWith(
                      suffixIcon: IconButton(
                        tooltip: obscure ? 'Mostrar senha' : 'Ocultar senha',
                        onPressed: onToggleObscure,
                        icon: Icon(
                          obscure
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
              ),
              const SizedBox(height: TaSpace.xl),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: auth.busy ? null : onLogin,
                  icon: auth.busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.login_rounded),
                  label: Text(
                    auth.busy ? 'Conferindo acesso…' : 'Abrir operação',
                  ),
                ),
              ),
              const SizedBox(height: TaSpace.md),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.verified_user_outlined,
                    size: 16,
                    color: TaColors.sage,
                  ),
                  const SizedBox(width: TaSpace.sm),
                  Expanded(
                    child: Text(
                      'A sessão vincula operador, propriedade e aparelho aos registros do campo.',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  InputDecoration _fieldDecoration({
    required String label,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: TaColors.paperDim.withValues(alpha: .68),
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

class _ConnectionNotice extends StatelessWidget {
  const _ConnectionNotice({
    required this.kind,
    required this.message,
    required this.busy,
    required this.onRetry,
  });

  final AuthFeedbackKind kind;
  final String message;
  final bool busy;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final connection = kind == AuthFeedbackKind.connection;
    final credentials = kind == AuthFeedbackKind.credentials;
    final icon = connection
        ? Icons.cloud_off_outlined
        : credentials
        ? Icons.key_off_outlined
        : Icons.info_outline;
    final title = connection
        ? 'Sem conexão com a base de campo'
        : credentials
        ? 'Confira sua identidade de acesso'
        : 'Acesso indisponível por enquanto';
    return Container(
      padding: const EdgeInsets.all(TaSpace.md),
      decoration: BoxDecoration(
        color: TaColors.clayBg,
        borderRadius: const BorderRadius.all(TaRadius.rMd),
        border: Border.all(color: TaColors.clay.withValues(alpha: .42)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: TaColors.clay),
          const SizedBox(width: TaSpace.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodySmall!.copyWith(
                    color: TaColors.clay,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(message, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          if (connection)
            IconButton(
              tooltip: 'Tentar novamente',
              onPressed: busy ? null : onRetry,
              icon: const Icon(Icons.refresh_rounded, color: TaColors.clay),
            ),
        ],
      ),
    );
  }
}

class _PropertyPin extends StatelessWidget {
  const _PropertyPin({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: compact ? 76 : 96,
      height: compact ? 76 : 96,
      decoration: BoxDecoration(
        color: TaColors.tagYellow,
        shape: BoxShape.circle,
        border: Border.all(color: TaColors.paper, width: 4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .26),
            blurRadius: 20,
            spreadRadius: 4,
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.sensors, color: TaColors.stamp, size: compact ? 24 : 30),
          const SizedBox(height: 2),
          const Text(
            'A1',
            style: TextStyle(
              color: TaColors.stamp,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: .8,
            ),
          ),
        ],
      ),
    );
  }
}

class _MapDetail extends StatelessWidget {
  const _MapDetail({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: TaColors.tagYellow, size: 15),
        const SizedBox(width: 6),
        Text(
          text,
          style: Theme.of(context).textTheme.bodySmall!.copyWith(
            color: TaColors.paperInk,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _MapScale extends StatelessWidget {
  const _MapScale();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Container(width: 64, height: 2, color: TaColors.paperInk),
        const SizedBox(height: 3),
        const Text(
          '250 m',
          style: TextStyle(
            color: TaColors.paperInkSoft,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _FieldContoursPainter extends CustomPainter {
  const _FieldContoursPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final contour = Paint()
      ..color = TaColors.paperInk.withValues(alpha: .13)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final boundary = Paint()
      ..color = TaColors.sage.withValues(alpha: .34)
      ..style = PaintingStyle.fill;

    final field = Path()
      ..moveTo(size.width * .16, size.height * .11)
      ..lineTo(size.width * .76, size.height * .05)
      ..lineTo(size.width * .91, size.height * .42)
      ..lineTo(size.width * .65, size.height * .89)
      ..lineTo(size.width * .12, size.height * .76)
      ..close();
    canvas.drawPath(field, boundary);

    for (var index = 0; index < 5; index++) {
      final inset = index * 20.0;
      final path = Path()
        ..moveTo(size.width * .04 + inset, size.height * .22 + inset * .18)
        ..quadraticBezierTo(
          size.width * .42,
          size.height * (.04 + index * .03),
          size.width * .9 - inset * .45,
          size.height * .27 + inset * .2,
        )
        ..quadraticBezierTo(
          size.width * .58,
          size.height * .72 - inset * .12,
          size.width * .12 + inset * .32,
          size.height * .78 - inset * .1,
        );
      canvas.drawPath(path, contour);
    }

    final route = Paint()
      ..color = TaColors.tagYellow.withValues(alpha: .78)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final routePath = Path()
      ..moveTo(0, size.height * .69)
      ..cubicTo(
        size.width * .22,
        size.height * .62,
        size.width * .47,
        size.height * .72,
        size.width * .57,
        size.height * .53,
      )
      ..cubicTo(
        size.width * .67,
        size.height * .38,
        size.width * .85,
        size.height * .44,
        size.width,
        size.height * .3,
      );
    canvas.drawPath(routePath, route);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PaperGridPainter extends CustomPainter {
  const _PaperGridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = TaColors.inkSoft.withValues(alpha: .045)
      ..strokeWidth = 1;
    const step = 42.0;
    for (var x = 0.0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = 0.0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
