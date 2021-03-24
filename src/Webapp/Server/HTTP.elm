module Webapp.Server.HTTP exposing
    ( Body, Headers, Method(..), Request, StatusCode(..), Url
    , bodyOf, headersOf, methodFromString, methodOf, methodString, pathOf, statusInt, urlOf
    )

{-| Data types and their helper functions to work with HTTP handlers


# Definition

@docs Body, Headers, Method, Request, StatusCode, Url


# Common Helpers

@docs bodyOf, headersOf, methodFromString, methodOf, methodString, pathOf, statusInt, urlOf

-}

import Json.Decode
import Json.Encode


{-| Alias for String
-}
type alias Url =
    String


{-| Alias for String
-}
type alias Body =
    String


{-| Custom type representing all http methods
-}
type Method
    = GET
    | HEAD
    | POST
    | PUT
    | DELETE
    | CONNECT
    | OPTIONS
    | TRACE
    | PATCH


{-| Returns http `Method` as String
-}
methodString : Method -> String
methodString method =
    case method of
        GET ->
            "GET"

        HEAD ->
            "HEAD"

        POST ->
            "POST"

        PUT ->
            "PUT"

        DELETE ->
            "DELETE"

        CONNECT ->
            "CONNECT"

        OPTIONS ->
            "OPTIONS"

        TRACE ->
            "TRACE"

        PATCH ->
            "PATCH"


{-| Parse a String and return as http `Method`
-}
methodFromString : String -> Method
methodFromString str =
    case str of
        "GET" ->
            GET

        "HEAD" ->
            HEAD

        "POST" ->
            POST

        "PUT" ->
            PUT

        "DELETE" ->
            DELETE

        "CONNECT" ->
            CONNECT

        "OPTIONS" ->
            OPTIONS

        "TRACE" ->
            TRACE

        "PATCH" ->
            PATCH

        _ ->
            GET


{-| Alias for opaque Json.Encode.Value
-}
type alias Request =
    Json.Decode.Value


{-| Alias for opaque Json.Encode.Value
-}
type alias Headers =
    Json.Decode.Value


{-| Returns http `method` from `Request`
-}
methodOf : Request -> Method
methodOf request =
    Json.Decode.decodeValue (Json.Decode.field "method" Json.Decode.string) request
        |> Result.map methodFromString
        |> Result.withDefault GET


{-| Returns `url` from `Request`
-}
urlOf : Request -> String
urlOf request =
    Json.Decode.decodeValue (Json.Decode.field "url" Json.Decode.string) request
        |> Result.withDefault ""


{-| Returns request body from `Request`
-}
bodyOf : Request -> String
bodyOf request =
    Json.Decode.decodeValue (Json.Decode.field "body" Json.Decode.string) request
        |> Result.withDefault ""


{-| Returns request headers from `Request`
-}
headersOf : Request -> Headers
headersOf request =
    Json.Decode.decodeValue (Json.Decode.field "headers" Json.Decode.value) request
        |> Result.withDefault Json.Encode.null


{-| Returns request path from `Request`
-}
pathOf : Request -> String
pathOf request =
    Json.Decode.decodeValue (Json.Decode.field "path" Json.Decode.string) request
        |> Result.withDefault "/"


{-| Custom type representing all http `StatusCode`
-}
type StatusCode
    = StatusContinue
    | StatusSwitchingProtocols
    | StatusProcessing
    | StatusEarlyHints
    | StatusOK
    | StatusCreated
    | StatusAccepted
    | StatusNonAuthoritativeInformation
    | StatusNoContent
    | StatusResetContent
    | StatusPartialContent
    | StatusMultiStatus
    | StatusAlreadyReported
    | StatusIMUsed
    | StatusMultipleChoices
    | StatusMovedPermanently
    | StatusFound
    | StatusSeeOther
    | StatusNotModified
    | StatusUseProxy
    | StatusTemporaryRedirect
    | StatusPermanentRedirect
    | StatusBadRequest
    | StatusUnauthorized
    | StatusPaymentRequired
    | StatusForbidden
    | StatusNotFound
    | StatusMethodNotAllowed
    | StatusNotAcceptable
    | StatusProxyAuthenticationRequired
    | StatusRequestTimeout
    | StatusConflict
    | StatusGone
    | StatusLengthRequired
    | StatusPreconditionFailed
    | StatusPayloadTooLarge
    | StatusURITooLong
    | StatusUnsupportedMediaType
    | StatusRangeNotSatisfiable
    | StatusExpectationFailed
    | StatusMisdirectedRequest
    | StatusUnprocessableEntity
    | StatusLocked
    | StatusFailedDependency
    | StatusTooEarly
    | StatusUpgradeRequired
    | StatusPreconditionRequired
    | StatusTooManyRequests
    | StatusRequestHeaderFieldsTooLarge
    | StatusUnavailableForLegalReasons
    | StatusInternalServerError
    | StatusNotImplemented
    | StatusBadGateway
    | StatusServiceUnavailable
    | StatusGatewayTimeout
    | StatusHTTPVersionNotSupported
    | StatusVariantAlsoNegotiates
    | StatusInsufficientStorage
    | StatusLoopDetected
    | StatusNotExtended
    | StatusNetworkAuthenticationRequired


{-| Returns http StatusCode as integer
-}
statusInt : StatusCode -> Int
statusInt code =
    case code of
        StatusContinue ->
            100

        StatusSwitchingProtocols ->
            101

        StatusProcessing ->
            102

        StatusEarlyHints ->
            103

        StatusOK ->
            200

        StatusCreated ->
            201

        StatusAccepted ->
            202

        StatusNonAuthoritativeInformation ->
            203

        StatusNoContent ->
            204

        StatusResetContent ->
            205

        StatusPartialContent ->
            206

        StatusMultiStatus ->
            207

        StatusAlreadyReported ->
            208

        StatusIMUsed ->
            226

        StatusMultipleChoices ->
            300

        StatusMovedPermanently ->
            301

        StatusFound ->
            302

        StatusSeeOther ->
            303

        StatusNotModified ->
            304

        StatusUseProxy ->
            305

        StatusTemporaryRedirect ->
            307

        StatusPermanentRedirect ->
            308

        StatusBadRequest ->
            400

        StatusUnauthorized ->
            401

        StatusPaymentRequired ->
            402

        StatusForbidden ->
            403

        StatusNotFound ->
            404

        StatusMethodNotAllowed ->
            405

        StatusNotAcceptable ->
            406

        StatusProxyAuthenticationRequired ->
            407

        StatusRequestTimeout ->
            408

        StatusConflict ->
            409

        StatusGone ->
            410

        StatusLengthRequired ->
            411

        StatusPreconditionFailed ->
            412

        StatusPayloadTooLarge ->
            413

        StatusURITooLong ->
            414

        StatusUnsupportedMediaType ->
            415

        StatusRangeNotSatisfiable ->
            416

        StatusExpectationFailed ->
            417

        StatusMisdirectedRequest ->
            421

        StatusUnprocessableEntity ->
            422

        StatusLocked ->
            423

        StatusFailedDependency ->
            424

        StatusTooEarly ->
            425

        StatusUpgradeRequired ->
            426

        StatusPreconditionRequired ->
            428

        StatusTooManyRequests ->
            429

        StatusRequestHeaderFieldsTooLarge ->
            431

        StatusUnavailableForLegalReasons ->
            451

        StatusInternalServerError ->
            500

        StatusNotImplemented ->
            501

        StatusBadGateway ->
            502

        StatusServiceUnavailable ->
            503

        StatusGatewayTimeout ->
            504

        StatusHTTPVersionNotSupported ->
            505

        StatusVariantAlsoNegotiates ->
            506

        StatusInsufficientStorage ->
            507

        StatusLoopDetected ->
            508

        StatusNotExtended ->
            510

        StatusNetworkAuthenticationRequired ->
            511
