import Testing

@testable import KeepMeUpCore

/// Verifies GitHub tag parsing and deterministic semantic-version ordering.
@Suite("Semantic versions")
struct SemanticVersionTests {
  /// Confirms the common leading `v` used by GitHub tags is accepted.
  @Test("Parses a leading v")
  func testParsesLeadingV() {
    #expect(SemanticVersion("v1.2.3")?.components == [1, 2, 3])
  }

  /// Confirms a larger numeric component is treated as a newer version.
  @Test("Compares numeric components")
  func testComparesNumericComponents() {
    #expect(SemanticVersion("1.9.9")! < SemanticVersion("1.10.0")!)
  }

  /// Confirms omitted trailing components compare as zero.
  @Test("Treats missing components as zero")
  func testTreatsMissingComponentsAsZero() {
    #expect(SemanticVersion("1.2") == SemanticVersion("1.2.0"))
  }

  /// Confirms malformed release tags are rejected rather than silently miscompared.
  @Test("Rejects malformed versions")
  func testRejectsMalformedVersion() {
    #expect(SemanticVersion("release-one") == nil)
  }
}
