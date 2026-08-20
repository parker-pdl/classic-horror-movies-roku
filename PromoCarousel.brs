' =============================================================================
' PromoCarousel.brs — cross-fading banner cycler + full-screen video takeover
' for the top-of-screen promo band.
' =============================================================================

sub init()
    m.posterBack    = m.top.findNode("posterBack")
    m.posterFront   = m.top.findNode("posterFront")
    m.titleLabel    = m.top.findNode("titleLabel")
    m.subtitleLabel = m.top.findNode("subtitleLabel")
    m.crossFadeAnim = m.top.findNode("crossFadeAnim")
    m.timer         = m.top.findNode("advanceTimer")
    m.videoPlayer   = m.top.findNode("videoPlayer")
    m.videoHint     = m.top.findNode("videoHint")
    m.videoHintBg   = m.top.findNode("videoHintBg")

    m.items = []
    m.index = 0

    m.timer.observeField("fire", "onTimerFired")
    m.crossFadeAnim.observeField("state", "onFadeStateChanged")
    m.videoPlayer.observeField("state", "onVideoStateChanged")
end sub

sub onItemsChanged()
    m.items = m.top.items
    m.index = 0
    if m.items = invalid or m.items.count() = 0 then return
    showItem(0)
end sub

sub onTextChanged()
    m.titleLabel.text    = m.top.promoTitle
    m.subtitleLabel.text = m.top.promoSubtitle
end sub

sub showItem(i as Integer)
    if m.items = invalid or i >= m.items.count() then return
    item = m.items[i]
    if item.type = "video"
        startVideoItem(item)
    else
        showImageItem(item)
    end if
end sub

sub showImageItem(item as Object)
    stopVideo()

    m.posterBack.uri  = item.uri
    m.posterFront.uri = item.uri
    m.posterFront.opacity = 0.0
    m.posterBack.opacity  = 1.0

    titleText    = m.top.promoTitle
    subtitleText = m.top.promoSubtitle
    if item.capTitle <> invalid then titleText = item.capTitle
    if item.capSubtitle <> invalid then subtitleText = item.capSubtitle
    m.titleLabel.text    = titleText
    m.subtitleLabel.text = subtitleText

    startTimer()
end sub

sub startTimer()
    if m.top.active = false then return
    if m.items = invalid or m.items.count() <= 1 then return
    m.timer.duration = m.top.intervalSecs
    m.timer.control  = "start"
end sub

' The parent screen flips "active" to false as soon as the user scrolls down
' away from the carousel, and back to true when they scroll back up to it.
sub onActiveChanged()
    if m.top.active
        if not m.top.isVideoActive then startTimer()
    else
        m.timer.control = "stop"
        if m.top.isVideoActive then stopVideo()
    end if
end sub

sub onTimerFired()
    if m.items = invalid or m.items.count() <= 1 then return
    nextIndex = (m.index + 1) mod m.items.count()

    nextItem = m.items[nextIndex]
    if nextItem.type = "video"
        m.index = nextIndex
        m.timer.control = "stop"
        startVideoItem(nextItem)
        return
    end if

    m.index = nextIndex
    m.posterFront.uri = nextItem.uri
    titleText    = m.top.promoTitle
    subtitleText = m.top.promoSubtitle
    if nextItem.capTitle <> invalid then titleText = nextItem.capTitle
    if nextItem.capSubtitle <> invalid then subtitleText = nextItem.capSubtitle
    m.titleLabel.text    = titleText
    m.subtitleLabel.text = subtitleText
    m.crossFadeAnim.control = "start"
end sub

sub onFadeStateChanged()
    if m.crossFadeAnim.state = "stopped"
        m.posterBack.uri     = m.posterFront.uri
        m.posterBack.opacity = 1.0
        m.posterFront.opacity = 0.0
    end if
end sub

' ─── Video takeover ─────────────────────────────────────────────────────────

sub startVideoItem(item as Object)
    m.timer.control = "stop"

    content = createObject("roSGNode", "ContentNode")
    content.url = item.uri
    if item.label <> invalid then content.title = item.label

    m.videoPlayer.content = content
    m.videoPlayer.mute    = m.top.muted
    m.videoPlayer.visible = true
    m.videoPlayer.control = "play"

    hintText = "Press any button to skip      *  " + iif(m.top.muted, "Unmute", "Mute")
    if item.label <> invalid and item.label <> "" then hintText = UCase(item.label) + "      " + hintText
    m.videoHint.text     = hintText
    m.videoHint.visible   = true
    m.videoHintBg.visible = true

    m.top.isVideoActive = true
end sub

sub stopVideo()
    if m.videoPlayer.control = "play" or m.videoPlayer.visible
        m.videoPlayer.control  = "stop"
        m.videoPlayer.visible  = false
        m.videoHint.visible    = false
        m.videoHintBg.visible  = false
    end if
    m.top.isVideoActive = false
end sub

sub onVideoStateChanged()
    state = m.videoPlayer.state
    if state = "finished" or state = "error"
        advanceAfterVideo()
    end if
end sub

sub onSkipVideo()
    if m.top.skipVideo <> true then return
    if m.top.isVideoActive
        advanceAfterVideo()
    end if
end sub

sub onToggleMute()
    if m.top.toggleMute <> true then return
    newMuted = not m.top.muted
    m.top.muted = newMuted
    m.videoPlayer.mute = newMuted
    if m.top.isVideoActive
        item = m.items[m.index]
        hintText = "Press any button to skip      *  " + iif(newMuted, "Unmute", "Mute")
        if item <> invalid and item.label <> invalid and item.label <> "" then hintText = UCase(item.label) + "      " + hintText
        m.videoHint.text = hintText
    end if
end sub

sub advanceAfterVideo()
    stopVideo()
    if m.items = invalid or m.items.count() = 0 then return
    nextIndex = (m.index + 1) mod m.items.count()
    m.index = nextIndex
    showItem(nextIndex)
end sub

function iif(condition as Boolean, whenTrue as Dynamic, whenFalse as Dynamic) as Dynamic
    if condition then return whenTrue
    return whenFalse
end function

' ─── Key handling (only reached while this node has focus, which the parent
' screen grants for the duration of video playback) ─────────────────────────
function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false
    if not m.top.isVideoActive then return false

    if key = "options" or key = "info" or key = "star"
        m.top.toggleMute = true
        return true
    end if

    m.top.skipVideo = true
    return true
end function
