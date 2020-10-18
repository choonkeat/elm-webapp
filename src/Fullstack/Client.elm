module Fullstack.Client exposing
    ( Ports, Protocol
    , element, document, application
    )

{-|


# Definition

@docs Ports, Protocol


# Common Helpers

@docs element, document, application

-}

import Browser
import Browser.Navigation
import Fullstack.Shared
import Html
import Http
import Json.Decode
import Json.Encode
import Platform exposing (Task)
import Url


type FrameworkMsg a
    = AppMsg a
    | WebSocketConnected Int
    | WebSocketReceive String


{-| Hook up ports to use websockets for passing serverMsg and clientMsg
-}
type alias Ports msg =
    { websocketConnected : (Int -> FrameworkMsg msg) -> Sub (FrameworkMsg msg)
    , websocketIn : (String -> FrameworkMsg msg) -> Sub (FrameworkMsg msg)
    }


{-| A set of required protocols.

    - `updateFromServer` is called when `serverMsg` is received via websocket
    - `clientMsgEncoder` encodes outgoing `clientMsg`, e.g. via `sendToServer`
    - `serverMsgDecoder` decodes replies from Server
    - `errorDecoder` decodes error replies from Server

-}
type alias Protocol serverMsg clientMsg model msg x =
    { updateFromServer : serverMsg -> model -> ( model, Cmd msg )
    , clientMsgEncoder : clientMsg -> Json.Encode.Value
    , serverMsgDecoder : Json.Decode.Decoder serverMsg
    , errorDecoder : Json.Decode.Decoder x
    }


{-| Returns a `Browser.element` to use as `main` in your client app
and a `sendToServer` function to send `clientMsg` with
-}
element :
    { -- Browser.element
      -- https://package.elm-lang.org/packages/elm/browser/latest/Browser#element
      element :
        { init : flags -> ( model, Cmd msg )
        , view : model -> Html.Html msg
        , update : msg -> model -> ( model, Cmd msg )
        , subscriptions : model -> Sub msg
        }

    -- Fullstack Extension
    , ports : Ports msg
    , protocol : Protocol serverMsg clientMsg model msg x
    }
    ->
        { element : Program flags model (FrameworkMsg msg)
        , sendToServer : clientMsg -> Task Http.Error (Result x serverMsg)
        }
element ({ ports, protocol } as cfg) =
    let
        sendToServer m =
            Http.task
                { method = "POST"
                , headers = []
                , url = Fullstack.Shared.httpEndpoint
                , body = Http.jsonBody (protocol.clientMsgEncoder m)
                , resolver = Http.stringResolver (serverMsgFromResponse (Fullstack.Shared.decodeResultResult protocol.errorDecoder protocol.serverMsgDecoder))
                , timeout = Just 60000
                }

        newElement =
            Browser.element
                { init = initDocument cfg.element.init
                , view = viewHtml cfg.element.view
                , update = update cfg.element.update protocol.updateFromServer protocol.serverMsgDecoder
                , subscriptions = subscriptions cfg.element.subscriptions ports
                }
    in
    { element = newElement
    , sendToServer = sendToServer
    }


{-| Returns a `Browser.document` to use as `main` in your client app
and a `sendToServer` function to send `clientMsg` with
-}
document :
    { -- Browser.document
      -- https://package.elm-lang.org/packages/elm/browser/latest/Browser#document
      document :
        { init : flags -> ( model, Cmd msg )
        , view : model -> Browser.Document msg
        , update : msg -> model -> ( model, Cmd msg )
        , subscriptions : model -> Sub msg
        }

    -- Fullstack Extension
    , ports : Ports msg
    , protocol : Protocol serverMsg clientMsg model msg x
    }
    ->
        { document : Program flags model (FrameworkMsg msg)
        , sendToServer : clientMsg -> Task Http.Error (Result x serverMsg)
        }
document ({ ports, protocol } as cfg) =
    let
        sendToServer m =
            Http.task
                { method = "POST"
                , headers = []
                , url = Fullstack.Shared.httpEndpoint
                , body = Http.jsonBody (protocol.clientMsgEncoder m)
                , resolver = Http.stringResolver (serverMsgFromResponse (Fullstack.Shared.decodeResultResult protocol.errorDecoder protocol.serverMsgDecoder))
                , timeout = Just 60000
                }

        newApplication =
            Browser.document
                { init = initDocument cfg.document.init
                , view = viewDocument cfg.document.view
                , update = update cfg.document.update protocol.updateFromServer protocol.serverMsgDecoder
                , subscriptions = subscriptions cfg.document.subscriptions ports
                }
    in
    { document = newApplication
    , sendToServer = sendToServer
    }


{-| Returns a `Browser.application` to use as `main` in your client app
and a `sendToServer` function to send `clientMsg` with
-}
application :
    -- Browser.application
    -- https://package.elm-lang.org/packages/elm/browser/latest/Browser#application
    { application :
        { init : flags -> Url.Url -> Browser.Navigation.Key -> ( model, Cmd msg )
        , view : model -> Browser.Document msg
        , update : msg -> model -> ( model, Cmd msg )
        , subscriptions : model -> Sub msg
        , onUrlRequest : Browser.UrlRequest -> msg
        , onUrlChange : Url.Url -> msg
        }

    -- Fullstack Extension
    , ports : Ports msg
    , protocol : Protocol serverMsg clientMsg model msg x
    }
    ->
        { application : Program flags model (FrameworkMsg msg)
        , sendToServer : clientMsg -> Task Http.Error (Result x serverMsg)
        }
application ({ ports, protocol } as cfg) =
    let
        sendToServer m =
            Http.task
                { method = "POST"
                , headers = []
                , url = Fullstack.Shared.httpEndpoint
                , body = Http.jsonBody (protocol.clientMsgEncoder m)
                , resolver = Http.stringResolver (serverMsgFromResponse (Fullstack.Shared.decodeResultResult protocol.errorDecoder protocol.serverMsgDecoder))
                , timeout = Just 60000
                }

        newApplication =
            Browser.application
                { init = initApplication cfg.application.init
                , view = viewDocument cfg.application.view
                , update = update cfg.application.update protocol.updateFromServer protocol.serverMsgDecoder
                , subscriptions = subscriptions cfg.application.subscriptions ports
                , onUrlRequest = cfg.application.onUrlRequest >> AppMsg
                , onUrlChange = cfg.application.onUrlChange >> AppMsg
                }
    in
    { application = newApplication
    , sendToServer = sendToServer
    }


serverMsgFromResponse : Json.Decode.Decoder serverMsg -> Http.Response String -> Result Http.Error serverMsg
serverMsgFromResponse serverMsgDecoder resp =
    case resp of
        Http.GoodStatus_ metadata s ->
            Json.Decode.decodeString serverMsgDecoder s
                |> Result.mapError (\err -> Http.BadBody (metadata.statusText ++ " " ++ Json.Decode.errorToString err))

        Http.BadStatus_ metadata s ->
            Json.Decode.decodeString serverMsgDecoder s
                |> Result.mapError (\err -> Http.BadBody (metadata.statusText ++ " " ++ Json.Decode.errorToString err))

        Http.BadUrl_ s ->
            Err (Http.BadUrl s)

        Http.Timeout_ ->
            Err Http.Timeout

        Http.NetworkError_ ->
            Err Http.NetworkError


initDocument : (flags -> ( model, Cmd msg )) -> flags -> ( model, Cmd (FrameworkMsg msg) )
initDocument appInit flags =
    let
        ( model, appCmd ) =
            appInit flags
    in
    ( model, Cmd.map AppMsg appCmd )


initApplication : (flags -> Url.Url -> Browser.Navigation.Key -> ( model, Cmd msg )) -> flags -> Url.Url -> Browser.Navigation.Key -> ( model, Cmd (FrameworkMsg msg) )
initApplication appInit flags urlUrl navKey =
    let
        ( model, appCmd ) =
            appInit flags urlUrl navKey
    in
    ( model, Cmd.map AppMsg appCmd )


viewHtml : (model -> Html.Html msg) -> model -> Html.Html (FrameworkMsg msg)
viewHtml appView model =
    Html.map AppMsg (appView model)


viewDocument : (model -> Browser.Document msg) -> model -> Browser.Document (FrameworkMsg msg)
viewDocument appView model =
    let
        { title, body } =
            appView model
    in
    { title = title, body = List.map (Html.map AppMsg) body }


update :
    (msg -> model -> ( model, Cmd msg ))
    -> (serverMsg -> model -> ( model, Cmd msg ))
    -> Json.Decode.Decoder serverMsg
    -> FrameworkMsg msg
    -> model
    -> ( model, Cmd (FrameworkMsg msg) )
update appUpdate updateFromServer serverMsgDecoder msg model =
    Tuple.mapSecond (Cmd.map AppMsg) <|
        -- all msg `Cmd msg` gets transformed to `Cmd (FrameworkMsg msg)`
        case msg of
            AppMsg m ->
                appUpdate m model

            WebSocketConnected t ->
                ( model, Cmd.none )

            WebSocketReceive str ->
                Json.Decode.decodeString serverMsgDecoder str
                    |> Result.map (\m -> updateFromServer m model)
                    |> Result.withDefault ( model, Cmd.none )


subscriptions :
    (model -> Sub msg)
    -> Ports msg
    -> model
    -> Sub (FrameworkMsg msg)
subscriptions appSubscription ports model =
    Sub.batch
        [ Sub.map AppMsg (appSubscription model)
        , ports.websocketIn WebSocketReceive
        , ports.websocketConnected WebSocketConnected
        ]
