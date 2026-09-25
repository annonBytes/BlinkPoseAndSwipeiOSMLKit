import XCTest
@testable import BlinkPoseAndSwipeiOSMLKit

final class ModelTests: XCTestCase {

    func testLibraryFromBeforeMIDISupportStillDecodes() throws {
        let id = UUID()
        let json = """
        [{"id":"\(id.uuidString)","title":"Old","fileName":"a.pdf","dateAdded":0,"preferredModality":"tap","isBuiltIn":false}]
        """
        let decoder = JSONDecoder()
        let scores = try decoder.decode([Score].self, from: Data(json.utf8))
        XCTAssertEqual(scores.first?.title, "Old")
        XCTAssertNil(scores.first?.midiFileName)
        XCTAssertNil(scores.first?.pageMarks)
    }

    func testScoreRoundTrips() throws {
        var score = Score(title: "Piece", fileName: "p.pdf", preferredModality: .wink)
        score.pageMarks = [PageMark(page: 1, beat: 16.5)]
        let decoded = try JSONDecoder().decode(Score.self, from: JSONEncoder().encode(score))
        XCTAssertEqual(decoded, score)
    }

    func testOnlyUnobtrusiveModalitiesAreSafeForPerformance() {
        let safe = Set(ModalityKind.allCases.filter(\.isPerformanceSafe))
        XCTAssertEqual(safe, [.tap, .swipe, .hardwareKey])
    }

    func testFaceModalitiesHaveConfigsAndOthersDoNot() {
        for kind in ModalityKind.allCases {
            XCTAssertEqual(kind.faceConfig != nil, !kind.isPerformanceSafe, "\(kind)")
        }
    }

    func testEveryModalityHasAnIcon() {
        for kind in ModalityKind.allCases {
            XCTAssertNotNil(UIImage(named: "modality-\(kind.rawValue)", in: Bundle(for: GestureFeedbackView.self), with: nil), "\(kind)")
        }
    }

    func testPageTransitionPreferencesHaveSaneDefaults() {
        for key in ["PageTransition.style", "PageTransition.axis", "PageTransition.duration"] {
            UserDefaults.standard.removeObject(forKey: key)
        }
        XCTAssertEqual(PageTransitionStyle.current, .curl)
        XCTAssertEqual(PageTransitionAxis.current, .horizontal)
        XCTAssertEqual(PageTransitionSpeed.duration, 0.45, accuracy: 0.001)
    }

    func testAutoScrollSpeedIsClamped() {
        AutoScroller.speed = 10_000
        XCTAssertEqual(AutoScroller.speed, AutoScroller.speedRange.upperBound)
        AutoScroller.speed = -5
        XCTAssertEqual(AutoScroller.speed, AutoScroller.speedRange.lowerBound)
        UserDefaults.standard.removeObject(forKey: "AutoScroll.speed")
    }

    func testEveryLanguageTranslatesTheSameKeys() throws {
        let bundle = Bundle(for: GestureFeedbackView.self)
        func keys(_ lang: String) throws -> Set<String> {
            let path = try XCTUnwrap(bundle.path(forResource: "Localizable", ofType: "strings", inDirectory: nil, forLocalization: lang))
            return Set((NSDictionary(contentsOfFile: path) as? [String: String] ?? [:]).keys)
        }
        let english = try keys("en")
        for lang in ["de", "fr", "es"] {
            XCTAssertEqual(english.subtracting(try keys(lang)), [], "\(lang) is missing keys")
        }
    }
}
