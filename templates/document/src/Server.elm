port module Server exposing (..)

import Json.Decode
import Json.Encode
import Platform exposing (Task)
import Protocol exposing (MsgFromServer)
import Protocol.Auto
import Task
import Time
import Url
import Webapp.Server
import Webapp.Server.HTTP exposing (Method(..), Request, Response, StatusCode(..))



-- port onWebsocketEvent : (Json.Encode.Value -> msg) -> Sub msg
--
--
-- port writeWs : Json.Encode.Value -> Cmd msg
--
--
-- writeWebsocketMessage =
--     Webapp.Server.writeWebsocketMessage writeWs


port onHttpRequest : (Json.Encode.Value -> msg) -> Sub msg


port onHttpResponse : Json.Encode.Value -> Cmd msg


writeResponse : Request -> Response -> Cmd msg
writeResponse =
    Webapp.Server.writeResponse onHttpResponse


main : Webapp.Server.Program Flags ServerState Protocol.RequestContext Msg String Protocol.MsgFromServer
main =
    Webapp.Server.worker
        { worker =
            { init = init
            , update = update
            , subscriptions = subscriptions
            }
        , ports =
            { writeResponse = writeResponse
            , onHttpRequest = onHttpRequest
            , onWebsocketEvent = \_ -> Sub.none -- onWebsocketEvent
            , writeWebsocketMessage = \_ _ _ -> Cmd.none -- writeWebsocketMessage
            }
        , protocol =
            { routeDecoder = routeDecoder
            , updateFromRoute = updateFromRoute
            , updateFromClient = updateFromClient
            , serverMsgEncoder = Protocol.Auto.encodeProtocolMsgFromServer
            , clientMsgDecoder = Protocol.Auto.decodeProtocolMsgFromClient
            , headerDecoder = headerDecoder
            , errorEncoder = Json.Encode.string
            , httpEndpoint = Protocol.httpEndpoint
            }
        }


type alias Flags =
    { jsSha : Maybe String
    , assetsHost : Maybe String
    }


type alias ServerState =
    { greeting : String
    , jsSha : String
    , assetsHost : String
    }


type Msg
    = OnHttpResponse Request (Result Response Response)



-- Platform.worker


init : Flags -> ( ServerState, Cmd Msg )
init flags =
    let
        serverState =
            { greeting = "Hello world"
            , jsSha = Maybe.withDefault "" flags.jsSha
            , assetsHost = Maybe.withDefault "" flags.assetsHost
            }

        cmd =
            Cmd.none
    in
    ( serverState, cmd )


update : Msg -> ServerState -> ( ServerState, Cmd Msg )
update msg serverState =
    case msg of
        OnHttpResponse request (Ok response) ->
            ( serverState, writeResponse request response )

        OnHttpResponse request (Err response) ->
            ( serverState, writeResponse request response )


subscriptions : ServerState -> Sub Msg
subscriptions serverState =
    Sub.none



-- Server-side route and update function


type Route
    = Homepage
    | ApiElmWebapp


routeDecoder : Url.Url -> Maybe Route
routeDecoder urlUrl =
    case urlUrl.path of
        "/" ->
            Just Homepage

        _ ->
            if Protocol.httpEndpoint == urlUrl.path then
                Just ApiElmWebapp

            else
                Nothing


updateFromRoute : ( Method, Protocol.RequestContext, Maybe Route ) -> Time.Posix -> Request -> ServerState -> ( ServerState, Cmd Msg )
updateFromRoute ( method, ctx, route ) now request serverState =
    case ( method, ctx, route ) of
        ( GET, _, _ ) ->
            ( serverState
            , writeResponse request
                { statusCode = StatusOK
                , body =
                    spaHtml
                        |> String.replace "JS_SHA" serverState.jsSha
                        |> String.replace """"/assets""" ("\"" ++ serverState.assetsHost ++ "/assets")
                , headers =
                    [ ( "Content-Type", Json.Encode.string "text/html; charset=utf-8" )
                    , ( "Cache-Control", Json.Encode.string "max-age=0" )
                    ]
                }
            )

        ( _, _, Just ApiElmWebapp ) ->
            -- we're here only when clientMsgDecoder failed
            ( serverState
            , writeResponse request
                { statusCode = StatusOK
                , body =
                    Protocol.ClientServerVersionMismatch Json.Encode.null
                        |> Protocol.Auto.encodeProtocolMsgFromServer
                        |> Json.Encode.encode 0
                , headers = []
                }
            )

        -- TODO: possibly a (POST, _, Login) to "Set-Cookie"
        ( _, _, _ ) ->
            ( serverState
            , writeResponse request { statusCode = StatusNotFound, body = "Not found?", headers = [] }
            )



-- MsgFromClient update function


updateFromClient : Protocol.RequestContext -> Time.Posix -> Protocol.MsgFromClient -> ServerState -> ( ServerState, Task String MsgFromServer )
updateFromClient ctx now clientMsg serverState =
    case clientMsg of
        Protocol.ManyMsgFromClient msglist ->
            -- Handling a batched list of `MsgFromClient`
            let
                overStateAndTask nextMsg ( currentState, accumulatedTasks ) =
                    updateFromClient ctx now nextMsg currentState
                        |> Tuple.mapSecond (\nextTask -> nextTask :: accumulatedTasks)
            in
            List.foldl overStateAndTask ( serverState, [] ) msglist
                |> Tuple.mapSecond (Task.sequence >> Task.map Protocol.ManyMsgFromServer)

        Protocol.SetGreeting s ->
            ( { serverState | greeting = s }
            , Task.succeed (Protocol.CurrentGreeting ("You said: <" ++ s ++ "> at " ++ Debug.toString now))
            )



--


headerDecoder : Time.Posix -> ServerState -> Json.Decode.Decoder Protocol.RequestContext
headerDecoder now serverState =
    Json.Decode.oneOf
        [ Json.Decode.map Protocol.Cookied (Json.Decode.field "cookie" Json.Decode.string)
        , Json.Decode.succeed Protocol.Anonymous
        ]


spaHtml : String
spaHtml =
    """
    <!DOCTYPE HTML>
    <html>
    <head>
      <meta charset="UTF-8">
      <title>create-elm-server</title>
      <script src="/assets/client.js?JS_SHA"></script>
      <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no">
    </head>
    <body>
    <div id="elm"></div>
    <script>
    var now = new Date()
    var app = Elm.Client.init({
      node: document.getElementById('elm'),
      flags: {}
    });

    if (window.WebSocket && app.ports && app.ports.websocketOut) {
      console.log('[js websocket]', window.WebSocket)
      ;(function (app, WebSocket) {
        var ws = {}
        app.ports.websocketOut.subscribe(function (msg) {
          try {
            console.log('[js websocket] send', msg)
            ws.conn.send(msg)
          } catch (e) {
            console.log('[js websocket] send fail', e) // e.g. ws.conn not established
          }
        })
        function connectWebSocket (app, wsUrl, optionalProtocol) {
          ws.conn = new WebSocket(wsUrl, optionalProtocol)
          ws.conn.onopen = function (event) {
            console.log('[js websocket] connected', event)
            app.ports.websocketConnected.send(event.timeStamp | 0)
          }
          ws.conn.onmessage = function (event) {
            console.log('[js websocket] message', event)
            app.ports.websocketIn.send(event.data)
          }
          ws.conn.onerror = function (event) {
            console.log('[js websocket] error', event)
          }
          ws.conn.onclose = function (event) {
            console.log('[js websocket] close', event)
            ws.conn.onclose = null
            ws.conn = null
            setTimeout(function () {
              console.log('[js websocket] retrying...')
              connectWebSocket(app, wsUrl, optionalProtocol)
            }, 1000)
          }
        }
        connectWebSocket(app, (window.location.protocol === 'https:' ? 'wss' : 'ws') + '://' + window.location.host)
      })(app, window.WebSocket)
    }

    </script>
    </body>
    </html>
    """
