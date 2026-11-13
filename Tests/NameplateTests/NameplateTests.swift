import Testing

@testable import Nameplate

@Test func removeAfterMatchesExactSeparator() {
    let rule = WindowTitleRule()
    #expect(
        rule.apply(to: "cardgames — SEEP_RULE_DIFFERENCES.md")
            == "cardgames — SEEP_RULE_DIFFERENCES.md")
    #expect(rule.apply(to: "cardgames - SEEP_RULE_DIFFERENCES.md") == "cardgames")
    #expect(WindowTitleProcessing.separator(in: "cardgames — SEEP_RULE_DIFFERENCES.md") == " — ")
}
