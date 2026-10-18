' =============================================================================
' PosterItem.brs — poster card renderer + focus animation
' =============================================================================

sub init()
    m.posterImage = m.top.findNode("posterImage")
    m.titleLabel  = m.top.findNode("titleLabel")
    m.titleScrim  = m.top.findNode("titleScrim")
    m.focusBorder = m.top.findNode("focusBorder")
    m.focusGlow   = m.top.findNode("focusGlow")
    m.cardBg      = m.top.findNode("cardBg")

    ' Scale from the card's centre so focus growth is symmetric
    m.top.scaleRotateCenter = [120, 180]
end sub

sub onItemContentChanged()
    item = m.top.itemContent
    if item <> invalid
        m.posterImage.uri = item.HDPosterUrl
        m.titleLabel.text = item.title
    end if
end sub

' Smoothly scale + reveal the title as the card gains focus (focusPercent 0->1)
sub onFocusChanged()
    fp = m.top.focusPercent
    s  = 1.0 + (0.08 * fp)
    m.top.scale = [s, s]
    m.focusBorder.opacity = 1.0 - fp
    m.focusGlow.opacity   = fp
    m.titleScrim.opacity  = fp
    m.titleLabel.opacity  = fp
end sub
