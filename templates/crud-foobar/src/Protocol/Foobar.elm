module Protocol.Foobar exposing (..)

import Dict exposing (Dict)
import Url.Builder
import Url.Parser exposing ((</>))


type MsgFromClient
    = Save (Maybe String) Foobar
    | Listing
    | Load String
    | Delete String


type MsgFromServer
    = Saved
    | Listed (Dict String Foobar)
    | Loaded Foobar
    | Deleted String


type alias Foobar =
    { title : String
    , body : String
    }


type Page
    = ListingPage
    | NewPage
    | ShowPage String
    | EditPage String


mountPath : List String
mountPath =
    [ "foobars" ]


pagePath : Page -> String
pagePath page =
    case page of
        ListingPage ->
            Url.Builder.absolute mountPath []

        NewPage ->
            Url.Builder.absolute (mountPath ++ [ "New" ]) []

        ShowPage pk ->
            Url.Builder.absolute (mountPath ++ [ "Show", pk ]) []

        EditPage pk ->
            Url.Builder.absolute (mountPath ++ [ "Edit", pk ]) []


pageRouter : Url.Parser.Parser (Page -> a) a
pageRouter =
    List.foldl (Url.Parser.s >> (</>)) Url.Parser.top mountPath
        </> Url.Parser.oneOf
                [ Url.Parser.map ListingPage Url.Parser.top
                , Url.Parser.map NewPage (Url.Parser.s "New")
                , Url.Parser.map ShowPage (Url.Parser.s "Show" </> Url.Parser.string)
                , Url.Parser.map EditPage (Url.Parser.s "Edit" </> Url.Parser.string)
                ]
