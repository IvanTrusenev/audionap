import Foundation
import Testing

@testable import Shared

struct ActivityWindowTests {

    @Test func emptyWindowHasNoFraction() {
        let window = ActivityWindow()
        #expect(window.activeFraction(at: 100) == nil)
        #expect(!window.isPlaying(at: 100))
    }

    @Test func sustainedActivityFillsTheWindow() {
        var window = ActivityWindow()
        var now = 0.0
        while now < 10.0 {
            window.mark(active: true, at: now)
            now += 0.1
        }
        #expect(window.activeFraction(at: 10) == 1.0)
        #expect(window.isPlaying(at: 10))
    }

    @Test func oneSecondBurstIsTenPercent() {
        var window = ActivityWindow()
        var now = 0.0
        while now < 10.0 {
            window.mark(active: now < 1.0, at: now)
            now += 0.1
        }
        let fraction = window.activeFraction(at: 10)
        #expect(fraction != nil)
        #expect(abs(fraction! - 0.1) < 0.02)
        #expect(!window.isPlaying(at: 10))
    }

    @Test func staleSlotsAreIgnored() {
        var window = ActivityWindow()
        var now = 0.0
        while now < 10.0 {
            window.mark(active: true, at: now)
            now += 0.1
        }
        // Ten seconds of silence after the activity: the window ages out.
        while now < 20.0 {
            window.mark(active: false, at: now)
            now += 0.1
        }
        #expect(window.activeFraction(at: 20) == 0.0)
    }

    @Test func halfWindowActiveReadsAsPlaying() {
        var window = ActivityWindow()
        var now = 0.0
        while now < 10.0 {
            window.mark(active: now < 5.0, at: now)
            now += 0.1
        }
        #expect(window.isPlaying(at: 10))
    }
}
