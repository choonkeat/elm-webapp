module Webapp.Server.Websocket exposing
    ( Connection
    , Headers
    , Key
    , WebsocketEvent(..)
    , decodeWebsocketEvent
    )

import Json.Decode
import Json.Encode


type alias Key =
    String


type alias Connection =
    Json.Encode.Value


type alias Payload =
    Json.Encode.Value


type alias Headers =
    Json.Encode.Value


type WebsocketEvent
    = Open Connection Key Headers
    | Message Connection Key Payload
    | Close Connection Key Int (Maybe String)


decodeWebsocketEvent : Json.Decode.Decoder WebsocketEvent
decodeWebsocketEvent =
    Json.Decode.oneOf
        [ Json.Decode.map3 Open
            (Json.Decode.field "open" Json.Decode.value)
            (Json.Decode.field "key" Json.Decode.string)
            (Json.Decode.field "headers" Json.Decode.value)
        , Json.Decode.map3 Message
            (Json.Decode.field "message" Json.Decode.value)
            (Json.Decode.field "key" Json.Decode.string)
            (Json.Decode.field "payload" Json.Decode.value)
        , Json.Decode.map4 Close
            (Json.Decode.field "close" Json.Decode.value)
            (Json.Decode.field "key" Json.Decode.string)
            (Json.Decode.field "reasonCode" Json.Decode.int)
            (Json.Decode.field "description" (Json.Decode.maybe Json.Decode.string))
        ]
