' =============================================================================
' ContentLoader.brs — remote feed fetch + ContentNode tree builder (Task thread)
' =============================================================================
' Strategy:
'   1. Fetch the remote feed FIRST (roku-feed.parkerdatalinktv.workers.dev,
'      which proxies this repo's feed/feed.json from GitHub main). Editing
'      feed/feed.json and pushing updates the channel within ~5 minutes,
'      with no channel rebuild or Roku review.
'   2. Fall back to the bundled pkg:/feed/feed.json if the remote feed is
'      unreachable or does not parse into at least one row.
'   3. Parse the JSON and build a root ContentNode whose children are the
'      category nodes, each holding the movie nodes the RowList renders.
'
' Feed item fields consumed downstream:
'   title, description, HDPosterUrl (poster), streamUrl (direct MP4/HLS),
'   streamFormat ("mp4"/"hls"), year.
' =============================================================================

sub init()
    m.top.functionName = "loadFeed"
end sub

sub loadFeed()
    feed = invalid
    root = invalid
    src = "remote"

    ' 1) Remote feed first (see note above)
    url = m.top.feedUrl
    if url <> invalid and url <> ""
        jsonText = httpGetString(url, 15000)
        if jsonText <> invalid and jsonText <> ""
            feed = ParseJson(jsonText)
            root = buildTree(feed)
        end if
    end if

    ' 2) Bundled copy if the remote feed failed or came back empty
    if root = invalid or root.getChildCount() = 0
        src = "bundled"
        feed = invalid
        jsonText = ReadAsciiFile("pkg:/feed/feed.json")
        if jsonText <> invalid and jsonText <> ""
            feed = ParseJson(jsonText)
        end if
        root = buildTree(feed)
    end if
    m.top.source  = src
    if feed <> invalid and root.getChildCount() > 0
        m.top.status = "ok"
    else
        m.top.status = "error"
    end if
    ' Assign content LAST so a single observer fires with a fully built tree
    m.top.content = root
end sub

' -----------------------------------------------------------------------------
' httpGetString — synchronous (within this Task thread) HTTPS GET with timeout.
' Returns the response body string, or invalid on any failure.
' -----------------------------------------------------------------------------
function httpGetString(url as string, timeoutMs as integer) as dynamic
    port = createObject("roMessagePort")
    xfer = createObject("roUrlTransfer")
    xfer.setMessagePort(port)
    xfer.setUrl(url)
    xfer.setCertificatesFile("common:/certs/ca-bundle.crt")
    xfer.initClientCertificates()
    xfer.addHeader("User-Agent", "ParkerDataLink-Roku/1.1")
    xfer.setRequest("GET")
    xfer.enableEncodings(true)

    if xfer.asyncGetToString()
        msg = wait(timeoutMs, port)
        if type(msg) = "roUrlEvent"
            if msg.getResponseCode() = 200
                return msg.getString()
            end if
        end if
        ' timed out or errored
        xfer.asyncCancel()
    end if
    return invalid
end function

' -----------------------------------------------------------------------------
' buildTree — turn the parsed feed (roAssociativeArray) into a ContentNode tree.
' -----------------------------------------------------------------------------
function buildTree(feed as dynamic) as object
    root = createObject("roSGNode", "ContentNode")
    if feed = invalid or GetInterface(feed, "ifAssociativeArray") = invalid then return root
    if feed.categories = invalid then return root

    for each cat in feed.categories
        if cat <> invalid and cat.items <> invalid
            catNode = root.createChild("ContentNode")
            catNode.title = valStr(cat.title, "Untitled")

            for each it in cat.items
                if it <> invalid
                    node = catNode.createChild("ContentNode")
                    node.id          = valStr(it.id, "")
                    node.title       = valStr(it.title, "Untitled")
                    node.description  = valStr(it.description, "")
                    poster = valStr(it.poster, "")
                    if poster <> "" then node.HDPosterUrl = poster

                    ' Custom fields (streamFormat is a built-in ContentNode field, so
                    ' we only add the ones ContentNode doesn't already define)
                    node.addFields({ streamUrl: "", year: "" })
                    node.streamUrl    = valStr(it.streamUrl, "")
                    node.streamFormat = valStr(it.streamFormat, "mp4")
                    node.year         = valStr(it.year, "")
                end if
            end for
        end if
    end for
    return root
end function

' Small helper: coerce a possibly-invalid value to a string with a default.
function valStr(v as dynamic, dflt as string) as string
    if v = invalid then return dflt
    if type(v) = "roString" or type(v) = "String" then return v
    return dflt
end function
