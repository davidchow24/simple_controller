# simple_controller

A lightweight and efficient state management solution for Flutter applications.

## Features

- 🚀 Simple and intuitive API
- 🎯 Type-safe state management
- 📦 Minimal boilerplate
- 🔄 Reactive updates
- 💡 Easy to learn and implement

## Usage

### Key Components

#### SimpleController

A controller class that extends ChangeNotifier to manage dependencies and notify listeners.

##### createState

A method to create a reactive state variable. It initializes the state with a given value and provides a way to listen for changes. This state can be used within the controller to manage and update the UI efficiently.

##### createCommand

A method to create a command that encapsulates a piece of logic or an action. It can be executed with one parameter and supports features like debouncing. Commands help in organizing and reusing logic within the controller.

#### SimpleControllerProvider

A widget that provides a single controller instance to its descendants. Use this when you need to provide a single controller to a widget subtree.

#### SimpleControllerProvider.multi

A widget that allows providing multiple controllers at once. Useful when you need to provide several controllers that work together.

#### context.use\<T>()

A method to access a controller of type T from the widget tree. This provides type-safe access to your controllers from any descendant widget.

#### controller.build()

A method to efficiently rebuild widgets when specific controller state changes. It takes a selector function to specify which state to watch and a builder function to construct the widget.

### Basic Example

```dart
class CounterController extends SimpleController {
  late final countState = createState(0);

  late final increment = createCommand((_) {
    countState.value++;
  });
}

class CounterProvider extends StatelessWidget {
  const CounterProvider({super.key});

  @override
  Widget build(BuildContext context) {
    return SimpleControllerProvider(
      create: (context) => CounterController(),
      child: const CounterWidget(),
    );
  }
}

class CounterWidget extends StatelessWidget {
  const CounterWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.use<CounterController>();
    return controller.build(
      select: (value) => value.countState.value,
      builder: (context, value, child) => Text(value.toString()),
    );
  }
}

class CounterButton extends StatelessWidget {
  const CounterButton({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.use<CounterController>();
    return TextButton(
      onPressed: () {
        controller.increment.execute(null);
      },
      child: const Text('Increment'),
    );
  }
}
```

### Advanced Usage

For more complex state management scenarios, you can:

```dart
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
```
