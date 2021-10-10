module Ext.Browser.Navigation exposing
    ( Key
    , SpaFlags
    , back
    , forward
    , load
    , onUrlChange
    , onUrlRequest
    , pushUrl
    , reload
    , reloadAndSkipCache
    , replaceUrl
    , spaFlags
    )

import Browser.Navigation
import Ext.Browser
import Ext.Browser.Ports
import Url


type Key
    = Key Float


type alias SpaFlags =
    { location : Ext.Browser.Location
    , navKey : Float
    }


spaFlags : { a | spaFlags : SpaFlags } -> { url : Url.Url, navKey : Key }
spaFlags record =
    { url = Ext.Browser.urlFromLocation record.spaFlags.location
    , navKey = Key record.spaFlags.navKey
    }


pushUrl : Key -> String -> Cmd msg
pushUrl (Key k) arg =
    Ext.Browser.Ports.pushUrl ( k, arg )


replaceUrl : Key -> String -> Cmd msg
replaceUrl (Key k) arg =
    Ext.Browser.Ports.replaceUrl ( k, arg )


back : Key -> Int -> Cmd msg
back (Key k) arg =
    Ext.Browser.Ports.back ( k, arg )


forward : Key -> Int -> Cmd msg
forward (Key k) arg =
    Ext.Browser.Ports.forward ( k, arg )


onUrlChange : (Url.Url -> msg) -> Sub msg
onUrlChange msg =
    Ext.Browser.Ports.onLocationChange (Ext.Browser.urlFromLocation >> msg)


onUrlRequest : (Ext.Browser.UrlRequest -> msg) -> Sub msg
onUrlRequest msg =
    Ext.Browser.Ports.onLocationRequest
        (\( before, after ) ->
            if
                before.protocol
                    == after.protocol
                    && before.host
                    == after.host
                    && before.port_
                    == after.port_
            then
                msg (Ext.Browser.Internal (Ext.Browser.urlFromLocation after))

            else
                msg (Ext.Browser.External (Url.toString (Ext.Browser.urlFromLocation after)))
        )


load : String -> Cmd msg
load =
    Browser.Navigation.load


reload : Cmd msg
reload =
    Browser.Navigation.reload


reloadAndSkipCache : Cmd msg
reloadAndSkipCache =
    Browser.Navigation.reloadAndSkipCache
