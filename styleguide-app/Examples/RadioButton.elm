module Examples.RadioButton exposing
    ( example
    , State, Msg
    )

{-|

@docs example
@docs State, Msg

-}

import Browser.Dom as Dom
import Category exposing (Category(..))
import Css exposing (..)
import Debug.Control as Control exposing (Control)
import Debug.Control.Extra as ControlExtra
import Example exposing (Example)
import Html.Styled as Html exposing (..)
import Html.Styled.Attributes as Attributes exposing (css)
import KeyboardSupport exposing (Direction(..), Key(..))
import Nri.Ui.Button.V10 as Button
import Nri.Ui.Data.PremiumLevel as PremiumLevel exposing (PremiumLevel)
import Nri.Ui.Heading.V2 as Heading
import Nri.Ui.Modal.V11 as Modal
import Nri.Ui.RadioButton.V3 as RadioButton
import Nri.Ui.Text.V6 as Text
import Task


{-| -}
example : Example State Msg
example =
    { name = "RadioButton"
    , version = 3
    , state = init
    , update = update
    , subscriptions = subscriptions
    , preview = []
    , view = view
    , categories = [ Inputs ]
    , keyboardSupport =
        [ { keys = [ Arrow Left ]
          , result = "Move the focus & select the radio button to the left"
          }
        , { keys = [ Arrow Right ]
          , result = "Move the focus & select the radio button to the right"
          }
        , { keys = [ Space ]
          , result = "Select the current radio button"
          }
        ]
    }


{-| -}
view : State -> List (Html Msg)
view state =
    let
        selectionSettings =
            Control.currentValue state.selectionSettings
    in
    [ Control.view SetSelectionSettings state.selectionSettings |> fromUnstyled
    , Html.code [ css [ Css.display Css.block, Css.margin2 (Css.px 20) Css.zero ] ]
        [ text <|
            "RadioButton.view [ "
                --++ String.join ", " (List.map Tuple.first selectionSettings)
                ++ "TODO: Example code!"
                ++ " ] "
        ]
    , viewRadioButtons selectionSettings state.selectedValue
    , Modal.view
        { title = "Go Premium!"
        , wrapMsg = ModalMsg
        , content = [ Text.mediumBody [ Text.plaintext "Often, we'll launch a modal showing the benefits of premium when a Premium pennant is clicked." ] ]
        , footer =
            [ Button.button "Okay"
                [ Button.modal
                , Button.onClick CloseModal
                , Button.id "close-premium-modal"
                ]
            ]
        , focusTrap =
            { focus = Focus
            , firstId = Modal.closeButtonId
            , lastId = "close-premium-modal"
            }
        }
        [ Modal.closeButton ]
        state.modal
    ]


viewRadioButtons : SelectionSettings -> Maybe Selection -> Html Msg
viewRadioButtons selectionSettings selectedValue =
    div []
        [ RadioButton.view
            (selectionToString Dogs)
            ([ RadioButton.value Dogs
             , RadioButton.name "pets"
             , RadioButton.selectedValue selectedValue
             , RadioButton.onSelect Select
             , RadioButton.valueToString selectionToString
             , RadioButton.describedBy [ "dogs-description" ]
             , RadioButton.block
             ]
                ++ List.map Tuple.second selectionSettings.dogs
            )
        , RadioButton.view
            (selectionToString Cats)
            ([ RadioButton.value Cats
             , RadioButton.name "pets"
             , RadioButton.selectedValue selectedValue
             , RadioButton.onSelect Select
             , RadioButton.valueToString selectionToString
             , if selectedValue == Just Cats then
                RadioButton.batch
                    [ RadioButton.describedBy [ "cats-description" ]
                    , RadioButton.hiddenLabel
                    ]

               else
                RadioButton.none
             , RadioButton.disclosure
                [ span
                    [ Attributes.id "cats-description" ]
                    [ Text.smallBody [ Text.plaintext "Cats kind of do their own thing" ] ]
                ]
             , RadioButton.block
             ]
                ++ List.map Tuple.second selectionSettings.cats
            )
        , RadioButton.view
            (selectionToString Robots)
            ([ RadioButton.premium
                { teacherPremiumLevel = PremiumLevel.Premium
                , contentPremiumLevel = PremiumLevel.PremiumWithWriting
                }
             , RadioButton.value Robots
             , RadioButton.name "pets"
             , RadioButton.selectedValue selectedValue
             , RadioButton.onSelect Select
             , RadioButton.valueToString selectionToString
             , RadioButton.showPennant <| OpenModal ""
             , RadioButton.block
             ]
                ++ List.map Tuple.second selectionSettings.robots
            )
        , p
            [ Attributes.id "dogs-description" ]
            [ text "Dogs are gregarious" ]
        ]


type Selection
    = Dogs
    | Cats
    | Robots


selectionToString : Selection -> String
selectionToString selection =
    case selection of
        Dogs ->
            "Dogs"

        Cats ->
            "Cats"

        Robots ->
            "Robots"


{-| -}
type alias State =
    { selectedValue : Maybe Selection
    , modal : Modal.Model
    , selectionSettings : Control SelectionSettings
    }


{-| -}
init : State
init =
    { selectedValue = Nothing
    , modal = Modal.init
    , selectionSettings = initSelectionSettings
    }


type alias SelectionSettings =
    { dogs : List ( String, RadioButton.Attribute Selection Msg )
    , cats : List ( String, RadioButton.Attribute Selection Msg )
    , robots : List ( String, RadioButton.Attribute Selection Msg )
    }


initSelectionSettings : Control SelectionSettings
initSelectionSettings =
    Control.record SelectionSettings
        |> Control.field "Dogs" controlAttributes
        |> Control.field "Cats" controlAttributes
        |> Control.field "Robots" controlAttributes


controlAttributes : Control (List ( String, RadioButton.Attribute Selection Msg ))
controlAttributes =
    ControlExtra.list
        |> ControlExtra.listItem "disabled" disabledOrEnabled


disabledOrEnabled : Control ( String, RadioButton.Attribute Selection Msg )
disabledOrEnabled =
    Control.map
        (\isDisabled ->
            if isDisabled then
                ( "RadioButton.disabled", RadioButton.disabled )

            else
                ( "RadioButton.enabled", RadioButton.enabled )
        )
        (Control.bool False)


type Msg
    = OpenModal String
    | ModalMsg Modal.Msg
    | CloseModal
    | Select Selection
    | SetSelectionSettings (Control SelectionSettings)
    | Focus String
    | Focused (Result Dom.Error ())


{-| -}
update : Msg -> State -> ( State, Cmd Msg )
update msg model =
    case msg of
        OpenModal returnFocusTo ->
            let
                ( modal, cmd ) =
                    Modal.open
                        { startFocusOn = Modal.closeButtonId
                        , returnFocusTo = returnFocusTo
                        }
            in
            ( { model | modal = modal }, Cmd.map ModalMsg cmd )

        ModalMsg modalMsg ->
            let
                ( modal, cmd ) =
                    Modal.update { dismissOnEscAndOverlayClick = True }
                        modalMsg
                        model.modal
            in
            ( { model | modal = modal }, Cmd.map ModalMsg cmd )

        CloseModal ->
            let
                ( modal, cmd ) =
                    Modal.close model.modal
            in
            ( { model | modal = modal }, Cmd.map ModalMsg cmd )

        Select value ->
            ( { model | selectedValue = Just value }, Cmd.none )

        SetSelectionSettings selectionSettings ->
            ( { model | selectionSettings = selectionSettings }
            , Cmd.none
            )

        Focus focus ->
            ( model, Task.attempt Focused (Dom.focus focus) )

        Focused _ ->
            ( model, Cmd.none )


subscriptions : State -> Sub Msg
subscriptions { modal } =
    Sub.map ModalMsg (Modal.subscriptions modal)
