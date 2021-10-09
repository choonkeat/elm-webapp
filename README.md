# Elm-Webapp

A setup for writing http based, client-server app in elm, inspired wholly by [Lamdera](https://lamdera.app)

### 1. Message passing

Client and Server communicate with each other using regular [Elm custom type](https://guide.elm-lang.org/types/custom_types.html) values.

[![](https://mermaid.ink/img/eyJjb2RlIjoic2VxdWVuY2VEaWFncmFtXG4gICAgbm90ZSBsZWZ0IG9mIENsaWVudC5lbG06IHR5cGUgTXNnRnJvbUNsaWVudCA9IEhlbGxvIFN0cmluZyB8IEdvb2RieWVcbiAgICBDbGllbnQuZWxtLT4-K1NlcnZlci5lbG06IHNlbmRUb1NlcnZlciAoSGVsbG8gXCJCb2JcIikgOiBDbWQgbXNnXG4gICAgU2VydmVyLmVsbS0tPj4tQ2xpZW50LmVsbTogVGFzay5zdWNjZWVkIChHcmVldCBcIkhpLCBCb2JcIilcbiAgICBub3RlIHJpZ2h0IG9mIFNlcnZlci5lbG06IHR5cGUgTXNnRnJvbVNlcnZlciA9IEdyZWV0IFN0cmluZyB8IEZhcmV3ZWxsXG4gICAgQ2xpZW50LmVsbS0-PitTZXJ2ZXIuZWxtOiBzZW5kVG9TZXJ2ZXIgR29vZGJ5ZSA6IENtZCBtc2dcbiAgICBTZXJ2ZXIuZWxtLS0-Pi1DbGllbnQuZWxtOiBUYXNrLnN1Y2NlZWQgRmFyZXdlbGxcbiAgICBcbiIsIm1lcm1haWQiOnsidGhlbWUiOiJkZWZhdWx0In0sInVwZGF0ZUVkaXRvciI6ZmFsc2UsImF1dG9TeW5jIjp0cnVlLCJ1cGRhdGVEaWFncmFtIjpmYWxzZX0)](https://mermaid-js.github.io/mermaid-live-editor/edit/#eyJjb2RlIjoic2VxdWVuY2VEaWFncmFtXG4gICAgbm90ZSBsZWZ0IG9mIENsaWVudC5lbG06IHR5cGUgTXNnRnJvbUNsaWVudCA9IEhlbGxvIFN0cmluZyB8IEdvb2RieWVcbiAgICBDbGllbnQuZWxtLT4-K1NlcnZlci5lbG06IHNlbmRUb1NlcnZlciAoSGVsbG8gXCJCb2JcIikgOiBDbWQgbXNnXG4gICAgU2VydmVyLmVsbS0tPj4tQ2xpZW50LmVsbTogVGFzay5zdWNjZWVkIChHcmVldCBcIkhpLCBCb2JcIilcbiAgICBub3RlIHJpZ2h0IG9mIFNlcnZlci5lbG06IHR5cGUgTXNnRnJvbVNlcnZlciA9IEdyZWV0IFN0cmluZyB8IEZhcmV3ZWxsXG4gICAgQ2xpZW50LmVsbS0-PitTZXJ2ZXIuZWxtOiBzZW5kVG9TZXJ2ZXIgR29vZGJ5ZSA6IENtZCBtc2dcbiAgICBTZXJ2ZXIuZWxtLS0-Pi1DbGllbnQuZWxtOiBUYXNrLnN1Y2NlZWQgRmFyZXdlbGxcbiAgICBcbiIsIm1lcm1haWQiOiJ7XG4gIFwidGhlbWVcIjogXCJkZWZhdWx0XCJcbn0iLCJ1cGRhdGVFZGl0b3IiOmZhbHNlLCJhdXRvU3luYyI6dHJ1ZSwidXBkYXRlRGlhZ3JhbSI6ZmFsc2V9)

elm-webapp will encode and decode these values to transmit them over HTTP. Websocket is possible but the code there is less robust.

Though elm-webapp does NOT manage the versioning & migration of `MsgFromClient` and `MsgFromServer`, the initial generated type definition does come with `ClientServerVersionMismatch` value which [is leveraged](https://github.com/choonkeat/elm-webapp/blob/78c3688cdf266a6338dac0fccd5707f26b0af531/src/Application.elm#L50-L54) to know that the client/server is out of sync and [present a "Please reload this browser page" message](https://github.com/choonkeat/elm-webapp/blob/78c3688cdf266a6338dac0fccd5707f26b0af531/src/Application.elm#L162-L165) to the end user.

### 2. Bring Your Own Data Persistence

elm-webapp does NOT persist the "model" of the server (aka `serverState`), unlike Lamdera. While you can still write code that update the model of Server, note that the values are only held in memory and is lost when the Server process exits. Doing so is still worthwhile during development though, enabling quick iteration of the app without messing with db & schema

You CAN have `Server.elm` instead
1. make [regular HTTP requests](https://docs.aws.amazon.com/apigateway/api-reference/making-http-requests/) to query and mutate persisted data on DynamoDB (e.g. [the-sett/elm-aws-core](https://package.elm-lang.org/packages/the-sett/elm-aws-core/latest/), [choonkeat/elm-aws](https://package.elm-lang.org/packages/choonkeat/elm-aws/latest/AWS))
2. make regular GraphQL HTTP requests to Hasura to query and mutate persisted data in a PostgreSQL database (e.g. [graphql-to-elm](https://www.npmjs.com/package/graphql-to-elm), [dillonkearns/elm-graphql](https://package.elm-lang.org/packages/dillonkearns/elm-graphql/latest/))

# Getting started

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
    ├── Protocol.elm
    └── Protocol
        └── Auto.elm

1 directory, 5 files
```

The above command generates a  `Client` of [Browser.element](https://package.elm-lang.org/packages/elm/browser/latest/Browser#element). To generate a [Browser.document](https://package.elm-lang.org/packages/elm/browser/latest/Browser#document) or [Browser.application](https://package.elm-lang.org/packages/elm/browser/latest/Browser#application) instead, use either commands

```
npx elm-webapp document hello-app
npx elm-webapp application hello-app
```

While app developers only get involved in the cyan boxes on the extreme left and right, here's a rough overview of how the pieces are put together end-to-end:

[![](https://mermaid.ink/img/eyJjb2RlIjoic2VxdWVuY2VEaWFncmFtXG4gICAgXG4gICAgcmVjdCByZ2JhKDE3MywgMjU1LCAyNDUsIDEpXG4gICAgbm90ZSByaWdodCBvZiBDbGllbnQuZWxtOiB0eXBlIE1zZ0Zyb21DbGllbnQgPSBIZWxsbyAoTWF5YmUgU3RyaW5nKVxuICAgIENsaWVudC5lbG0tPj5XZWJhcHAuQ2xpZW50OiBzZW5kVG9TZXJ2ZXIgKEhlbGxvIChKdXN0IFwiQWxpY2VcIikpIDogQ21kIG1zZ1xuICAgIGVuZFxuICAgIFdlYmFwcC5DbGllbnQtPj5XZWJhcHAuQ2xpZW50OiBjbGllbnRNc2dFbmNvZGVyXG4gICAgV2ViYXBwLkNsaWVudC0-PmVsbS9odHRwOiBIdHRwLnRhc2tcbiAgICBlbG0vaHR0cC0tPj5pbmRleC5qczogXG4gICAgaW5kZXguanMgLT4-IFdlYmFwcC5TZXJ2ZXI6IHBvcnQgb25IdHRwUmVxdWVzdFxuICAgIFdlYmFwcC5TZXJ2ZXIgLT4-IFdlYmFwcC5TZXJ2ZXI6IGNsaWVudE1zZ0RlY29kZXI8YnI-aGVhZGVyRGVjb2RlclxuICAgIHJlY3QgcmdiYSgxNzMsIDI1NSwgMjQ1LCAxKVxuICAgIFdlYmFwcC5TZXJ2ZXItPj4rU2VydmVyLmVsbTogIHVwZGF0ZUZyb21DbGllbnQgPTxicj5jYXNlIGNsaWVudE1zZyBvZi4uLlxuICAgIFNlcnZlci5lbG0tPj4tV2ViYXBwLlNlcnZlcjogVGFzay5zdWNjZWVkIChHcmVldCBcIkhpLCBBbGljZVwiKVxuICAgIG5vdGUgbGVmdCBvZiBTZXJ2ZXIuZWxtOiB0eXBlIE1zZ0Zyb21TZXJ2ZXIgPSBHcmVldCBTdHJpbmdcbiAgICBlbmRcbiAgICBXZWJhcHAuU2VydmVyIC0-PiBXZWJhcHAuU2VydmVyOiBzZXJ2ZXJNc2dFbmNvZGVyXG4gICAgV2ViYXBwLlNlcnZlciAtPj4gaW5kZXguanM6IHBvcnQgb25IdHRwUmVzcG9uc2VcbiAgICBpbmRleC5qcyAtLT4-IGVsbS9odHRwOiBcbiAgICBlbG0vaHR0cCAtPj4gV2ViYXBwLkNsaWVudDogSHR0cC5yZXNvbHZlclxuICAgIFdlYmFwcC5DbGllbnQgLT4-IFdlYmFwcC5DbGllbnQ6IHNlcnZlck1zZ0RlY29kZXJcbiAgICByZWN0IHJnYmEoMTczLCAyNTUsIDI0NSwgMSlcbiAgICBXZWJhcHAuQ2xpZW50IC0-PiBDbGllbnQuZWxtOiB1cGRhdGVGcm9tU2VydmVyID08YnI-Y2FzZSBzZXJ2ZXJNc2cgb2YgLi4uXG4gICAgZW5kXG4iLCJtZXJtYWlkIjp7InRoZW1lIjoiZGVmYXVsdCJ9LCJ1cGRhdGVFZGl0b3IiOmZhbHNlLCJhdXRvU3luYyI6dHJ1ZSwidXBkYXRlRGlhZ3JhbSI6ZmFsc2V9)](https://mermaid-js.github.io/mermaid-live-editor/edit/#eyJjb2RlIjoic2VxdWVuY2VEaWFncmFtXG4gICAgXG4gICAgcmVjdCByZ2JhKDE3MywgMjU1LCAyNDUsIDEpXG4gICAgbm90ZSByaWdodCBvZiBDbGllbnQuZWxtOiB0eXBlIE1zZ0Zyb21DbGllbnQgPSBIZWxsbyAoTWF5YmUgU3RyaW5nKVxuICAgIENsaWVudC5lbG0tPj5XZWJhcHAuQ2xpZW50OiBzZW5kVG9TZXJ2ZXIgKEhlbGxvIChKdXN0IFwiQWxpY2VcIikpIDogQ21kIG1zZ1xuICAgIGVuZFxuICAgIFdlYmFwcC5DbGllbnQtPj5XZWJhcHAuQ2xpZW50OiBjbGllbnRNc2dFbmNvZGVyXG4gICAgV2ViYXBwLkNsaWVudC0-PmVsbS9odHRwOiBIdHRwLnRhc2tcbiAgICBlbG0vaHR0cC0tPj5pbmRleC5qczogXG4gICAgaW5kZXguanMgLT4-IFdlYmFwcC5TZXJ2ZXI6IHBvcnQgb25IdHRwUmVxdWVzdFxuICAgIFdlYmFwcC5TZXJ2ZXIgLT4-IFdlYmFwcC5TZXJ2ZXI6IGNsaWVudE1zZ0RlY29kZXI8YnI-aGVhZGVyRGVjb2RlclxuICAgIHJlY3QgcmdiYSgxNzMsIDI1NSwgMjQ1LCAxKVxuICAgIFdlYmFwcC5TZXJ2ZXItPj4rU2VydmVyLmVsbTogIHVwZGF0ZUZyb21DbGllbnQgPTxicj5jYXNlIGNsaWVudE1zZyBvZi4uLlxuICAgIFNlcnZlci5lbG0tPj4tV2ViYXBwLlNlcnZlcjogVGFzay5zdWNjZWVkIChHcmVldCBcIkhpLCBBbGljZVwiKVxuICAgIG5vdGUgbGVmdCBvZiBTZXJ2ZXIuZWxtOiB0eXBlIE1zZ0Zyb21TZXJ2ZXIgPSBHcmVldCBTdHJpbmdcbiAgICBlbmRcbiAgICBXZWJhcHAuU2VydmVyIC0-PiBXZWJhcHAuU2VydmVyOiBzZXJ2ZXJNc2dFbmNvZGVyXG4gICAgV2ViYXBwLlNlcnZlciAtPj4gaW5kZXguanM6IHBvcnQgb25IdHRwUmVzcG9uc2VcbiAgICBpbmRleC5qcyAtLT4-IGVsbS9odHRwOiBcbiAgICBlbG0vaHR0cCAtPj4gV2ViYXBwLkNsaWVudDogSHR0cC5yZXNvbHZlclxuICAgIFdlYmFwcC5DbGllbnQgLT4-IFdlYmFwcC5DbGllbnQ6IHNlcnZlck1zZ0RlY29kZXJcbiAgICByZWN0IHJnYmEoMTczLCAyNTUsIDI0NSwgMSlcbiAgICBXZWJhcHAuQ2xpZW50IC0-PiBDbGllbnQuZWxtOiB1cGRhdGVGcm9tU2VydmVyID08YnI-Y2FzZSBzZXJ2ZXJNc2cgb2YgLi4uXG4gICAgZW5kXG4iLCJtZXJtYWlkIjoie1xuICBcInRoZW1lXCI6IFwiZGVmYXVsdFwiXG59IiwidXBkYXRlRWRpdG9yIjpmYWxzZSwiYXV0b1N5bmMiOnRydWUsInVwZGF0ZURpYWdyYW0iOmZhbHNlfQ)

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

☝️ This record is where we provide our standard [Browser.element](https://package.elm-lang.org/packages/elm/browser/latest/Browser#element), [Browser.document](https://package.elm-lang.org/packages/elm/browser/latest/Browser#document), or [Browser.application](https://package.elm-lang.org/packages/elm/browser/latest/Browser#application)

```elm
        , ports =
            { websocketConnected = \_ -> Sub.none -- websocketConnected
            , websocketIn = \_ -> Sub.none -- websocketIn
            }
```

☝️ Here's where you can connect a WebSocket port implementation to communicate with `src/Server.elm`. Uncomment to enable.

By default, `elm-webapp` is wired up to communicate with `src/Server.elm` through regular http `POST /api/elm-webapp`

```elm
        , protocol =
            { updateFromServer = updateFromServer
            , clientMsgEncoder = Protocol.Auto.encodeProtocolMsgFromClient
            , serverMsgDecoder =
                Json.Decode.oneOf
                    [ Protocol.Auto.decodeProtocolMsgFromServer
                    , Json.Decode.map Protocol.ClientServerVersionMismatch Json.Decode.value
                    ]
            , errorDecoder = Json.Decode.string
            , httpEndpoint = Protocol.httpEndpoint
            }
        }
```

☝️ This section wires up the necessary functions to coordinate with `src/Server.elm`

#### updateFromServer

```elm
updateFromServer : MsgFromServer -> Model -> ( Model, Cmd Msg )
```
is the entry point where we handle `MsgFromServer` values from `src/Server.elm`. We usually do a `case ... of` statement inside, much like how we write our standard `update` function

#### main

```elm
main =
    webapp.element
```

that gives us our `main` function for the client.

#### sendToServer

```elm
sendToServer : Protocol.MsgFromClient -> Cmd Msg
sendToServer =
    webapp.sendToServer >> Task.attempt OnMsgFromServer
```

sends `MsgFromClient` values to our server whereby the server must respond with a `MsgFromServer` that we've wired to handle in `updateFromServer` (see above). This happens over http post by default, and over websockets if enabled (see above)

This is how we achieve a seamless and type-safe way for Client-Server communication.

## `src/Server.elm`

serves our `Client` frontend app by default, and can respond to values from `Client.sendToServer` or regular http requests.

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
☝️ This record is where we provide our standard [Platform.worker](https://package.elm-lang.org/packages/elm/core/latest/Platform#worker)

```elm
        , ports =
            { writeResponse = writeResponse
            , onHttpRequest = onHttpRequest
            , onWebsocketEvent = \_ -> Sub.none -- onWebsocketEvent
            , writeWebsocketMessage = \_ _ _ -> Cmd.none -- writeWebsocketMessage
            }
```

☝️ Here's where we've connected our httpserver with Elm ports. You can connect a WebSocket server Elm port too; uncomment to enable.

```elm
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
```
☝️ This section wires up the necessary functions to coordinate with `src/Client.elm`

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

- `index.js` boots up our `src/Server.elm`
	- by default, `node.js`  runs [`http.createServer`](https://nodejs.org/api/http.html#http_http_createserver_options_requestlistener) and let Elm handles http request and write responses via Elm ports
	- if env `LAMBDA` is set, `lambda.js` will instead setup a callback so we can handle http request inside [AWS Lambda behind an API Gateway](https://docs.aws.amazon.com/apigateway/latest/developerguide/getting-started-with-lambda-integration.html).
	- other possible integrations are `cloudflare-workers.js` or even [`deno-deploy.js`](https://deno.com/deploy)
	- PRs are extremely welcome to improve the robustness of these integrations 🙇‍♂️
- `src/Protocol.elm` holds the types shared between Server and Client.
    - [encoders & decoders are auto-generated](https://github.com/choonkeat/elm-auto-encoder-decoder) in `src/Protocol/Auto.elm` ; also see [gotchas regarding imported types](https://github.com/choonkeat/elm-auto-encoder-decoder#dont-be-alarmed-with-i-cannot-find--variable-compiler-errors)
    - we're using `elm-auto-encoder-decoder` in `elm-webapp` only for convenience; you can switch it out for your own encoders & decoders. BUT if you continue using `elm-auto-encoder-decoder`, don't use them anywhere else (e.g. as encoder to save in db, exposed as part of your external api, etc...). Main reason being that the serialized format could change future releases of `elm-auto-encoder-decoder` and thus MUST NOT be relied on.

# How do I...

- Support OAuth login? See https://github.com/choonkeat/elm-webapp-oauth-example#readme

# License

Copyright © 2021 Chew Choon Keat

Distributed under the MIT license.
