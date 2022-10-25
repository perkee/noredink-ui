module Spec.Nri.Ui.Highlighter exposing (spec)

import Accessibility.Key as Key
import Expect exposing (Expectation)
import Html.Styled exposing (toUnstyled)
import Nri.Ui.Colors.V1 as Colors
import Nri.Ui.Highlightable.V1 as Highlightable exposing (Highlightable)
import Nri.Ui.Highlighter.V1 as Highlighter
import Nri.Ui.HighlighterTool.V1 as Tool exposing (Tool)
import ProgramTest exposing (..)
import Regex exposing (Regex)
import Spec.KeyboardHelpers as KeyboardHelpers
import Spec.MouseHelpers as MouseHelpers
import Test exposing (..)
import Test.Html.Query as Query
import Test.Html.Selector as Selector


spec : Test
spec =
    describe "Nri.Ui.Highlighter.V1"
        [ describe "keyboard behavior" keyboardTests
        ]


keyboardTests : List Test
keyboardTests =
    [ test "has a focusable element when there is one" <|
        \() ->
            Highlightable.initFragments Nothing "Pothos indirect light"
                |> program Nothing
                |> ensureTabbable "Pothos"
                |> done
    , test "has only one element included in the tab sequence" <|
        \() ->
            Highlightable.initFragments Nothing "Pothos indirect light"
                |> program Nothing
                |> ensureOnlyOneInTabSequence (String.words "Pothos indirect light")
                |> done
    , test "moves focus right on right arrow key" <|
        \() ->
            Highlightable.initFragments Nothing "Pothos indirect light"
                |> program Nothing
                |> ensureTabbable "Pothos"
                |> rightArrow
                |> ensureTabbable "indirect"
                |> ensureOnlyOneInTabSequence (String.words "Pothos indirect light")
                |> rightArrow
                |> ensureTabbable "light"
                -- once we're on the final element, pressing right arrow again should
                -- _not_ wrap the focus. We should stay right where we are!
                |> rightArrow
                |> ensureTabbable "light"
                |> done
    , test "moves focus left on left arrow key" <|
        \() ->
            Highlightable.initFragments Nothing "Pothos indirect light"
                |> program Nothing
                |> ensureTabbable "Pothos"
                |> rightArrow
                |> ensureTabbable "indirect"
                |> leftArrow
                |> ensureTabbable "Pothos"
                |> ensureOnlyOneInTabSequence (String.words "Pothos indirect light")
                -- once we're on the first element, pressing left arrow again should
                -- _not_ wrap the focus. We should stay right where we are!
                |> leftArrow
                |> ensureTabbable "Pothos"
                |> done
    , test "moves focus right on shift + right arrow" <|
        \() ->
            Highlightable.initFragments Nothing "Pothos indirect light"
                |> program Nothing
                |> ensureTabbable "Pothos"
                |> shiftRight
                |> ensureTabbable "indirect"
                |> shiftRight
                |> ensureTabbable "light"
                |> shiftRight
                |> ensureTabbable "light"
                |> done
    , test "moves focus left on shift + left arrow" <|
        \() ->
            Highlightable.initFragments Nothing "Pothos indirect light"
                |> program Nothing
                |> ensureTabbable "Pothos"
                |> rightArrow
                |> ensureTabbable "indirect"
                |> shiftLeft
                |> ensureTabbable "Pothos"
                |> shiftLeft
                |> ensureTabbable "Pothos"
                |> done
    , test "expands selection one element to the right on shift + right arrow and highlight selected elements" <|
        \() ->
            Highlightable.initFragments Nothing "Pothos indirect light"
                |> program Nothing
                |> shiftRight
                |> releaseShiftRight
                |> ensureMarked [ "Pothos", " ", "indirect" ]
                |> shiftRight
                |> releaseShiftRight
                |> ensureMarked [ "Pothos", " ", "indirect", " ", "light" ]
                |> shiftRight
                |> releaseShiftRight
                |> ensureMarked [ "Pothos", " ", "indirect", " ", "light" ]
                |> done
    , test "expands selection one element to the left on shift + left arrow and highlight selected elements" <|
        \() ->
            Highlightable.initFragments Nothing "Pothos indirect light"
                |> program Nothing
                |> rightArrow
                |> rightArrow
                |> shiftLeft
                |> releaseShiftLeft
                |> ensureMarked [ "indirect", " ", "light" ]
                |> shiftLeft
                |> releaseShiftLeft
                |> ensureMarked [ "Pothos", " ", "indirect", " ", "light" ]
                |> shiftLeft
                |> releaseShiftLeft
                |> ensureMarked [ "Pothos", " ", "indirect", " ", "light" ]
                |> done
    , test "merges highlights" <|
        \() ->
            Highlightable.initFragments Nothing "Pothos indirect light"
                |> program Nothing
                |> ensureTabbable "Pothos"
                |> shiftRight
                |> releaseShiftRight
                |> ensureMarked [ "Pothos", " ", "indirect" ]
                |> ensureTabbable "indirect"
                |> rightArrow
                |> ensureTabbable "light"
                |> shiftLeft
                |> releaseShiftLeft
                |> ensureMarked [ "Pothos", " ", "indirect", " ", "light" ]
                |> done
    , test "selects element on MouseDown and highlights selected element on MouseUp" <|
        \() ->
            Highlightable.initFragments Nothing "Pothos indirect light"
                |> program Nothing
                |> ensureTabbable "Pothos"
                |> mouseDown "Pothos"
                |> mouseUp "Pothos"
                |> ensureMarked [ "Pothos" ]
                |> done
    , test "selects element on MouseDown, expands selection on MouseOver, and highlights selected elements on MouseUp" <|
        \() ->
            Highlightable.initFragments Nothing "Pothos indirect light"
                |> program Nothing
                |> ensureTabbable "Pothos"
                |> mouseDown "Pothos"
                |> mouseOver "indirect"
                |> mouseUp "Pothos"
                |> ensureMarked [ "Pothos", " ", "indirect" ]
                |> done
    , test "Highlights element on Space" <|
        \() ->
            Highlightable.initFragments Nothing "Pothos indirect light"
                |> program Nothing
                |> ensureTabbable "Pothos"
                |> space
                |> ensureMarked [ "Pothos" ]
                |> done
    , test "Removes highlight from element on MouseUp" <|
        \() ->
            Highlightable.initFragments Nothing "Pothos indirect light"
                |> program Nothing
                |> ensureTabbable "Pothos"
                |> space
                |> ensureMarked [ "Pothos" ]
                |> ensureTabbable "Pothos"
                |> mouseDown "Pothos"
                |> mouseUp "Pothos"
                |> expectViewHasNot [ Selector.tag "mark" ]
    , test "Removes entire highlight from a group of elements on MouseUp" <|
        \() ->
            Highlightable.initFragments Nothing "Pothos indirect light"
                |> program Nothing
                |> ensureTabbable "Pothos"
                |> shiftRight
                |> releaseShiftRight
                |> ensureMarked [ "Pothos", " ", "indirect" ]
                |> mouseDown "indirect"
                |> mouseUp "indirect"
                |> expectViewHasNot [ Selector.tag "mark" ]
    , test "Removes highlight from element on Space" <|
        \() ->
            Highlightable.initFragments Nothing "Pothos indirect light"
                |> program Nothing
                |> ensureTabbable "Pothos"
                |> space
                |> ensureMarked [ "Pothos" ]
                |> ensureTabbable "Pothos"
                |> space
                |> expectViewHasNot [ Selector.tag "mark" ]
    , describe "Regression tests for A11-1767"
        [ test "generic start announcement is made when mark does not include first element" <|
            \() ->
                Highlightable.initFragments Nothing "Pothos indirect light"
                    |> program Nothing
                    |> rightArrow
                    |> shiftRight
                    |> releaseShiftRight
                    |> ensureMarked [ "indirect" ]
                    |> expectView (hasStartHighlightBeforeContent "start highlight" "indirect")
        , test "specific start announcement is made when mark does not include first element" <|
            \() ->
                Highlightable.initFragments Nothing "Pothos indirect light"
                    |> program (Just "banana")
                    |> rightArrow
                    |> ensureTabbable "indirect"
                    |> shiftRight
                    |> releaseShiftRight
                    |> ensureMarked [ "indirect" ]
                    |> expectView (hasStartHighlightBeforeContent "start banana highlight" "indirect")
        ]
    ]


hasStartHighlightBeforeContent : String -> String -> Query.Single msg -> Expectation
hasStartHighlightBeforeContent startHighlightMarker relevantHighlightableText view =
    let
        styles =
            view
                |> Query.find [ Selector.tag "style" ]
                |> Query.children []
                |> Debug.toString

        startHighlightClassRegex : Maybe Regex
        startHighlightClassRegex =
            "\\.(\\_[a-zA-Z0-9]+)::before\\{content:\\\\\"\\s*\\[\\s*"
                ++ startHighlightMarker
                |> Regex.fromString

        maybeClassName : Maybe String
        maybeClassName =
            startHighlightClassRegex
                |> Maybe.andThen
                    (\regex ->
                        Regex.find regex styles
                            |> List.head
                            |> Maybe.andThen (.submatches >> List.head)
                    )
                |> Maybe.withDefault Nothing
    in
    case maybeClassName of
        Just className ->
            Query.has
                [ Selector.tag "mark"
                , Selector.containing
                    [ Selector.class className
                    , Selector.containing [ Selector.text relevantHighlightableText ]
                    ]
                ]
                view

        Nothing ->
            "Expected to find a class defining a ::before element with content: `"
                ++ startHighlightMarker
                ++ "`, but failed to find the class in the styles: \n\n"
                ++ styles
                |> Expect.fail


ensureTabbable : String -> TestContext -> TestContext
ensureTabbable word testContext =
    testContext
        |> ensureView
            (Query.find [ Selector.attribute (Key.tabbable True) ]
                >> Query.has [ Selector.text word ]
            )


ensureOnlyOneInTabSequence : List String -> TestContext -> TestContext
ensureOnlyOneInTabSequence words testContext =
    testContext
        |> ensureView
            (Query.findAll [ Selector.attribute (Key.tabbable True) ]
                >> Query.count (Expect.equal 1)
            )
        |> ensureView
            (Query.findAll [ Selector.attribute (Key.tabbable False) ]
                >> Query.count (Expect.equal (List.length words - 1))
            )


ensureMarked : List String -> TestContext -> TestContext
ensureMarked words testContext =
    testContext
        |> ensureView
            (Query.find [ Selector.tag "mark" ]
                >> Query.children [ Selector.class "highlighter-highlightable" ]
                >> Expect.all (List.indexedMap (\i w -> Query.index i >> Query.has [ Selector.text w ]) words)
            )


space : TestContext -> TestContext
space =
    KeyboardHelpers.pressSpaceKey { targetDetails = [] }
        [ Selector.attribute (Key.tabbable True) ]


rightArrow : TestContext -> TestContext
rightArrow =
    KeyboardHelpers.pressRightArrow { targetDetails = [] }
        [ Selector.attribute (Key.tabbable True) ]


leftArrow : TestContext -> TestContext
leftArrow =
    KeyboardHelpers.pressLeftArrow { targetDetails = [] }
        [ Selector.attribute (Key.tabbable True) ]


shiftRight : TestContext -> TestContext
shiftRight =
    KeyboardHelpers.pressShiftRight { targetDetails = [] }
        [ Selector.attribute (Key.tabbable True) ]


shiftLeft : TestContext -> TestContext
shiftLeft =
    KeyboardHelpers.pressShiftLeft { targetDetails = [] }
        [ Selector.attribute (Key.tabbable True) ]


releaseShiftRight : TestContext -> TestContext
releaseShiftRight =
    KeyboardHelpers.releaseShiftRight { targetDetails = [] }
        [ Selector.attribute (Key.tabbable True) ]


releaseShiftLeft : TestContext -> TestContext
releaseShiftLeft =
    KeyboardHelpers.releaseShiftLeft { targetDetails = [] }
        [ Selector.attribute (Key.tabbable True) ]


mouseDown : String -> TestContext -> TestContext
mouseDown word =
    MouseHelpers.cancelableMouseDown [ Selector.tag "span", Selector.containing [ Selector.text word ] ]


mouseUp : String -> TestContext -> TestContext
mouseUp word =
    MouseHelpers.cancelableMouseUp [ Selector.tag "span", Selector.containing [ Selector.text word ] ]


mouseOver : String -> TestContext -> TestContext
mouseOver word =
    MouseHelpers.cancelableMouseOver [ Selector.tag "span", Selector.containing [ Selector.text word ] ]


marker : Maybe String -> Tool ()
marker name =
    Tool.Marker
        (Tool.buildMarker
            { highlightColor = Colors.magenta
            , hoverColor = Colors.magenta
            , hoverHighlightColor = Colors.magenta
            , kind = ()
            , name = name
            }
        )


type alias TestContext =
    ProgramTest (Highlighter.Model ()) (Highlighter.Msg ()) ()


program : Maybe String -> List (Highlightable ()) -> TestContext
program name highlightables =
    ProgramTest.createSandbox
        { init =
            Highlighter.init
                { id = "test-highlighter-container"
                , highlightables = highlightables
                , marker = marker name
                }
        , update =
            \msg model ->
                case Highlighter.update msg model of
                    ( newModel, _, _ ) ->
                        newModel
        , view = Highlighter.view >> toUnstyled
        }
        |> ProgramTest.start ()