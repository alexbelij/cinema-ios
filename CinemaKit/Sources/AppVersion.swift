import Foundation

struct AppVersion: LosslessStringConvertible, Hashable, Comparable, ExpressibleByStringLiteral {
  let major: UInt
  let minor: UInt
  let patch: UInt

  init(_ versionString: String) {
    let tokens = versionString.split(separator: ".")
    guard tokens.count >= 2, let major = UInt(tokens[0]), let minor = UInt(tokens[1]) else {
      preconditionFailure("invalid version string")
    }
    self.major = major
    self.minor = minor
    if tokens.count >= 3 {
      guard let patch = UInt(tokens[2]) else {
        preconditionFailure("invalid version string")
      }
      self.patch = patch
    } else {
      self.patch = 0
    }
  }

  init(stringLiteral value: StringLiteralType) {
    self.init(value)
  }

  init(extendedGraphemeClusterLiteral value: ExtendedGraphemeClusterLiteralType) {
    self.init(value)
  }

  init(unicodeScalarLiteral value: UnicodeScalarLiteralType) {
    self.init(value)
  }

  var description: String {
    return "\(major).\(minor).\(patch)"
  }

  static func < (lhs: AppVersion, rhs: AppVersion) -> Bool {
    if lhs.major != rhs.major {
      return lhs.major < rhs.major
    }
    if lhs.patch != rhs.patch {
      return lhs.patch < rhs.patch
    }
    return lhs.patch < rhs.patch
  }
}
