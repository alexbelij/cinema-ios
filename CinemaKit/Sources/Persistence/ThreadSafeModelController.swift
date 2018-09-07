import Dispatch

class ThreadSafeModelController<ModelType, ErrorType> {
  private let queue: DispatchQueue
  private var suspendedCalls = [((ModelType) -> Void, (ErrorType) -> Void)]()
  private var isLoading = false
  private var model: ModelType?

  init(label: String) {
    queue = DispatchQueue(label: label)
  }

  func initializeWithDefaultValue() {
    queue.async {
      guard self.model == nil else { fatalError("model has already been initialized") }
      self.model = self.makeWithDefaultValue()
    }
  }

  func makeWithDefaultValue() -> ModelType {
    fatalError("must be overridden")
  }

  func access(onceLoaded modelHandler: @escaping (ModelType) -> Void,
              whenUnableToLoad errorHandler: @escaping (ErrorType) -> Void) {
    queue.async {
      if let model = self.model {
        modelHandler(model)
      } else {
        self.suspendedCalls.append((modelHandler, errorHandler))
        if !self.isLoading {
          self.isLoading = true
          self.loadModel()
        }
      }
    }
  }

  func access(_ modelHandler: @escaping (ModelType) -> Void) {
    queue.async {
      if let model = self.model {
        modelHandler(model)
      } else {
        fatalError("access(onceLoaded:whenUnableToLoad:) has not been called before")
      }
    }
  }

  func loadModel() {
    fatalError("must be overridden")
  }

  func abortLoading(with error: ErrorType) {
    queue.async {
      self.finishLoading(model: nil, error: error)
    }
  }

  func completeLoading(with model: ModelType) {
    queue.async {
      self.finishLoading(model: model, error: nil)
    }
  }

  private func finishLoading(model: ModelType?, error: ErrorType?) {
    dispatchPrecondition(condition: DispatchPredicate.onQueue(queue))
    self.isLoading = false
    if let model = model {
      self.model = model
      for (modelHandler, _) in suspendedCalls {
        modelHandler(model)
      }
    } else if let error = error {
      for (_, errorHandler) in suspendedCalls {
        errorHandler(error)
      }
    }
    suspendedCalls.removeAll()
  }

  func requestReload() {
    queue.async {
      self.model = nil
    }
  }

  func persist() {
    dispatchPrecondition(condition: DispatchPredicate.onQueue(queue))
    if let model = self.model {
      persist(model)
    }
  }

  func persist(_ model: ModelType) {
    fatalError("must be overridden")
  }

  func clear() {
    fatalError("must be overridden")
  }
}
