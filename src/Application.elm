module Application exposing (..)

import Browser
import Browser.Navigation
import Webapp.Client
import Html exposing (Html, button, div, form, input, text)
import Html.Attributes exposing (type_)
import Html.Events exposing (onClick, onInput, onSubmit)
import Http
import Json.Decode
import Json.Encode
import Platform exposing (Task)
import Task
import Types
import Types.Auto
import Url



-- port websocketConnected : (Int -> msg) -> Sub msg
--
--
-- port websocketIn : (String -> msg) -> Sub msg
--
--
-- port websocketOut : String -> Cmd msg


webapp =
    Webapp.Client.application
        { application =
            { init = init
            , view = view
            , update = update
            , subscriptions = subscriptions
            , onUrlRequest = OnUrlRequest
            , onUrlChange = OnUrlChange
            }
        , ports =
            { websocketConnected = \_ -> Sub.none -- websocketConnected
            , websocketIn = \_ -> Sub.none -- websocketIn
            }
        , protocol =
            { updateFromServer = updateFromServer
            , clientMsgEncoder = Types.Auto.encodeTypesMsgFromClient
            , serverMsgDecoder = Types.Auto.decodeTypesMsgFromServer
            , errorDecoder = Json.Decode.string
            }
        }


main =
    webapp.application


{-| Clients send messages to Server with this
-}
sendToServer : Types.MsgFromClient -> Task Http.Error (Result String Types.MsgFromServer)
sendToServer =
    webapp.sendToServer


type alias Flags =
    {}


type alias Model =
    { navKey : Browser.Navigation.Key
    , greeting : String
    , serverGreeting : String
    }


type Msg
    = OnUrlRequest Browser.UrlRequest
    | OnUrlChange Url.Url
    | OnMsgFromServer (Result Http.Error (Result String Types.MsgFromServer))
    | SendMessage Types.MsgFromClient
    | SetGreeting String


init : Flags -> Url.Url -> Browser.Navigation.Key -> ( Model, Cmd Msg )
init flags url navKey =
    ( { navKey = navKey
      , greeting = ""
      , serverGreeting = ""
      }
    , Cmd.none
    )


view : Model -> Browser.Document Msg
view model =
    Browser.Document "Elm Webapp Client"
        [ form [ onSubmit (SendMessage (Types.SetGreeting model.greeting)) ]
            [ input [ onInput SetGreeting ] []
            , button [ type_ "submit" ] [ text "Send to server" ]
            ]
        , if model.serverGreeting == "" then
            text ""

          else
            div []
                [ text "Server reply: "
                , text model.serverGreeting
                ]
        ]


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        OnUrlRequest urlRequest ->
            -- TODO
            ( model, Cmd.none )

        OnUrlChange urlUrl ->
            -- TODO
            ( model, Cmd.none )

        OnMsgFromServer (Err err) ->
            -- http error
            ( { model | serverGreeting = Debug.toString err }, Cmd.none )

        OnMsgFromServer (Ok (Err err)) ->
            -- error from Server.elm
            ( { model | serverGreeting = "app error: " ++ err }, Cmd.none )

        OnMsgFromServer (Ok (Ok serverMsg)) ->
            updateFromServer serverMsg model

        SendMessage clientMsg ->
            -- ( model, websocketOut (Json.Encode.encode 0 (Types.encodeTypesMsgFromClient clientMsg)) )
            ( model, Task.attempt OnMsgFromServer (sendToServer clientMsg) )

        SetGreeting s ->
            ( { model | greeting = s }, Cmd.none )


updateFromServer : Types.MsgFromServer -> Model -> ( Model, Cmd Msg )
updateFromServer serverMsg model =
    case serverMsg of
        Types.CurrentGreeting s ->
            ( { model | serverGreeting = s }, Cmd.none )


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none
