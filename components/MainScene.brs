' =============================================================================
' MainScene.brs — screen orchestrator + remote feed bootstrap
'
' Flow: SplashScreen -> HomeScreen (interactive, beacon fires) -> IntroVideo
'       overlay on top of home -> HomeScreen (overlay removed)
'
' Req 3.2 fix: AppLaunchComplete is signaled as soon as HomeScreen is ready,
' BEFORE the intro video starts.  The intro plays as a visual overlay and does
' NOT block interactivity.
' =============================================================================

function FEED_URL() as string
    return "https://roku-feed.parkerdatalinktv.workers.dev/feed.json"
end function

function INTRO_URL() as string
    return "https://pub-4a1ee3e926844caba75e0b33d0b2208d.r2.dev/short%20trailer%20PDL.mp4"
end function

sub init()
    m.splashScreen = m.top.findNode("splashScreen")
    m.homeScreen   = m.top.findNode("homeScreen")
    m.detailScreen = m.top.findNode("detailScreen")
    m.introVideo   = m.top.findNode("introVideo")

    m.splashDone        = false
    m.homeRevealed      = false
    m.contentReady      = false
    m.launchBeaconFired = false
    m.pendingDeepLinkId = ""

    try
        if m.splashScreen <> invalid then m.splashScreen.observeField("splashComplete", "onSplashComplete")
        if m.homeScreen <> invalid   then m.homeScreen.observeField("itemSelected", "onItemSelected")
        if m.detailScreen <> invalid
            m.detailScreen.observeField("goBack", "onDetailBack")
            m.detailScreen.observeField("playbackStarted", "onDeepLinkPlaybackStarted")
        end if
        if m.introVideo <> invalid then m.introVideo.observeField("state", "onIntroStateChanged")
    catch e
        print "[MainScene] observer wiring failed: "; e.message
    end try

    m.failsafeTimer = m.top.findNode("failsafeTimer")
    if m.failsafeTimer <> invalid
        m.failsafeTimer.observeField("fire", "onFailsafeFired")
        m.failsafeTimer.control = "start"
    end if

    startContentLoad()
end sub

sub onFailsafeFired()
    if m.homeRevealed then return
    print "[MainScene] FAILSAFE: skipping to home"
    m.splashDone = true
    revealHome()
end sub

' -----------------------------------------------------------------------------
sub startContentLoad()
    try
        m.loader = createObject("roSGNode", "ContentLoader")
        if m.loader = invalid then return
        m.loader.feedUrl = FEED_URL()
        m.loader.observeField("content", "onContentLoaded")
        m.loader.control = "RUN"
    catch e
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
        if m.pendingDeepLinkId <> ""
            if tryResolveDeepLink(m.pendingDeepLinkId) then return
            m.pendingDeepLinkId = ""
        end if
        if m.detailScreen <> invalid and m.detailScreen.visible then return
        if m.homeRevealed then return
    end if
end sub

' ─── Splash -> Home (interactive) -> Intro overlay ────────────────────────────

sub onSplashComplete()
    m.splashDone = true
    if m.detailScreen <> invalid and m.detailScreen.visible then return
    revealHome()
    playIntroOverlay()
end sub

sub playIntroOverlay()
    if m.introVideo = invalid then return
    c = createObject("roSGNode", "ContentNode")
    c.url = INTRO_URL()
    c.streamFormat = "mp4"
    m.introVideo.content = c
    m.introVideo.visible = true
    m.introVideo.setFocus(true)
    m.introVideo.control = "play"
end sub

sub onIntroStateChanged()
    if m.introVideo = invalid then return
    s = m.introVideo.state
    if s = "finished" or s = "error" or s = "stopped"
        m.introVideo.control = "stop"
        m.introVideo.visible = false
        if m.homeScreen <> invalid then m.homeScreen.setFocus(true)
    end if
end sub

sub revealHome()
    m.homeRevealed = true
    if m.splashScreen <> invalid then m.splashScreen.visible = false
    if m.detailScreen <> invalid then m.detailScreen.visible = false
    if m.homeScreen <> invalid
        m.homeScreen.screenActive = true
        m.homeScreen.visible = true
        m.homeScreen.setFocus(true)
    end if
    if m.failsafeTimer <> invalid then m.failsafeTimer.control = "stop"
    if m.pendingDeepLinkId = "" then signalLaunchCompleteOnce()
end sub

' ─── Deep linking ────────────────────────────────────────────────────────────

sub onDeepLinkChanged()
    id = m.top.deepLinkContentId
    if id = invalid or id = "" then return
    m.pendingDeepLinkId = id
    if m.contentReady then tryResolveDeepLink(id)
end sub

function tryResolveDeepLink(id as String) as Boolean
    if m.contentRoot = invalid then return false
    item = findItemById(m.contentRoot, id)
    if item = invalid then return false
    m.pendingDeepLinkId = ""
    if m.splashScreen <> invalid then m.splashScreen.visible = false
    if m.introVideo <> invalid
        m.introVideo.control = "stop"
        m.introVideo.visible = false
    end if
    if m.homeScreen <> invalid
        m.homeScreen.screenActive = false
        m.homeScreen.visible = false
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

sub onDeepLinkPlaybackStarted()
    if m.detailScreen.playbackStarted then signalLaunchCompleteOnce()
end sub

sub signalLaunchCompleteOnce()
    if m.launchBeaconFired then return
    m.launchBeaconFired = true
    try
        m.top.signalBeacon("AppLaunchComplete")
    catch e
        print "[MainScene] signalBeacon failed: "; e.message
    end try
end sub

' ─── Navigation ──────────────────────────────────────────────────────────────

sub onItemSelected(event as Dynamic)
    selectedItem = event.getData()
    if selectedItem <> invalid
        m.detailScreen.autoPlay    = false
        m.detailScreen.itemContent = selectedItem
        if m.homeScreen <> invalid
            m.homeScreen.screenActive = false
            m.homeScreen.visible = false
        end if
        m.detailScreen.visible = true
        m.detailScreen.setFocus(true)
    end if
end sub

sub onDetailBack()
    if m.detailScreen <> invalid then m.detailScreen.visible = false
    if m.homeScreen <> invalid
        m.homeScreen.screenActive = true
        m.homeScreen.visible = true
        m.homeScreen.setFocus(true)
    end if
end sub
