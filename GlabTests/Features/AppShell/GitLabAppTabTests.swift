import Testing
@testable import Glab

@Suite("GitLab app tabs")
struct GitLabAppTabTests {
    @Test("The app exposes Home, Inbox, and Search")
    func exposesAppTabs() {
        #expect(GitLabAppTab.allCases == [.home, .inbox, .search])
        #expect(GitLabAppTab.defaultTab == .home)
    }

    @Test("Each tab has stable native presentation metadata")
    func presentsTabs() {
        #expect(GitLabAppTab.home.title == "Home")
        #expect(GitLabAppTab.home.systemImage == "house.fill")
        #expect(GitLabAppTab.inbox.title == "Inbox")
        #expect(GitLabAppTab.inbox.systemImage == "tray.fill")
        #expect(GitLabAppTab.search.title == "Search")
        #expect(GitLabAppTab.search.systemImage == "magnifyingglass")
    }
}
