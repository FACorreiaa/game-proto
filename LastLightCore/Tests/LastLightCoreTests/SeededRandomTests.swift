import Testing
@testable import LastLightCore

@Test func sameSeedSameSequence() {
    var a = SeededRandom(seed: 42), b = SeededRandom(seed: 42)
    #expect((0..<100).map { _ in a.next() } == (0..<100).map { _ in b.next() })
}

@Test func differentSeedsDiffer() {
    var a = SeededRandom(seed: 1), b = SeededRandom(seed: 2)
    #expect(a.next() != b.next())
}

@Test func knownFirstValue() {
    var r = SeededRandom(seed: 0)
    #expect(r.next() == 0xE220A8397B1DCDAF) // SplitMix64 reference output for seed 0
}
