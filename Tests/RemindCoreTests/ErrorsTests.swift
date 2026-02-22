import Testing

@testable import RemindCore

@MainActor
struct ErrorsTests {
  @Test("Error descriptions")
  func descriptions() {
    #expect(RemindCoreError.accessDenied.localizedDescription.contains("denied"))
    #expect(RemindCoreError.accessRestricted.localizedDescription.contains("restricted"))
    #expect(RemindCoreError.writeOnlyAccess.localizedDescription.contains("write-only"))
    #expect(RemindCoreError.listNotFound("Work").localizedDescription.contains("Work"))
    #expect(RemindCoreError.reminderNotFound("abc").localizedDescription.contains("abc"))
    #expect(RemindCoreError.ambiguousIdentifier("a", matches: ["1", "2"]).localizedDescription.contains("matches"))
    #expect(RemindCoreError.invalidIdentifier("x").localizedDescription.contains("Invalid identifier"))
    #expect(RemindCoreError.invalidDate("bad").localizedDescription.contains("Invalid date"))
    #expect(RemindCoreError.unsupported("nope").localizedDescription.contains("nope"))
    #expect(RemindCoreError.operationFailed("fail").localizedDescription.contains("fail"))
    #expect(
      RemindCoreError.eventKitError("save reminder", detail: "timeout").localizedDescription
        .contains("save reminder"))
  }

  @Test("Error messages include recovery hints")
  func recoveryHints() {
    #expect(RemindCoreError.accessDenied.localizedDescription.contains("remindctl authorize"))
    #expect(RemindCoreError.accessRestricted.localizedDescription.contains("administrator"))
    #expect(RemindCoreError.writeOnlyAccess.localizedDescription.contains("Full Access"))
    #expect(RemindCoreError.listNotFound("X").localizedDescription.contains("remindctl list"))
    #expect(RemindCoreError.reminderNotFound("X").localizedDescription.contains("remindctl show"))
    #expect(RemindCoreError.invalidDate("X").localizedDescription.contains("YYYY-MM-DD"))
    #expect(
      RemindCoreError.eventKitError("save", detail: "err").localizedDescription
        .contains("remindctl status"))
  }
}
