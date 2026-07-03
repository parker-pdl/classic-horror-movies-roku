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

    ' Forward deep-link arguments into the scene graph (if present)
    if args <> invalid and args.contentId <> invalid and args.mediaType <> invalid
        scene.deepLinkContentId = args.contentId
        scene.deepLinkMediaType = args.mediaType
    end if

    ' Primary event loop — keeps the channel alive
    while true
        msg = wait(0, m.port)
        if type(msg) = "roSGScreenEvent"
            if msg.isScreenClosed() then return
        end if
    end while
end sub
