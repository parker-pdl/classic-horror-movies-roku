' =============================================================================
' Classic Horror Movies by: ParkerDataLink.com — Main Entry Point
' =============================================================================
' Boots the SceneGraph render thread and forwards any deep-link arguments
' (contentId / mediaType) into the scene so the channel can jump straight to
' a title when launched via ECP or Roku Search.
' =============================================================================

sub Main(args as Dynamic)
    screen = CreateObject("roSGScreen")
    m.port = CreateObject("roMessagePort")
    screen.setMessagePort(m.port)

    scene = screen.CreateScene("MainScene")
    screen.show()

    ' ── Memory monitoring (required for certification) ─────────────────────
    ' Two separate APIs, both routed through the same message port: the
    ' newer per-app roAppMemoryMonitor (limits/usage + a graduated warning
    ' event as usage climbs), and the older device-wide "general" low-memory
    ' signal. We don't need to act on every threshold for a small catalogue
    ' channel like this one, but the events must be enabled and handled for
    ' the channel to report memory pressure correctly.
    m.memMonitor = CreateObject("roAppMemoryMonitor")
    if m.memMonitor <> invalid
        m.memMonitor.SetPort(m.port)
        m.memMonitor.EnableMemoryWarningEvent(true)
        print "Channel available memory (KB): "; m.memMonitor.GetChannelAvailableMemory()
        print "Current memory usage: "; m.memMonitor.GetMemoryLimitPercent(); "%"
        limits = m.memMonitor.GetChannelMemoryLimit()
        if limits <> invalid
            print "Max foreground memory (KB): "; limits.maxForegroundMemory
            print "Max background memory (KB): "; limits.maxBackgroundMemory
        end if
    end if

    m.deviceInfo = CreateObject("roDeviceInfo")
    if m.deviceInfo <> invalid
        m.deviceInfo.SetMessagePort(m.port)
        m.deviceInfo.EnableLowGeneralMemoryEvent(true)
    end if

    ' Forward deep-link arguments into the scene graph (if present)
    if args <> invalid and args.contentId <> invalid and args.mediaType <> invalid
        scene.deepLinkContentId = args.contentId
        scene.deepLinkMediaType = args.mediaType
    end if

    ' Primary event loop — keeps the channel alive
    while true
        msg = wait(0, m.port)
        msgType = type(msg)

        if msgType = "roSGScreenEvent"
            if msg.isScreenClosed() then return

        else if msgType = "roInputEvent"
            ' Live deep link while the channel is already running (requires
            ' supports_input_launch=1 in the manifest). Forward it into the
            ' scene the same way the launch-time args are forwarded above --
            ' deepLinkContentId is alwaysNotify, so re-setting it (even to
            ' the same value) re-triggers navigation in MainScene.brs.
            if msg.isInput()
                info = msg.getInfo()
                if info <> invalid and info.DoesExist("contentid") and info.DoesExist("mediatype")
                    scene.deepLinkContentId = info.contentid
                    scene.deepLinkMediaType = info.mediatype
                end if
            end if

        else if msgType = "roAppMemoryNotificationEvent"
            ' Per-app memory pressure, graduated at 80/85/90/95% of the
            ' channel's limit. Nothing in this channel holds large caches
            ' worth dropping, so we just log it -- but the event must be
            ' handled (not just enabled) to satisfy certification.
            info = msg.getInfo()
            if info <> invalid
                print "Memory warning: "; info.lookup("MemoryUsagePercent"); "% of limit"
            end if

        else if msgType = "roDeviceInfoEvent"
            ' Device-wide low-memory signal (older/general API). Same
            ' treatment -- log and continue; this app's footprint is small.
            if msg.isStatusMessage()
                info = msg.getInfo()
                if info <> invalid then print "General memory level: "; info.generalMemoryLevel
            end if
        end if
    end while
end sub
