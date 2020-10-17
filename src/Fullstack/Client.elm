module Fullstack.Client exposing (instance)

{-|


# Common Helpers

@docs instance

-}

import Browser
import Browser.Navigation
import Fullstack.Server
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


type alias Ports msg =
    { websocketConnected : (Int -> FrameworkMsg msg) -> Sub (FrameworkMsg msg)
    , websocketIn : (String -> FrameworkMsg msg) -> Sub (FrameworkMsg msg)
    }


type alias Protocol serverMsg clientMsg model msg x =
    { updateFromServer : serverMsg -> model -> ( model, Cmd msg )
    , clientMsgEncoder : clientMsg -> Json.Encode.Value
    , serverMsgDecoder : Json.Decode.Decoder serverMsg
    , errorDecoder : Json.Decode.Decoder x
    }


{-| Returns a `Browser.application` to use as `main` in your client app
and a `sendToServer` function to send `clientMsg` with
-}
instance :
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
instance { application, ports, protocol } =
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
                { init = init application.init
                , view = view application.view
                , update = update application.update protocol.updateFromServer protocol.serverMsgDecoder
                , subscriptions = subscriptions application.subscriptions ports
                , onUrlRequest = application.onUrlRequest >> AppMsg
                , onUrlChange = application.onUrlChange >> AppMsg
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


init : (flags -> Url.Url -> Browser.Navigation.Key -> ( model, Cmd msg )) -> flags -> Url.Url -> Browser.Navigation.Key -> ( model, Cmd (FrameworkMsg msg) )
init appInit flags urlUrl navKey =
    let
        ( model, appCmd ) =
            appInit flags urlUrl navKey
    in
    ( model, Cmd.map AppMsg appCmd )


view : (model -> Browser.Document msg) -> model -> Browser.Document (FrameworkMsg msg)
view appView model =
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
