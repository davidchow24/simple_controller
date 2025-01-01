import 'package:flutter/material.dart';
import 'package:simple_controller/simple_controller.dart';

enum Env {
  dev,
  uat,
  stg,
  prod,
}

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

class HomePageController extends ChangeNotifier {
  HomePageController({
    required MainAppController mainAppController,
  }) {
    load(
      countLength: mainAppController.countLength,
    );
  }

  void load({
    int? countLength,
  }) {
    _counts = List.generate(
      countLength ?? _counts.length,
      (index) => _counts.elementAtOrNull(index) ?? 0,
    );
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
      dependencies: (context, controller) => [
        context.dependency(
          select: (MainAppController value) => value.countLength,
          listen: (prev, next) => controller.load(
            countLength: next,
          ),
        ),
      ],
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
            spacing: 8.0,
            children: [
              for (var i = 0; i < value; i++)
                homePageController.build(
                  select: (value) => value.counts.elementAtOrNull(i),
                  builder: (context, value) => Text('count${i + 1}: $value'),
                ),
            ],
          ),
        ),
      ),
      floatingActionButton: homePageController.build(
        select: (value) => value.counts.length,
        builder: (context, value) => Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 8.0,
          children: [
            for (var i = 0; i < value; i++)
              FilledButton.icon(
                onPressed: () {
                  homePageController.increment(i);
                },
                icon: Icon(Icons.add),
                label: Text('count${i + 1}'),
              ),
          ],
        ),
      ),
    );
  }
}
