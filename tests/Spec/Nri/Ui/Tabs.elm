module Spec.Nri.Ui.Tabs exposing (spec)

import Browser.Dom as Dom
import Html.Styled as Html exposing (..)
import Nri.Ui.Tabs.V8 as Tabs
import ProgramTest exposing (..)
import Spec.Helpers exposing (nriDescription)
import Spec.TabsInternalHelpers exposing (..)
import Task
import Test exposing (..)
import Test.Html.Selector as Selector exposing (all, containing)


spec : Test
spec =
    describe "Nri.Ui.Tabs.V8"
        [ describe "panel rendering" panelRenderingTests
        , describe "keyboard behavior" keyboardTests
        ]


panelRenderingTests : List Test
panelRenderingTests =
    [ test "displays the associated panel when a tab is activated" <|
        \() ->
            program
                |> ensureTabbable "Tab 0"
                |> ensurePanelDisplayed "Panel 0"
                |> done
    , test "has only one panel displayed" <|
        \() ->
            program
                |> ensureOnlyOnePanelDisplayed [ "Panel 0", "Panel 1", "Panel 2" ]
                |> done
    , test "uses an attribute to identify the tabs container" <|
        \() ->
            program
                |> ensureViewHas
                    [ all
                        [ nriDescription "Nri-Ui__tabs"
                        , containing [ Selector.text "Tab 0" ]
                        , containing [ Selector.text "Tab 1" ]
                        , containing [ Selector.text "Tab 2" ]
                        ]
                    ]
                |> ensureViewHasNot
                    [ all
                        [ nriDescription "Nri-Ui__tabs"
                        , containing [ Selector.text "Panel 0" ]
                        , containing [ Selector.text "Panel 1" ]
                        , containing [ Selector.text "Panel 2" ]
                        ]
                    ]
                |> done
    ]


keyboardTests : List Test
keyboardTests =
    [ test "has a focusable tab" <|
        \() ->
            program
                |> ensureTabbable "Tab 0"
                |> done
    , test "all panels are focusable" <|
        \() ->
            program
                |> ensurePanelsFocusable [ "Panel 0", "Panel 1", "Panel 2" ]
                |> done
    , test "has only one tab included in the tab sequence" <|
        \() ->
            program
                |> ensureOnlyOneTabInSequence [ "Tab 0", "Tab 1", "Tab 2" ]
                |> done
    , test "moves focus right on right arrow key" <|
        \() ->
            program
                |> ensureTabbable "Tab 0"
                |> releaseRightArrow
                |> ensureTabbable "Tab 1"
                |> ensureOnlyOneTabInSequence [ "Tab 0", "Tab 1", "Tab 2" ]
                |> releaseRightArrow
                |> ensureTabbable "Tab 2"
                |> done
    , test "moves focus left on left arrow key" <|
        \() ->
            program
                |> ensureTabbable "Tab 0"
                |> releaseRightArrow
                |> ensureTabbable "Tab 1"
                |> releaseLeftArrow
                |> ensureTabbable "Tab 0"
                |> ensureOnlyOneTabInSequence [ "Tab 0", "Tab 1", "Tab 2" ]
                |> done
    , test "when the focus is on the first element, move focus to the last element on left arrow key" <|
        \() ->
            program
                |> ensureTabbable "Tab 0"
                |> releaseLeftArrow
                |> ensureTabbable "Tab 2"
                |> ensureOnlyOneTabInSequence [ "Tab 0", "Tab 1", "Tab 2" ]
                |> done
    , test "when the focus is on the last element, move focus to the first element on right arrow key" <|
        \() ->
            program
                |> ensureTabbable "Tab 0"
                |> releaseLeftArrow
                |> ensureTabbable "Tab 2"
                |> releaseRightArrow
                |> ensureTabbable "Tab 0"
                |> ensureOnlyOneTabInSequence [ "Tab 0", "Tab 1", "Tab 2" ]
                |> done
    ]


update : Msg -> State -> State
update msg model =
    case msg of
        FocusAndSelectTab { select, focus } ->
            Tuple.first
                ( { model | selected = select }
                , focus
                    |> Maybe.map (Dom.focus >> Task.attempt Focused)
                    |> Maybe.withDefault Cmd.none
                )

        Focused error ->
            Tuple.first ( model, Cmd.none )


view : State -> Html Msg
view model =
    Tabs.view
        { focusAndSelect = FocusAndSelectTab
        , selected = model.selected
        }
        []
        [ Tabs.build { id = 0, idString = "tab-0" } [ Tabs.tabString "Tab 0", Tabs.panelHtml (text "Panel 0") ]
        , Tabs.build { id = 1, idString = "tab-1" } [ Tabs.tabString "Tab 1", Tabs.panelHtml (text "Panel 1") ]
        , Tabs.build { id = 2, idString = "tab-2" } [ Tabs.tabString "Tab 2", Tabs.panelHtml (text "Panel 2") ]
        ]


type alias TestContext =
    ProgramTest State Msg ()


program : TestContext
program =
    ProgramTest.createSandbox
        { init = init
        , update = update
        , view = view >> Html.toUnstyled
        }
        |> ProgramTest.start ()
