import XCTest

final class ListenUITests:XCTestCase {
    func testBrowseGroupsAndNativeRemoval() throws {
        let app = XCUIApplication(); app.launchArguments = ["--uitesting"]; app.launch()
        let book = app.buttons["book-Sample recording"]
        XCTAssertTrue(book.waitForExistence(timeout: 30))
        XCTAssertTrue(app.segmentedControls["librarySections"].waitForExistence(timeout: 10))
        app.buttons["Authors"].tap()
        XCTAssertTrue(app.staticTexts["Unknown author"].waitForExistence(timeout: 10))
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = "Browse authors"; shot.lifetime = .keepAlways; add(shot)
        app.buttons["Narrators"].tap()
        XCTAssertTrue(app.staticTexts["Not credited"].waitForExistence(timeout: 10))
        app.buttons["Books"].tap()
        book.swipeLeft()
        app.buttons["Remove"].firstMatch.tap()
        XCTAssertTrue(app.buttons["Remove from device"].waitForExistence(timeout: 10))
        app.buttons["Remove from device"].tap()
        XCTAssertTrue(app.buttons["emptyImport"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Try a free classic"].exists)
    }
    func testStoreCaptureWithFreeClassic() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["SOVO_STORE_CAPTURE"] == "1", "Explicit network capture run only")
        executionTimeAllowance = 600
        let app = XCUIApplication(); app.launch()
        let book = app.buttons["book-Alice’s Adventures in Wonderland"]
        if !book.waitForExistence(timeout: 5) {
            let classic = app.buttons["Try a free classic"]
            XCTAssertTrue(classic.waitForExistence(timeout: 20)); classic.tap()
            app.buttons["Add to library"].tap()
            XCTAssertTrue(book.waitForExistence(timeout: 300), "The public-domain classic must import through the real app")
        }
        func capture(_ name: String) {
            let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = "Store-" + name; shot.lifetime = .keepAlways; add(shot)
        }
        capture("Library")
        app.buttons["Authors"].tap()
        let author = app.buttons["category-Lewis Carroll"]
        XCTAssertTrue(author.waitForExistence(timeout: 15))
        capture("Authors")
        author.tap()
        _ = app.links["Wikipedia · biography & portrait credits"].waitForExistence(timeout: 30)
        capture("Author-profile")
        app.buttons["You"].firstMatch.tap()
        app.buttons["Library"].firstMatch.tap()
        app.buttons["Books"].tap()
        XCTAssertTrue(book.waitForExistence(timeout: 10)); book.tap()
        let pause = app.buttons["playerPlayPause"]
        XCTAssertTrue(pause.waitForExistence(timeout: 20)); XCTAssertEqual(pause.label, "Pause")
        capture("Player")
        app.buttons["Chapters"].firstMatch.tap()
        capture("Chapters")
        app.buttons["Done"].firstMatch.tap()
        pause.tap(); app.buttons["closePlayer"].tap()
        capture("Mini-player")
        book.swipeLeft(); app.buttons["Details"].firstMatch.tap()
        XCTAssertTrue(app.buttons["startListening"].waitForExistence(timeout: 15))
        capture("Book-details")
    }
    override func setUp() { super.setUp(); continueAfterFailure = false; executionTimeAllowance = 90 }
    func testLibraryPlayerAndSettings() throws {
        let app=XCUIApplication();app.launchArguments=["--uitesting"];app.launch()
        let book=app.buttons["book-Sample recording"]
        XCTAssertTrue(book.waitForExistence(timeout:30));book.tap()
        let play=app.buttons["playerPlayPause"];XCTAssertTrue(play.waitForExistence(timeout:15))
        XCTAssertEqual(play.label, "Pause")
        app.buttons["addBookmark"].tap();XCTAssertTrue(app.staticTexts["bookmarkSaved"].waitForExistence(timeout:5))
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Bookmarks (")).firstMatch.tap()
        let mark = app.buttons["userBookmark"].firstMatch
        XCTAssertTrue(mark.waitForExistence(timeout: 10)); mark.swipeRight()
        app.buttons["Edit note"].tap()
        let note = app.descendants(matching: .any).matching(identifier: "bookmarkNote").firstMatch
        XCTAssertTrue(note.waitForExistence(timeout: 10)); note.tap(); note.typeText(" My test note")
        app.buttons["Save"].tap()
        XCTAssertTrue(app.buttons["userBookmark"].firstMatch.waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["userBookmark"].firstMatch.label.contains("My test note"))
        app.buttons["closeBookmarks"].tap()
        let playerShot = XCTAttachment(screenshot: app.screenshot()); playerShot.name = "Player"; playerShot.lifetime = .keepAlways; add(playerShot)
        play.tap();app.buttons["closePlayer"].tap()
        XCTAssertTrue(app.buttons["miniPlayPause"].waitForExistence(timeout:10))
        let attachment=XCTAttachment(screenshot:app.screenshot());attachment.name="Player flow";attachment.lifetime = .keepAlways;add(attachment)
    }
    func testTabsRemainAccessibleAfterPlaybackStarts() throws {
        let app = XCUIApplication(); app.launchArguments = ["--uitesting"]; app.launch()
        let book = app.buttons["book-Sample recording"]
        XCTAssertTrue(book.waitForExistence(timeout: 30))
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: book)
        wait(for: [ready], timeout: 30); book.tap()
        let opened = app.buttons["closePlayer"].waitForExistence(timeout: 15)
        if !opened {
            let failure = XCTAttachment(screenshot: app.screenshot()); failure.name = "Book selection diagnostic"; failure.lifetime = .keepAlways; add(failure)
        }
        XCTAssertTrue(opened)
        app.buttons["closePlayer"].tap()
        for name in ["You", "Settings", "Library"] {
            let tab = app.buttons[name].firstMatch
            XCTAssertTrue(tab.waitForExistence(timeout: 10), name)
            XCTAssertTrue(tab.isHittable, name)
            tab.tap()
            if name == "You" {
                let page = XCTAttachment(screenshot: app.screenshot()); page.name = "You"; page.lifetime = .keepAlways; add(page)
            }
        }
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "Mini-player and accessible navigation"
        shot.lifetime = .keepAlways; add(shot)
    }
    func testPersonalReadingAndConnectionsLiveInSettings() throws {
        let app = XCUIApplication(); app.launchArguments = ["--uitesting"]; app.launch()
        app.buttons["You"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Your reading life."].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Last 7 days"].exists)
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = "You"; shot.lifetime = .keepAlways; add(shot)
        app.buttons["Settings"].firstMatch.tap()
        app.swipeUp()
        XCTAssertTrue(app.buttons["goodreadsSettings"].waitForExistence(timeout: 10))
        app.buttons["goodreadsSettings"].tap()
        XCTAssertTrue(app.buttons["connectGoodreads"].waitForExistence(timeout: 10))
        app.buttons["connectGoodreads"].tap()
        XCTAssertTrue(app.webViews.firstMatch.waitForExistence(timeout: 15))
    }
    func testGenreShelfAndAirPodsSleepGuide() throws {
        let app = XCUIApplication(); app.launchArguments = ["--uitesting"]; app.launch()
        let sections = app.segmentedControls["librarySections"]
        XCTAssertTrue(sections.waitForExistence(timeout: 30))
        app.buttons["Genres"].tap()
        let uncategorized = app.buttons["category-Uncategorized"]
        XCTAssertTrue(uncategorized.waitForExistence(timeout: 10)); uncategorized.tap()
        XCTAssertTrue(app.staticTexts["Sample recording"].firstMatch.waitForExistence(timeout: 10))
        app.buttons["Settings"].firstMatch.tap()
        let guide = app.buttons["airPodsSleepHelp"]
        for _ in 0..<6 {
            if guide.exists && guide.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(guide.exists && guide.isHittable); guide.tap()
        XCTAssertTrue(app.staticTexts["Let your book rest, too."].waitForExistence(timeout: 10))
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = "AirPods sleep pause setup"; shot.lifetime = .keepAlways; add(shot)
    }
    func testSettings() throws {
        let app=XCUIApplication();app.launchArguments=["--uitesting"];app.launch()
        app.buttons["Settings"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Library & iCloud"].waitForExistence(timeout:10))
        let attachment=XCTAttachment(screenshot:app.screenshot());attachment.name="Settings";attachment.lifetime = .keepAlways;add(attachment)
    }
    func testBookmarkNoteSurvivesAppTermination() throws {
        // Two cold launches and keyboard automation take over two minutes on hosted runners.
        executionTimeAllowance = 180
        let app = XCUIApplication(); app.launchArguments = ["--uitesting"]; app.launch()
        let book = app.buttons["book-Sample recording"]
        XCTAssertTrue(book.waitForExistence(timeout: 30)); book.tap()
        XCTAssertTrue(app.buttons["playerPlayPause"].waitForExistence(timeout: 15))
        // Pause progress updates before editing so XCTest can observe an idle event loop.
        app.buttons["playerPlayPause"].tap()
        app.buttons["addBookmark"].tap()
        XCTAssertTrue(app.staticTexts["bookmarkSaved"].waitForExistence(timeout: 5))
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Bookmarks (")).firstMatch.tap()
        let mark = app.buttons["userBookmark"].firstMatch
        XCTAssertTrue(mark.waitForExistence(timeout: 10)); mark.swipeRight()
        app.buttons["Edit note"].tap()
        let note = app.descendants(matching: .any).matching(identifier: "bookmarkNote").firstMatch
        XCTAssertTrue(note.waitForExistence(timeout: 10)); note.tap(); note.typeText(" Persisted QA note")
        app.buttons["Save"].tap()
        app.terminate()
        app.launchArguments = ["--uitesting", "--uitesting-preserve"]; app.launch()
        XCTAssertTrue(book.waitForExistence(timeout: 30)); book.tap()
        XCTAssertTrue(app.buttons["playerPlayPause"].waitForExistence(timeout: 15))
        app.buttons["playerPlayPause"].tap()
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Bookmarks (")).firstMatch.tap()
        XCTAssertTrue(app.buttons["userBookmark"].firstMatch.waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["userBookmark"].firstMatch.label.contains("Persisted QA note"))
    }
    func testLibraryScreenshot() throws {
        let app=XCUIApplication();app.launchArguments=["--uitesting"];app.launch()
        XCTAssertTrue(app.staticTexts["Sample recording"].firstMatch.waitForExistence(timeout:30))
        let attachment=XCTAttachment(screenshot:app.screenshot());attachment.name="Library";attachment.lifetime = .keepAlways;add(attachment)
    }
    func testServerConnectionForm() throws {
        let app = XCUIApplication(); app.launchArguments = ["--uitesting"]; app.launch()
        app.buttons["Settings"].firstMatch.tap()
        app.swipeUp()
        app.buttons["mediaServersSettings"].tap()
        let addServer = app.buttons["addServer"]; XCTAssertTrue(addServer.waitForExistence(timeout: 10)); addServer.tap()
        XCTAssertTrue(app.textFields["serverURL"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.switches["Use an API token"].exists)
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = "Servers"; shot.lifetime = .keepAlways; add(shot)
    }

}
