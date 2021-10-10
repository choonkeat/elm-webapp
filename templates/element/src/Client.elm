module Client exposing (..)

import Browser
import Browser.Navigation
import Html exposing (Html, button, div, form, input, text)
import Html.Attributes exposing (type_)
import Html.Events exposing (onClick, onInput, onSubmit)
import Http
import Json.Decode
import Json.Encode
import Platform exposing (Task)
import Protocol
import Protocol.Auto
import Task
import Url
import Webapp.Client



-- port websocketConnected : (Int -> msg) -> Sub msg
--
--
-- port websocketIn : (String -> msg) -> Sub msg
--
--
-- port websocketOut : String -> Cmd msg


webapp :
    { element : Webapp.Client.Program Flags Model Msg
    , sendToServer : Protocol.MsgFromClient -> Task Http.Error (Result String Protocol.MsgFromServer)
    }
webapp =
    Webapp.Client.element
        { element =
            { init = init
            , view = view
            , update = update
            , subscriptions = subscriptions
            }
        , ports =
            { websocketConnected = \_ -> Sub.none -- websocketConnected
            , websocketIn = \_ -> Sub.none -- websocketIn
            }
        , protocol =
            { updateFromServer = updateFromServer
            , clientMsgEncoder = Protocol.Auto.encodeProtocolMsgFromClient
            , serverMsgDecoder =
                Json.Decode.oneOf
                    [ Protocol.Auto.decodeProtocolMsgFromServer
                    , Json.Decode.map Protocol.ClientServerVersionMismatch Json.Decode.value
                    ]
            , errorDecoder = Json.Decode.string
            , httpEndpoint = Protocol.httpEndpoint
            }
        }


main : Webapp.Client.Program Flags Model Msg
main =
    webapp.element


{-| Clients send messages to Server with this
-}
sendToServer : Protocol.MsgFromClient -> Cmd Msg
sendToServer =
    webapp.sendToServer >> Task.attempt OnMsgFromServer


type alias Flags =
    {}


type alias Model =
    { greeting : String
    , serverGreeting : String
    }


type Msg
    = OnMsgFromServer (Result Http.Error (Result String Protocol.MsgFromServer))
    | SendMessage Protocol.MsgFromClient
    | SetGreeting String


init : Flags -> ( Model, Cmd Msg )
init flags =
    ( { greeting = ""
      , serverGreeting = ""
      }
    , Cmd.none
    )


view : Model -> Html.Html Msg
view model =
    div []
        [ form [ onSubmit (SendMessage (Protocol.SetGreeting model.greeting)) ]
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
        OnMsgFromServer (Err err) ->
            -- http error
            ( { model | serverGreeting = Debug.toString err }, Cmd.none )

        OnMsgFromServer (Ok (Err err)) ->
            -- error from Server.elm
            ( { model | serverGreeting = "app error: " ++ err }, Cmd.none )

        OnMsgFromServer (Ok (Ok serverMsg)) ->
            updateFromServer serverMsg model

        SendMessage clientMsg ->
            -- ( model, websocketOut (Json.Encode.encode 0 (Protocol.encodeProtocolMsgFromClient clientMsg)) )
            ( model, sendToServer clientMsg )

        SetGreeting s ->
            ( { model | greeting = s }, Cmd.none )


updateFromServer : Protocol.MsgFromServer -> Model -> ( Model, Cmd Msg )
updateFromServer serverMsg model =
    case serverMsg of
        Protocol.ManyMsgFromServer msglist ->
            -- Handling a batched list of `MsgFromServer`
            let
                overModelAndCmd nextMsg ( currentModel, currentCmd ) =
                    updateFromServer nextMsg currentModel
                        |> Tuple.mapSecond (\nextCmd -> Cmd.batch [ nextCmd, currentCmd ])
            in
            List.foldl overModelAndCmd ( model, Cmd.none ) msglist

        Protocol.ClientServerVersionMismatch raw ->
            ( { model | serverGreeting = "Oops! This page has expired. Please reload this page in your browser." }
            , Cmd.none
            )

        Protocol.CurrentGreeting s ->
            ( { model | serverGreeting = s }, Cmd.none )


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none
