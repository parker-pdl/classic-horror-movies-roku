' =============================================================================
' MainScene.brs — screen orchestrator + remote feed bootstrap
' =============================================================================
' Loads the catalogue from a remote JSON feed (hosted on parkerdatalink.com)
' via the ContentLoader Task, with a bundled fallback, then wires the
' Splash -> Home -> Detail navigation.
' =============================================================================

' Where the channel pulls its catalogue from. Host feed.json here and you can
' add / remove / reorder films without re-sideloading the channel.
function FEED_URL() as string
    return "https://roku-feed.parkerdatalinktv.workers.dev/feed.json"
end function

sub init()
    m.splashScreen = m.top.findNode("splashScreen")
    m.homeScreen   = m.top.findNode("homeScreen")
    m.detailScreen = m.top.findNode("detailScreen")

    m.splashDone   = false
    m.contentReady = false

    ' Navigation signals from child screens
    m.splashScreen.observeField("splashComplete", "onSplashComplete")
    m.homeScreen.observeField("itemSelected",     "onItemSelected")
    m.detailScreen.observeField("goBack",         "onDetailBack")

    startContentLoad()
end sub

' -----------------------------------------------------------------------------
' Kick off the remote feed load on a Task thread.
' -----------------------------------------------------------------------------
sub startContentLoad()
    m.loader = createObject("roSGNode", "ContentLoader")
    m.loader.feedUrl = FEED_URL()
    m.loader.observeField("content", "onContentLoaded")
    m.loader.control = "RUN"
end sub

sub onContentLoaded()
    root = m.loader.content
    if root <> invalid and root.getChildCount() > 0
        m.homeScreen.content = root
        m.contentReady = true
        if m.splashDone then revealHome()
    end if
end sub

' ─── Screen transition callbacks ────────────────────────────────────────────

sub onSplashComplete()
    m.splashDone = true
    revealHome()
end sub

sub revealHome()
    m.splashScreen.visible = false
    m.detailScreen.visible = false
    m.homeScreen.visible   = true
    m.homeScreen.setFocus(true)
end sub

sub onItemSelected(event as Dynamic)
    selectedItem = event.getData()
    if selectedItem <> invalid
        m.detailScreen.itemContent = selectedItem
        m.homeScreen.visible   = false
        m.detailScreen.visible = true
        m.detailScreen.setFocus(true)
    end if
end sub

sub onDetailBack()
    m.detailScreen.visible = false
    m.homeScreen.visible   = true
    m.homeScreen.setFocus(true)
end sub
