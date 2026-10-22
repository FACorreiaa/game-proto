import Foundation
import LastLightCore

// Usage: lastlight-sim [--trials N] [--seed S] [--margin M]
var trials = 1000, seed: UInt64 = 1, margin = 0.15
var args = CommandLine.arguments.dropFirst().makeIterator()
while let flag = args.next() {
    guard let value = args.next() else { break }
    switch flag {
    case "--trials": trials = Int(value) ?? trials
    case "--seed": seed = UInt64(value) ?? seed
    case "--margin": margin = Double(value) ?? margin
    default: FileHandle.standardError.write(Data("unknown flag \(flag)\n".utf8))
    }
}

let report = BalanceRunner.run(pool: SamplePool.units, bonds: SamplePool.bonds, bondLevel: 1, stage: .one,
                               enemy: SamplePool.enemy, teamSize: 5, trials: trials, seed: seed)

print("trials \(report.trials)  overall \(String(format: "%.3f", report.overallWinRate))")
for (unit, rate) in report.unitWinRates.sorted(by: { $0.value > $1.value }) {
    let delta = rate - report.overallWinRate
    print("\(unit.padding(toLength: 14, withPad: " ", startingAt: 0))  \(String(format: "%.3f", rate))  \(String(format: "%+.3f", delta))")
}
for (bond, rate) in report.bondWinRates.sorted(by: { $0.key < $1.key }) {
    print("bond \(bond)  \(String(format: "%.3f", rate))")
}
let dominant = report.dominantUnits(margin: margin)
print("DOMINANT: \(dominant.isEmpty ? "none" : dominant.joined(separator: ", "))")
