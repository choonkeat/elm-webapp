module Extra.Http exposing (..)

import Http


errorString : Http.Error -> String
errorString err =
    case err of
        Http.BadUrl s ->
            "BadUrl: " ++ s

        Http.Timeout ->
            "Timeout"

        Http.NetworkError ->
            "NetworkError"

        Http.BadStatus i ->
            "BadStatus: " ++ String.fromInt i

        Http.BadBody s ->
            "BadBody: " ++ s
