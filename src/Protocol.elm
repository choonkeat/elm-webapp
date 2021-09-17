module Protocol exposing (..)

import Json.Decode
import Json.Encode


{-| All messages that Client can send to Server
-}
type MsgFromClient
    = ManyMsgFromClient (List MsgFromClient)
    | SetGreeting String


{-| All messages that Server can reply to Client
-}
type MsgFromServer
    = ManyMsgFromServer (List MsgFromServer)
    | ClientServerVersionMismatch Json.Encode.Value
    | CurrentGreeting String


{-| Http headers will be parsed into a RequestContext
Failure to parse means error; keep an always successful scenario, e.g. Anonymous
-}
type RequestContext
    = Cookied String
    | Anonymous
