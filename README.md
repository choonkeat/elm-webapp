
# Elm-Webapp

A setup for writing http based, client-server app in elm, inspired wholly by [Lamdera](https://lamdera.app)

## Getting started

```
npx elm-webapp element hello-app
```

This will create a skeleton file directory structure

```
hello-app
├── Makefile
├── index.js
└── src
    ├── Client.elm
    ├── Server.elm
    ├── Types.elm
    └── Types
        └── Auto.elm

1 directory, 5 files
```

The above command generates a  `Client` of [Browser.element](https://package.elm-lang.org/packages/elm/browser/latest/Browser#element). To generate a [Browser.document](https://package.elm-lang.org/packages/elm/browser/latest/Browser#document) or [Browser.application](https://package.elm-lang.org/packages/elm/browser/latest/Browser#application) instead, use either commands

```
npx elm-webapp document hello-app
npx elm-webapp application hello-app
```

## `src/Client.elm`

In this file, we see

```elm
webapp =
    Webapp.Client.element
        { element =
            { init = init
            , view = view
            , update = update
            , subscriptions = subscriptions
            }
```

This record is where we provide our standard [Browser.element](https://package.elm-lang.org/packages/elm/browser/latest/Browser#element)

```
        , ports =
            { websocketConnected = \_ -> Sub.none -- websocketConnected
            , websocketIn = \_ -> Sub.none -- websocketIn
            }
```

Here's where you can connect a WebSocket port implementation. Uncomment to enable.

```
        , protocol =
            { updateFromServer = updateFromServer
            , clientMsgEncoder = Types.Auto.encodeTypesMsgFromClient
            , serverMsgDecoder = Types.Auto.decodeTypesMsgFromServer
            , errorDecoder = Json.Decode.string
            }
        }
```

This section wires up the necessary functions to coordinate with `src/Server.elm`

#### updateFromServer

```elm
updateFromServer : MsgFromServer -> Model -> ( Model, Cmd Msg )
```
is the entry point where we handle `Types.MsgFromServer` values from `src/Server.elm`. We usually do a `case ... of` statement inside, much like how we write our standard `update` function

#### main

```elm
main =
    webapp.element
```

that gives us our `main` function for the client.

#### sendToServer

used to send `Types.MsgFromClient` values to our server whereby the server must respond with a `MsgFromServer` that we're wired to handle in `updateFromServer` (see above)

This is a seamless way for Client-Server communication.

```elm
sendToServer : MsgFromClient -> Task Http.Error (Result String MsgFromServer)
sendToServer =
    webapp.sendToServer
```

## `src/Server.elm`

serves our `Client` frontend app by default, and can respond to values from `Client.sendToServer`

```elm
main : Program Flags ServerState RequestContext Msg String MsgFromServer
main =
    Webapp.Server.worker
        { worker =
            { init = init
            , update = update
            , subscriptions = subscriptions
            }
```
This record is where we provide our standard [Platform.worker](https://package.elm-lang.org/packages/elm/core/latest/Platform#worker)

```elm
        , ports =
            { writeResponse = writeResponse
            , onHttpRequest = onHttpRequest
            , onWebsocketEvent = \_ -> Sub.none -- onWebsocketEvent
            , writeWebsocketMessage = \_ _ _ -> Cmd.none -- writeWebsocketMessage
            }
```

Here's where we've connected our httpserver with Elm ports. You can connect a WebSocket server Elm port too; uncomment to enable.

```elm
        , protocol =
            { routeDecoder = routeDecoder
            , updateFromRoute = updateFromRoute
            , updateFromClient = updateFromClient
            , serverMsgEncoder = Types.Auto.encodeTypesMsgFromServer
            , clientMsgDecoder = Types.Auto.decodeTypesMsgFromClient
            , headerDecoder = headerDecoder
            , errorEncoder = Json.Encode.string
            }
        }
```
This section wires up the necessary functions to coordinate with `src/Client.elm`

#### updateFromClient

```elm
updateFromClient : RequestContext -> Time.Posix -> MsgFromClient -> ServerState -> ( ServerState, Task String MsgFromServer )
```
is called whenever the `Client` sends a value over with its `sendToServer`. We usually do a `case ... of` statement inside, much like how we write our standard `update` function

#### updateFromRoute

```elm
updateFromRoute : ( Method, RequestContext, Maybe Route ) -> Time.Posix -> Request -> ServerState -> ( ServerState, Cmd Msg )
```
is the catch-all handler for http request; called whenever `Server` has to handle a http request that isn't handled by `updateFromClient`. e.g. oauth redirect path.

Note that `ServerState` is simply `Model` you see in standard Elm apps; named differently.

#### headerDecoder

```elm
headerDecoder : ServerState -> Json.Decode.Decoder RequestContext
```
is applied to http request headers and gives us a more meaningfully categorised `RequestContext` . e.g. we can decode the `Authorization` header and determine if the JWT value gives us a valid `LoggedInUser Email` or an `AnonymousUser`

This difference can be put into good use when we handle `updateFromClient` or `updateFromRoute`

## Other files

- `src/Types.elm` holds the types shared between Server and Client.
- `index.js` boots up our Server.elm and listens to http requests at port 8000
- `src/Types/Auto.elm` contains [auto-generated Json Encoder and Decoder](https://github.com/choonkeat/elm-auto-encoder-decoder) for all types defined in `src/Types.elm`. See [notes regarding imported types](https://github.com/choonkeat/elm-auto-encoder-decoder#dont-be-alarmed-with-i-cannot-find--variable-compiler-errors).

## License

Copyright © 2021 Chew Choon Keat

Distributed under the MIT license.
