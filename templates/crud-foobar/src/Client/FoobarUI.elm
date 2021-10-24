module Client.FoobarUI exposing
    ( Model
    , Msg(..)
    , init
    , linkToPage
    , update
    , updateFromPage
    , view
    )

import Dict exposing (Dict)
import Extra.Http
import FormData exposing (FormData)
import Html exposing (Html, button, div, form, h1, input, label, li, ol, p, small, sup, text, textarea)
import Html.Attributes exposing (autofocus, class, disabled, href, placeholder, style, type_, value)
import Html.Events exposing (onBlur, onClick, onInput, onSubmit)
import Protocol.Foobar exposing (Foobar)
import RemoteData


type alias Model =
    { page : Protocol.Foobar.Page
    , foobarForm : RemoteData.WebData (FormData Field Foobar)
    , foobars : RemoteData.WebData (Dict String Foobar)
    , foobar : RemoteData.WebData Foobar
    }


init : Model
init =
    { page = Protocol.Foobar.ListingPage
    , foobarForm = RemoteData.NotAsked
    , foobars = RemoteData.NotAsked
    , foobar = RemoteData.NotAsked
    }


type Msg
    = OnInput Field String
    | OnBlur (Maybe Field)
    | OnCheck Field Bool
    | OnSave (Maybe String) Foobar
    | OnDelete String
    | FromServer Protocol.Foobar.MsgFromServer


update : Msg -> Model -> ( Model, Maybe Protocol.Foobar.MsgFromClient )
update msg model =
    case msg of
        -- FormData standard wiring
        OnInput k string ->
            ( { model | foobarForm = RemoteData.map (FormData.onInput k string) model.foobarForm }
            , Nothing
            )

        OnBlur k ->
            ( { model | foobarForm = RemoteData.map (FormData.onVisited k) model.foobarForm }
            , Nothing
            )

        OnCheck k bool ->
            ( { model | foobarForm = RemoteData.map (FormData.onCheck k bool) model.foobarForm }
            , Nothing
            )

        -- Our own form submit handling
        OnSave maybeId foobar ->
            ( { model
                | foobar = RemoteData.Loading
                , foobarForm = RemoteData.map (FormData.onSubmit True) model.foobarForm
              }
            , Just (Protocol.Foobar.Save maybeId foobar)
            )

        OnDelete pk ->
            ( model, Just (Protocol.Foobar.Delete pk) )

        FromServer serverMsg ->
            case serverMsg of
                Protocol.Foobar.Saved ->
                    ( { model | foobarForm = RemoteData.map (FormData.onSubmit False) model.foobarForm }
                    , Nothing
                    )

                Protocol.Foobar.Listed foobars ->
                    ( { model | foobars = RemoteData.succeed foobars }
                    , Nothing
                    )

                Protocol.Foobar.Loaded foobar ->
                    ( { model
                        | foobar = RemoteData.succeed foobar
                        , foobarForm =
                            RemoteData.succeed
                                (FormData.init fieldToString
                                    [ ( Title, foobar.title )
                                    , ( Body, foobar.body )
                                    ]
                                )
                      }
                    , Nothing
                    )

                Protocol.Foobar.Deleted _ ->
                    ( { model | foobar = RemoteData.NotAsked }
                    , Nothing
                    )


updateFromPage : Protocol.Foobar.Page -> Model -> ( Model, Maybe Protocol.Foobar.MsgFromClient )
updateFromPage page model =
    updateFromPageHelper { model | page = page }


updateFromPageHelper : Model -> ( Model, Maybe Protocol.Foobar.MsgFromClient )
updateFromPageHelper model =
    case model.page of
        Protocol.Foobar.ListingPage ->
            ( { model | foobars = RemoteData.Loading }, Just Protocol.Foobar.Listing )

        Protocol.Foobar.NewPage ->
            ( { model | foobarForm = RemoteData.succeed (FormData.init fieldToString []) }, Nothing )

        Protocol.Foobar.ShowPage pk ->
            ( { model | foobar = RemoteData.Loading }, Just (Protocol.Foobar.Load pk) )

        Protocol.Foobar.EditPage pk ->
            ( { model | foobarForm = RemoteData.Loading, foobar = RemoteData.Loading }, Just (Protocol.Foobar.Load pk) )


type Field
    = Title
    | Body


fieldToString : Field -> String
fieldToString field =
    case field of
        Title ->
            "Title"

        Body ->
            "Body"


view : Model -> Html Msg
view model =
    case model.page of
        Protocol.Foobar.ListingPage ->
            div []
                [ h1 [] [ text "Foobars" ]
                , viewRemote viewListing model.foobars
                , linkToPage Protocol.Foobar.NewPage [] [ text "New" ]
                ]

        Protocol.Foobar.NewPage ->
            div []
                [ h1 [] [ text "New" ]
                , viewRemote (editForm { cancelPage = Protocol.Foobar.ListingPage } Nothing) model.foobarForm
                ]

        Protocol.Foobar.ShowPage pk ->
            div []
                [ h1 [] [ text "Show" ]
                , viewRemote viewDetail model.foobar
                , linkToPage Protocol.Foobar.ListingPage [] [ text "Foobars" ]
                , text " | "
                , linkToPage (Protocol.Foobar.EditPage pk) [] [ text "Edit" ]
                ]

        Protocol.Foobar.EditPage pk ->
            div []
                [ h1 [] [ text "Edit" ]
                , viewRemote (editForm { cancelPage = Protocol.Foobar.ShowPage pk } (Just pk)) model.foobarForm
                , div [ style "float" "right" ] [ button [ onClick (OnDelete pk) ] [ text "Delete" ] ]
                ]


linkToPage : Protocol.Foobar.Page -> List (Html.Attribute msg) -> List (Html msg) -> Html msg
linkToPage page attrs children =
    Html.a (href (Protocol.Foobar.pagePath page) :: attrs) children


viewListing : Dict String Foobar -> Html Msg
viewListing foobars =
    ol []
        (Dict.foldl (\k v list -> viewRow k v :: list) [] foobars)


viewRow : String -> Foobar -> Html Msg
viewRow id foobar =
    li []
        [ linkToPage (Protocol.Foobar.ShowPage id) [] [ text foobar.title ]
        , linkToPage (Protocol.Foobar.EditPage id) [ style "float" "right" ] [ text "Edit" ]
        ]


viewDetail : Foobar -> Html msg
viewDetail foobar =
    div []
        [ small [] [ text "Title" ]
        , p [] [ text foobar.title ]
        , small [] [ text "Body" ]
        , p [] [ text foobar.body ]
        ]


editForm : { cancelPage : Protocol.Foobar.Page } -> Maybe String -> FormData Field Foobar -> Html Msg
editForm { cancelPage } maybeId foobarForm =
    let
        ( data, errors ) =
            FormData.parse parseDontValidate foobarForm
                |> Tuple.mapSecond (FormData.visitedErrors foobarForm)

        ( formAttr, submitButtonAttr, submitButtonLabel ) =
            case data of
                FormData.Invalid ->
                    ( disabled True, disabled True, "Submit" )

                FormData.Valid foobar ->
                    ( onSubmit (OnSave maybeId foobar), disabled False, "Submit" )

                FormData.Submitting _ ->
                    ( disabled True, disabled True, "Submitting..." )
    in
    form [ formAttr ]
        [ p []
            [ label []
                [ text "Title"
                , sup [] [ text "*" ]
                , p []
                    [ input
                        [ onInput (OnInput Title)
                        , onBlur (OnBlur (Just Title))
                        , value (FormData.value Title foobarForm)
                        , type_ "text"
                        , placeholder "Enter title"
                        , autofocus True
                        ]
                        []
                    , case FormData.errorAt (Just Title) errors of
                        Just err ->
                            small [ class "error" ] [ text " ", text err ]

                        Nothing ->
                            text ""
                    ]
                ]
            , label []
                [ text "Body"
                , sup [] [ text "*" ]
                , p []
                    [ textarea
                        [ onInput (OnInput Body)
                        , onBlur (OnBlur (Just Body))
                        , value (FormData.value Body foobarForm)
                        , placeholder "Enter body"
                        ]
                        []
                    , case FormData.errorAt (Just Body) errors of
                        Just err ->
                            small [ class "error" ] [ text " ", text err ]

                        Nothing ->
                            text ""
                    ]
                ]
            , p []
                [ button [ submitButtonAttr ] [ text submitButtonLabel ]
                , text " "
                , linkToPage cancelPage [] [ text "Cancel" ]
                ]
            ]
        ]


parseDontValidate : List ( Field, String ) -> ( Maybe Foobar, List ( Maybe Field, String ) )
parseDontValidate keyValues =
    let
        initialState =
            ( { title = ""
              , body = ""
              }
            , [ ( Just Title, "cannot be blank" )
              ]
            )

        ( resultState, resultErrs ) =
            List.foldl
                (\( field, value ) ( foobar, errs ) ->
                    case field of
                        Title ->
                            ( { foobar | title = value }
                            , fieldValidWhen Title (not (String.isEmpty value)) errs
                            )

                        Body ->
                            ( { foobar | body = value }
                            , errs
                            )
                )
                initialState
                keyValues
    in
    if List.isEmpty resultErrs then
        ( Just resultState, [] )

    else
        ( Nothing, resultErrs )



-- LIBS


fieldValidWhen : f -> Bool -> List ( Maybe f, a ) -> List ( Maybe f, a )
fieldValidWhen field valid errors =
    List.filter (\( maybeField, _ ) -> Just field /= maybeField || not valid) errors


viewRemote : (a -> Html msg) -> RemoteData.WebData a -> Html msg
viewRemote viewSuccess remote =
    case remote of
        RemoteData.NotAsked ->
            p [] [ text "Not asked" ]

        RemoteData.Loading ->
            p [] [ text "Loading..." ]

        RemoteData.Success a ->
            viewSuccess a

        RemoteData.Failure err ->
            p [] [ text (Extra.Http.errorString err) ]
