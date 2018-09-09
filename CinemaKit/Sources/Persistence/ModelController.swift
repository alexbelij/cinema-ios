protocol ModelController {
  associatedtype ModelType
  associatedtype ErrorType

  func initializeWithDefaultValue()
  func access(onceLoaded modelHandler: @escaping (ModelType) -> Void,
              whenUnableToLoad errorHandler: @escaping (ErrorType) -> Void)
  func access(_ modelHandler: @escaping (ModelType) -> Void)
  func requestReload()
  func persist()
  func clear()
}

private class _AnyModelControllerBoxBase<ModelType, ErrorType>: ModelController {
  private func _abstract() -> Never { fatalError("must be overridden") }

  func initializeWithDefaultValue() {
    _abstract()
  }

  func access(onceLoaded modelHandler: @escaping (ModelType) -> Void,
              whenUnableToLoad errorHandler: @escaping (ErrorType) -> Void) {
    _abstract()
  }

  func access(_ modelHandler: @escaping (ModelType) -> Void) {
    _abstract()
  }

  func requestReload() {
    _abstract()
  }

  func persist() {
    _abstract()
  }

  func clear() {
    _abstract()
  }
}

private class _ModelControllerBox<Base: ModelController>:
    _AnyModelControllerBoxBase<Base.ModelType, Base.ErrorType> {
  private let base: Base

  init(_ base: Base) {
    self.base = base
  }

  override func initializeWithDefaultValue() {
    base.initializeWithDefaultValue()
  }

  override func access(onceLoaded modelHandler: @escaping (Base.ModelType) -> Void,
                       whenUnableToLoad errorHandler: @escaping (Base.ErrorType) -> Void) {
    base.access(onceLoaded: modelHandler, whenUnableToLoad: errorHandler)
  }

  override func access(_ modelHandler: @escaping (Base.ModelType) -> Void) {
    base.access(modelHandler)
  }

  override func requestReload() {
    base.requestReload()
  }

  override func persist() {
    base.persist()
  }

  override func clear() {
    base.clear()
  }
}

public class AnyModelController<ModelType, ErrorType>: ModelController {
  private let box: _AnyModelControllerBoxBase<ModelType, ErrorType>

  init<X: ModelController>(_ base: X) where X.ModelType == ModelType, X.ErrorType == ErrorType {
    self.box = _ModelControllerBox(base)
  }

  func initializeWithDefaultValue() {
    box.initializeWithDefaultValue()
  }

  func access(onceLoaded modelHandler: @escaping (ModelType) -> Void,
              whenUnableToLoad errorHandler: @escaping (ErrorType) -> Void) {
    box.access(onceLoaded: modelHandler, whenUnableToLoad: errorHandler)
  }

  func access(_ modelHandler: @escaping (ModelType) -> Void) {
    box.access(modelHandler)
  }

  func requestReload() {
    box.requestReload()
  }

  func persist() {
    box.persist()
  }

  func clear() {
    box.clear()
  }
}
