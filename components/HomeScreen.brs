' =============================================================================
' HomeScreen.brs — RowList wiring, spotlight hero updates, selection bubbling
' =============================================================================

sub init()
    m.rowList    = m.top.findNode("rowList")
    m.heroPoster = m.top.findNode("heroPoster")
    m.heroTitle  = m.top.findNode("heroTitle")
    m.heroMeta   = m.top.findNode("heroMeta")
    m.heroDesc   = m.top.findNode("heroDesc")

    m.rowList.observeField("rowItemFocused",  "onRowItemFocused")
    m.rowList.observeField("rowItemSelected", "onRowItemSelected")

    ' ── Promo carousel wiring ────────────────────────────────────────────
    m.promoCarousel = m.top.findNode("promoCarousel")
    if m.promoCarousel <> invalid
        ' Register the focus-handoff observer BEFORE assigning items, so we
        ' never miss the very first isVideoActive change if item[0] were a
        ' video (it isn't right now, but keep this ordering as a safe habit).
        m.promoCarousel.observeField("isVideoActive", "onCarouselVideoActiveChanged")

        m.promoCarousel.items = [
            { uri: "pkg:/images/promo/banners/pdl-brand.jpg", type: "image", capTitle: "PARKER DATA LINK", capSubtitle: "Horror. Sci-Fi. Cult Classics." }
            { uri: "pkg:/images/promo/banners/advent-poster.jpg", type: "image", capTitle: "ADVENT", capSubtitle: "A NEW HORROR SHORT  •  NOW STREAMING" }
            { uri: "pkg:/images/promo/banners/advent-still1.jpg", type: "image", capTitle: "ADVENT", capSubtitle: "A NEW HORROR SHORT  •  NOW STREAMING" }
            { uri: "pkg:/images/promo/banners/advent-still2.jpg", type: "image", capTitle: "ADVENT", capSubtitle: "A NEW HORROR SHORT  •  NOW STREAMING" }
            { uri: "pkg:/videos/my-passion-1.mp4", type: "video", label: "My Passion", capTitle: "MY PASSION", capSubtitle: "Watch Our Ad" }
            { uri: "pkg:/images/promo/banners/advent-poster.jpg", type: "image", capTitle: "ADVENT", capSubtitle: "A NEW HORROR SHORT  •  NOW STREAMING" }
            { uri: "pkg:/images/promo/banners/advent-still3.jpg", type: "image", capTitle: "ADVENT", capSubtitle: "A NEW HORROR SHORT  •  NOW STREAMING" }
            { uri: "pkg:/images/promo/banners/advent-still4.jpg", type: "image", capTitle: "ADVENT", capSubtitle: "A NEW HORROR SHORT  •  NOW STREAMING" }
            { uri: "pkg:/images/promo/banners/advent-still5.jpg", type: "image", capTitle: "ADVENT", capSubtitle: "A NEW HORROR SHORT  •  NOW STREAMING" }
        ]
    end if
end sub

' While the carousel's video item is playing, hand it focus so any remote
' button reaches its onKeyEvent (skip/mute). Otherwise focus stays on the
' row list for normal browsing -- this lets the user scroll away from the
' carousel at any time, video or not.
sub onCarouselVideoActiveChanged()
    if m.promoCarousel = invalid then return
    if m.promoCarousel.isVideoActive
        m.promoCarousel.setFocus(true)
    else
        m.rowList.setFocus(true)
    end if
end sub

' Bind the ContentNode tree and seed the hero with the first title
sub onContentChanged()
    m.rowList.content = m.top.content
    updateHero([0, 0])
end sub

sub onRowItemFocused()
    updateHero(m.rowList.rowItemFocused)
end sub

' Refresh the spotlight panel from the focused [rowIndex, itemIndex]
sub updateHero(idx as Dynamic)
    if idx = invalid or idx.count() < 2 then return
    content = m.top.content
    if content = invalid then return
    cat = content.getChild(idx[0])
    if cat = invalid then return
    item = cat.getChild(idx[1])
    if item = invalid then return

    m.heroTitle.text  = item.title
    m.heroDesc.text   = item.description
    if item.HDPosterUrl <> invalid then m.heroPoster.uri = item.HDPosterUrl

    yr   = item.year
    meta = cat.title
    if yr <> invalid and yr <> "" then meta = yr + "   •   " + cat.title
    m.heroMeta.text = meta
end sub

' Open the detail screen for the chosen [rowIndex, itemIndex]
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
    return false   ' Back on the home screen exits the channel (default)
end function
