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
class CounterController extends ChangeNotifier {
  int count = 0;

  void increment() {
    count++;
    notifyListeners(); // Notify listeners
  }
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
      select: (value) => value.count,
      builder: (context, value) => Text(value.toString()),
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
        controller.increment();
      },
      child: const Text('Increment'),
    );
  }
}
```

### Advanced Usage

For more complex state management scenarios, you can:

```dart
class EnvController extends ChangeNotifier {
  Env _env = Env.dev;
  Env get env => _env;

  void setEnv(Env? env) {
    if (env == null) {
      return;
    }
    _env = env;
    notifyListeners();
  }
}

class MainAppController extends ChangeNotifier {
  MainAppController({
    required EnvController envController,
  }) {
    load(
      env: envController.env,
    );
  }

  void load({
    Env? env,
  }) {
    if (env != null) {
      _countLength = switch (env) {
        Env.dev => 3,
        Env.uat => 2,
        Env.stg => 1,
        Env.prod => 0,
      };
      notifyListeners();
    }
  }

  int _countLength = 1;
  int get countLength => _countLength;
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return SimpleControllerProvider.multi(
      providers: [
        SimpleControllerProvider<EnvController>(
          create: (context) => EnvController(),
        ),
        SimpleControllerProvider<MainAppController>(
          create: (context) => MainAppController(
            envController: context.use(),
          ),
          dependencies: (context, controller) => [
            context.dependency(
              select: (EnvController value) => value.env,
              listen: (prev, next) => controller.load(
                env: next,
              ),
            ),
          ],
        ),
      ],
      child: ...,
    );
  }
}
```
