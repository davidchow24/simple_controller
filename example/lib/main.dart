import 'package:flutter/material.dart';
import 'package:simple_controller/simple_controller.dart';

enum Env {
  dev,
  uat,
  stg,
  prod,
}

class EnvController extends SimpleController {
  Env _env = Env.dev;
  Env get env => _env;

  SimpleControllerCommand<void, Env?> get updateEnv =>
      createCommand(_updateEnv);

  void _updateEnv(Env? env) {
    if (env == null) {
      return;
    }
    _env = env;
  }
}

class MainAppController extends SimpleController {
  MainAppController({
    required EnvController envController,
  }) {
    addDependency(
      controller: envController,
      select: (value) => value.env,
      listen: _envControllerEnvListener,
    );
  }

  void _envControllerEnvListener(Env prev, Env next) {
    _countLength = switch (next) {
      Env.dev => 3,
      Env.uat => 2,
      Env.stg => 1,
      Env.prod => 0,
    };
    notifyListeners();
  }

  final int maxCountLength = 3;

  int _countLength = 1;
  int get countLength => _countLength;

  bool get isMaxCountLength => _countLength >= maxCountLength;

  bool get isMinCountLength => _countLength <= 0;

  SimpleControllerCommand<void, Null> get incrementCountLength =>
      createCommand(_incrementCountLength);

  void _incrementCountLength(Null _) async {
    if (isMaxCountLength) {
      return;
    }
    // Simulate async operation
    await Future.delayed(Duration(milliseconds: 300));
    _countLength++;
  }

  SimpleControllerCommand<void, Null> get decrementCountLength =>
      createCommand(_decrementCountLength);

  void _decrementCountLength(Null _) async {
    if (isMinCountLength) {
      return;
    }
    // Simulate async operation
    await Future.delayed(Duration(milliseconds: 300));
    _countLength--;
  }
}

class HomePageController extends SimpleController {
  HomePageController({
    required MainAppController mainAppController,
  }) {
    addDependency(
      controller: mainAppController,
      select: (value) => value.countLength,
      listen: _mainAppControllerCountLengthListener,
    );
  }

  void _mainAppControllerCountLengthListener(int prev, int next) {
    _counts = List.generate(next, (i) => _counts.elementAtOrNull(i) ?? 0);
    notifyListeners();
  }

  List<int> _counts = [];
  List<int> get counts => _counts;

  SimpleControllerCommand<void, int> get increment => createCommand(_increment);

  void _increment(int index) {
    _counts[index]++;
  }
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
        SimpleControllerProvider<EnvController>(
          create: (context) => EnvController(),
        ),
        SimpleControllerProvider<MainAppController>(
          create: (context) => MainAppController(
            envController: context.use(),
          ),
        ),
      ],
      child: MaterialApp(
        home: SimpleControllerProvider(
          create: (context) => HomePageController(
            mainAppController: context.use(),
          ),
          child: HomePage(),
        ),
      ),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final envController = context.use<EnvController>();
    final mainAppController = context.use<MainAppController>();
    final homePageController = context.use<HomePageController>();

    return Scaffold(
      appBar: AppBar(
        title: Text('Home'),
        actions: [
          envController.build(
            select: (value) => value.env,
            builder: (context, env) {
              return DropdownButton(
                value: env,
                items: [
                  for (final value in Env.values)
                    DropdownMenuItem(
                      value: value,
                      child: Text(value.name),
                    ),
                ],
                onChanged: envController.updateEnv.execute,
              );
            },
          ),
          SizedBox(width: 8.0),
          mainAppController.build(
            select: (value) => value.isMinCountLength,
            builder: (context, isMinCountLength) => mainAppController.build(
              select: (value) => value.decrementCountLength.isExecuting,
              builder: (context, isExecuting) => IconButton(
                onPressed: isMinCountLength || isExecuting
                    ? null
                    : () {
                        mainAppController.decrementCountLength.execute(null);
                      },
                icon: Icon(Icons.remove),
              ),
            ),
          ),
          SizedBox(width: 8.0),
          mainAppController.build(
            select: (value) => value.isMaxCountLength,
            builder: (context, isMaxCountLength) => mainAppController.build(
              select: (value) => value.incrementCountLength.isExecuting,
              builder: (context, isExecuting) => IconButton(
                onPressed: isMaxCountLength || isExecuting
                    ? null
                    : () {
                        mainAppController.incrementCountLength.execute(null);
                      },
                icon: Icon(Icons.add),
              ),
            ),
          ),
        ],
      ),
      body: Center(
        child: homePageController.build(
          select: (value) => value.counts.length,
          builder: (context, length) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < length; i++) ...[
                if (i > 0) const SizedBox(height: 8.0),
                homePageController.build(
                  select: (value) => value.counts.elementAtOrNull(i),
                  builder: (context, value) {
                    return Text('count${i + 1}: $value');
                  },
                ),
              ],
            ],
          ),
        ),
      ),
      floatingActionButton: homePageController.build(
        select: (value) => value.counts.length,
        builder: (context, length) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < length; i++) ...[
                if (i > 0) const SizedBox(height: 8.0),
                FilledButton.icon(
                  onPressed: () {
                    homePageController.increment.execute(i);
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
