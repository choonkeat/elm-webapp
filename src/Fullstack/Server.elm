module Fullstack.Server exposing
    ( PlatformWorker, Ports, Protocol
    , worker, writeResponse, writeWebsocketMessage
    )

{-|


# Definition

@docs PlatformWorker, Ports, Protocol


# Common Helpers

@docs worker, writeResponse, writeWebsocketMessage

-}

import Dict exposing (Dict)
import Fullstack.Server.HTTP exposing (Body, Headers, Method, Request, StatusCode(..), bodyOf, headersOf, methodOf, pathOf, urlOf)
import Fullstack.Server.Websocket
import Fullstack.Shared
import Json.Decode
import Json.Encode
import Platform exposing (Task)
import Task
import Time
import Types
import Url


type FrameworkMsg msg x serverMsg
    = AppMsg msg
    | OnHttpRequest (Maybe Time.Posix) Request
    | OnWebsocketEvent (Maybe Time.Posix) Json.Decode.Value
    | ReplyHttpClient Request (Result x serverMsg)
    | ReplyWebsocketClient Fullstack.Server.Websocket.Key Fullstack.Server.Websocket.Connection (Result x serverMsg)


type alias FrameworkModel a header =
    { appModel : a

    -- storing state, but not doing anything with it at the moment
    , websockets : Dict Fullstack.Server.Websocket.Key { conn : Fullstack.Server.Websocket.Connection, headers : header }
    }


{-| This is the input to create a Platform.worker
-}
type alias PlatformWorker flags model msg =
    { init : flags -> ( model, Cmd msg )
    , update : msg -> model -> ( model, Cmd msg )
    , subscriptions : model -> Sub msg
    }


{-| Use this to wire up your port in your own `Server.elm`

    port onHttpResponse : Json.Encode.Value -> Cmd msg

    writeResponse =
        Fullstack.Server.writeResponse onHttpResponse

-}
writeResponse :
    (Json.Encode.Value -> Cmd msg)
    -> Request
    ->
        { statusCode : StatusCode
        , headers : List ( String, Json.Encode.Value )
        , body : String
        }
    -> Cmd msg
writeResponse onHttpResponse request { statusCode, body, headers } =
    let
        portValue =
            Json.Encode.object
                [ ( "request", request )
                , ( "statusCode", Json.Encode.int (Fullstack.Server.HTTP.statusInt statusCode) )
                , ( "body", Json.Encode.string body )
                , ( "headers", Json.Encode.object headers )
                ]
    in
    onHttpResponse portValue


{-| Use this to wire up your port in your own `Server.elm` via websocket

    port writeWs : Json.Encode.Value -> Cmd msg

    writeWebsocketMessage =
        Fullstack.Server.writeWebsocketMessage writeWs

-}
writeWebsocketMessage : (Json.Encode.Value -> Cmd msg) -> Fullstack.Server.Websocket.Connection -> Fullstack.Server.Websocket.Key -> String -> Cmd msg
writeWebsocketMessage writeWs connection key body =
    let
        value =
            Json.Encode.object
                [ ( "key", Json.Encode.string key )
                , ( "connection", connection )
                , ( "body", Json.Encode.string body )
                ]
    in
    writeWs value


{-| A set of required ports

    - `writeResponse` is your function created with your port `onHttpResponse`

        port onHttpResponse : Json.Encode.Value -> Cmd msg

        writeResponse =
            Fullstack.Server.writeResponse onHttpResponse



    - `onHttpRequest` is a port defined in your `Server.elm`

        port onHttpRequest : (Json.Encode.Value -> msg) -> Sub msg

-}
type alias Ports msg x serverMsg =
    { writeResponse :
        Request
        ->
            { statusCode : StatusCode
            , headers : List ( String, Json.Encode.Value )
            , body : String
            }
        -> Cmd (FrameworkMsg msg x serverMsg)
    , onHttpRequest : (Json.Encode.Value -> FrameworkMsg msg x serverMsg) -> Sub (FrameworkMsg msg x serverMsg)
    , onWebsocketEvent : (Json.Encode.Value -> FrameworkMsg msg x serverMsg) -> Sub (FrameworkMsg msg x serverMsg)
    , writeWebsocketMessage : Fullstack.Server.Websocket.Connection -> Fullstack.Server.Websocket.Key -> String -> Cmd (FrameworkMsg msg x serverMsg)
    }


{-| A set of required protocols.

  - `headerDecoder` decoded value will be made available to `updateFromRoute` and `updateFromClient`
  - `clientMsgDecoder` decodes the request body IF request was sent from Client `sendToServer`
      - `updateFromClient` is called if `clientMsgDecoder` succeeds
      - `serverMsgEncoder` encodes the response body for a successful `clientMsgDecoder`
      - `errorEncoder` encodes the response body for a failed `clientMsgDecoder`
  - `routeDecoder` decodes a `Url.Url`; if successful, `updateFromRoute` will be called
      - `updateFromRoute` is called as long as `headerDecoder` succeeds
      - otherwise Fullstack.Server will respond with error 500

-}
type alias Protocol msg x serverMsg clientMsg route header model =
    { headerDecoder : Json.Decode.Decoder header
    , clientMsgDecoder : Json.Decode.Decoder clientMsg
    , updateFromClient : header -> Time.Posix -> clientMsg -> model -> ( model, Task x serverMsg )
    , serverMsgEncoder : serverMsg -> Json.Encode.Value
    , errorEncoder : x -> Json.Encode.Value
    , routeDecoder : Url.Url -> Maybe route
    , updateFromRoute : ( Method, header, Maybe route ) -> Time.Posix -> Request -> model -> ( model, Cmd msg )
    }


{-| Returns a Fullstack.Server program, capable of communicating with Fullstack.Client program
-}
worker :
    -- Platform.worker
    -- https://package.elm-lang.org/packages/elm/core/latest/Platform#worker
    { worker : PlatformWorker flags model msg

    -- Fullstack Extension
    , ports : Ports msg x serverMsg
    , protocol : Protocol msg x serverMsg clientMsg endpoint header model
    }
    -> Program flags (FrameworkModel model header) (FrameworkMsg msg x serverMsg)
worker ({ ports, protocol } as cfg) =
    Platform.worker
        { init = init cfg.worker.init
        , update = update cfg.worker.update ports protocol
        , subscriptions =
            subscriptions cfg.worker.subscriptions ports.onHttpRequest ports.onWebsocketEvent
        }


init : (flags -> ( model, Cmd msg )) -> flags -> ( FrameworkModel model header, Cmd (FrameworkMsg msg x serverMsg) )
init appInit flags =
    let
        ( appModel, appCmd ) =
            appInit flags

        model =
            FrameworkModel appModel Dict.empty
    in
    ( model, Cmd.map AppMsg appCmd )


update :
    (msg -> model -> ( model, Cmd msg ))
    -> Ports msg x serverMsg
    -> Protocol msg x serverMsg clientMsg endpoint header model
    -> FrameworkMsg msg x serverMsg
    -> FrameworkModel model header
    -> ( FrameworkModel model header, Cmd (FrameworkMsg msg x serverMsg) )
update appUpdate ports protocol msg model =
    case msg of
        AppMsg m ->
            case appUpdate m model.appModel of
                ( newAppModel, appCmd ) ->
                    ( { model | appModel = newAppModel }, Cmd.map AppMsg appCmd )

        OnWebsocketEvent Nothing value ->
            ( model, Task.perform (\now -> OnWebsocketEvent (Just now) value) Time.now )

        OnWebsocketEvent (Just now) value ->
            case Json.Decode.decodeValue Fullstack.Server.Websocket.decodeWebsocketEvent value of
                Err err ->
                    ( model, Cmd.none )

                Ok wsEvent ->
                    routeWebsocketRequest now protocol.updateFromClient protocol.clientMsgDecoder protocol.headerDecoder model wsEvent

        ReplyWebsocketClient key conn serverMsgResult ->
            ( model
            , ports.writeWebsocketMessage conn
                key
                (Json.Encode.encode 0
                    (Fullstack.Shared.encodeResultResult protocol.errorEncoder protocol.serverMsgEncoder serverMsgResult)
                )
            )

        OnHttpRequest Nothing request ->
            ( model, Task.perform (\now -> OnHttpRequest (Just now) request) Time.now )

        OnHttpRequest (Just now) request ->
            let
                endpoint =
                    urlOf request
                        |> Url.fromString
                        |> Maybe.andThen protocol.routeDecoder

                maybeHeader =
                    headersOf request
                        |> Json.Decode.decodeValue protocol.headerDecoder
                        |> Result.toMaybe

                clientMsgResult =
                    Json.Decode.decodeString protocol.clientMsgDecoder (bodyOf request)
            in
            case ( maybeHeader, clientMsgResult, pathOf request == Fullstack.Shared.httpEndpoint ) of
                ( Just context, Ok clientmsg, True ) ->
                    let
                        ( newAppModel, updateTask ) =
                            protocol.updateFromClient context now clientmsg model.appModel

                        replyCmd =
                            Task.attempt (ReplyHttpClient request) updateTask
                    in
                    ( { model | appModel = newAppModel }
                    , replyCmd
                    )

                ( Just context, _, _ ) ->
                    let
                        triplet =
                            ( methodOf request, context, endpoint )
                    in
                    case protocol.updateFromRoute triplet now request model.appModel of
                        ( newAppModel, appCmd ) ->
                            ( { model | appModel = newAppModel }, Cmd.map AppMsg appCmd )

                ( _, err, _ ) ->
                    -- invalid http request, just reject; no hard feelings
                    ( model
                    , ports.writeResponse
                        request
                        { statusCode = StatusInternalServerError
                        , body = "Internal server error"
                        , headers =
                            [ ( "X-Elm-Server-Framework", Json.Encode.string "OnHttpRequest" )
                            ]
                        }
                    )

        ReplyHttpClient request serverMsgResult ->
            let
                body =
                    Json.Encode.encode 0 (Fullstack.Shared.encodeResultResult protocol.errorEncoder protocol.serverMsgEncoder serverMsgResult)
            in
            ( model
            , ports.writeResponse
                request
                { statusCode = StatusOK
                , body = body
                , headers =
                    [ ( "Content-Type", Json.Encode.string "application/json" )
                    , ( "X-Elm-Server-Framework", Json.Encode.string "ReplyHttpClient" )
                    ]
                }
            )


subscriptions :
    (model -> Sub msg)
    -> ((Json.Encode.Value -> FrameworkMsg msg x serverMsg) -> Sub (FrameworkMsg msg x serverMsg))
    -> ((Json.Encode.Value -> FrameworkMsg msg x serverMsg) -> Sub (FrameworkMsg msg x serverMsg))
    -> FrameworkModel model header
    -> Sub (FrameworkMsg msg x serverMsg)
subscriptions appSubscription onHttpRequest onWebsocketEvent model =
    Sub.batch
        [ Sub.map AppMsg (appSubscription model.appModel)
        , onHttpRequest (OnHttpRequest Nothing)
        , onWebsocketEvent (OnWebsocketEvent Nothing)
        ]



--


routeWebsocketRequest :
    Time.Posix
    -> (header -> Time.Posix -> clientMsg -> model -> ( model, Task x serverMsg ))
    -> Json.Decode.Decoder clientMsg
    -> Json.Decode.Decoder header
    -> FrameworkModel model header
    -> Fullstack.Server.Websocket.WebsocketEvent
    -> ( FrameworkModel model header, Cmd (FrameworkMsg msg x serverMsg) )
routeWebsocketRequest now updateFromClient clientMsgDecoder headerDecoder model event =
    case event of
        Fullstack.Server.Websocket.Open conn key rawHeaders ->
            case Json.Decode.decodeValue headerDecoder rawHeaders of
                Ok headers ->
                    let
                        newWebsockets =
                            Dict.insert key { conn = conn, headers = headers } model.websockets
                    in
                    ( { model | websockets = newWebsockets }, Cmd.none )

                Err err ->
                    ( model, Cmd.none )

        Fullstack.Server.Websocket.Message conn key payload ->
            let
                clientMsgResult =
                    Json.Decode.decodeValue (Json.Decode.at [ "utf8Data" ] Json.Decode.string) payload
                        |> Result.andThen (Json.Decode.decodeString clientMsgDecoder)
            in
            case ( Dict.get key model.websockets, clientMsgResult ) of
                ( Just { headers }, Ok clientmsg ) ->
                    let
                        ( newAppModel, updateTask ) =
                            -- TODO
                            updateFromClient headers now clientmsg model.appModel

                        replyCmd =
                            Task.attempt (ReplyWebsocketClient key conn) updateTask
                    in
                    ( { model | appModel = newAppModel }
                    , replyCmd
                    )

                invalidWsRequest ->
                    ( model, Cmd.none )

        Fullstack.Server.Websocket.Close conn key reasonCode description ->
            let
                newWebsockets =
                    Dict.remove key model.websockets
            in
            ( { model | websockets = newWebsockets }, Cmd.none )
