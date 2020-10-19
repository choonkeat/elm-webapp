module Types exposing (..)

import Json.Decode
import Json.Encode


{-| All messages that Client can send to Server
-}
type MsgFromClient
    = SetGreeting String


{-| All messages that Server can reply to Client
-}
type MsgFromServer
    = CurrentGreeting String


{-| Http headers will be parsed into a RequestContext
Failure to parse means error; keep an always successful scenario, e.g. Anonymous
-}
type RequestContext
    = Cookied String
    | Anonymous



-- Encoder/Decoder
-- consider using "npx elm-auto-encoder-decoder src/Types.elm" instead


encodeTypesMsgFromServer : MsgFromServer -> Json.Encode.Value
encodeTypesMsgFromServer v =
    case v of
        CurrentGreeting s ->
            Json.Encode.list identity
                [ Json.Encode.string "Types.CurrentGreeting", Json.Encode.string s ]


decodeTypesMsgFromServer : Json.Decode.Decoder MsgFromServer
decodeTypesMsgFromServer =
    Json.Decode.index 0 Json.Decode.string
        |> Json.Decode.andThen
            (\word ->
                case word of
                    "Types.CurrentGreeting" ->
                        Json.Decode.map CurrentGreeting
                            (Json.Decode.index 1 Json.Decode.string)

                    _ ->
                        Json.Decode.fail "Invalid MsgFromServer"
            )


encodeTypesMsgFromClient : MsgFromClient -> Json.Encode.Value
encodeTypesMsgFromClient v =
    case v of
        SetGreeting s ->
            Json.Encode.list identity
                [ Json.Encode.string "Types.SetGreeting", Json.Encode.string s ]


decodeTypesMsgFromClient : Json.Decode.Decoder MsgFromClient
decodeTypesMsgFromClient =
    Json.Decode.index 0 Json.Decode.string
        |> Json.Decode.andThen
            (\word ->
                case word of
                    "Types.SetGreeting" ->
                        Json.Decode.map SetGreeting
                            (Json.Decode.index 1 Json.Decode.string)

                    _ ->
                        Json.Decode.fail "Invalid MsgFromClient"
            )
