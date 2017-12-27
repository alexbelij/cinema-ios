import UIKit

class ScrimView: UIView {
  private let scrimLayer = CAGradientLayer()

  override init(frame: CGRect) {
    super.init(frame: frame)
    commonInit()
  }

  required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
    commonInit()
  }

  private func commonInit() {
    let opacity: CGFloat = 0.3
    scrimLayer.colors = [UIColor.black.withAlphaComponent(opacity).cgColor,
                         UIColor.black.withAlphaComponent(opacity / 2.0).cgColor,
                         UIColor.clear.cgColor]
    scrimLayer.locations = [0, 0.3, 1]
    self.layer.addSublayer(scrimLayer)
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    scrimLayer.frame = self.bounds
  }
}
