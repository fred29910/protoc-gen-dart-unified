/// A cancellation token that can be used to signal cancellation to one or more
/// operations.
///
/// Similar to CancellationToken in .NET or AbortController in JavaScript.
/// The token is triggered by calling [cancel], after which [isCancelled] returns
/// true and any registered [onCancel] callbacks are invoked.
class RpcCancelToken {
  bool _isCancelled = false;
  final List<void Function()> _callbacks = [];
  Object? _cancelledReason;

  /// Whether this token has been cancelled.
  bool get isCancelled => _isCancelled;

  /// The reason for cancellation (if any).
  Object? get cancelledReason => _cancelledReason;

  /// Registers a callback that will be invoked when the token is cancelled.
  ///
  /// If the token is already cancelled, the callback is invoked immediately.
  void onCancel(void Function() callback) {
    if (_isCancelled) {
      callback();
      return;
    }
    _callbacks.add(callback);
  }

  /// Cancels the token, invoking all registered callbacks.
  void cancel([Object? reason]) {
    if (_isCancelled) return;
    _isCancelled = true;
    _cancelledReason = reason;
    for (final cb in _callbacks) {
      cb();
    }
    _callbacks.clear();
  }

  /// Throws an [RpcCancelledException] if the token has been cancelled.
  ///
  /// Useful for use in async operations that need to check cancellation
  /// between await points.
  void throwIfCancelled() {
    if (_isCancelled) {
      throw RpcCancelledException(_cancelledReason);
    }
  }
}

/// Exception thrown when an operation is cancelled via [RpcCancelToken].
class RpcCancelledException implements Exception {
  final Object? reason;

  const RpcCancelledException([this.reason]);

  @override
  String toString() =>
      'RpcCancelledException${reason != null ? ': $reason' : ''}';
}
