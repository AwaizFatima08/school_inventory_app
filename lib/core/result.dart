/// A typed outcome for recoverable I/O: either [Ok] with a value or [Err]
/// with an [AppFailure]. Repository writes return this instead of throwing.
sealed class Result<T> {
  const Result();
}

final class Ok<T> extends Result<T> {
  const Ok(this.value);
  final T value;
}

final class Err<T> extends Result<T> {
  const Err(this.failure);
  final AppFailure failure;
}

/// Stable failure codes; [message] is the user-facing explanation.
enum FailureCode {
  permissionDenied,
  notFound,
  insufficientStock,
  invalidState,
  invalidInput,
  network,
  auth,
  unknown,
}

class AppFailure {
  const AppFailure(this.code, this.message);
  final FailureCode code;
  final String message;

  @override
  String toString() => message;
}
