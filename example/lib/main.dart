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

  void setEnv(Env? env) {
    if (env == null) {
      return;
    }
    _env = env;
    notifyListeners();
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

  void incrementCountLength() {
    if (isMaxCountLength) {
      return;
    }
    _countLength++;
    notifyListeners();
  }

  void decrementCountLength() {
    if (isMinCountLength) {
      return;
    }
    _countLength--;
    notifyListeners();
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

  void increment(int index) {
    _counts[index]++;
    notifyListeners();
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
        home: HomePageProvider(
          child: HomePage(),
        ),
      ),
    );
  }
}

class HomePageProvider extends StatelessWidget {
  const HomePageProvider({
    required this.child,
    super.key,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SimpleControllerProvider(
      create: (context) => HomePageController(
        mainAppController: context.use(),
      ),
      child: child,
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
            builder: (context, value) => DropdownButton(
              value: value,
              items: [
                for (final env in Env.values)
                  DropdownMenuItem(
                    value: env,
                    child: Text(env.name),
                  ),
              ],
              onChanged: envController.setEnv,
            ),
          ),
          SizedBox(width: 8.0),
          mainAppController.build(
            select: (value) => value.isMinCountLength,
            builder: (context, value) => IconButton(
              onPressed: value ? null : mainAppController.decrementCountLength,
              icon: Icon(Icons.remove),
            ),
          ),
          SizedBox(width: 8.0),
          mainAppController.build(
            select: (value) => value.isMaxCountLength,
            builder: (context, value) => IconButton(
              onPressed: value ? null : mainAppController.incrementCountLength,
              icon: Icon(Icons.add),
            ),
          ),
        ],
      ),
      body: Center(
        child: homePageController.build(
          select: (value) => value.counts.length,
          builder: (context, value) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < value; i++) ...[
                if (i > 0) const SizedBox(height: 8.0),
                homePageController.build(
                  select: (value) => value.counts.elementAtOrNull(i),
                  builder: (context, value) => Text('count${i + 1}: $value'),
                ),
              ],
            ],
          ),
        ),
      ),
      floatingActionButton: homePageController.build(
        select: (value) => value.counts.length,
        builder: (context, value) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < value; i++) ...[
              if (i > 0) const SizedBox(height: 8.0),
              FilledButton.icon(
                onPressed: () {
                  homePageController.increment(i);
                },
                icon: Icon(Icons.add),
                label: Text('count${i + 1}'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
