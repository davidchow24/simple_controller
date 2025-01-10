import 'dart:async';

import 'package:flutter/widgets.dart';

/// [BuildContext] extension to use [SimpleController].
extension SimpleControllerBuildContextExtension on BuildContext {
  /// Get the controller from the [SimpleControllerProvider] in the context.
  N use<N extends SimpleController>() {
    return SimpleControllerProvider._of<N>(this);
  }
}

/// An extension on [SimpleController] that provides a [build] method for creating
/// a widget that listens to changes in the controller's state and rebuilds accordingly.
extension SimpleSimpleControllerExtension<N extends SimpleController> on N {
  /// Create a widget that listens to changes in the controller's state and rebuilds accordingly.
  Widget build<S>({
    required S Function(N value) select,
    required Widget Function(
      BuildContext context,
      S value,
      Widget? child,
    ) builder,
    Function(S prev, S next)? listen,
    Widget? child,
  }) {
    return _SimpleControllerSelector(
      controller: this,
      select: select,
      listen: listen,
      builder: builder,
      child: child,
    );
  }
}

class SimpleControllerState<T> {
  const SimpleControllerState({
    required T Function() getState,
    required SimpleControllerCommand<void, T> setState,
  })  : _getState = getState,
        _setState = setState;

  final T Function() _getState;

  final SimpleControllerCommand<void, T> _setState;

  T get value => _getState();

  set value(T value) {
    _setState.execute(value);
  }

  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SimpleControllerState<T> && other.value == value;
  }

  @override
  int get hashCode => value.hashCode;
}

/// A dependency class that holds a controller, a selector function, a listener function,
class _SimpleControllerDependency<T, N extends SimpleController> {
  const _SimpleControllerDependency({
    required this.controller,
    required this.select,
    required this.listen,
    this.fireImmediately = true,
  });

  final N controller;
  final T Function(N value) select;
  final void Function(T prev, T next) listen;
  final bool fireImmediately;
}

/// A command class that executes a callback function with debounce and throttle options.
class SimpleControllerCommand<Output, Input> {
  SimpleControllerCommand._({
    required String? key,
    required Map<String, int> executingCountMap,
    required Map<String, int> debounceCountMap,
    required Map<String, int> throttleCountMap,
    required FutureOr<Output> Function(Input) callback,
    required Duration debounce,
    required Duration throttle,
    required bool skipIfExecuting,
    required void Function() notifyListeners,
  })  : _key = key ?? callback.hashCode.toString(),
        _executingCountMap = executingCountMap,
        _debounceCountMap = debounceCountMap,
        _throttleCountMap = throttleCountMap,
        _callback = callback,
        _debounce = debounce,
        _throttle = throttle,
        _skipIfExecuting = skipIfExecuting,
        _notifyListeners = notifyListeners;

  final String _key;
  final Map<String, int> _executingCountMap;
  final Map<String, int> _debounceCountMap;
  final Map<String, int> _throttleCountMap;
  final void Function() _notifyListeners;
  final FutureOr<Output> Function(Input) _callback;
  final Duration _debounce;
  final Duration _throttle;
  final bool _skipIfExecuting;

  /// Returns true if the command is currently executing.
  bool get isExecuting {
    final executingCount = _executingCountMap[_key];
    return executingCount != null && executingCount > 0;
  }

  void _incrementExecutingCount() {
    final executingCount = _executingCountMap[_key] ?? 0;
    _executingCountMap[_key] = executingCount + 1;
    if (_executingCountMap[_key] == 1) {
      _notifyListeners();
    }
  }

  void _decrementExecutingCount() {
    final executingCount = _executingCountMap[_key] ?? 0;
    _executingCountMap[_key] = executingCount - 1;
    if (_executingCountMap[_key] == 0) {
      _executingCountMap.remove(_key);
      _notifyListeners();
    }
  }

  /// Returns true if the command is currently debouncing.
  bool get isDebouncing {
    final debounceCount = _debounceCountMap[_key];
    return debounceCount != null && debounceCount > 0;
  }

  void _incrementDebounceCount() {
    final debounceCount = _debounceCountMap[_key] ?? 0;
    _debounceCountMap[_key] = debounceCount + 1;
  }

  void _decrementDebounceCount() {
    final debounceCount = _debounceCountMap[_key] ?? 0;
    _debounceCountMap[_key] = debounceCount - 1;
  }

  /// Returns true if the command is currently throttling.
  bool get isThrottling {
    final throttleCount = _throttleCountMap[_key];
    return throttleCount != null && throttleCount > 0;
  }

  void _incrementThrottleCount() {
    final throttleCount = _throttleCountMap[_key] ?? 0;
    _throttleCountMap[_key] = throttleCount + 1;
  }

  void _decrementThrottleCount() {
    final throttleCount = _throttleCountMap[_key] ?? 0;
    _throttleCountMap[_key] = throttleCount - 1;
    if (_throttleCountMap[_key] == 0) {
      _throttleCountMap.remove(_key);
      _notifyListeners();
    }
  }

  Completer<Output?> _completer = Completer<Output?>();

  void _execute({
    required Input input,
    required Duration debounce,
    required Duration throttle,
    required bool skipIfExecuting,
  }) async {
    if (debounce > Duration.zero) {
      _incrementDebounceCount();
      Timer(
        debounce,
        () {
          _decrementDebounceCount();
          if (isDebouncing) {
            return;
          }
          _executeCommand(
            input: input,
            skipIfExecuting: skipIfExecuting,
          );
        },
      );
    } else if (throttle > Duration.zero) {
      if (isThrottling) {
        return;
      }
      _incrementThrottleCount();
      _executeCommand(
        input: input,
        skipIfExecuting: skipIfExecuting,
      );
      Timer(
        throttle,
        () {
          _decrementThrottleCount();
        },
      );
    } else {
      _executeCommand(
        input: input,
        skipIfExecuting: skipIfExecuting,
      );
    }
  }

  void _executeCommand({
    required Input input,
    required bool skipIfExecuting,
  }) async {
    if (skipIfExecuting && isExecuting) {
      return;
    }
    _incrementExecutingCount();
    try {
      final result = await _callback(input);
      _completer.complete(result);
    } catch (e) {
      _completer.completeError(e);
    } finally {
      _decrementExecutingCount();
      if (!isExecuting) {
        _completer = Completer<Output?>();
      }
    }
  }

  /// Execute the command with the given input.
  Future<Output?> execute(Input input) {
    _execute(
      input: input,
      debounce: _debounce,
      throttle: _throttle,
      skipIfExecuting: _skipIfExecuting,
    );
    return _completer.future;
  }
}

/// A controller class that extends [ChangeNotifier] to manage dependencies and notify listeners.
///
/// The [SimpleController] class allows adding dependencies to other controllers and listening
/// to changes in their selected values. It maintains a list of states, each representing a dependency
/// and its associated listener.
class SimpleController extends ChangeNotifier {
  final List<_SimpleControllerDependencyState> _dependencyStates = [];

  final Map<String, int> _executingCountMap = {};
  final Map<String, int> _debounceCountMap = {};
  final Map<String, int> _throttleCountMap = {};

  final Map<Key, Object?> _stateMap = {};

  /// Create a [SimpleControllerState] with an initial state.
  @protected
  SimpleControllerState<T> createState<T>(
    T initialState, {
    FutureOr<T> Function()? onInit,
    void Function(T prev, T next)? listen,
  }) {
    final key = UniqueKey();

    void setState(T value) {
      final prev = _stateMap[key] as T;
      final next = value;
      _stateMap[key] = next;
      notifyListeners();
      listen?.call(prev, value);
    }

    if (onInit != null) {
      final futureOr = onInit();
      if (futureOr is Future<T>) {
        _stateMap[key] = initialState;
        futureOr.then(setState);
      } else {
        _stateMap[key] = futureOr;
      }
    } else {
      _stateMap[key] = initialState;
    }

    return SimpleControllerState<T>(
      getState: () => _stateMap[key] as T,
      setState: createCommand(setState),
    );
  }

  /// Create a [SimpleControllerCommand] with a callback function.
  @protected
  SimpleControllerCommand<Output, Input> createCommand<Output, Input>(
    FutureOr<Output> Function(Input) callback, {
    String? key,
    Duration debounce = Duration.zero,
    Duration throttle = Duration.zero,
    bool skipIfExecuting = true,
  }) {
    return SimpleControllerCommand._(
      key: key,
      executingCountMap: _executingCountMap,
      debounceCountMap: _debounceCountMap,
      throttleCountMap: _throttleCountMap,
      callback: callback,
      debounce: debounce,
      throttle: throttle,
      skipIfExecuting: skipIfExecuting,
      notifyListeners: notifyListeners,
    );
  }

  /// Add a dependency to the controller.
  @protected
  void addDependency<T, N extends SimpleController>({
    required N controller,
    required T Function(N value) select,
    required FutureOr<void> Function(T prev, T next) listen,
    bool fireImmediately = true,
  }) {
    final index = _dependencyStates.length;

    final selectedValue = select(controller);

    final listener = () async {
      final prev = _dependencyStates[index].value;
      final next = select(controller);
      if (prev != next) {
        _dependencyStates[index].value = next;
        await listen(prev, next);
        notifyListeners();
      }
    };

    _dependencyStates.add(
      _SimpleControllerDependencyState(
        dependency: _SimpleControllerDependency<T, N>(
          controller: controller,
          select: select,
          listen: listen,
          fireImmediately: fireImmediately,
        ),
        listener: listener,
        value: selectedValue,
      ),
    );

    controller.addListener(listener);

    if (fireImmediately) {
      listen(selectedValue, selectedValue);
    }
  }

  /// Remove a dependency from the controller.
  @override
  void dispose() {
    for (var i = 0; i < _dependencyStates.length; i++) {
      final state = _dependencyStates[i];
      state.dependency.controller.removeListener(state.listener);
    }
    super.dispose();
  }
}

/// [SimpleControllerProvider] is a widget that provides a [SimpleController] to its children.
class SimpleControllerProvider<N extends SimpleController>
    extends StatefulWidget {
  const SimpleControllerProvider({
    required this.create,
    this.child,
    Key? key,
  }) : super(key: key);

  /// Create a [SimpleControllerProvider] widget that provides a [SimpleController] to its children.
  static Widget multi({
    required List<SimpleControllerProvider> providers,
    required Widget child,
  }) {
    var result = child;
    for (final provider in providers.reversed) {
      result = provider._wrapWith(
        child: result,
      );
    }
    return result;
  }

  SimpleControllerProvider<N> _wrapWith<T extends SimpleController>({
    required Widget? child,
  }) {
    return SimpleControllerProvider<N>(
      create: create,
      child: child,
    );
  }

  static N _of<N extends SimpleController>(BuildContext context) {
    return context
        .findAncestorStateOfType<_SimpleControllerProviderState<N>>()!
        ._controller;
  }

  /// The function to create the [SimpleController].
  final N Function(BuildContext context) create;

  /// The child widget to wrap with the [SimpleController].
  final Widget? child;

  @override
  State<SimpleControllerProvider<N>> createState() =>
      _SimpleControllerProviderState<N>();
}

class _SimpleControllerProviderState<N extends SimpleController>
    extends State<SimpleControllerProvider<N>> {
  late final N _controller = widget.create(context);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child ?? SizedBox.shrink();
  }
}

class _SimpleControllerSelector<T, N extends SimpleController>
    extends StatefulWidget {
  const _SimpleControllerSelector({
    required this.controller,
    required this.select,
    required this.builder,
    this.listen,
    this.child,
    Key? key,
  }) : super(key: key);

  final N controller;
  final T Function(N value) select;
  final void Function(T prev, T next)? listen;
  final Widget Function(BuildContext context, T value, Widget? child) builder;
  final Widget? child;

  @override
  State<_SimpleControllerSelector<T, N>> createState() =>
      _SimpleControllerSelectorState<T, N>();
}

class _SimpleControllerSelectorState<T, N extends SimpleController>
    extends State<_SimpleControllerSelector<T, N>> {
  late T _value = widget.select(widget.controller);

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_listener);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_listener);
    super.dispose();
  }

  void _listener() {
    final value = widget.select(widget.controller);
    if (mounted && _notEqual(_value, value)) {
      widget.listen?.call(_value, value);
      setState(() {
        _value = value;
      });
    }
  }

  bool _notEqual(T prev, T next) {
    return prev != next;
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(
      context,
      _value,
      widget.child,
    );
  }
}

class _SimpleControllerDependencyState<T> {
  _SimpleControllerDependencyState({
    required this.dependency,
    required this.listener,
    required this.value,
  });

  final _SimpleControllerDependency dependency;
  final void Function() listener;
  T value;
}
