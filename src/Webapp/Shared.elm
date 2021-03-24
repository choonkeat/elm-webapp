module Webapp.Shared exposing (..)

import Json.Decode
import Json.Encode


httpEndpoint =
    "/api/elm-webapp"



-- encoder decoder following the style of Auto


encodeResultResult : (x -> Json.Encode.Value) -> (a -> Json.Encode.Value) -> Result.Result x a -> Json.Encode.Value
encodeResultResult encodex encodea result =
    case result of
        Err x ->
            Json.Encode.list identity [ Json.Encode.string "Err", encodex x ]

        Ok a ->
            Json.Encode.list identity [ Json.Encode.string "Ok", encodea a ]


decodeResultResult : Json.Decode.Decoder x -> Json.Decode.Decoder a -> Json.Decode.Decoder (Result.Result x a)
decodeResultResult decodex decodea =
    Json.Decode.index 0 Json.Decode.string
        |> Json.Decode.andThen
            (\s ->
                case s of
                    "Err" ->
                        Json.Decode.map Err (Json.Decode.index 1 decodex)

                    "Ok" ->
                        Json.Decode.map Ok (Json.Decode.index 1 decodea)

                    _ ->
                        Json.Decode.fail ("Unexpected: " ++ s)
            )
