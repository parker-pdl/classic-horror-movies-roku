' =============================================================================
' PlayBeacon.brs — fire-and-forget "movie started" ping (Task thread)
' =============================================================================
' Counts are read back at https://pdl-play-counter.parkerdatalinktv.workers.dev/top?app=chm
' A failed ping is ignored; it never affects playback.

sub init()
    m.top.functionName = "sendPing"
end sub

sub sendPing()
    xfer = createObject("roUrlTransfer")
    url = "https://pdl-play-counter.parkerdatalinktv.workers.dev/play?app=chm&p=roku"
    url = url + "&id=" + xfer.Escape(m.top.itemId) + "&t=" + xfer.Escape(m.top.title)

    port = createObject("roMessagePort")
    xfer.setMessagePort(port)
    xfer.setUrl(url)
    xfer.setCertificatesFile("common:/certs/ca-bundle.crt")
    xfer.initClientCertificates()
    xfer.addHeader("User-Agent", "ParkerDataLink-Roku/1.1")
    if xfer.asyncGetToString()
        msg = wait(5000, port)
        if type(msg) <> "roUrlEvent" then xfer.asyncCancel()
    end if
end sub
