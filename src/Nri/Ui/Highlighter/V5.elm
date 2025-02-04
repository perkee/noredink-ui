module Nri.Ui.Highlighter.V5 exposing
    ( Model, Msg(..), PointerMsg(..)
    , init, update
    , view, static, staticWithTags
    , viewMarkdown, staticMarkdown, staticMarkdownWithTags
    , viewWithOverlappingHighlights
    , Intent(..), hasChanged, HasChanged(..)
    , removeHighlights
    , clickedHighlightable, hoveredHighlightable
    , selectShortest
    )

{-| Changes from V4:

  - adds `isHovering` to track whether the user is already hovering over a group,
    so that we don't reapply hover styles when the user toggles a highlight.
  - renames `Blur` to `MouseOut` to be more consistent with `MouseOver` and because it's
    not really a blur event.

Highlighter provides a view/model/update to display a view to highlight text and show marks.


# Patch changes:

  - Made all highlighter views lazy
  - Optimized `selectShortest` for the normal case of 0 or 1 highlight.


# Types

@docs Model, Msg, PointerMsg


# Init/View/Update

@docs init, update

@docs view, static, staticWithTags
@docs viewMarkdown, staticMarkdown, staticMarkdownWithTags
@docs viewWithOverlappingHighlights


## Intents

@docs Intent, hasChanged, HasChanged


## Setters

@docs removeHighlights


## Getters

@docs clickedHighlightable, hoveredHighlightable
@docs selectShortest

-}

import Accessibility.Styled.Key as Key
import Browser.Dom as Dom
import Css
import Html.Styled as Html exposing (Attribute, Html, p, span)
import Html.Styled.Attributes exposing (attribute, class, css)
import Html.Styled.Events as Events
import Html.Styled.Lazy exposing (lazy)
import Json.Decode
import List.Extra
import Markdown.Block
import Markdown.Inline
import Nri.Ui.Highlightable.V3 as Highlightable exposing (Highlightable)
import Nri.Ui.HighlighterTool.V1 as Tool
import Nri.Ui.Html.Attributes.V2 as AttributesExtra
import Nri.Ui.Mark.V6 as Mark exposing (Mark)
import Set exposing (Set)
import Sort exposing (Sorter)
import Sort.Dict as Dict
import Task



-- Model


{-| Model of a highlighter
-}
type alias Model marker =
    { -- Used to identify a highlighter. This is necessary when there are
      -- multiple highlighters on the same page because we add listeners
      -- in javascript (see ./highlighter.js) and because we move focus by id for keyboard users.
      id : String
    , highlightables : List (Highlightable marker) -- The actual highlightable elements
    , marker : Tool.Tool marker -- Currently used marker
    , joinAdjacentInteractiveHighlights : Bool
    , sorter : Sorter marker

    -- Internal state to track user's interactions
    , hintingIndices : Maybe ( Int, Int )
    , mouseDownIndex : Maybe Int
    , mouseOverIndex : Maybe Int
    , isInitialized : Initialized
    , hasChanged : HasChanged
    , selectionStartIndex : Maybe Int
    , selectionEndIndex : Maybe Int
    , focusIndex : Maybe Int

    -- We want to track whether the user is already hovering over a group,
    -- so that we don't reapply hover styles when the user toggles a highlight.
    , isHovering : Bool
    }


{-| -}
type HasChanged
    = Changed
    | NotChanged


type Initialized
    = Initialized
    | NotInitialized


{-| Setup initial model

joinAdjacentInteractiveHighlights - When true, and static highlightables are sandwiched by highlighted interactive highlightables of the same type, apply the highlight to the static highlightable as well.

-}
init :
    { id : String
    , highlightables : List (Highlightable marker)
    , marker : Tool.Tool marker
    , joinAdjacentInteractiveHighlights : Bool
    , sorter : Sorter marker
    }
    -> Model marker
init config =
    { id = config.id
    , highlightables =
        if config.joinAdjacentInteractiveHighlights then
            Highlightable.joinAdjacentInteractiveHighlights config.sorter config.highlightables

        else
            config.highlightables
    , marker = config.marker
    , joinAdjacentInteractiveHighlights = config.joinAdjacentInteractiveHighlights
    , sorter = config.sorter

    -- Internal state to track user's interactions
    , hintingIndices = Nothing
    , mouseDownIndex = Nothing
    , mouseOverIndex = Nothing
    , isInitialized = NotInitialized
    , hasChanged = NotChanged
    , selectionStartIndex = Nothing
    , selectionEndIndex = Nothing
    , focusIndex =
        List.Extra.findIndex (\highlightable -> .type_ highlightable == Highlightable.Interactive) config.highlightables
    , isHovering = False
    }



-- UPDATE


{-| -}
type Msg marker
    = Pointer PointerMsg
    | Keyboard KeyboardMsg
    | Focused (Result Dom.Error ())


{-| Messages used by highlighter when interacting with a mouse or finger.
-}
type PointerMsg
    = Down Int
    | Out
    | Over Int
      -- the `Maybe String`s here are for detecting touchend events via
      -- subscription--we listen at the document level but get the id associated
      -- with the subscription when it fires messages. Mouse-triggered events
      -- will not have this info!
    | Move (Maybe String) Int
    | Up (Maybe String)
    | Ignored


type KeyboardMsg
    = MoveLeft Int
    | MoveRight Int
    | SelectionExpandLeft Int
    | SelectionExpandRight Int
    | SelectionApplyTool Int
    | SelectionReset Int
    | ToggleHighlight Int


{-| Possible intents or "external effects" that the Highlighter can request (see `perform`).
-}
type Intent
    = Intent
        { listenTo : ListenTo
        , changed : HasChanged
        }


type alias ListenTo =
    Maybe String


{-| Get intent based on the resulting model from `update`.

  - This ensures that we initialize the highlighter in JS exactly once.
  - Sets the `hasChanged` flag if the model has changed. This is used by the user of `Highlighter` to
    determine whether they want to execute follow up actions.

-}
withIntent : ( Model m, Cmd (Msg m) ) -> ( Model m, Cmd (Msg m), Intent )
withIntent ( new, cmd ) =
    ( { new | isInitialized = Initialized, hasChanged = NotChanged }
    , cmd
    , Intent
        { listenTo =
            case new.isInitialized of
                Initialized ->
                    Nothing

                NotInitialized ->
                    Just new.id
        , changed = new.hasChanged
        }
    )


{-| Check if the highlighter has changed.
-}
hasChanged : Intent -> HasChanged
hasChanged (Intent { changed }) =
    changed


{-| Actions are used as an intermediate algebra from pointer events to actual changes to the model.
-}
type Action marker
    = Focus Int
    | Hint Int Int
    | MouseDown Int
    | MouseUp
    | MouseOver Int
    | MouseOut
    | RemoveHint
    | Save (Tool.MarkerModel marker)
    | Toggle Int (Tool.MarkerModel marker)
    | StartSelection Int
    | ExpandSelection Int
    | ResetSelection


{-| Update for highlighter returning additional info about whether there was a change
-}
update : Msg marker -> Model marker -> ( Model marker, Cmd (Msg marker), Intent )
update msg model =
    withIntent <|
        case msg of
            Pointer pointerMsg ->
                pointerEventToActions pointerMsg model
                    |> performActions model
                    |> Tuple.mapFirst maybeJoinAdjacentInteractiveHighlights

            Keyboard keyboardMsg ->
                keyboardEventToActions keyboardMsg model
                    |> performActions model
                    |> Tuple.mapFirst maybeJoinAdjacentInteractiveHighlights

            Focused _ ->
                ( model, Cmd.none )


maybeJoinAdjacentInteractiveHighlights : Model m -> Model m
maybeJoinAdjacentInteractiveHighlights model =
    if model.joinAdjacentInteractiveHighlights then
        { model | highlightables = Highlightable.joinAdjacentInteractiveHighlights model.sorter model.highlightables }

    else
        model


nextInteractiveIndex : Int -> List (Highlightable marker) -> Maybe Int
nextInteractiveIndex index highlightables =
    let
        isInteractive highlightable =
            .type_ highlightable == Highlightable.Interactive

        interactiveHighlightables =
            List.filter isInteractive highlightables
    in
    List.foldl
        (\x ( maybeNextIndex, hasIndexMatched ) ->
            if hasIndexMatched then
                ( Just x.index, False )

            else
                ( maybeNextIndex, x.index == index )
        )
        ( Nothing, False )
        interactiveHighlightables
        |> Tuple.first


previousInteractiveIndex : Int -> List (Highlightable marker) -> Maybe Int
previousInteractiveIndex index highlightables =
    let
        isInteractive highlightable =
            .type_ highlightable == Highlightable.Interactive

        interactiveHighlightables =
            List.filter isInteractive highlightables
    in
    List.foldr
        (\x ( maybeNextIndex, hasIndexMatched ) ->
            if hasIndexMatched then
                ( Just x.index, False )

            else
                ( maybeNextIndex, x.index == index )
        )
        ( Nothing, False )
        interactiveHighlightables
        |> Tuple.first


keyboardEventToActions : KeyboardMsg -> Model marker -> List (Action marker)
keyboardEventToActions msg model =
    case msg of
        MoveLeft index ->
            case previousInteractiveIndex index model.highlightables of
                Nothing ->
                    []

                Just i ->
                    [ Focus i, ResetSelection, RemoveHint ]

        MoveRight index ->
            case nextInteractiveIndex index model.highlightables of
                Nothing ->
                    []

                Just i ->
                    [ Focus i, ResetSelection, RemoveHint ]

        SelectionExpandLeft index ->
            case previousInteractiveIndex index model.highlightables of
                Nothing ->
                    []

                Just i ->
                    Focus i
                        :: (case model.selectionStartIndex of
                                Just startIndex ->
                                    [ ExpandSelection i, Hint startIndex i ]

                                Nothing ->
                                    [ StartSelection index, ExpandSelection i, Hint index i ]
                           )

        SelectionExpandRight index ->
            case nextInteractiveIndex index model.highlightables of
                Nothing ->
                    []

                Just i ->
                    Focus i
                        :: (case model.selectionStartIndex of
                                Just startIndex ->
                                    [ ExpandSelection i, Hint startIndex i ]

                                Nothing ->
                                    [ StartSelection index, ExpandSelection i, Hint index i ]
                           )

        SelectionApplyTool index ->
            case model.marker of
                Tool.Marker marker ->
                    [ Save marker, ResetSelection, Focus index ]

                Tool.Eraser _ ->
                    [ RemoveHint, ResetSelection, Focus index ]

        SelectionReset index ->
            [ ResetSelection, RemoveHint, Focus index ]

        ToggleHighlight index ->
            case model.marker of
                Tool.Marker marker ->
                    [ Toggle index marker
                    , Focus index
                    ]

                Tool.Eraser _ ->
                    [ MouseOver index
                    , Hint index index
                    , MouseUp
                    , RemoveHint
                    , Focus index
                    ]


{-| Pointer events to actions.
-}
pointerEventToActions : PointerMsg -> Model marker -> List (Action marker)
pointerEventToActions msg model =
    case msg of
        Ignored ->
            []

        Move _ eventIndex ->
            case model.mouseDownIndex of
                Just downIndex ->
                    [ MouseOver eventIndex
                    , Hint downIndex eventIndex
                    ]

                Nothing ->
                    -- We're dealing with a touch move that hasn't been where
                    -- the initial touch down was not over a highlightable
                    -- region. We need to pretend like the first move into the
                    -- highlightable region was actually a touch down.
                    pointerEventToActions (Down eventIndex) model

        Over eventIndex ->
            case model.mouseDownIndex of
                Just downIndex ->
                    [ MouseOver eventIndex
                    , Hint downIndex eventIndex
                    ]

                Nothing ->
                    if not model.isHovering then
                        [ MouseOver eventIndex ]

                    else
                        []

        Out ->
            [ MouseOut ]

        Down eventIndex ->
            [ MouseOver eventIndex
            , MouseDown eventIndex
            , Hint eventIndex eventIndex
            ]

        Up _ ->
            let
                save marker =
                    case ( model.mouseOverIndex, model.mouseDownIndex ) of
                        ( Just overIndex, Just downIndex ) ->
                            if overIndex == downIndex then
                                [ Toggle downIndex marker ]

                            else
                                [ Save marker ]

                        ( Nothing, Just downIndex ) ->
                            [ Save marker ]

                        _ ->
                            []
            in
            case model.marker of
                Tool.Marker marker ->
                    MouseUp :: save marker

                Tool.Eraser _ ->
                    [ MouseUp, RemoveHint ]


{-| We fold over actions using (Model marker) as the accumulator.
-}
performActions : Model marker -> List (Action marker) -> ( Model marker, Cmd (Msg m) )
performActions model actions =
    List.foldl performAction ( model, [] ) actions
        |> Tuple.mapSecond Cmd.batch


{-| Performs actual changes to the model, or emit a command.
-}
performAction : Action marker -> ( Model marker, List (Cmd (Msg m)) ) -> ( Model marker, List (Cmd (Msg m)) )
performAction action ( model, cmds ) =
    case action of
        Focus index ->
            ( { model | focusIndex = Just index }
            , Task.attempt Focused (Dom.focus (highlightableId model.id index)) :: cmds
            )

        Hint start end ->
            ( { model | hintingIndices = Just ( start, end ) }, cmds )

        Save marker ->
            case model.hintingIndices of
                Just hinting ->
                    ( { model
                        | highlightables = saveHinted marker hinting model.highlightables
                        , hasChanged = Changed
                        , hintingIndices = Nothing
                      }
                    , cmds
                    )

                Nothing ->
                    ( model, cmds )

        Toggle index marker ->
            ( { model
                | highlightables = toggleHinted index marker model.highlightables
                , hasChanged = Changed
                , hintingIndices = Nothing
              }
            , cmds
            )

        RemoveHint ->
            case model.hintingIndices of
                Just hinting ->
                    ( { model
                        | highlightables = removeHinted hinting model.highlightables
                        , hasChanged = Changed
                        , hintingIndices = Nothing
                      }
                    , cmds
                    )

                Nothing ->
                    ( model, cmds )

        MouseDown index ->
            ( { model | mouseDownIndex = Just index }, cmds )

        MouseUp ->
            ( { model | mouseDownIndex = Nothing, mouseOverIndex = Nothing }, cmds )

        MouseOver index ->
            ( { model | mouseOverIndex = Just index, isHovering = True }, cmds )

        MouseOut ->
            ( { model | mouseOverIndex = Nothing, isHovering = False }, cmds )

        StartSelection index ->
            ( { model | selectionStartIndex = Just index }, cmds )

        ExpandSelection index ->
            ( { model | selectionEndIndex = Just index }, cmds )

        ResetSelection ->
            ( { model | selectionStartIndex = Nothing, selectionEndIndex = Nothing }, cmds )


isHinted : Maybe ( Int, Int ) -> Highlightable marker -> Bool
isHinted hintingIndices x =
    case hintingIndices of
        Just ( from, to ) ->
            between from to x

        Nothing ->
            False


between : Int -> Int -> Highlightable marker -> Bool
between from to { index } =
    if from < to then
        from <= index && index <= to

    else
        to <= index && index <= from


saveHinted : Tool.MarkerModel marker -> ( Int, Int ) -> List (Highlightable marker) -> List (Highlightable marker)
saveHinted marker ( hintBeginning, hintEnd ) =
    List.map
        (\highlightable ->
            if between hintBeginning hintEnd highlightable then
                Highlightable.set (Just marker) highlightable

            else
                highlightable
        )
        >> trimHighlightableGroups


toggleHinted : Int -> Tool.MarkerModel marker -> List (Highlightable marker) -> List (Highlightable marker)
toggleHinted index marker highlightables =
    let
        hintedRange =
            inSameRange index highlightables

        inClickedRange highlightable =
            Set.member highlightable.index hintedRange

        toggle highlightable =
            if inClickedRange highlightable && Just marker == List.head highlightable.marked then
                Highlightable.set Nothing highlightable

            else if highlightable.index == index then
                Highlightable.set (Just marker) highlightable

            else
                highlightable
    in
    List.map toggle highlightables
        |> trimHighlightableGroups


{-| This removes all-static highlights. We need to track events on static elements,
so that we don't miss mouse events if a user starts or ends a highlight on a space, say,
but we should only persist changes to interactive segments.
It is meant to be called as a clean up after the highlightings have been changed.
-}
trimHighlightableGroups : List (Highlightable marker) -> List (Highlightable marker)
trimHighlightableGroups highlightables =
    let
        apply segment ( lastInteractiveHighlighterMarkers, staticAcc, acc ) =
            -- logic largely borrowed from joinAdjacentInteractiveHighlights.
            -- TODO in the next version: clean up the implementation!
            case segment.type_ of
                Highlightable.Interactive ->
                    let
                        bracketingHighlightTypes =
                            List.filterMap (\x -> List.Extra.find ((==) x) lastInteractiveHighlighterMarkers)
                                segment.marked

                        static_ =
                            -- for every static tag, ensure that if it's not between interactive segments
                            -- that share a mark in common, marks are removed.
                            List.map
                                (\s ->
                                    { s
                                        | marked =
                                            List.filterMap (\x -> List.Extra.find ((==) x) bracketingHighlightTypes)
                                                s.marked
                                    }
                                )
                                staticAcc
                    in
                    ( segment.marked, [], segment :: static_ ++ acc )

                Highlightable.Static ->
                    ( lastInteractiveHighlighterMarkers, segment :: staticAcc, acc )
    in
    highlightables
        |> List.foldr apply ( [], [], [] )
        |> (\( _, static_, acc ) -> removeHighlights_ static_ ++ acc)
        |> List.foldl apply ( [], [], [] )
        |> (\( _, static_, acc ) -> removeHighlights_ static_ ++ acc)
        |> List.reverse


{-| Finds the group indexes of the groups which are in the same highlighting as the group index
passed in the first argument.
-}
inSameRange : Int -> List (Highlightable marker) -> Set Int
inSameRange index highlightables =
    List.Extra.groupWhile (\a b -> a.marked == b.marked) highlightables
        |> List.map (\( first, rest ) -> first.index :: List.map .index rest)
        |> List.Extra.find (List.member index)
        |> Maybe.withDefault []
        |> Set.fromList


removeHinted : ( Int, Int ) -> List (Highlightable marker) -> List (Highlightable marker)
removeHinted ( hintBeginning, hintEnd ) =
    List.map
        (\highlightable ->
            if between hintBeginning hintEnd highlightable then
                Highlightable.set Nothing highlightable

            else
                highlightable
        )


{-| -}
removeHighlights : Model marker -> Model marker
removeHighlights model =
    { model | highlightables = removeHighlights_ model.highlightables }


removeHighlights_ : List (Highlightable m) -> List (Highlightable m)
removeHighlights_ =
    List.map (Highlightable.set Nothing)


{-| You are not likely to need this helper unless you're working with inline commenting.
-}
clickedHighlightable : Model marker -> Maybe (Highlightable.Highlightable marker)
clickedHighlightable model =
    Maybe.andThen (\i -> Highlightable.byId i model.highlightables) model.mouseDownIndex


{-| You are not likely to need this helper unless you're working with inline commenting.
-}
hoveredHighlightable : Model marker -> Maybe (Highlightable.Highlightable marker)
hoveredHighlightable model =
    Maybe.andThen (\i -> Highlightable.byId i model.highlightables) model.mouseOverIndex


isHovered_ :
    { config
        | mouseOverIndex : Maybe Int
        , mouseDownIndex : Maybe Int
        , hintingIndices : Maybe ( Int, Int )
        , highlightables : List (Highlightable marker)
        , overlaps : OverlapsSupport marker
        , maybeTool : Maybe tool
    }
    -> List (List (Highlightable ma))
    -> Highlightable marker
    -> Bool
isHovered_ config groups highlightable =
    case config.maybeTool of
        Nothing ->
            False

        Just _ ->
            directlyHoveringInteractiveSegment config highlightable
                || (case config.overlaps of
                        OverlapsSupported { hoveredMarkerWithShortestHighlight } ->
                            inHoveredGroupForOverlaps config hoveredMarkerWithShortestHighlight highlightable

                        OverlapsNotSupported ->
                            inHoveredGroupWithoutOverlaps config groups highlightable
                   )


directlyHoveringInteractiveSegment : { config | mouseOverIndex : Maybe Int } -> Highlightable m -> Bool
directlyHoveringInteractiveSegment { mouseOverIndex } highlightable =
    (mouseOverIndex == Just highlightable.index)
        && (highlightable.type_ == Highlightable.Interactive)


inHoveredGroupWithoutOverlaps :
    { config
        | mouseOverIndex : Maybe Int
        , hintingIndices : Maybe ( Int, Int )
        , highlightables : List (Highlightable marker)
    }
    -> List (List (Highlightable ma))
    -> Highlightable m
    -> Bool
inHoveredGroupWithoutOverlaps config groups highlightable =
    case highlightable.marked of
        [] ->
            -- if the highlightable is not marked, then it shouldn't
            -- take on group hover styles
            -- if the mouse is over it, it's hovered.
            -- otherwise, it's not!
            Just highlightable.index == config.mouseOverIndex

        _ ->
            -- if the highlightable is in a group that's hovered,
            -- apply hovered styles
            groups
                |> List.filter (List.any (.index >> (==) highlightable.index))
                |> List.head
                |> Maybe.withDefault []
                |> List.any (.index >> Just >> (==) config.mouseOverIndex)


inHoveredGroupForOverlaps :
    { config
        | mouseOverIndex : Maybe Int
        , mouseDownIndex : Maybe Int
        , highlightables : List (Highlightable marker)
    }
    -> Maybe marker
    -> Highlightable marker
    -> Bool
inHoveredGroupForOverlaps config hoveredMarkerWithShortestHighlight highlightable =
    case config.mouseDownIndex of
        Just _ ->
            -- If the user is actively highlighting, don't show the entire highlighted region as hovered
            -- This is so that when creating an overlap, the hover styles don't imply that you've
            -- selected more than you have
            False

        Nothing ->
            case hoveredMarkerWithShortestHighlight of
                Nothing ->
                    False

                Just marker ->
                    List.member marker (List.map .kind highlightable.marked)


{-| Highlights can overlap. Sometimes, we want to apply a certain behavior (e.g., hover color change) on just the shortest
highlight. Use this function to find out which marker applies to the least amount of text.

Note that this is shortest by text length, not shortest by number of highlightables.

You are not likely to need this helper unless you're working with inline commenting.

-}
selectShortest :
    ({ model | highlightables : List (Highlightable marker), sorter : Sorter marker } -> Maybe (Highlightable marker))
    -> { model | highlightables : List (Highlightable marker), sorter : Sorter marker }
    -> Maybe marker
selectShortest getHighlightable state =
    let
        candidateIds =
            state
                |> getHighlightable
                |> Maybe.map (\highlightable -> List.map .kind highlightable.marked)
                |> Maybe.withDefault []
    in
    case candidateIds of
        [] ->
            Nothing

        marker :: [] ->
            Just marker

        first :: second :: rest ->
            Just
                (markerWithShortestHighlight
                    state.sorter
                    state.highlightables
                    ( first, second, rest )
                )


markerWithShortestHighlight :
    Sorter marker
    -> List (Highlightable marker)
    -> ( marker, marker, List marker )
    -> marker
markerWithShortestHighlight sorter highlightables ( first, second, rest ) =
    let
        isMarkerRelevant : marker -> Bool
        isMarkerRelevant someMarker =
            someMarker == first || someMarker == second || List.member someMarker rest

        updateMarkerLengthsForHighlightable : Highlightable marker -> Dict.Dict marker Int -> Dict.Dict marker Int
        updateMarkerLengthsForHighlightable highlightable soFar =
            let
                textLength =
                    String.length highlightable.text
            in
            List.foldl
                (\{ kind } -> updateLengthForMarker kind textLength)
                soFar
                highlightable.marked

        updateLengthForMarker : marker -> Int -> Dict.Dict marker Int -> Dict.Dict marker Int
        updateLengthForMarker someMarker textLength soFar =
            if isMarkerRelevant someMarker then
                Dict.update
                    someMarker
                    (\currentValue ->
                        currentValue
                            |> Maybe.map (\length -> length + textLength)
                            |> Maybe.withDefault textLength
                            |> Just
                    )
                    soFar

            else
                soFar

        keepMarkerWithShortestLength : marker -> Int -> Maybe ( marker, Int ) -> Maybe ( marker, Int )
        keepMarkerWithShortestLength marker length soFar =
            case soFar of
                Nothing ->
                    Just ( marker, length )

                Just (( _, currentMin ) as previousResult) ->
                    if length < currentMin then
                        Just ( marker, length )

                    else
                        Just previousResult
    in
    highlightables
        |> List.foldl updateMarkerLengthsForHighlightable (Dict.empty sorter)
        |> Dict.foldl keepMarkerWithShortestLength Nothing
        |> Maybe.map Tuple.first
        |> Maybe.withDefault first



-- VIEWS


{-| -}
view : Model marker -> Html (Msg marker)
view =
    lazy
        (\model ->
            view_
                { showTagsInline = False
                , maybeTool = Just model.marker
                , mouseOverIndex = model.mouseOverIndex
                , mouseDownIndex = model.mouseDownIndex
                , hintingIndices = model.hintingIndices
                , overlaps = OverlapsNotSupported
                , viewSegment = viewHighlightable { renderMarkdown = False, overlaps = OverlapsNotSupported } model
                , id = model.id
                , highlightables = model.highlightables
                }
        )


{-| -}
viewWithOverlappingHighlights : Model marker -> Html (Msg marker)
viewWithOverlappingHighlights =
    lazy
        (\model ->
            let
                hoveredMarkers =
                    model.highlightables
                        |> List.Extra.find (\h -> Just h.index == model.mouseOverIndex)
                        |> Maybe.map (.marked >> List.map .kind)
                        |> Maybe.withDefault []

                overlaps =
                    OverlapsSupported
                        { hoveredMarkerWithShortestHighlight =
                            case hoveredMarkers of
                                [] ->
                                    Nothing

                                marker :: [] ->
                                    Just marker

                                first :: second :: rest ->
                                    Just
                                        (markerWithShortestHighlight
                                            model.sorter
                                            model.highlightables
                                            ( first, second, rest )
                                        )
                        }
            in
            view_
                { showTagsInline = False
                , maybeTool = Just model.marker
                , mouseOverIndex = model.mouseOverIndex
                , mouseDownIndex = model.mouseDownIndex
                , hintingIndices = model.hintingIndices
                , overlaps = overlaps
                , viewSegment = viewHighlightable { renderMarkdown = False, overlaps = overlaps } model
                , id = model.id
                , highlightables = model.highlightables
                }
        )


{-| Same as `view`, but will render strings like "_blah_" inside of emphasis tags.

WARNING: the version of markdown used here is extremely limited, as the highlighter content needs to be entirely in-line content. Lists & other block-level elements will _not_ render as they usually would!

WARNING: markdown is rendered highlightable by highlightable, so be sure to provide highlightables like ["_New York Times_"]["*New York Times*"], NOT like ["_New ", "York ", "Times_"]["*New ", "York ", "Times*"]

-}
viewMarkdown : Model marker -> Html (Msg marker)
viewMarkdown =
    lazy
        (\model ->
            view_
                { showTagsInline = False
                , maybeTool = Just model.marker
                , mouseOverIndex = model.mouseOverIndex
                , mouseDownIndex = model.mouseDownIndex
                , hintingIndices = model.hintingIndices
                , overlaps = OverlapsNotSupported
                , viewSegment = viewHighlightable { renderMarkdown = True, overlaps = OverlapsNotSupported } model
                , id = model.id
                , highlightables = model.highlightables
                }
        )


{-| -}
static : { config | id : String, highlightables : List (Highlightable marker) } -> Html msg
static =
    lazy
        (\config ->
            view_
                { showTagsInline = False
                , maybeTool = Nothing
                , mouseOverIndex = Nothing
                , mouseDownIndex = Nothing
                , hintingIndices = Nothing
                , overlaps = OverlapsNotSupported
                , viewSegment =
                    viewHighlightableSegment
                        { interactiveHighlighterId = Nothing
                        , focusIndex = Nothing
                        , eventListeners = []
                        , maybeTool = Nothing
                        , mouseOverIndex = Nothing
                        , mouseDownIndex = Nothing
                        , hintingIndices = Nothing
                        , renderMarkdown = False
                        , sorter = Nothing
                        , overlaps = OverlapsNotSupported
                        }
                , id = config.id
                , highlightables = config.highlightables
                }
        )


{-| Same as `static`, but will render strings like "_blah_" inside of emphasis tags.

WARNING: the version of markdown used here is extremely limited, as the highlighter content needs to be entirely in-line content. Lists & other block-level elements will _not_ render as they usually would!

WARNING: markdown is rendered highlightable by highlightable, so be sure to provide highlightables like ["_New York Times_"]["*New York Times*"], NOT like ["_New ", "York ", "Times_"]["*New ", "York ", "Times*"]

-}
staticMarkdown : { config | id : String, highlightables : List (Highlightable marker) } -> Html msg
staticMarkdown =
    lazy
        (\config ->
            view_
                { showTagsInline = False
                , maybeTool = Nothing
                , mouseOverIndex = Nothing
                , mouseDownIndex = Nothing
                , hintingIndices = Nothing
                , overlaps = OverlapsNotSupported
                , viewSegment =
                    viewHighlightableSegment
                        { interactiveHighlighterId = Nothing
                        , focusIndex = Nothing
                        , eventListeners = []
                        , maybeTool = Nothing
                        , mouseOverIndex = Nothing
                        , mouseDownIndex = Nothing
                        , hintingIndices = Nothing
                        , renderMarkdown = True
                        , sorter = Nothing
                        , overlaps = OverlapsNotSupported
                        }
                , id = config.id
                , highlightables = config.highlightables
                }
        )


{-| -}
staticWithTags : { config | id : String, highlightables : List (Highlightable marker) } -> Html msg
staticWithTags =
    lazy
        (\config ->
            let
                viewStaticHighlightableWithTags : Highlightable marker -> List Css.Style -> Html msg
                viewStaticHighlightableWithTags =
                    viewHighlightableSegment
                        { interactiveHighlighterId = Nothing
                        , focusIndex = Nothing
                        , eventListeners = []
                        , maybeTool = Nothing
                        , mouseOverIndex = Nothing
                        , mouseDownIndex = Nothing
                        , hintingIndices = Nothing
                        , renderMarkdown = False
                        , sorter = Nothing
                        , overlaps = OverlapsNotSupported
                        }
            in
            view_
                { showTagsInline = True
                , maybeTool = Nothing
                , mouseOverIndex = Nothing
                , mouseDownIndex = Nothing
                , hintingIndices = Nothing
                , overlaps = OverlapsNotSupported
                , viewSegment = viewStaticHighlightableWithTags
                , id = config.id
                , highlightables = config.highlightables
                }
        )


{-| Same as `staticWithTags`, but will render strings like "_blah_" inside of emphasis tags.

WARNING: the version of markdown used here is extremely limited, as the highlighter content needs to be entirely in-line content. Lists & other block-level elements will _not_ render as they usually would!

WARNING: markdown is rendered highlightable by highlightable, so be sure to provide highlightables like ["_New York Times_"]["*New York Times*"], NOT like ["_New ", "York ", "Times_"]["*New ", "York ", "Times*"]

-}
staticMarkdownWithTags : { config | id : String, highlightables : List (Highlightable marker) } -> Html msg
staticMarkdownWithTags =
    lazy
        (\config ->
            let
                viewStaticHighlightableWithTags : Highlightable marker -> List Css.Style -> Html msg
                viewStaticHighlightableWithTags =
                    viewHighlightableSegment
                        { interactiveHighlighterId = Nothing
                        , focusIndex = Nothing
                        , eventListeners = []
                        , maybeTool = Nothing
                        , mouseOverIndex = Nothing
                        , mouseDownIndex = Nothing
                        , hintingIndices = Nothing
                        , renderMarkdown = True
                        , sorter = Nothing
                        , overlaps = OverlapsNotSupported
                        }
            in
            view_
                { showTagsInline = True
                , maybeTool = Nothing
                , mouseOverIndex = Nothing
                , mouseDownIndex = Nothing
                , hintingIndices = Nothing
                , overlaps = OverlapsNotSupported
                , viewSegment = viewStaticHighlightableWithTags
                , id = config.id
                , highlightables = config.highlightables
                }
        )


{-| Groups highlightables with the same state together.
-}
buildGroups :
    { model
        | hintingIndices : Maybe ( Int, Int )
        , mouseOverIndex : Maybe Int
    }
    -> List (Highlightable marker)
    -> List (List (Highlightable marker))
buildGroups model =
    List.Extra.groupWhile (groupHighlightables model)
        >> List.map (\( elem, list ) -> elem :: list)


groupHighlightables :
    { model
        | hintingIndices : Maybe ( Int, Int )
        , mouseOverIndex : Maybe Int
    }
    -> Highlightable marker
    -> Highlightable marker
    -> Bool
groupHighlightables { hintingIndices, mouseOverIndex } x y =
    let
        xIsHinted =
            isHinted hintingIndices x

        yIsHinted =
            isHinted hintingIndices y

        xIsHovered =
            mouseOverIndex == Just x.index

        yIsHovered =
            mouseOverIndex == Just y.index

        xAndYHaveTheSameState =
            -- Both are hinted
            (xIsHinted && yIsHinted)
                || -- Neither is hinted
                   (not xIsHinted && not yIsHinted)
                || -- Neither is hovered
                   (not xIsHovered && not yIsHovered)
    in
    (xAndYHaveTheSameState
        && (List.head x.marked == Nothing)
        && (List.head y.marked == Nothing)
    )
        || (List.head x.marked == List.head y.marked && List.head x.marked /= Nothing)
        || ((List.head x.marked /= Nothing) && yIsHinted)
        || ((List.head y.marked /= Nothing) && xIsHinted)


type OverlapsSupport marker
    = OverlapsNotSupported
    | OverlapsSupported { hoveredMarkerWithShortestHighlight : Maybe marker }


{-| When elements are marked and the view doesn't support overlaps, wrap the marked elements in a single `mark` html node.
-}
view_ :
    { showTagsInline : Bool
    , maybeTool : Maybe (Tool.Tool marker)
    , mouseOverIndex : Maybe Int
    , mouseDownIndex : Maybe Int
    , hintingIndices : Maybe ( Int, Int )
    , overlaps : OverlapsSupport marker
    , viewSegment : Highlightable marker -> List Css.Style -> Html msg
    , highlightables : List (Highlightable marker)
    , id : String
    }
    -> Html msg
view_ config =
    let
        toMark : Highlightable marker -> Tool.MarkerModel marker -> Mark.Mark
        toMark highlightable marker =
            { name = marker.name
            , startStyles = marker.startGroupClass
            , styles =
                markedHighlightableStyles config
                    (isHovered_ config highlightableGroups)
                    highlightable
            , endStyles = marker.endGroupClass
            }

        highlightableGroups =
            buildGroups config config.highlightables

        withoutOverlaps : List (List ( Highlightable marker, Maybe Mark ))
        withoutOverlaps =
            List.map
                (\group ->
                    List.map
                        (\highlightable ->
                            ( highlightable
                            , Maybe.map (toMark highlightable) (List.head highlightable.marked)
                            )
                        )
                        group
                )
                highlightableGroups

        withOverlaps : List ( Highlightable marker, List Mark )
        withOverlaps =
            List.map
                (\highlightable ->
                    ( highlightable
                    , List.map (toMark highlightable) highlightable.marked
                    )
                )
                config.highlightables
    in
    p [ Html.Styled.Attributes.id config.id, class "highlighter-container" ] <|
        if config.showTagsInline then
            List.concatMap (Mark.viewWithInlineTags config.viewSegment) withoutOverlaps

        else
            case config.overlaps of
                OverlapsSupported _ ->
                    Mark.viewWithOverlaps config.viewSegment withOverlaps

                OverlapsNotSupported ->
                    List.concatMap (Mark.view config.viewSegment) withoutOverlaps


viewHighlightable :
    { renderMarkdown : Bool, overlaps : OverlapsSupport marker }
    ->
        { config
            | id : String
            , focusIndex : Maybe Int
            , marker : Tool.Tool marker
            , mouseOverIndex : Maybe Int
            , mouseDownIndex : Maybe Int
            , hintingIndices : Maybe ( Int, Int )
            , sorter : Sorter marker
            , highlightables : List (Highlightable marker)
        }
    -> Highlightable marker
    -> List Css.Style
    -> Html (Msg marker)
viewHighlightable { renderMarkdown, overlaps } config highlightable =
    case highlightable.type_ of
        Highlightable.Interactive ->
            viewHighlightableSegment
                { interactiveHighlighterId = Just config.id
                , focusIndex = config.focusIndex
                , eventListeners =
                    [ onPreventDefault "mouseover" (Pointer <| Over highlightable.index)
                    , onPreventDefault "mouseleave" (Pointer <| Out)
                    , onPreventDefault "mouseup" (Pointer <| Up Nothing)
                    , onPreventDefault "mousedown" (Pointer <| Down highlightable.index)
                    , onPreventDefault "touchstart" (Pointer <| Down highlightable.index)
                    , attribute "data-interactive" ""
                    , Key.onKeyDownPreventDefault
                        [ Key.space (Keyboard <| ToggleHighlight highlightable.index)
                        , Key.right (Keyboard <| MoveRight highlightable.index)
                        , Key.left (Keyboard <| MoveLeft highlightable.index)
                        , Key.shiftRight (Keyboard <| SelectionExpandRight highlightable.index)
                        , Key.shiftLeft (Keyboard <| SelectionExpandLeft highlightable.index)
                        ]
                    , Key.onKeyUpPreventDefault
                        [ Key.shiftRight (Keyboard <| SelectionApplyTool highlightable.index)
                        , Key.shiftLeft (Keyboard <| SelectionApplyTool highlightable.index)
                        , Key.shift (Keyboard <| SelectionReset highlightable.index)
                        ]
                    ]
                , renderMarkdown = renderMarkdown
                , maybeTool = Just config.marker
                , mouseOverIndex = config.mouseOverIndex
                , mouseDownIndex = config.mouseDownIndex
                , hintingIndices = config.hintingIndices
                , sorter = Just config.sorter
                , overlaps = overlaps
                }
                highlightable

        Highlightable.Static ->
            viewHighlightableSegment
                { interactiveHighlighterId = Nothing
                , focusIndex = config.focusIndex
                , eventListeners =
                    -- Static highlightables need listeners as well.
                    -- because otherwise we miss mouse events.
                    -- For example, a user hovering over a static space in a highlight
                    -- should see the entire highlight change to hover styles.
                    [ onPreventDefault "mouseover" (Pointer <| Over highlightable.index)
                    , onPreventDefault "mouseleave" (Pointer <| Out)
                    , onPreventDefault "mouseup" (Pointer <| Up Nothing)
                    , onPreventDefault "mousedown" (Pointer <| Down highlightable.index)
                    , onPreventDefault "touchstart" (Pointer <| Down highlightable.index)
                    , attribute "data-static" ""
                    ]
                , renderMarkdown = renderMarkdown
                , maybeTool = Just config.marker
                , mouseOverIndex = config.mouseOverIndex
                , mouseDownIndex = config.mouseDownIndex
                , hintingIndices = config.hintingIndices
                , sorter = Just config.sorter
                , overlaps = overlaps
                }
                highlightable


viewHighlightableSegment :
    { interactiveHighlighterId : Maybe String
    , focusIndex : Maybe Int
    , eventListeners : List (Attribute msg)
    , maybeTool : Maybe (Tool.Tool marker)
    , mouseOverIndex : Maybe Int
    , mouseDownIndex : Maybe Int
    , hintingIndices : Maybe ( Int, Int )
    , renderMarkdown : Bool
    , sorter : Maybe (Sorter marker)
    , overlaps : OverlapsSupport marker
    }
    -> Highlightable marker
    -> List Css.Style
    -> Html msg
viewHighlightableSegment ({ interactiveHighlighterId, focusIndex, eventListeners, renderMarkdown } as config) highlightable markStyles =
    let
        whitespaceClass txt =
            -- we need to override whitespace styles in order to support
            -- student-provided paragraph indents in essay writing
            -- (specifically in Self Reviews)
            --
            -- TODO: there *has* to be a better way to do this, but what is it?
            -- Ideally we would be able to provide `List Css.Style` for these
            -- cases, since they'll probably be different for the quiz engine
            -- and essay writing.
            case txt of
                "\t" ->
                    [ class "highlighter-whitespace-tab" ]

                " " ->
                    [ class "highlighter-whitespace-single-space" ]

                "\n" ->
                    [ class "highlighter-whitespace-newline" ]

                _ ->
                    []

        isInteractive =
            interactiveHighlighterId /= Nothing
    in
    span
        (eventListeners
            ++ List.map (Html.Styled.Attributes.map never) highlightable.customAttributes
            ++ whitespaceClass highlightable.text
            ++ [ attribute "data-highlighter-item-index" <| String.fromInt highlightable.index
               , case interactiveHighlighterId of
                    Just highlighterId ->
                        Html.Styled.Attributes.id (highlightableId highlighterId highlightable.index)

                    Nothing ->
                        AttributesExtra.none
               , css
                    (Css.focus [ Css.zIndex (Css.int 1), Css.position Css.relative ]
                        :: unmarkedHighlightableStyles config highlightable
                        ++ markStyles
                    )
               , class "highlighter-highlightable"
               , case List.head highlightable.marked of
                    Just _ ->
                        class "highlighter-highlighted"

                    _ ->
                        AttributesExtra.none
               , if isInteractive then
                    Key.tabbable
                        (case focusIndex of
                            Nothing ->
                                False

                            Just i ->
                                highlightable.index == i
                        )

                 else
                    AttributesExtra.none
               ]
        )
        (if renderMarkdown then
            renderInlineMarkdown highlightable.text

         else
            [ Html.text highlightable.text ]
        )


renderInlineMarkdown : String -> List (Html msg)
renderInlineMarkdown text_ =
    let
        ( leftWhitespace, inner, rightWhitespace ) =
            String.foldr
                (\char ( l, i, r ) ->
                    if char == ' ' then
                        if i == "" then
                            ( l, i, String.cons char r )

                        else
                            ( String.cons char l, i, r )

                    else
                        ( "", String.cons char l ++ i, r )
                )
                ( "", "", "" )
                text_

        innerMarkdown =
            Markdown.Block.parse Nothing inner
                |> List.map
                    (Markdown.Block.walk
                        (inlinifyMarkdownBlock
                            >> Markdown.Block.PlainInlines
                        )
                    )
                |> List.concatMap Markdown.Block.toHtml
                |> List.map Html.fromUnstyled
    in
    Html.text leftWhitespace :: innerMarkdown ++ [ Html.text rightWhitespace ]


inlinifyMarkdownBlock : Markdown.Block.Block a b -> List (Markdown.Inline.Inline b)
inlinifyMarkdownBlock block =
    case block of
        Markdown.Block.BlankLine str ->
            [ Markdown.Inline.Text str ]

        Markdown.Block.ThematicBreak ->
            []

        Markdown.Block.Heading _ _ inlines ->
            inlines

        Markdown.Block.CodeBlock _ str ->
            [ Markdown.Inline.Text str ]

        Markdown.Block.Paragraph _ inlines ->
            inlines

        Markdown.Block.BlockQuote blocks ->
            List.concatMap inlinifyMarkdownBlock blocks

        Markdown.Block.List _ blocks ->
            List.concatMap inlinifyMarkdownBlock (List.concat blocks)

        Markdown.Block.PlainInlines inlines ->
            inlines

        Markdown.Block.Custom b blocks ->
            List.concatMap inlinifyMarkdownBlock blocks


highlightableId : String -> Int -> String
highlightableId highlighterId index =
    "highlighter-" ++ highlighterId ++ "-highlightable-" ++ String.fromInt index


unmarkedHighlightableStyles :
    { config
        | maybeTool : Maybe (Tool.Tool marker)
        , hintingIndices : Maybe ( Int, Int )
        , mouseOverIndex : Maybe Int
    }
    -> Highlightable marker
    -> List Css.Style
unmarkedHighlightableStyles config highlightable =
    if highlightable.marked /= [] then
        []

    else
        case config.maybeTool of
            Nothing ->
                []

            Just tool ->
                let
                    isHinted_ =
                        isHinted config.hintingIndices highlightable

                    isHovered =
                        directlyHoveringInteractiveSegment config highlightable
                in
                Css.property "user-select" "none"
                    :: (case tool of
                            Tool.Marker marker ->
                                if isHinted_ then
                                    marker.hintClass

                                else if isHovered then
                                    -- When hovered, but not marked
                                    List.concat
                                        [ marker.hoverClass
                                        , marker.startGroupClass
                                        , marker.endGroupClass
                                        ]

                                else
                                    []

                            Tool.Eraser eraser_ ->
                                if isHinted_ then
                                    eraser_.hintClass

                                else if isHovered then
                                    eraser_.hoverClass

                                else
                                    []
                       )


markedHighlightableStyles :
    { config
        | maybeTool : Maybe (Tool.Tool marker)
        , mouseOverIndex : Maybe Int
        , hintingIndices : Maybe ( Int, Int )
        , overlaps : OverlapsSupport marker
    }
    -> (Highlightable marker -> Bool)
    -> Highlightable marker
    -> List Css.Style
markedHighlightableStyles ({ maybeTool, mouseOverIndex, hintingIndices } as config) getIsHovered ({ marked } as highlightable) =
    case maybeTool of
        Nothing ->
            [ case List.head marked of
                Just markedWith ->
                    Css.batch markedWith.highlightClass

                Nothing ->
                    Css.backgroundColor Css.transparent
            ]

        Just tool ->
            let
                isHinted_ =
                    isHinted hintingIndices highlightable

                isHovered =
                    getIsHovered highlightable
            in
            case tool of
                Tool.Marker marker ->
                    [ Css.property "user-select" "none"
                    , case List.head marked of
                        Just markedWith ->
                            if isHinted_ then
                                Css.batch marker.hintClass

                            else if isHovered then
                                -- Override marking with selected tool
                                Css.batch marker.hoverHighlightClass

                            else
                                -- otherwise, show the standard mark styles
                                Css.batch markedWith.highlightClass

                        Nothing ->
                            if isHinted_ then
                                Css.batch marker.hintClass

                            else if isHovered then
                                -- When Hovered but not marked
                                [ marker.hoverClass
                                , marker.startGroupClass
                                , marker.endGroupClass
                                ]
                                    |> List.concat
                                    |> Css.batch

                            else
                                Css.backgroundColor Css.transparent
                    ]

                Tool.Eraser eraser_ ->
                    case List.head marked of
                        Just markedWith ->
                            [ Css.property "user-select" "none"
                            , Css.batch markedWith.highlightClass
                            , Css.batch
                                (if isHinted_ then
                                    eraser_.hintClass

                                 else if isHovered then
                                    eraser_.hoverClass

                                 else
                                    []
                                )
                            ]

                        Nothing ->
                            [ Css.property "user-select" "none", Css.backgroundColor Css.transparent ]


{-| Helper for `on` to preventDefault.
-}
onPreventDefault : String -> msg -> Attribute msg
onPreventDefault name msg =
    let
        -- If we attempt to preventDefault on an event which is not cancelable
        -- Chrome will blow up and complain that:
        --
        -- Ignored attempt to cancel a touchmove event with cancelable=false,
        -- for example because scrolling is in progress and cannot be interrupted.
        --
        -- So instead we only preventDefault when it is safe to do so.
        checkIfCancelable =
            Json.Decode.field "cancelable" Json.Decode.bool
                |> Json.Decode.map (\result -> ( msg, result ))
    in
    Events.preventDefaultOn name
        checkIfCancelable
