' =============================================================================
' Classic Horror Movies by: ParkerDataLink.com — Main Entry Point
' =============================================================================
' Boots the SceneGraph render thread and forwards any deep-link arguments
' (contentId / mediaType) into the scene so the channel can jump straight to
' a title when launched via ECP or Roku Search.
'
' Req 5.1: roInput is created BEFORE screen.show() so warm-launch deep links
' (channel already running) are received and forwarded to the scene.
' Cold-launch args require only contentId (mediaType is optional).
' =============================================================================

sub Main(args as Dynamic)
    screen = CreateObject("roSGScreen")
    m.port = CreateObject("roMessagePort")
    screen.setMessagePort(m.port)

    ' Wire up roInput NOW so warm-launch deep links (channel already running)
    ' are received on m.port during the event loop below.
    input = CreateObject("roInput")
    input.setMessagePort(m.port)

    scene = screen.CreateScene("MainScene")
    screen.show()

    ' Forward cold-launch deep-link args (mediaType is optional per Roku spec)
    if args <> invalid and args.contentId <> invalid and args.contentId <> ""
        scene.deepLinkContentId = args.contentId
        if args.mediaType <> invalid then scene.deepLinkMediaType = args.mediaType
    end if

    ' Primary event loop — keeps the channel alive and handles warm deep links
    while true
        msg = wait(0, m.port)
        msgType = type(msg)
        if msgType = "roSGScreenEvent"
            if msg.isScreenClosed() then return
        else if msgType = "roInputEvent"
            ' Warm-launch: channel already running, new deep link arrived
            info = msg.getInfo()
            if info <> invalid and info.contentId <> invalid and info.contentId <> ""
                scene.deepLinkContentId = info.contentId
                if info.mediaType <> invalid then scene.deepLinkMediaType = info.mediaType
            end if
        end if
    end while
end sub
