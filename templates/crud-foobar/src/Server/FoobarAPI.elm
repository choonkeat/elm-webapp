module Server.FoobarAPI exposing (..)

import Dict exposing (Dict)
import Protocol
import Protocol.Foobar
import Task exposing (Task)
import Time


{-| Explicit about the subset of ServerState we're dealing with
-}
type alias PartialServerState a =
    { a
        | foobars : Dict String Protocol.Foobar.Foobar
    }


{-| TODO:

Current implementation maintain state in memory via `serverState`
This is useful to speed up development: enabling fast iteration,
changing the required data

Before releasing the feature, refactor the state management: instead
of `Task.succeed`, perform actual task to persist state with an
external db, e.g. Hasura

-}
updateFromClient : Protocol.RequestContext -> Time.Posix -> Protocol.Foobar.MsgFromClient -> PartialServerState a -> ( PartialServerState a, Task String Protocol.MsgFromServer )
updateFromClient _ now clientMsg serverState =
    case clientMsg of
        Protocol.Foobar.Listing ->
            ( serverState
            , Task.succeed (Protocol.MsgToFoobar (Protocol.Foobar.Listed serverState.foobars))
            )

        Protocol.Foobar.Save maybeId newFoobar ->
            let
                newId =
                    Maybe.withDefault (String.fromInt (Time.posixToMillis now)) maybeId
            in
            ( { serverState
                | foobars =
                    Dict.insert newId newFoobar serverState.foobars
              }
            , Task.succeed
                (Protocol.ManyMsgFromServer
                    [ Protocol.ShowAlert (Protocol.Alert "Saved" "Foobar saved successfully!")
                    , Protocol.RedirectTo (Protocol.FoobarPage (Protocol.Foobar.ShowPage newId))
                    ]
                )
            )

        Protocol.Foobar.Load id ->
            let
                maybeFoobar =
                    Dict.get id serverState.foobars
            in
            case maybeFoobar of
                Just a ->
                    ( serverState
                    , Task.succeed (Protocol.MsgToFoobar (Protocol.Foobar.Loaded a))
                    )

                Nothing ->
                    ( serverState
                    , Task.succeed
                        (Protocol.ManyMsgFromServer
                            [ Protocol.ShowAlert (Protocol.Alert "Not Found" ("Foobar not found: " ++ id))
                            , Protocol.RedirectTo (Protocol.FoobarPage Protocol.Foobar.ListingPage)
                            ]
                        )
                    )

        Protocol.Foobar.Delete id ->
            ( { serverState
                | foobars =
                    Dict.remove id serverState.foobars
              }
            , Task.succeed
                (Protocol.ManyMsgFromServer
                    [ Protocol.ShowAlert (Protocol.Alert "Deleted" "Foobar deleted successfully!")
                    , Protocol.RedirectTo (Protocol.FoobarPage Protocol.Foobar.ListingPage)
                    ]
                )
            )
