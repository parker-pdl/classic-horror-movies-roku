' =============================================================================
' HomeScreen.brs — Focused poster fills background; no carousel.
' =============================================================================

sub init()
    m.rowList   = m.top.findNode("rowList")
    m.bgPoster  = m.top.findNode("bgPoster")
    m.heroTitle = m.top.findNode("heroTitle")
    m.heroMeta  = m.top.findNode("heroMeta")
    m.heroDesc  = m.top.findNode("heroDesc")

    m.rowList.observeField("rowItemFocused",  "onRowItemFocused")
    m.rowList.observeField("rowItemSelected", "onRowItemSelected")
end sub

sub onScreenActiveChanged()
    ' Called by MainScene when this screen comes back into the foreground.
    ' setFocus on the Group doesn't reach the RowList — must be explicit.
    if m.top.screenActive and m.rowList <> invalid
        m.rowList.setFocus(true)
    end if
end sub

sub onContentChanged()
    m.rowList.content = m.top.content
    updateHero([0, 0])
end sub

sub onRowItemFocused()
    idx = m.rowList.rowItemFocused
    updateHero(idx)
end sub

' Update background poster and hero text to match the focused item
sub updateHero(idx as Dynamic)
    if idx = invalid or idx.count() < 2 then return
    content = m.top.content
    if content = invalid then return
    cat = content.getChild(idx[0])
    if cat = invalid then return
    item = cat.getChild(idx[1])
    if item = invalid then return

    m.heroTitle.text = item.title
    m.heroDesc.text  = item.description
    if item.HDPosterUrl <> invalid and item.HDPosterUrl <> ""
        m.bgPoster.uri = item.HDPosterUrl
    end if

    yr   = item.year
    meta = cat.title
    if yr <> invalid and yr <> "" then meta = yr + "   •   " + cat.title
    m.heroMeta.text = meta
end sub

sub onRowItemSelected(event as Dynamic)
    idx = event.getData()
    if idx <> invalid and idx.count() = 2
        content = m.top.content
        if content <> invalid
            cat = content.getChild(idx[0])
            if cat <> invalid
                item = cat.getChild(idx[1])
                if item <> invalid then m.top.itemSelected = item
            end if
        end if
    end if
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    return false   ' Back exits the channel (OS default)
end function
