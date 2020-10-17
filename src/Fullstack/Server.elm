module Fullstack.Server exposing
    ( PlatformWorker, Ports, Protocol
    , instance, writeResponse
    )

{-|


# Definition

@docs PlatformWorker, Ports, Protocol


# Common Helpers

@docs instance, writeResponse

-}

import Dict exposing (Dict)
import Fullstack.Server.HTTP exposing (Body, Headers, Method, Request, StatusCode(..), bodyOf, headersOf, methodOf, pathOf, urlOf)
import Fullstack.Shared
import Json.Decode
import Json.Encode
import Platform exposing (Task)
import Task
import Time
import Url


type FrameworkMsg msg x serverMsg
    = AppMsg msg
    | OnHttpRequest (Maybe Time.Posix) Request
    | ReplyHttpClient Request (Result x serverMsg)


type alias FrameworkModel a =
    { appModel : a
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
instance :
    -- Platform.worker
    -- https://package.elm-lang.org/packages/elm/core/latest/Platform#worker
    { worker : PlatformWorker flags model msg

    -- Fullstack Extension
    , ports : Ports msg x serverMsg
    , protocol : Protocol msg x serverMsg clientMsg endpoint header model
    }
    -> Program flags (FrameworkModel model) (FrameworkMsg msg x serverMsg)
instance { worker, ports, protocol } =
    Platform.worker
        { init = init worker.init
        , update = update worker.update ports protocol
        , subscriptions =
            subscriptions worker.subscriptions ports.onHttpRequest
        }


init : (flags -> ( model, Cmd msg )) -> flags -> ( FrameworkModel model, Cmd (FrameworkMsg msg x serverMsg) )
init appInit flags =
    let
        ( appModel, appCmd ) =
            appInit flags

        model =
            FrameworkModel appModel
    in
    ( model, Cmd.map AppMsg appCmd )


update :
    (msg -> model -> ( model, Cmd msg ))
    -> Ports msg x serverMsg
    -> Protocol msg x serverMsg clientMsg endpoint header model
    -> FrameworkMsg msg x serverMsg
    -> FrameworkModel model
    -> ( FrameworkModel model, Cmd (FrameworkMsg msg x serverMsg) )
update appUpdate ports protocol msg model =
    case msg of
        AppMsg m ->
            case appUpdate m model.appModel of
                ( newAppModel, appCmd ) ->
                    ( { model | appModel = newAppModel }, Cmd.map AppMsg appCmd )

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
    -> FrameworkModel model
    -> Sub (FrameworkMsg msg x serverMsg)
subscriptions appSubscription onHttpRequest model =
    Sub.batch
        [ Sub.map AppMsg (appSubscription model.appModel)
        , onHttpRequest (OnHttpRequest Nothing)
        ]
