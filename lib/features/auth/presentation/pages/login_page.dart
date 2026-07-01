import 'package:flutter/material.dart';

import '../providers/auth_provider.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _setError(String? msg) => setState(() => _error = msg);
  void _setLoading(bool v) => setState(() => _loading = v);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Hero
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 40, 24, 32),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [const Color(0xFF004D38), cs.primary],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.sports_tennis_rounded,
                        color: Colors.white, size: 28),
                  ),
                  const SizedBox(height: 20),
                  const Text('ShuttleLeague',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5)),
                  const SizedBox(height: 4),
                  Text('Less organizing. More playing.',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.75),
                          fontSize: 14)),
                ],
              ),
            ),

            // Tabs
            TabBar(
              controller: _tabs,
              tabs: const [
                Tab(text: 'Sign In'),
                Tab(text: 'Register'),
              ],
            ),

            if (_error != null)
              Container(
                margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: cs.errorContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline_rounded,
                        size: 16, color: cs.onErrorContainer),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_error!,
                          style: TextStyle(
                              fontSize: 13, color: cs.onErrorContainer)),
                    ),
                  ],
                ),
              ),

            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: [
                  _SignInForm(
                    loading: _loading,
                    onSubmit: _signIn,
                  ),
                  _RegisterForm(
                    loading: _loading,
                    onSubmit: _register,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _signIn(String email, String password) async {
    _setError(null);
    _setLoading(true);
    try {
      await AuthService.signIn(email: email, password: password);
    } on Exception catch (e) {
      _setError(e.toString().replaceFirst('Exception: ', '').replaceFirst('[firebase_auth/', '').replaceAll(']', ''));
    } finally {
      _setLoading(false);
    }
  }

  Future<void> _register(
      String name, String email, String password, bool isAdmin, String? code) async {
    _setError(null);
    _setLoading(true);
    try {
      await AuthService.register(
        name: name,
        email: email,
        password: password,
        isAdmin: isAdmin,
        adminCode: code,
      );
    } on Exception catch (e) {
      _setError(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      _setLoading(false);
    }
  }
}

// ─── Sign In Form ─────────────────────────────────────────────────────────────

class _SignInForm extends StatefulWidget {
  final bool loading;
  final Future<void> Function(String email, String password) onSubmit;

  const _SignInForm({required this.loading, required this.onSubmit});

  @override
  State<_SignInForm> createState() => _SignInFormState();
}

class _SignInFormState extends State<_SignInForm> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _form,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const SizedBox(height: 8),
          TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email',
              prefixIcon: Icon(Icons.email_outlined),
            ),
            validator: (v) =>
                v == null || !v.contains('@') ? 'Enter a valid email' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _pass,
            obscureText: _obscure,
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: const Icon(Icons.lock_outline_rounded),
              suffixIcon: IconButton(
                icon: Icon(_obscure
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
            validator: (v) =>
                v == null || v.length < 6 ? 'Min 6 characters' : null,
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: widget.loading
                  ? null
                  : () {
                      if (_form.currentState!.validate()) {
                        widget.onSubmit(_email.text, _pass.text);
                      }
                    },
              child: widget.loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Sign In'),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Register Form ────────────────────────────────────────────────────────────

class _RegisterForm extends StatefulWidget {
  final bool loading;
  final Future<void> Function(
      String name, String email, String password, bool isAdmin, String? code) onSubmit;

  const _RegisterForm({required this.loading, required this.onSubmit});

  @override
  State<_RegisterForm> createState() => _RegisterFormState();
}

class _RegisterFormState extends State<_RegisterForm> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _code = TextEditingController();
  bool _obscure = true;
  bool _isAdmin = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _pass.dispose();
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Form(
      key: _form,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const SizedBox(height: 8),
          TextFormField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Full Name',
              prefixIcon: Icon(Icons.person_outline_rounded),
            ),
            validator: (v) =>
                v == null || v.trim().length < 2 ? 'Enter your name' : null,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email',
              prefixIcon: Icon(Icons.email_outlined),
            ),
            validator: (v) =>
                v == null || !v.contains('@') ? 'Enter a valid email' : null,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _pass,
            obscureText: _obscure,
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: const Icon(Icons.lock_outline_rounded),
              suffixIcon: IconButton(
                icon: Icon(_obscure
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
            validator: (v) =>
                v == null || v.length < 6 ? 'Min 6 characters' : null,
          ),
          const SizedBox(height: 16),

          // Admin toggle
          Card(
            color: _isAdmin
                ? cs.primaryContainer
                : cs.surfaceContainerLow,
            child: SwitchListTile(
              value: _isAdmin,
              onChanged: (v) => setState(() => _isAdmin = v),
              title: const Text('Register as Admin',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              subtitle: Text(_isAdmin
                  ? 'Enter the admin code below'
                  : 'Toggle to request admin access'),
              secondary: Icon(
                Icons.admin_panel_settings_rounded,
                color: _isAdmin ? cs.primary : cs.outline,
              ),
            ),
          ),

          if (_isAdmin) ...[
            const SizedBox(height: 12),
            TextFormField(
              controller: _code,
              decoration: const InputDecoration(
                labelText: 'Admin Code',
                prefixIcon: Icon(Icons.vpn_key_rounded),
                hintText: 'Enter code provided by your organiser',
              ),
              validator: _isAdmin
                  ? (v) => v == null || v.trim().isEmpty
                      ? 'Admin code required'
                      : null
                  : null,
            ),
          ],

          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: widget.loading
                  ? null
                  : () {
                      if (_form.currentState!.validate()) {
                        widget.onSubmit(
                          _name.text,
                          _email.text,
                          _pass.text,
                          _isAdmin,
                          _isAdmin ? _code.text : null,
                        );
                      }
                    },
              child: widget.loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Create Account'),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'Admin code: ask your league organiser',
              style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}
