' =============================================================================
' DetailScreen.brs — detail view + in-channel Video-node playback
' =============================================================================
' Plays a direct MP4 / HLS stream (item.streamUrl) with the built-in Roku
' Video node. Trick-play (pause / FF / RW) is enabled; Back stops playback
' and returns to the detail view, Back again returns to browse.
' =============================================================================

sub init()
    m.detailPoster      = m.top.findNode("detailPoster")
    m.detailTitle       = m.top.findNode("detailTitle")
    m.categoryLabel     = m.top.findNode("categoryLabel")
    m.detailDescription = m.top.findNode("detailDescription")
    m.sourceLabel       = m.top.findNode("sourceLabel")
    m.statusLabel       = m.top.findNode("statusLabel")
    m.playButton        = m.top.findNode("playButton")
    m.playBtnBg         = m.top.findNode("playBtnBg")
    m.videoPlayer       = m.top.findNode("videoPlayer")
    m.bufferingOverlay  = m.top.findNode("bufferingOverlay")
    m.bufferingLabel    = m.top.findNode("bufferingLabel")

    m.isPlaying = false

    m.videoPlayer.observeField("state", "onVideoStateChanged")
end sub

' ─── Populate UI from the selected ContentNode ──────────────────────────────
sub onItemContentChanged()
    item = m.top.itemContent
    if item = invalid then return

    if item.HDPosterUrl <> invalid then m.detailPoster.uri = item.HDPosterUrl
    m.detailTitle.text       = item.title
    m.detailDescription.text = item.description

    ' Build "year • category" from the item's fields and its parent row
    meta = ""
    yr = item.year
    if yr <> invalid and yr <> "" then meta = yr
    parent = item.getParent()
    if parent <> invalid and parent.title <> invalid and parent.title <> ""
        if meta <> "" then meta = meta + "   •   "
        meta = meta + parent.title
    end if
    m.categoryLabel.text = meta

    ' Stream readiness
    streamUrl = item.getField("streamUrl")
    if streamUrl <> invalid and streamUrl <> ""
        m.sourceLabel.text = "Public domain • Ready to play"
    else
        m.sourceLabel.text = "No stream URL configured for this title."
    end if

    m.statusLabel.text = ""
    m.playButton.setFocus(true)

    ' Deep-link launches jump straight into playback instead of waiting on
    ' the Play button.
    if m.top.autoPlay
        playVideo()
    end if
end sub

' ─── Playback ───────────────────────────────────────────────────────────────
sub playVideo()
    item = m.top.itemContent
    if item = invalid then return

    streamUrl = item.getField("streamUrl")
    if streamUrl = invalid or streamUrl = ""
        showError("No stream URL configured for this video.")
        return
    end if

    streamFormat = item.getField("streamFormat")
    if streamFormat = invalid or streamFormat = ""
        if Instr(1, streamUrl, ".m3u8") > 0
            streamFormat = "hls"
        else
            streamFormat = "mp4"
        end if
    end if

    videoContent = createObject("roSGNode", "ContentNode")
    videoContent.url          = streamUrl
    videoContent.title        = item.title
    videoContent.streamFormat = streamFormat

    m.videoPlayer.content = videoContent
    m.videoPlayer.visible = true
    m.bufferingOverlay.visible = true
    m.bufferingLabel.text = "Loading " + item.title + "..."
    m.videoPlayer.control = "play"
    m.videoPlayer.setFocus(true)
    m.isPlaying = true
    m.statusLabel.text = ""
end sub

sub onVideoStateChanged()
    state = m.videoPlayer.state
    if state = "playing"
        m.bufferingOverlay.visible = false
        m.top.playbackStarted = true
    else if state = "buffering"
        m.bufferingOverlay.visible = true
        m.bufferingLabel.text = "Buffering..."
    else if state = "paused"
        m.bufferingOverlay.visible = false
    else if state = "finished"
        stopVideo()
        m.statusLabel.color = "0x66FF66FF"
        m.statusLabel.text  = "Playback complete."
    else if state = "error"
        errInfo = ""
        if m.videoPlayer.errorCode <> invalid then errInfo = " (code " + m.videoPlayer.errorCode.toStr() + ")"
        stopVideo()
        showError("Playback error" + errInfo + chr(10) + "The stream may be temporarily unavailable — try another title.")
    end if
end sub

sub stopVideo()
    m.videoPlayer.control = "stop"
    m.videoPlayer.visible = false
    m.bufferingOverlay.visible = false
    m.isPlaying = false
    m.playButton.setFocus(true)
end sub

sub showError(msg as String)
    m.statusLabel.color = "0xFF6666FF"
    m.statusLabel.text  = msg
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if press
        if key = "OK"
            if m.playButton.hasFocus() and not m.isPlaying
                m.playBtnBg.color = "0xB0060FFF"
                playVideo()
                m.playBtnBg.color = "0xE50914FF"
                return true
            end if
        else if key = "back"
            if m.isPlaying
                stopVideo()
                return true
            else
                m.top.goBack = true
                return true
            end if
        else if key = "play"
            if m.isPlaying
                if m.videoPlayer.state = "playing"
                    m.videoPlayer.control = "pause"
                else if m.videoPlayer.state = "paused"
                    m.videoPlayer.control = "resume"
                end if
                return true
            else if m.playButton.hasFocus()
                playVideo()
                return true
            end if
        end if
    end if
    return false
end function
