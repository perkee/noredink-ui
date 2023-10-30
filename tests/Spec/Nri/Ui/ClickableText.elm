module Spec.Nri.Ui.ClickableText exposing (..)

import Accessibility.Aria as Aria
import Accessibility.Role as Role
import Html.Attributes as Attributes
import Html.Styled exposing (..)
import Nri.Test.KeyboardHelpers.V1 as KeyboardHelpers
import Nri.Test.MouseHelpers.V1 as MouseHelpers
import Nri.Ui.ClickableText.V3 as ClickableText
import Nri.Ui.UiIcon.V1 as UiIcon
import ProgramTest exposing (..)
import Spec.Helpers exposing (expectFailure)
import Test exposing (..)
import Test.Html.Event as Event
import Test.Html.Query as Query
import Test.Html.Selector as Selector exposing (..)


spec : Test
spec =
    describe "Nri.Ui.ClickableText.V3"
        [ describe "elements" elementTests
        , describe "attributes" attributeTests
        , describe "icon accessibility" iconAccessibilityTests
        , describe "disabled behavior and attributes" disabledStateTests
        ]


type Type_
    = Button
    | Link


elementTests : List Test
elementTests =
    [ test "the `button` type renders as a button element" <|
        \() ->
            program Button []
                |> ensureViewHas [ tag "button" ]
                |> done
    , test "the `link` type renders as an anchor element" <|
        \() ->
            program Link []
                |> ensureViewHas [ tag "a" ]
                |> done
    , test "renders an svg element when an icon is provided" <|
        \() ->
            program Button [ ClickableText.icon UiIcon.arrowLeft ]
                |> ensureViewHas [ tag "svg" ]
                |> done
    , test "renders an svg element when a right icon is provided" <|
        \() ->
            program Button [ ClickableText.rightIcon UiIcon.arrowLeft ]
                |> ensureViewHas [ tag "svg" ]
                |> done
    , test "renders an svg element when an external link is provided" <|
        \() ->
            program Link [ ClickableText.linkExternal "https://example.com" ]
                |> ensureViewHas [ tag "svg" ]
                |> done
    ]


attributeTests : List Test
attributeTests =
    [ test "a link has the `href` attribute set to the provided value" <|
        \() ->
            program Link [ ClickableText.href "https://example.com" ]
                |> ensureViewHas
                    [ attribute (Attributes.href "https://example.com")
                    ]
                |> done
    , test "an external link has the `href` attribute set to the provided value" <|
        \() ->
            program Link [ ClickableText.linkExternal "https://example.com" ]
                |> ensureViewHas
                    [ attribute (Attributes.href "https://example.com")
                    ]
                |> done
    , test "a default link has the `target` attribute set to `\"_self\"`" <|
        \() ->
            program Link [ ClickableText.href "https://example.com" ]
                |> ensureViewHas
                    [ attribute (Attributes.target "_self")
                    ]
                |> done
    , test "an external link has the `target` attribute set to `\"_blank\"`" <|
        \() ->
            program Link [ ClickableText.linkExternal "https://example.com" ]
                |> ensureViewHas
                    [ attribute (Attributes.target "_blank")
                    ]
                |> done
    , test "an external link has the `rel` attribute set to `\"noopener noreferrer\"`" <|
        \() ->
            program Link [ ClickableText.linkExternal "https://example.com" ]
                |> ensureViewHas
                    [ attribute (Attributes.rel "noopener noreferrer")
                    ]
                |> done
    ]


iconAccessibilityTests : List Test
iconAccessibilityTests =
    [ test "the icon has the `aria-hidden` attribute set to `\"true\"`" <|
        \() ->
            program Button [ ClickableText.icon UiIcon.arrowLeft ]
                |> ensureViewHas
                    [ attribute (Aria.hidden True)
                    ]
                |> done
    , test "the icon has the `role` attribute set to `\"img\"`" <|
        \() ->
            program Button [ ClickableText.icon UiIcon.arrowLeft ]
                |> ensureViewHas
                    [ attribute Role.img
                    ]
                |> done
    , test "the icon has the `focusable` attribute set to `\"false\"`" <|
        \() ->
            program Button [ ClickableText.icon UiIcon.arrowLeft ]
                |> ensureViewHas
                    [ attribute (Attributes.attribute "focusable" "false")
                    ]
                |> done
    , test "the right icon has the `aria-hidden` attribute set to `\"true\"`" <|
        \() ->
            program Button [ ClickableText.rightIcon UiIcon.arrowLeft ]
                |> ensureViewHas
                    [ attribute (Aria.hidden True)
                    ]
                |> done
    , test "the right icon has the `role` attribute set to `\"img\"`" <|
        \() ->
            program Button [ ClickableText.rightIcon UiIcon.arrowLeft ]
                |> ensureViewHas
                    [ attribute Role.img
                    ]
                |> done
    , test "the right icon has the `focusable` attribute set to `\"false\"`" <|
        \() ->
            program Button [ ClickableText.rightIcon UiIcon.arrowLeft ]
                |> ensureViewHas
                    [ attribute (Attributes.attribute "focusable" "false")
                    ]
                |> done
    , test "the `aria-hidden` attribute is not present for an external link icon" <|
        \() ->
            program Link [ ClickableText.linkExternal "https://example.com" ]
                |> ensureViewHasNot
                    [ attribute (Aria.hidden True)
                    ]
                |> done
    , test "the external link icon has the `role` attribute set to `\"img\"`" <|
        \() ->
            program Link [ ClickableText.linkExternal "https://example.com" ]
                |> ensureViewHas
                    [ attribute Role.img
                    ]
                |> done
    , test "the external link icon has the `focusable` attribute set to `\"false\"`" <|
        \() ->
            program Link [ ClickableText.linkExternal "https://example.com" ]
                |> ensureViewHas
                    [ attribute (Attributes.attribute "focusable" "false")
                    ]
                |> done
    , test "the external link icon has the `title` tag set to `\"Opens in a new tab\"`" <|
        \() ->
            program Link [ ClickableText.linkExternal "https://example.com" ]
                |> ensureViewHas
                    [ tag "title"
                    , containing [ Selector.text "Opens in a new tab" ]
                    ]
                |> done
    ]


disabledStateTests : List Test
disabledStateTests =
    [ test "the `aria-disabled` attribute is not present for an enabled ClickableText" <|
        \() ->
            program Button []
                |> ensureViewHasNot [ attribute (Aria.disabled True) ]
                |> done
    , test "the `aria-disabled` attribute is present and set to `\"true\"` for a disabled ClickableText" <|
        \() ->
            program Button [ ClickableText.disabled True ]
                |> ensureViewHas [ attribute (Aria.disabled True) ]
                |> done
    , test "is clickable when enabled" <|
        \() ->
            program Button
                [ ClickableText.onClick NoOp
                ]
                |> clickOnButton
                |> done
    , test "is not clickable when disabled" <|
        \() ->
            program Button
                [ ClickableText.disabled True
                ]
                |> clickOnButton
                |> done
                |> expectFailure "Event.expectEvent: I found a node, but it does not listen for \"click\" events like I expected it would."
    ]


buttonSelectors : List Selector
buttonSelectors =
    [ tag "button"
    ]


type alias TestContext =
    ProgramTest Model Msg ()


pressSpaceOnButton : TestContext -> TestContext
pressSpaceOnButton =
    KeyboardHelpers.pressSpace keyboardHelperConfig { targetDetails = [] } buttonSelectors


clickOnButton : TestContext -> TestContext
clickOnButton =
    MouseHelpers.click mouseHelperConfig buttonSelectors


type alias Model =
    ()


init : Model
init =
    ()


type Msg
    = NoOp


update : Msg -> Model -> Model
update msg state =
    case msg of
        NoOp ->
            state


view : Type_ -> List (ClickableText.Attribute Msg) -> Model -> Html Msg
view type_ attributes _ =
    div []
        (case type_ of
            Button ->
                [ ClickableText.button "Accessible name" attributes
                ]

            Link ->
                [ ClickableText.link "Accessible name" attributes
                ]
        )


program : Type_ -> List (ClickableText.Attribute Msg) -> TestContext
program type_ attributes =
    ProgramTest.createSandbox
        { init = init
        , update = update
        , view = view type_ attributes >> toUnstyled
        }
        |> ProgramTest.start ()


keyboardHelperConfig : KeyboardHelpers.Config (ProgramTest model msg effect) Selector.Selector (Query.Single msg)
keyboardHelperConfig =
    { programTest_simulateDomEvent = ProgramTest.simulateDomEvent
    , query_find = Query.find
    , event_custom = Event.custom
    }


mouseHelperConfig : MouseHelpers.Config (ProgramTest model msg effect) Selector.Selector (Query.Single msg)
mouseHelperConfig =
    { programTest_simulateDomEvent = ProgramTest.simulateDomEvent
    , query_find = Query.find
    , event_click = Event.click
    , event_mouseDown = Event.mouseDown
    , event_mouseUp = Event.mouseUp
    , event_mouseOver = Event.mouseOver
    , event_custom = Event.custom
    }
