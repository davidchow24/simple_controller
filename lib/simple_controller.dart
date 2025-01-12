import 'dart:developer' as developer;
import 'dart:async';

import 'package:flutter/widgets.dart';

void _log({
  required _LogType type,
  required String message,
  required String debugLabel,
}) {
  if (SimpleController.showLog) {
    SimpleController.log(
      [
        if (SimpleController.showLogDetail)
          '[${DateTime.now().toIso8601String()}]',
        '[${type.typeName}]',
        '[${debugLabel}]',
        if (SimpleController.showLogDetail) '[${message}]',
      ].join(' '),
    );
  }
}

enum _LogType {
  init,
  change,
  dispose,
}

extension _LogTypeExtension on _LogType {
  String get typeName => this.toString().split('.').last.toUpperCase();
}

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
    return _SimpleControllerSelectorWidget(
      controller: this,
      select: select,
      listen: listen,
      builder: builder,
      child: child,
    );
  }
}

/// A reference class that holds a [SimpleControllerState] and a [setState] function.
class SimpleControllerStateRef<T> {
  SimpleControllerStateRef({
    required SimpleControllerState<T> state,
    required void Function(T value) setState,
  })  : _state = state,
        _setState = setState;

  final SimpleControllerState<T> _state;
  final void Function(T value) _setState;

  final List<SimpleControllerState> _dependencies = [];

  void _dispose() {
    for (final dependency in _dependencies) {
      dependency._removeListener(_listener);
    }
    _dependencies.clear();
  }

  void _listener() async {
    final onInit = _state._onInit;
    if (onInit != null) {
      final futureOr = onInit(this);
      if (futureOr is Future<T>) {
        final value = await futureOr;
        _setState(value);
      } else {
        _setState(futureOr);
      }
    }
  }

  /// Watch a [SimpleControllerState] and return its value.
  S watchState<S>(SimpleControllerState<S> state) {
    _dependencies.add(state);
    state._addListener(_listener);
    return state.value;
  }
}

/// A state class that holds a [SimpleControllerStateRef] and a [setState] function.
class SimpleControllerState<T> {
  SimpleControllerState._({
    required String debugLabel,
    required FutureOr<T> Function(SimpleControllerStateRef<T> ref)? onInit,
    required Object? Function() getState,
    required SimpleControllerCommand<void, T> setState,
    required void Function(T value)? onDispose,
  })  : _debugLabel = debugLabel,
        _onInitCallback = onInit,
        _getState = getState,
        _setState = setState,
        _onDispose = onDispose;

  final FutureOr<T> Function(SimpleControllerStateRef<T> ref)? _onInitCallback;

  final void Function(T value)? _onDispose;

  final Object? Function() _getState;

  final SimpleControllerCommand<void, T> _setState;

  final String _debugLabel;

  void _dispose() {
    final onDispose = _onDispose;
    if (onDispose != null) {
      _log(
        type: _LogType.dispose,
        message: '',
        debugLabel: _debugLabel,
      );
      onDispose(value);
    }
  }

  FutureOr<T> Function(SimpleControllerStateRef<T> ref)? get _onInit {
    final onInit = _onInitCallback;
    return onInit != null
        ? (SimpleControllerStateRef<T> ref) {
            return onInit(ref);
          }
        : null;
  }

  void _setValue(T value) {
    _setState.execute(value);
    for (final listener in _listeners) {
      listener();
    }
  }

  T get value => _getState() as T;

  set value(T value) {
    _setValue(value);
  }

  final List<void Function()> _listeners = [];

  void _addListener(void Function() listener) {
    if (_listeners.contains(listener)) {
      return;
    }
    _listeners.add(listener);
  }

  void _removeListener(void Function() listener) {
    _listeners.remove(listener);
  }
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
  /// Whether to show log messages.
  static bool showLog = false;

  /// Whether to show log details.
  static bool showLogDetail = false;

  /// The log function to use.
  static void Function(String message) log = (String message) {
    developer.log(
      message,
      name: 'simple_controller',
    );
  };

  final List<_SimpleControllerDependencyState> _dependencyStates = [];

  final Map<String, int> _executingCountMap = {};
  final Map<String, int> _debounceCountMap = {};
  final Map<String, int> _throttleCountMap = {};

  final Map<Key, Object?> _stateValueMap = {};
  final Map<Key, SimpleControllerState> _stateMap = {};
  final Map<Key, SimpleControllerStateRef> _stateRefMap = {};

  SimpleControllerState<T> _baseCreateState<T>({
    required String? debugLabel,
    T? initialState,
    required FutureOr<T> Function(SimpleControllerStateRef<T> ref)? onInit,
    required void Function(T value)? onDispose,
    required void Function(T prev, T next)? listen,
  }) {
    final key = UniqueKey();

    var currentDebugLabel = debugLabel ?? key.hashCode.toString();
    if (SimpleController.showLog && debugLabel == null) {
      final stackTrace = StackTrace.current;
      final frames = stackTrace.toString().split('\n');
      final index = frames.indexWhere(
        (frame) =>
            frame.contains('SimpleController.createState') ||
            frame.contains('SimpleController.createRefState'),
      );
      if (index > -1 && index + 1 < frames.length) {
        final frame = frames[index + 1];
        final regex = RegExp(r'#\d+\s+(.+)\s+.+$');
        final match = regex.firstMatch(frame);
        if (match != null) {
          final frameLabel = match.group(1);
          if (frameLabel != null) {
            currentDebugLabel = frameLabel;
          }
        }
      }
    }

    final currentOnDispose = onDispose;

    void setState(T value) {
      final prev = _stateValueMap[key] as T;
      final next = value;
      if (prev != next) {
        _log(
          type: _LogType.change,
          message: '$prev -> $next',
          debugLabel: currentDebugLabel,
        );
        _stateValueMap[key] = next;
        notifyListeners();
        listen?.call(prev, value);
        if (currentOnDispose != null) {
          _log(
            type: _LogType.dispose,
            message: '',
            debugLabel: currentDebugLabel,
          );
          currentOnDispose(prev);
        }
      }
    }

    final state = SimpleControllerState<T>._(
      onInit: onInit,
      getState: () => _stateValueMap[key],
      setState: createCommand(setState),
      onDispose: currentOnDispose,
      debugLabel: currentDebugLabel,
    );

    _stateMap[key] = state;

    final stateOnInit = state._onInit;
    final stateSetValue = state._setValue;

    if (stateOnInit != null) {
      final stateRef = SimpleControllerStateRef<T>(
        state: state,
        setState: stateSetValue,
      );
      _stateRefMap[key] = stateRef;
      final futureOr = stateOnInit(stateRef);
      if (futureOr is Future<T>) {
        _stateValueMap[key] = initialState;
        futureOr.then(stateSetValue);
      } else {
        _stateValueMap[key] = futureOr;
      }
    } else {
      _stateValueMap[key] = initialState;
    }

    _log(
      type: _LogType.init,
      message: '${_stateValueMap[key]}',
      debugLabel: currentDebugLabel,
    );

    return state;
  }

  @protected

  /// Create a [SimpleControllerState] with a reference to other states.
  ///
  /// The [onInit] function is called when the state is created and must return a value of type [T].
  /// The [onInit] function receives a [SimpleControllerStateRef] that can be used to watch other states.
  ///
  /// The [debugLabel] is used for logging purposes.
  ///
  /// The [onDispose] function is called when the state is disposed.
  ///
  /// The [listen] function is called when the state changes.
  @protected
  SimpleControllerState<T> createRefState<T>(
    T Function(SimpleControllerStateRef<T> ref) onInit, {
    String? debugLabel,
    void Function(T value)? onDispose,
    void Function(T prev, T next)? listen,
  }) {
    return _baseCreateState(
      debugLabel: debugLabel,
      onInit: onInit,
      onDispose: onDispose,
      listen: listen,
    );
  }

  /// Create a [SimpleControllerState] with an initial value.
  ///
  /// The [initialState] is the initial value of the state.
  ///
  /// The [onInit] function is called when the state is created and can optionally return a new value of type [T].
  /// The [onInit] function receives a [SimpleControllerStateRef] that can be used to watch other states.
  ///
  /// The [debugLabel] is used for logging purposes.
  ///
  /// The [onDispose] function is called when the state is disposed.
  ///
  /// The [listen] function is called when the state changes.
  @protected
  SimpleControllerState<T> createState<T>(
    T initialState, {
    String? debugLabel,
    FutureOr<T> Function(SimpleControllerStateRef<T> ref)? onInit,
    void Function(T value)? onDispose,
    void Function(T prev, T next)? listen,
  }) {
    return _baseCreateState(
      debugLabel: debugLabel,
      initialState: initialState,
      onInit: onInit,
      onDispose: onDispose,
      listen: listen,
    );
  }

  /// Create a [SimpleControllerCommand] with a callback function.
  ///
  /// The [callback] function is called when the command is executed.
  ///
  /// The [key] is used to identify the command in the debounce and throttle.
  ///
  /// The [debounce] is the debounce duration.
  ///
  /// The [throttle] is the throttle duration.
  ///
  /// The [skipIfExecuting] is whether to skip the command if it is already executing.
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
  ///
  /// The [controller] is the controller to watch.
  ///
  /// The [select] function is used to select the value from the controller.
  ///
  /// The [listen] function is called when the value changes.
  ///
  /// The [fireImmediately] is whether to fire the listener immediately.
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
    for (final state in _stateMap.values) {
      state._dispose();
    }
    for (final stateRef in _stateRefMap.values) {
      stateRef._dispose();
    }
    for (var i = 0; i < _dependencyStates.length; i++) {
      final state = _dependencyStates[i];
      state.dependency.controller.removeListener(state.listener);
    }
    _stateRefMap.clear();
    _stateValueMap.clear();
    _stateMap.clear();
    _dependencyStates.clear();
    _executingCountMap.clear();
    _debounceCountMap.clear();
    _throttleCountMap.clear();
    super.dispose();
  }
}

/// A provider widget that provides a [SimpleController] to its children.
class SimpleControllerProvider<N extends SimpleController>
    extends StatefulWidget {
  const SimpleControllerProvider({
    required this.create,
    this.child,
    Key? key,
  }) : super(key: key);

  /// Create a [SimpleControllerProvider] widget that provides a [SimpleController] to its children.
  ///
  /// The [providers] is a list of [SimpleControllerProvider] widgets to wrap.
  ///
  /// The [child] is the child widget to wrap with the [SimpleController].
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

class _SimpleControllerSelectorWidget<T, N extends SimpleController>
    extends StatefulWidget {
  const _SimpleControllerSelectorWidget({
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
  State<_SimpleControllerSelectorWidget<T, N>> createState() =>
      _SimpleControllerSelectorWidgetState<T, N>();
}

class _SimpleControllerSelectorWidgetState<T, N extends SimpleController>
    extends State<_SimpleControllerSelectorWidget<T, N>> {
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
