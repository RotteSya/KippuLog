import Testing
@testable import KippuLog

struct SmokeTests {
    @Test @MainActor func designTokensExist() {
        _ = Ink.shu
        _ = Typo.mincho(20)
    }
}
