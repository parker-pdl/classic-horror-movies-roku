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

    ' AppLaunchComplete must fire exactly once, at the point the channel is
    ' first actually usable -- either when the home page finishes rendering,
    ' or (for a deep-link launch) when the deep-linked video actually starts
    ' playing. Certification requires this beacon; see MEASURING_PERFORMANCE.
    m.launchBeaconFired = false

    ' Set (possibly again, via alwaysNotify) whenever main.brs forwards a
    ' deep link -- either at launch, or later via a live roInputEvent while
    ' the channel is already running (supports_input_launch=1).
    m.pendingDeepLinkId = ""

    ' Navigation signals from child screens. Wrapped because a single bad
    ' observeField (e.g. against a node that failed to build) would
    ' otherwise abort init() before startContentLoad() ever runs, stranding
    ' the channel on the splash screen.
    try
        if m.splashScreen <> invalid then m.splashScreen.observeField("splashComplete", "onSplashComplete")
        if m.homeScreen <> invalid then m.homeScreen.observeField("itemSelected", "onItemSelected")
        if m.detailScreen <> invalid
            m.detailScreen.observeField("goBack", "onDetailBack")
            m.detailScreen.observeField("playbackStarted", "onDeepLinkPlaybackStarted")
        end if
    catch e
        print "[MainScene] observer wiring failed: "; e.message
    end try

    ' Failsafe: guarantees we leave the splash screen no matter what.
    m.failsafeTimer = m.top.findNode("failsafeTimer")
    if m.failsafeTimer <> invalid
        m.failsafeTimer.observeField("fire", "onFailsafeFired")
        m.failsafeTimer.control = "start"
    end if

    startContentLoad()
end sub

' Nothing got us off the splash screen in time -- force it.
sub onFailsafeFired()
    if m.splashScreen <> invalid and m.splashScreen.visible
        print "[MainScene] FAILSAFE: forcing home screen (splash bootstrap stalled)"
        m.splashDone = true
        revealHome()
    end if
end sub

' -----------------------------------------------------------------------------
' Kick off the remote feed load on a Task thread.
' -----------------------------------------------------------------------------
sub startContentLoad()
    try
        m.loader = createObject("roSGNode", "ContentLoader")
        if m.loader = invalid
            print "[MainScene] ContentLoader task could not be created"
            return
        end if
        m.loader.feedUrl = FEED_URL()
        m.loader.observeField("content", "onContentLoaded")
        m.loader.control = "RUN"
    catch e
        ' The failsafe timer still gets us to the home screen; it'll just be
        ' empty rather than the channel appearing dead on the splash.
        print "[MainScene] startContentLoad failed: "; e.message
    end try
end sub

sub onContentLoaded()
    if m.loader = invalid then return
    root = m.loader.content
    if root <> invalid and root.getChildCount() > 0
        m.contentRoot = root
        if m.homeScreen <> invalid then m.homeScreen.content = root
        m.contentReady = true

        ' If a deep link was waiting on the feed to finish loading, resolve
        ' it now -- whether that's "still on splash" (fast network) or
        ' "already sitting on the home screen" (slow network, handled by
        ' onSplashComplete below in the meantime).
        if m.pendingDeepLinkId <> ""
            if tryResolveDeepLink(m.pendingDeepLinkId) then return
            m.pendingDeepLinkId = ""
        end if

        if m.detailScreen <> invalid and m.detailScreen.visible then return
        if m.splashDone then revealHome()
    end if
end sub

' ─── Screen transition callbacks ────────────────────────────────────────────

' Always leaves the splash screen once its minimum time has elapsed --
' NEVER blocks on the network feed load finishing. The feed can still be
' loading when this fires (slow network, a Worker hiccup, whatever); the
' row list just populates whenever onContentLoaded eventually runs. Getting
' stuck on the splash screen indefinitely is worse than a briefly-empty
' home screen.
sub onSplashComplete()
    m.splashDone = true
    if m.detailScreen <> invalid and m.detailScreen.visible then return
    revealHome()
end sub

sub revealHome()
    if m.splashScreen <> invalid then m.splashScreen.visible = false
    if m.detailScreen <> invalid then m.detailScreen.visible = false
    if m.homeScreen <> invalid
        m.homeScreen.screenActive = true
        m.homeScreen.visible = true
        m.homeScreen.setFocus(true)
    end if
    if m.failsafeTimer <> invalid then m.failsafeTimer.control = "stop"
    ' Don't signal the launch-complete beacon yet if a deep link is still
    ' waiting to resolve -- it'll fire from onDeepLinkPlaybackStarted once
    ' that title actually starts playing instead.
    if m.pendingDeepLinkId = "" then signalLaunchCompleteOnce()
end sub

' ─── Deep linking (roInput / supports_input_launch=1) ──────────────────────
' Fires on launch (main.brs forwards the launch args into this field) and
' again any time the channel receives a live roInputEvent while already
' running -- main.brs re-sets this same field for that case too.
sub onDeepLinkChanged()
    id = m.top.deepLinkContentId
    if id = invalid or id = "" then return
    m.pendingDeepLinkId = id

    if m.contentReady
        ' Channel is already up and running (live deep link) -- resolve
        ' immediately instead of waiting on the splash/content gate above.
        tryResolveDeepLink(id)
    end if
end sub

' Searches every category for an item whose id matches, and if found,
' navigates straight into DetailScreen with autoplay on. Returns true if a
' match was found and navigation happened.
function tryResolveDeepLink(id as String) as Boolean
    if m.contentRoot = invalid then return false
    item = findItemById(m.contentRoot, id)
    if item = invalid then return false

    m.pendingDeepLinkId = ""
    if m.splashScreen <> invalid then m.splashScreen.visible = false
    if m.homeScreen <> invalid
        m.homeScreen.screenActive = false
        m.homeScreen.visible      = false
    end if
    if m.failsafeTimer <> invalid then m.failsafeTimer.control = "stop"
    m.detailScreen.autoPlay    = true
    m.detailScreen.itemContent = item
    m.detailScreen.visible     = true
    m.detailScreen.setFocus(true)
    return true
end function

function findItemById(root as Object, id as String) as Dynamic
    for c = 0 to root.getChildCount() - 1
        category = root.getChild(c)
        for i = 0 to category.getChildCount() - 1
            item = category.getChild(i)
            if item.id = id then return item
        end for
    end for
    return invalid
end function

' The deep-linked video actually started playing -- this is the correct
' moment to signal AppLaunchComplete for that launch path.
sub onDeepLinkPlaybackStarted()
    if m.detailScreen.playbackStarted then signalLaunchCompleteOnce()
end sub

sub signalLaunchCompleteOnce()
    if m.launchBeaconFired then return
    m.launchBeaconFired = true
    ' Never let a beacon problem take down an otherwise-working channel.
    try
        m.top.signalBeacon("AppLaunchComplete")
    catch e
        print "[MainScene] signalBeacon failed: "; e.message
    end try
end sub

sub onItemSelected(event as Dynamic)
    selectedItem = event.getData()
    if selectedItem <> invalid
        ' Manual browse selection -- never autoplay; that's reserved for the
        ' deep-link path (tryResolveDeepLink).
        m.detailScreen.autoPlay    = false
        m.detailScreen.itemContent = selectedItem
        ' Park the carousel BEFORE handing the screen over, so it can't
        ' start a video / grab focus behind the movie about to play.
        if m.homeScreen <> invalid
            m.homeScreen.screenActive = false
            m.homeScreen.visible      = false
        end if
        m.detailScreen.visible = true
        m.detailScreen.setFocus(true)
    end if
end sub

sub onDetailBack()
    if m.detailScreen <> invalid then m.detailScreen.visible = false
    if m.homeScreen <> invalid
        m.homeScreen.screenActive = true
        m.homeScreen.visible      = true
        m.homeScreen.setFocus(true)
    end if
end sub
