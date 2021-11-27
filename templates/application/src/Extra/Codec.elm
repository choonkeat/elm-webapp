module Extra.Codec exposing (..)

{-| Add custom encoder/decoders here for when encoder/decoders
can't be auto generated
-}

import Json.Decode
import Json.Encode
import Time


decodeTimePosix : Json.Decode.Decoder Time.Posix
decodeTimePosix =
    Json.Decode.int
        |> Json.Decode.map Time.millisToPosix


encodeTimePosix : Time.Posix -> Json.Encode.Value
encodeTimePosix t =
    Time.posixToMillis t
        |> Json.Encode.int
