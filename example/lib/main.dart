import 'package:flutter/material.dart';
import 'package:simple_controller/simple_controller.dart';

enum Env {
  dev,
  uat,
  stg,
  prod,
}

class SettingController extends SimpleController {
  late final localeState = createState(Locale('en', 'US'));
  late final themeModeState = createState(ThemeMode.system);
  late final envState = createState(Env.dev);
}

class MainAppController extends SimpleController {
  MainAppController({
    required SettingController settingController,
  }) {
    addDependency(
      controller: settingController,
      select: (value) => value.envState.value,
      listen: (prev, next) {
        countLengthState.value = switch (next) {
          Env.dev => 3,
          Env.uat => 2,
          Env.stg => 1,
          Env.prod => 0,
        };
      },
    );
  }

  late final countLengthState = createState(0);

  final int maxCountLength = 3;

  bool get isMaxCountLength => countLengthState.value >= maxCountLength;

  bool get isMinCountLength => countLengthState.value <= 0;

  late final incrementCountLength = createCommand((_) {
    if (isMaxCountLength) {
      return;
    }
    countLengthState.value++;
  });

  late final decrementCountLength = createCommand((_) {
    if (isMinCountLength) {
      return;
    }
    countLengthState.value--;
  });
}

class HomePageController extends SimpleController {
  HomePageController({
    required MainAppController mainAppController,
  }) {
    addDependency(
      controller: mainAppController,
      select: (value) => value.countLengthState.value,
      listen: (prev, next) {
        countsState.value = List.generate(
          next,
          (i) => countsState.value.elementAtOrNull(i) ?? 0,
        );
      },
    );
  }

  late final countsState = createState(<int>[]);

  late final increment = createCommand(
    (int index) {
      countsState.value[index]++;
    },
    debounce: const Duration(milliseconds: 100),
  );
}

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return SimpleControllerProvider.multi(
      providers: [
        SimpleControllerProvider<SettingController>(
          create: (context) => SettingController(),
        ),
        SimpleControllerProvider<MainAppController>(
          create: (context) => MainAppController(
            settingController: context.use(),
          ),
        ),
      ],
      child: Builder(
        builder: (context) {
          final settingController = context.use<SettingController>();

          return settingController.build(
            select: (value) => (
              locale: value.localeState.value,
              themeMode: value.themeModeState.value,
            ),
            builder: (context, value, child) => MaterialApp(
              locale: value.locale,
              themeMode: value.themeMode,
              theme: ThemeData.light(),
              darkTheme: ThemeData.dark(),
              home: child,
            ),
            child: SimpleControllerProvider(
              create: (context) => HomePageController(
                mainAppController: context.use(),
              ),
              child: HomePage(),
            ),
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
    final controller = context.use<HomePageController>();

    return Scaffold(
      appBar: AppBar(
        title: Text('Home'),
        actions: [
          SettingWidget(),
          SizedBox(width: 8.0),
        ],
      ),
      body: Center(
        child: controller.build(
          select: (value) => value.countsState.value.length,
          builder: (context, length, child) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < length; i++) ...[
                if (i > 0) const SizedBox(height: 8.0),
                controller.build(
                  select: (value) => value.countsState.value.elementAtOrNull(i),
                  builder: (context, value, child) {
                    return Text('count${i + 1}: $value');
                  },
                ),
              ],
              const SizedBox(height: 8.0),
              MainWidget(),
            ],
          ),
        ),
      ),
      floatingActionButton: controller.build(
        select: (value) => value.countsState.value.length,
        builder: (context, length, child) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < length; i++) ...[
                if (i > 0) const SizedBox(height: 8.0),
                FilledButton.icon(
                  onPressed: () {
                    controller.increment.execute(i);
                  },
                  icon: Icon(Icons.add),
                  label: Text('count${i + 1}'),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class SettingWidget extends StatelessWidget {
  const SettingWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.use<SettingController>();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        controller.build(
          select: (value) => value.themeModeState.value,
          builder: (context, themeMode, child) {
            return DropdownButton(
              value: themeMode,
              items: [
                for (final value in ThemeMode.values)
                  DropdownMenuItem(
                    value: value,
                    child: Text(value.name),
                  ),
              ],
              onChanged: (value) {
                if (value != null) {
                  controller.themeModeState.value = value;
                }
              },
            );
          },
        ),
        SizedBox(width: 8.0),
        controller.build(
          select: (value) => value.envState.value,
          builder: (context, env, child) {
            return DropdownButton(
              value: env,
              items: [
                for (final value in Env.values)
                  DropdownMenuItem(
                    value: value,
                    child: Text(value.name),
                  ),
              ],
              onChanged: (value) {
                if (value != null) {
                  controller.envState.value = value;
                }
              },
            );
          },
        ),
      ],
    );
  }
}

class MainWidget extends StatelessWidget {
  const MainWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.use<MainAppController>();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        controller.build(
          select: (value) => value.isMinCountLength,
          builder: (context, isMinCountLength, child) => controller.build(
            select: (value) => value.decrementCountLength.isExecuting,
            builder: (context, isExecuting, child) => IconButton(
              onPressed: isMinCountLength || isExecuting
                  ? null
                  : () {
                      controller.decrementCountLength.execute(null);
                    },
              icon: Icon(Icons.remove),
            ),
          ),
        ),
        SizedBox(width: 8.0),
        controller.build(
          select: (value) => value.isMaxCountLength,
          builder: (context, isMaxCountLength, child) => controller.build(
            select: (value) => value.incrementCountLength.isExecuting,
            builder: (context, isExecuting, child) => IconButton(
              onPressed: isMaxCountLength || isExecuting
                  ? null
                  : () {
                      controller.incrementCountLength.execute(null);
                    },
              icon: Icon(Icons.add),
            ),
          ),
        ),
      ],
    );
  }
}
