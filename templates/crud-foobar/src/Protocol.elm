module Protocol exposing (..)

import Json.Encode
import Protocol.Foobar
import Url.Parser


{-| Url path that Client sends MsgFromClient values to
-}
httpEndpoint : String
httpEndpoint =
    "/api/elm-webapp"


{-| All messages that Client can send to Server
-}
type MsgFromClient
    = ManyMsgFromClient (List MsgFromClient)
    | MsgFromFoobar Protocol.Foobar.MsgFromClient
    | SetGreeting String


{-| All messages that Server can reply to Client
-}
type MsgFromServer
    = ManyMsgFromServer (List MsgFromServer)
    | ClientServerVersionMismatch Json.Encode.Value
    | MsgToFoobar Protocol.Foobar.MsgFromServer
    | ShowAlert Alert
    | RedirectTo Page
    | CurrentGreeting String


{-| Http headers will be parsed into a RequestContext
Failure to parse means error; keep an always successful scenario, e.g. Anonymous
-}
type RequestContext
    = Cookied String
    | Anonymous



--


type alias Alert =
    { title : String
    , body : String
    }


clientServerMismatchAlert : Alert
clientServerMismatchAlert =
    Alert "Oops! Page has expired" "Please reload this page on your browser"


type Page
    = NotFoundPage
    | HomePage
    | FoobarPage Protocol.Foobar.Page


pageRouter : Url.Parser.Parser (Page -> a) a
pageRouter =
    Url.Parser.oneOf
        [ Url.Parser.map HomePage Url.Parser.top
        , Url.Parser.map FoobarPage Protocol.Foobar.pageRouter
        ]


pagePath : Page -> String
pagePath page =
    case page of
        FoobarPage subPage ->
            Protocol.Foobar.pagePath subPage

        NotFoundPage ->
            "/"

        HomePage ->
            "/"
