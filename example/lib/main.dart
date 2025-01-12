import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:simple_controller/simple_controller.dart';

enum Env {
  dev,
  prod,
}

class SettingController extends SimpleController {
  final supportedLocales = [
    const Locale('en', 'US'),
    const Locale('fr', 'FR'),
    const Locale('de', 'DE'),
    const Locale('es', 'ES'),
    const Locale('it', 'IT'),
  ];

  late final envState = createState(Env.dev);

  late final themeModeState = createState(ThemeMode.system);

  late final localeState = createState(supportedLocales.first);

  late final counterToggleState = createState(false);

  late final devInitialCountState = createState(999);

  late final prodInitialCountState = createState(0);

  late final initialCountState = createRefState(
    (ref) {
      final env = ref.watchState(envState);
      if (env == Env.dev) {
        return ref.watchState(devInitialCountState);
      }
      return ref.watchState(prodInitialCountState);
    },
  );
}

class CounterController extends SimpleController {
  CounterController({
    required SettingController settingController,
  }) : _settingController = settingController {
    addDependency(
      controller: settingController,
      select: (value) => value.initialCountState.value,
      listen: (prev, next) {
        final prevText = initialCountTextControllerState.value.text;
        final nextText = '$next';
        if (prevText != nextText) {
          initialCountTextControllerState.value.text = nextText;
        }
      },
    );
  }

  final SettingController _settingController;

  late final initialCountTextControllerState = createState(
    TextEditingController(
      text: '${_settingController.initialCountState.value}',
    ),
    onDispose: (value) {
      value.dispose();
    },
  );

  late final counterState = createRefState(
    (ref) {
      final initialCount = ref.watchState(_settingController.initialCountState);
      return initialCount;
    },
  );

  late final increment = createCommand((_) {
    counterState.value++;
  });
}

void main() {
  SimpleController.showLog = true;
  SimpleController.showLogDetail = false;
  SimpleController.log = (message) {
    developer.log(
      message,
      name: 'simple_controller',
    );
  };
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return SimpleControllerProvider.multi(
      providers: [
        SimpleControllerProvider<SettingController>(
          create: (context) => SettingController(),
        ),
      ],
      child: Builder(
        builder: (context) {
          final settingController = context.use<SettingController>();
          return settingController.build(
            select: (settingController) => (
              themeMode: settingController.themeModeState.value,
              locale: settingController.localeState.value,
              supportedLocales: settingController.supportedLocales,
            ),
            builder: (context, states, child) {
              return MaterialApp(
                themeMode: states.themeMode,
                theme: ThemeData.light(),
                darkTheme: ThemeData.dark(),
                locale: states.locale,
                supportedLocales: states.supportedLocales,
                localizationsDelegates: const [
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                ],
                home: child,
              );
            },
            child: const HomePage(),
          );
        },
      ),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final settingController = context.use<SettingController>();
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            spacing: 8.0,
            mainAxisSize: MainAxisSize.min,
            children: [
              const EnvWidget(),
              const ThemeModeWidget(),
              const LocaleWidget(),
              const EnvInitialCountWidget(),
              const CounterToggleWidget(),
              settingController.build(
                select: (value) => value.counterToggleState.value,
                builder: (context, value, child) {
                  if (value) {
                    return SimpleControllerProvider(
                      create: (context) => CounterController(
                        settingController: context.use(),
                      ),
                      child: const Column(
                        spacing: 8.0,
                        children: [
                          InitialCountWidget(),
                          CounterWidget(),
                        ],
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class EnvWidget extends StatelessWidget {
  const EnvWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final settingController = context.use<SettingController>();
    return settingController.build(
      select: (value) => value.envState.value,
      builder: (context, value, child) {
        return DropdownMenu(
          initialSelection: value,
          dropdownMenuEntries: [
            for (final env in Env.values)
              DropdownMenuEntry(
                value: env,
                label: '$env',
              ),
          ],
          onSelected: (env) {
            if (env != null) {
              settingController.envState.value = env;
            }
          },
        );
      },
    );
  }
}

class ThemeModeWidget extends StatelessWidget {
  const ThemeModeWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final settingController = context.use<SettingController>();
    return settingController.build(
      select: (value) => value.themeModeState.value,
      builder: (context, value, child) {
        return DropdownMenu(
          initialSelection: value,
          dropdownMenuEntries: [
            for (final themeMode in ThemeMode.values)
              DropdownMenuEntry(
                value: themeMode,
                label: '$themeMode',
              ),
          ],
          onSelected: (themeMode) {
            if (themeMode != null) {
              settingController.themeModeState.value = themeMode;
            }
          },
        );
      },
    );
  }
}

class LocaleWidget extends StatelessWidget {
  const LocaleWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final settingController = context.use<SettingController>();
    return settingController.build(
      select: (value) => (
        locale: value.localeState.value,
        supportedLocales: value.supportedLocales,
      ),
      builder: (context, states, child) {
        return DropdownMenu(
          initialSelection: states.locale,
          dropdownMenuEntries: [
            for (final locale in states.supportedLocales)
              DropdownMenuEntry(
                value: locale,
                label: '$locale',
              ),
          ],
          onSelected: (locale) {
            if (locale != null) {
              settingController.localeState.value = locale;
            }
          },
        );
      },
    );
  }
}

class EnvInitialCountWidget extends StatelessWidget {
  const EnvInitialCountWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final settingController = context.use<SettingController>();

    return Column(
      spacing: 8.0,
      children: [
        settingController.build(
          select: (value) => (
            prodInitialCount: value.prodInitialCountState.value,
            devInitialCount: value.devInitialCountState.value,
          ),
          builder: (context, value, child) {
            return Text(
              'Initial Count\n'
              '${Env.prod}: ${value.prodInitialCount}\n'
              '${Env.dev}: ${value.devInitialCount}',
              textAlign: TextAlign.center,
            );
          },
        ),
        FilledButton.icon(
          onPressed: () {
            settingController.prodInitialCountState.value++;
          },
          icon: const Icon(Icons.add),
          label: const Text('Increment Prod'),
        ),
        FilledButton.icon(
          onPressed: () {
            settingController.prodInitialCountState.value--;
          },
          icon: const Icon(Icons.remove),
          label: const Text('Decrement Prod'),
        ),
        FilledButton.icon(
          onPressed: () {
            settingController.devInitialCountState.value++;
          },
          icon: const Icon(Icons.add),
          label: const Text('Increment Dev'),
        ),
        FilledButton.icon(
          onPressed: () {
            settingController.devInitialCountState.value--;
          },
          icon: const Icon(Icons.remove),
          label: const Text('Decrement Dev'),
        ),
      ],
    );
  }
}

class CounterToggleWidget extends StatelessWidget {
  const CounterToggleWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final settingController = context.use<SettingController>();
    return ConstrainedBox(
      constraints: const BoxConstraints(
        maxWidth: 300,
      ),
      child: settingController.build(
        select: (value) => value.counterToggleState.value,
        builder: (context, value, child) {
          return SwitchListTile(
            value: value,
            onChanged: (value) {
              settingController.counterToggleState.value = value;
            },
            title: const Text('Counter Toggle'),
          );
        },
      ),
    );
  }
}

class InitialCountWidget extends StatelessWidget {
  const InitialCountWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final counterController = context.use<CounterController>();
    return counterController.build(
      select: (value) => value.initialCountTextControllerState.value,
      builder: (context, value, child) {
        return TextFormField(
          controller: value,
          onChanged: (value) {
            final parsedValue = int.tryParse(value);
            if (parsedValue != null) {
              final settingController = context.use<SettingController>();
              settingController.initialCountState.value = parsedValue;
            }
          },
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Initial Count',
            border: OutlineInputBorder(),
            constraints: BoxConstraints(
              maxWidth: 132,
            ),
          ),
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
          ],
        );
      },
    );
  }
}

class CounterWidget extends StatelessWidget {
  const CounterWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final counterController = context.use<CounterController>();
    return Column(
      spacing: 4.0,
      children: [
        const Text(
          'You have pushed the button this many times:',
          textAlign: TextAlign.center,
        ),
        counterController.build(
          select: (value) => value.counterState.value,
          builder: (context, value, child) {
            return Text('$value');
          },
        ),
        FilledButton.icon(
          onPressed: () {
            counterController.increment.execute(null);
          },
          icon: const Icon(Icons.add),
          label: const Text('Increment'),
        ),
      ],
    );
  }
}
