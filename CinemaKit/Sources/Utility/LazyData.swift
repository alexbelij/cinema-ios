import Dispatch

class LazyData<DataType, ErrorType> {
  private let queue: DispatchQueue
  private var suspendedCalls = [((DataType) -> Void, (ErrorType) -> Void)]()
  private var isLoading = false
  private var data: DataType?

  init(label: String) {
    queue = DispatchQueue(label: label)
  }

  func initializeWithDefaultValue() {
    queue.async {
      guard self.data == nil else { fatalError("data has already been initialized") }
      self.data = self.makeWithDefaultValue()
    }
  }

  func makeWithDefaultValue() -> DataType {
    fatalError("must be overridden")
  }

  func access(onceLoaded dataHandler: @escaping (DataType) -> Void,
              whenUnableToLoad errorHandler: @escaping (ErrorType) -> Void) {
    queue.async {
      if let data = self.data {
        dataHandler(data)
      } else {
        self.suspendedCalls.append((dataHandler, errorHandler))
        if !self.isLoading {
          self.isLoading = true
          self.loadData()
        }
      }
    }
  }

  func access(_ dataHandler: @escaping (DataType) -> Void) {
    queue.async {
      if let data = self.data {
        dataHandler(data)
      } else {
        fatalError("access(onceLoaded:whenUnableToLoad:) has not been called before")
      }
    }
  }

  func loadData() {
    fatalError("must be overridden")
  }

  func abortLoading(with error: ErrorType) {
    queue.async {
      self.finishLoading(data: nil, error: error)
    }
  }

  func completeLoading(with data: DataType) {
    queue.async {
      self.finishLoading(data: data, error: nil)
    }
  }

  private func finishLoading(data: DataType?, error: ErrorType?) {
    dispatchPrecondition(condition: DispatchPredicate.onQueue(queue))
    self.isLoading = false
    if let data = data {
      self.data = data
      for (dataHandler, _) in suspendedCalls {
        dataHandler(data)
      }
    } else if let error = error {
      for (_, errorHandler) in suspendedCalls {
        errorHandler(error)
      }
    }
    suspendedCalls.removeAll()
  }

  func persist() {
    dispatchPrecondition(condition: DispatchPredicate.onQueue(queue))
    if let data = self.data {
      persist(data)
    }
  }

  func persist(_ data: DataType) {
    fatalError("must be overridden")
  }

  func clear() {
    fatalError("must be overridden")
  }
}
