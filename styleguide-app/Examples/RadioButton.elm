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
import CommonControls exposing (premiumLevel)
import Css
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
    [ div
        [ css [ Css.displayFlex ] ]
        [ Control.view SetSelectionSettings state.selectionSettings |> fromUnstyled
        , viewExamplesCode selectionSettings state.selectedValue
        ]
    , viewExamples selectionSettings state.selectedValue
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


viewExamplesCode : SelectionSettings -> Maybe Selection -> Html Msg
viewExamplesCode selectionSettings selectedValue =
    let
        toExampleCode ( kind, settings ) =
            "RadioButton.view\n\t[ "
                ++ String.join "\n\t, " (List.map Tuple.first settings)
                ++ "\n\t] "
    in
    Html.code
        [ css
            [ Css.display Css.block
            , Css.marginLeft (Css.px 20)
            ]
        ]
        [ Html.pre []
            [ text
                ("  " ++ String.join "\n, " (List.map toExampleCode (examples selectionSettings)))
            ]
        ]


viewExamples : SelectionSettings -> Maybe Selection -> Html Msg
viewExamples selectionSettings selectedValue =
    let
        viewExample_ ( kind, settings ) =
            viewExample kind
                (List.map Tuple.second settings)
                selectedValue
    in
    div []
        (List.map viewExample_ (examples selectionSettings))


viewExample :
    Selection
    -> List (RadioButton.Attribute Selection Msg)
    -> Maybe Selection
    -> Html Msg
viewExample selection selectionSettings selectedValue =
    RadioButton.view
        { label = selectionToString selection
        , name = "pets"
        }
        ([ RadioButton.value selection
         , RadioButton.selectedValue selectedValue
         , RadioButton.onSelect Select
         , RadioButton.valueToString selectionToString
         ]
            ++ selectionSettings
        )


examples :
    SelectionSettings
    -> List ( Selection, List ( String, RadioButton.Attribute Selection Msg ) )
examples selectionSettings =
    [ ( Dogs, selectionSettings.dogs )
    , ( Cats, selectionSettings.cats )
    , ( Rats, selectionSettings.rats )
    ]


type Selection
    = Dogs
    | Cats
    | Rats


selectionToString : Selection -> String
selectionToString selection =
    case selection of
        Dogs ->
            "Dogs"

        Cats ->
            "Cats"

        Rats ->
            "Rats"


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
    , rats : List ( String, RadioButton.Attribute Selection Msg )
    }


initSelectionSettings : Control SelectionSettings
initSelectionSettings =
    Control.record SelectionSettings
        |> Control.field "Dogs" controlAttributes
        |> Control.field "Cats" controlAttributes
        |> Control.field "Rats" controlAttributes


controlAttributes : Control (List ( String, RadioButton.Attribute Selection Msg ))
controlAttributes =
    ControlExtra.list
        |> ControlExtra.listItem "hiddenLabel" labelVisibility
        |> ControlExtra.listItem "disabled" disabledOrEnabled
        |> ControlExtra.optionalListItem "showPennant" showPennant
        |> ControlExtra.optionalListItem "premium"
            -- TODO: allow the teacher premium level to vary as well:
            (Control.map
                (\( contentLevel, clevel ) ->
                    ( """
                    RadioButton.premium
                        { teacherPremiumLevel = PremiumLevel.Premium
                        , contentPremiumLevel = """
                        ++ contentLevel
                        ++ "}"
                    , RadioButton.premium
                        { teacherPremiumLevel = PremiumLevel.Premium
                        , contentPremiumLevel = clevel
                        }
                    )
                )
                premiumLevel
            )
        |> ControlExtra.optionalListItem "containerCss"
            (Control.choice
                [ ( "100% width"
                  , Control.value
                        ( "RadioButton.containerCss [ Css.width (Css.pct 100) ]"
                        , RadioButton.containerCss [ Css.width (Css.pct 100) ]
                        )
                  )
                , ( "10px right margin"
                  , Control.value
                        ( "RadioButton.containerCss [ Css.marginRight (Css.px 10) ]"
                        , RadioButton.containerCss [ Css.marginRight (Css.px 10) ]
                        )
                  )
                ]
            )
        |> ControlExtra.optionalListItem "extra content" controlDisclosure


labelVisibility : Control ( String, RadioButton.Attribute Selection Msg )
labelVisibility =
    Control.map
        (\isHidden ->
            if isHidden then
                ( "RadioButton.hiddenLabel", RadioButton.hiddenLabel )

            else
                ( "RadioButton.visibleLabel", RadioButton.visibleLabel )
        )
        (Control.bool False)


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


showPennant : Control ( String, RadioButton.Attribute Selection Msg )
showPennant =
    Control.value
        ( "RadioButton.showPennant OpenPremiumModal"
        , RadioButton.showPennant (OpenModal "dogs")
        )


controlDisclosure : Control ( String, RadioButton.Attribute Selection Msg )
controlDisclosure =
    Control.map
        (\content ->
            ( "RadioButton.disclosure [ Text.smallBody [ Text.plaintext \""
                ++ content
                ++ "\" ]"
            , RadioButton.disclosure [ Text.smallBody [ Text.plaintext content ] ]
            )
        )
        (Control.string "These pets occupy themselves.")


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
