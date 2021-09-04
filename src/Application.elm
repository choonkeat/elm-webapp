module Application exposing (..)

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
    { application : Webapp.Client.Program Flags Model Msg
    , sendToServer : Protocol.MsgFromClient -> Task Http.Error (Result String Protocol.MsgFromServer)
    }
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
            , clientMsgEncoder = Protocol.Auto.encodeProtocolMsgFromClient
            , serverMsgDecoder = Protocol.Auto.decodeProtocolMsgFromServer
            , errorDecoder = Json.Decode.string
            }
        }


main : Webapp.Client.Program Flags Model Msg
main =
    webapp.application


{-| Clients send messages to Server with this
-}
sendToServer : Protocol.MsgFromClient -> Cmd Msg
sendToServer =
    webapp.sendToServer >> Task.attempt OnMsgFromServer


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
    | OnMsgFromServer (Result Http.Error (Result String Protocol.MsgFromServer))
    | SendMessage Protocol.MsgFromClient
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

        Protocol.CurrentGreeting s ->
            ( { model | serverGreeting = s }, Cmd.none )


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none
