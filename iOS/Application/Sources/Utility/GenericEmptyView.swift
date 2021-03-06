import UIKit

class GenericEmptyView: UIView {
  private var button: UIButton?
  private var buttonAction: (() -> Void)?

  override init(frame: CGRect) {
    super.init(frame: frame)
  }

  convenience init(accessory accessoryConfig: AccessoryConfig = .none,
                   description textConfig: TextConfig = .none,
                   action buttonConfig: ButtonConfig = .none) {
    self.init()
    self.configure(accessory: accessoryConfig, description: textConfig, action: buttonConfig)
  }

  required init?(coder aDecoder: NSCoder) {
    fatalError("GenericEmptyView must be initialized using GenericEmptyView(frame:)")
  }

  func configure(accessory accessoryConfig: AccessoryConfig = .none,
                 description textConfig: TextConfig = .none,
                 action buttonConfig: ButtonConfig = .none) {
    if let button = self.button {
      button.removeTarget(self, action: #selector(buttonTapped), for: .touchUpInside)
      self.button = nil
      self.buttonAction = nil
    }
    for subview in subviews {
      subview.removeFromSuperview()
    }
    let stackView = setUpStackView()
    setUpAccessory(accessoryConfig, in: stackView)
    setUpText(textConfig, in: stackView)
    setUpButton(buttonConfig, in: stackView)
  }

  private func setUpStackView() -> UIStackView {
    let stackView = UIStackView()
    stackView.translatesAutoresizingMaskIntoConstraints = false
    stackView.axis = .vertical
    stackView.alignment = .center
    stackView.distribution = .fill
    stackView.spacing = 8.0
    addSubview(stackView)
    NSLayoutConstraint.activate(
        [
          stackView.centerXAnchor.constraint(equalTo: safeAreaLayoutGuide.centerXAnchor),
          stackView.centerYAnchor.constraint(equalTo: safeAreaLayoutGuide.centerYAnchor),
          stackView.widthAnchor.constraint(equalTo: safeAreaLayoutGuide.widthAnchor, multiplier: 0.66)
        ]
    )
    return stackView
  }

  private func setUpAccessory(_ config: AccessoryConfig, in stackView: UIStackView) {
    switch config {
      case .none: break
      case let .image(image):
        let imageView = UIImageView(image: image)
        imageView.contentMode = .scaleAspectFit
        stackView.addArrangedSubview(imageView)
      case .activityIndicator:
        let indicatorView = UIActivityIndicatorView(style: .gray)
        indicatorView.startAnimating()
        stackView.addArrangedSubview(indicatorView)
    }
  }

  private func setUpText(_ config: TextConfig, in stackView: UIStackView) {
    switch config {
      case .none: break
      case let .basic(text):
        let titleLabel = makeCenteredMultiLineLabel(text: text)
        titleLabel.textColor = .secondaryText
        stackView.addArrangedSubview(titleLabel)
      case let .detailed(title, message):
        let titleLabel = makeCenteredMultiLineLabel(text: title)
        titleLabel.textColor = .secondaryText
        titleLabel.font = UIFont.boldSystemFont(ofSize: titleLabel.font.pointSize)
        stackView.addArrangedSubview(titleLabel)
        let messageLabel = makeCenteredMultiLineLabel(text: message)
        messageLabel.textColor = .secondaryText
        messageLabel.font = UIFont.systemFont(ofSize: UIFont.systemFontSize)
        stackView.addArrangedSubview(messageLabel)
    }
  }

  private func makeCenteredMultiLineLabel(text: String) -> UILabel {
    let label = UILabel()
    label.textAlignment = .center
    label.numberOfLines = 0
    label.text = text
    return label
  }

  private func setUpButton(_ config: ButtonConfig, in stackView: UIStackView) {
    switch config {
      case .none: break
      case let .button(title, action):
        stackView.addArrangedSubview(spacingView(ofHeight: 12))
        let button = UIButton(type: .roundedRect)
        button.setTitle(title, for: .normal)
        button.layer.borderWidth = 1.0
        button.layer.borderColor = button.tintColor.cgColor
        button.layer.cornerRadius = 5.0
        button.contentEdgeInsets = UIEdgeInsets(top: 6, left: 8, bottom: 6, right: 8)
        button.addTarget(self, action: #selector(buttonTapped), for: .touchUpInside)
        stackView.addArrangedSubview(button)
        self.button = button
        self.buttonAction = action
    }
  }

  private func spacingView(ofHeight height: CGFloat) -> UIView {
    let view = UIView()
    view.translatesAutoresizingMaskIntoConstraints = false
    view.heightAnchor.constraint(equalToConstant: height).isActive = true
    return view
  }

  @objc
  private func buttonTapped() {
    guard let action = self.buttonAction else { preconditionFailure("button action has not been set") }
    action()
  }

  enum AccessoryConfig {
    case none
    case image(UIImage)
    case activityIndicator
  }

  enum TextConfig {
    case none
    case basic(String)
    case detailed(title: String, message: String)
  }

  enum ButtonConfig {
    case none
    case button(title: String, action: () -> Void)
  }
}
