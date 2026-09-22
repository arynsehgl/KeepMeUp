import Foundation

/// Parses and compares the numeric core of semantic versions used by GitHub releases.
public struct SemanticVersion: Comparable, Equatable, Sendable {
  /// Numeric version components padded during comparison when versions have different lengths.
  public let components: [Int]

  /// Creates a semantic version from values such as `v1.2.3` or `1.2.3`.
  public init?(_ rawValue: String) {
    let trimmedValue = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
    let withoutPrefix =
      trimmedValue.first?.lowercased() == "v"
      ? String(trimmedValue.dropFirst())
      : trimmedValue
    let numericCore = withoutPrefix.split(separator: "-", maxSplits: 1).first.map(String.init) ?? ""
    let parsedComponents = numericCore.split(separator: ".").compactMap { Int($0) }

    guard !parsedComponents.isEmpty,
      parsedComponents.count == numericCore.split(separator: ".").count
    else {
      return nil
    }

    components = parsedComponents
  }

  /// Treats omitted trailing components as zero when determining version equality.
  public static func == (lhs: SemanticVersion, rhs: SemanticVersion) -> Bool {
    !(lhs < rhs) && !(rhs < lhs)
  }

  /// Compares versions component by component while treating omitted trailing components as zero.
  public static func < (lhs: SemanticVersion, rhs: SemanticVersion) -> Bool {
    let componentCount = max(lhs.components.count, rhs.components.count)

    for index in 0..<componentCount {
      let leftComponent = index < lhs.components.count ? lhs.components[index] : 0
      let rightComponent = index < rhs.components.count ? rhs.components[index] : 0

      if leftComponent != rightComponent {
        return leftComponent < rightComponent
      }
    }

    return false
  }
}
