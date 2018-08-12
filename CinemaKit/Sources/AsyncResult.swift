public enum AsyncResult<Value, ErrorType: Error> {
  case failure(ErrorType)
  case success(Value)

  public var isFailure: Bool {
    switch self {
      case .failure: return true
      case .success: return false
    }
  }

  public var isSuccess: Bool {
    switch self {
      case .failure: return false
      case .success: return true
    }
  }

  public var error: ErrorType? {
    switch self {
      case let .failure(error): return error
      case .success: return nil
    }
  }

  public var value: Value? {
    switch self {
      case .failure: return nil
      case let .success(value): return value
    }
  }
}
