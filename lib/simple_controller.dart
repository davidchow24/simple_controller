import 'package:flutter/widgets.dart';

/// [BuildContext] extension to use [SimpleControllerProvider] and [SimpleControllerDependency].
extension SimpleControllerBuildContextExtension on BuildContext {
  /// Get the controller from the [SimpleControllerProvider] in the context.
  N use<N extends ChangeNotifier>() {
    return SimpleControllerProvider._of<N>(this);
  }

  /// Create a [SimpleControllerDependency] widget to listen to the controller.
  SimpleControllerDependency dependency<N extends ChangeNotifier, S>({
    required S Function(N value) select,
    required void Function(S prev, S next)? listen,
  }) {
    return SimpleControllerDependency<N, S>(
      controller: use(),
      select: select,
      listen: listen,
    );
  }
}

/// [ChangeNotifier] extension to use [SimpleControllerDependency].
extension SimpleControllerChangeNotifierExtension<N extends ChangeNotifier>
    on N {
  /// Create a [SimpleControllerDependency] widget to listen to the controller.
  Widget build<S>({
    required S Function(N value) select,
    Function(S prev, S next)? listen,
    required Widget Function(BuildContext context, S value) builder,
  }) {
    return _SimpleControllerSelector(
      controller: this,
      select: select,
      listen: listen,
      builder: builder,
    );
  }
}

/// [SimpleControllerDependency] is a widget that listens to a [ChangeNotifier] and rebuilds when the value changes.
class SimpleControllerDependency<N extends ChangeNotifier, T>
    extends StatelessWidget {
  const SimpleControllerDependency({
    required this.controller,
    required this.select,
    required this.listen,
    Key? key,
  }) : super(key: key);

  /// The [ChangeNotifier] to listen to.
  final N controller;

  /// The function to select the value from the [ChangeNotifier].
  final T Function(N value) select;

  /// The function to listen to the value changes.
  final void Function(T prev, T next)? listen;

  @override
  Widget build(BuildContext context) {
    return _SimpleControllerSelector(
      controller: controller,
      select: select,
      listen: listen,
      builder: (context, value) => SizedBox.shrink(),
    );
  }
}

/// [SimpleControllerProvider] is a widget that provides a [ChangeNotifier] to its children.
class SimpleControllerProvider<N extends ChangeNotifier>
    extends StatefulWidget {
  const SimpleControllerProvider({
    required this.create,
    this.child,
    this.dependencies,
    Key? key,
  }) : super(key: key);

  /// Create a [SimpleControllerProvider] widget that provides a [ChangeNotifier] to its children.
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

  SimpleControllerProvider<N> _wrapWith<T extends ChangeNotifier>({
    required Widget? child,
  }) {
    return SimpleControllerProvider<N>(
      create: create,
      dependencies: dependencies,
      child: child,
    );
  }

  static N _of<N extends ChangeNotifier>(BuildContext context) {
    return context
        .findAncestorStateOfType<_SimpleControllerProviderState<N>>()!
        ._controller;
  }

  /// The function to create the [ChangeNotifier].
  final N Function(BuildContext context) create;

  /// The function to get the dependencies of the [ChangeNotifier].
  final List<SimpleControllerDependency> Function(
    BuildContext context,
    N controller,
  )? dependencies;

  /// The child widget to wrap with the [ChangeNotifier].
  final Widget? child;

  @override
  State<SimpleControllerProvider<N>> createState() =>
      _SimpleControllerProviderState<N>();
}

class _SimpleControllerProviderState<N extends ChangeNotifier>
    extends State<SimpleControllerProvider<N>> {
  late final N _controller = widget.create(context);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dependencies = widget.dependencies?.call(context, _controller);
    final child = widget.child ?? const SizedBox.shrink();

    if (dependencies != null) {
      return Stack(
        textDirection: TextDirection.ltr,
        children: [
          for (final dependency in dependencies) dependency,
          child,
        ],
      );
    }

    return child;
  }
}

class _SimpleControllerSelector<T, N extends ChangeNotifier>
    extends StatefulWidget {
  const _SimpleControllerSelector({
    required this.controller,
    required this.select,
    this.listen,
    required this.builder,
    Key? key,
  }) : super(key: key);

  final N controller;
  final T Function(N value) select;
  final void Function(T prev, T next)? listen;
  final Widget Function(BuildContext context, T value) builder;

  @override
  State<_SimpleControllerSelector<T, N>> createState() =>
      _SimpleControllerSelectorState<T, N>();
}

class _SimpleControllerSelectorState<T, N extends ChangeNotifier>
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
    return widget.builder(context, _value);
  }
}
