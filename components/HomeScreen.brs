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
