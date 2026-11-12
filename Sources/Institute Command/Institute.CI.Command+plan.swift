import Console
import GitHub_Standard
import Institute_CI_Contract
import Institute_CI_Model
import Institute_Model
import Institute_Repository_Policy
import JSON

import struct Swift.String

extension Institute.CI.Command {

    static func plan(_ rest: [Swift.String]) {
        let subjectRepository = value("--subject-repository", in: rest)
        let lintBundle = Institute.Organization.lintBundle(forRepository: GitHub_Standard::GitHub.Repository.Slug(subjectRepository))
        let deviation = Institute.Repository.Policy.Deviation.read(root: value("--workspace", in: rest))
        let timeout: Institute.CI.Timeout
        do {
            timeout = try Institute.CI.Timeout(metadata: deviation.timeoutMinutes)
        } catch {
            refuse(
                "plan refused: timeout-minutes in \(Institute.Repository.Policy.Deviation.path) is "
                    + "'\(deviation.timeoutMinutes)'; it must be a whole number of minutes from 1 to "
                    + "\(Institute.CI.Timeout.maximum)."
            )
        }

        let today = value("--today", in: rest)
        var deschedule: [Swift.String: Swift.String] = [:]
        let nightlyImage = value("--nightly-main-image", in: rest)
        if !nightlyImage.isEmpty {
            do {
                let nightly = Institute.CI.NightlyException(
                    image: nightlyImage,
                    upstreamIssue: value("--nightly-main-upstream-issue", in: rest),
                    recheck: value("--nightly-main-recheck", in: rest)
                )
                if case .expired = try nightly.disposition(
                    today: today,
                    subjectRepository: value("--subject-repository", in: rest)
                ) {
                    deschedule[
                        Institute.CI.NightlyException
                            .classifiedLeg.id
                    ] = "nightly-exception-expired"
                }
            } catch {
                refuse("plan refused: \(error)")
            }
        }

        let swiftVersion = value("--swift-version", in: rest)
        let floorImage = value("--release-floor-image", in: rest)
        let linuxImage: Swift.String
        do {
            linuxImage = try Institute.CI.ReleaseFloorException.resolve(
                swiftVersion: swiftVersion,
                exception: floorImage.isEmpty
                    ? nil
                    : Institute.CI.ReleaseFloorException(
                        swiftVersion: swiftVersion,
                        image: floorImage,
                        upstreamRelease: value("--release-floor-upstream-release", in: rest),
                        recheck: value("--release-floor-recheck", in: rest)
                    ),
                today: today
            )
        } catch {
            refuse("plan refused: \(error)")
        }

        let event = value("--event", in: rest)
        let plan: Institute.CI.Plan
        do {
            plan = try Institute.CI.Plan(
                forcedTier: value("--tier", in: rest),
                ref: value("--ref", in: rest),
                headMessage: value("--head-message", in: rest),
                event: event,
                platformSupport: deviation.platforms,
                lintBundle: lintBundle,
                packageContentChanged:
                    Institute.CI.Package.Diff
                    .packageContentChanged(
                        event: event,
                        eventPath: value("--event-path", in: rest),
                        repository: value("--workflow-repository", in: rest),
                        workspace: value("--workspace", in: rest)
                    ),
                deschedule: deschedule
            )
        } catch {
            refuse("plan refused: \(error)")
        }

        emit([
            "tier": plan.tier.rawValue.json,
            "legs": plan.legs.map(\.id).joined(separator: ",").json,
            "gating": plan.gating.map(\.id).joined(separator: ",").json,
            "package-content-changed": plan.packageContentChanged.json,
            "linux-image": linuxImage.json,
            "lint-bundle": lintBundle.json,
            "embedded-target": deviation.embeddedTarget.json,
            "timeout-minutes": Swift.String(timeout.minutes).json,
            "descheduled": plan.descheduled
                .map { "\($0.leg.id)=\($0.reason)" }
                .joined(separator: ",").json,
        ])
    }

    static func aggregate(_ rest: [Swift.String]) {
        let needsJSON = value("--needs-json", in: rest)
        guard !needsJSON.isEmpty else {
            refuse("aggregate requires --needs-json '{job: {result: ...}}'")
        }
        let needs = decoded(needsJSON, "aggregate --needs-json")
        func result(of job: Swift.String) -> Swift.String {
            guard let record = needs[job] else { return "" }
            return Swift.String(record["result"])
        }
        var results: [Swift.String: Swift.String] = [:]
        for job in needs.keys where job != "plan" {
            results[job] = result(of: job)
        }
        let verdict = Institute.CI.AggregateVerdict(
            planResult: result(of: "plan"),
            results: results,
            gating: value("--gating", in: rest).split(separator: ",").map(Swift.String.init),
            subjectRepository: value("--subject-repository", in: rest),
            subjectSha: value("--subject-sha", in: rest),
            tier: value("--tier", in: rest),
            requireFullTier: rest.contains("--require-full-tier"),
            packageContentChanged: value("--package-content-changed", in: rest) != "false",
            descheduled: value("--descheduled", in: rest)
                .split(separator: ",")
                .map { Swift.String($0.split(separator: "=")[0]) }
        )
        for finding in verdict.findings {
            Console.Output.error("institute ci: \(finding)")
        }
        print(verdict.pass ? "pass" : "fail")
        terminate(verdict.pass ? 0 : 1)
    }
}
