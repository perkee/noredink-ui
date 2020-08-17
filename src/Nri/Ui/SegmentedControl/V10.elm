module Nri.Ui.SegmentedControl.V10 exposing
    ( Option, view
    , SelectOption, viewSelect
    , Width(..)
    )

{-| Changes from V9:

  - hides non-displayed content rather than fully removing from the DOM, allowing for the content the SegmentedControl controls to have overflowY: auto & maintain scroll position
  - 💀 removes NavConfig and SelectConfig
  - combines `view` and `viewSpa` (for V9 `view` behavior, be sure `toUrl` is Nothing. for V9 `viewSpa` behavior, pass through a Just as `toUrl`)
  - add custom attributes hole to the Option (in order to make SegmentedControls compatible with the Modal component)
  - combine `css` attributes into one to prevent class-name-order-change css :bug:s
  - :bug: fix overflowing-y svg icon issue

@docs Option, view
@docs SelectOption, viewSelect
@docs Width

-}

import Accessibility.Styled exposing (..)
import Accessibility.Styled.Aria as Aria
import Accessibility.Styled.Role as Role
import Accessibility.Styled.Widget as Widget
import Css exposing (..)
import EventExtras
import Html.Styled
import Html.Styled.Attributes as Attributes exposing (css, href)
import Html.Styled.Events as Events
import Html.Styled.Keyed as Keyed
import Nri.Ui
import Nri.Ui.Colors.Extra exposing (withAlpha)
import Nri.Ui.Colors.V1 as Colors
import Nri.Ui.Fonts.V1 as Fonts
import Nri.Ui.Html.Attributes.V2 as AttributesExtra
import Nri.Ui.Svg.V1 as Svg exposing (Svg)
import Nri.Ui.Util exposing (dashify)


{-| -}
type Width
    = FitContent
    | FillContainer


{-| -}
type alias SelectOption value msg =
    { value : value
    , label : String
    , attributes : List (Attribute msg)
    , icon : Maybe Svg
    }


{-| Creates _just the segmented select_ when you need the ui element itself and
not a page control

  - `onClick` : the message to produce when an option is selected (clicked) by the user
  - `options`: the list of options available
  - `selected`: if present, the value of the currently-selected option
  - `width`: how to size the segmented control

-}
viewSelect :
    { onClick : a -> msg
    , options : List (SelectOption a msg)
    , selected : Maybe a
    , width : Width
    }
    -> Html msg
viewSelect config =
    let
        viewRadio option =
            let
                isSelected =
                    Just option.value == config.selected
            in
            button
                ([ Attributes.id (segmentIdFor option)
                 , css (getStyles { isSelected = isSelected, width = config.width })
                 , Role.radio
                 , if isSelected then
                    Widget.selected True

                   else
                    Widget.selected False
                 , Events.onClick (config.onClick option.value)
                 ]
                    ++ option.attributes
                )
                [ viewIcon option.icon
                , text option.label
                ]
    in
    div
        [ css
            [ displayFlex
            , cursor pointer
            ]
        , Role.radioGroup
        ]
        (List.map viewRadio config.options)


{-| -}
type alias Option value msg =
    { value : value
    , label : String
    , attributes : List (Attribute msg)
    , icon : Maybe Svg
    , content : Html msg
    }


{-|

  - `onClick` : the message to produce when an option is selected (clicked) by the user
  - `options`: the list of options available
  - `selected`: the value of the currently-selected option
  - `width`: how to size the segmented control
  - `toUrl`: a optional function that takes a `route` and returns the URL of that route. You should always use pass a `toUrl` function when the segmented control options correspond to routes in your SPA.

-}
view :
    { onClick : a -> msg
    , options : List (Option a msg)
    , selected : a
    , width : Width
    , toUrl : Maybe (a -> String)
    }
    -> Html msg
view config =
    let
        isSelected option =
            option.value == config.selected

        viewTab option =
            case config.toUrl of
                Just toUrl ->
                    -- This is a for a SPA view
                    Html.Styled.a
                        (href (toUrl option.value)
                            :: EventExtras.onClickPreventDefaultForLinkWithHref
                                (config.onClick option.value)
                            :: tabAttributes option
                            ++ option.attributes
                        )
                        [ viewIcon option.icon
                        , text option.label
                        ]

                Nothing ->
                    -- This is for a non-SPA view
                    button
                        (Events.onClick (config.onClick option.value)
                            :: tabAttributes option
                            ++ option.attributes
                        )
                        [ viewIcon option.icon
                        , text option.label
                        ]

        tabAttributes option =
            [ Attributes.id (segmentIdFor option)
            , css (getStyles { isSelected = isSelected option, width = config.width })
            , Role.tab
            , if isSelected option then
                Aria.currentPage

              else
                AttributesExtra.none
            ]

        viewTabPanel option =
            tabPanel
                [ Aria.labelledBy (segmentIdFor option)
                , css
                    [ paddingTop (px 10)
                    , if isSelected option then
                        Css.batch []

                      else
                        Css.display none
                    ]
                , Widget.hidden (not (isSelected option))
                ]
                [ option.content
                ]
    in
    div []
        [ tabList [ css [ displayFlex, cursor pointer ] ]
            (List.map viewTab config.options)
        , Keyed.node "div" [] <|
            List.map (\option -> ( keyedNodeIdFor option, viewTabPanel option ))
                config.options
        ]


segmentIdFor : { option | label : String } -> String
segmentIdFor option =
    "Nri-Ui-SegmentedControl-Segment-" ++ dashify option.label


keyedNodeIdFor : { option | label : String } -> String
keyedNodeIdFor option =
    "Nri-Ui-SegmentedControl-Panel-keyed-node-" ++ dashify option.label


panelIdFor : { option | label : String } -> String
panelIdFor option =
    "Nri-Ui-SegmentedControl-Panel-" ++ dashify option.label


viewIcon : Maybe Svg.Svg -> Html msg
viewIcon icon =
    case icon of
        Nothing ->
            text ""

        Just svg ->
            svg
                |> Svg.withWidth (px 18)
                |> Svg.withHeight (px 18)
                |> Svg.withCss
                    [ display inlineBlock
                    , verticalAlign textTop
                    , lineHeight (px 15)
                    , marginRight (px 8)
                    ]
                |> Svg.toHtml


getStyles : { isSelected : Bool, width : Width } -> List Style
getStyles { isSelected, width } =
    [ sharedSegmentStyles
    , if isSelected then
        focusedSegmentStyles

      else
        unFocusedSegmentStyles
    , case width of
        FitContent ->
            Css.batch []

        FillContainer ->
            expandingTabStyles
    ]


sharedSegmentStyles : Style
sharedSegmentStyles =
    [ padding2 (px 6) (px 20)
    , height (px 45)
    , Fonts.baseFont
    , fontSize (px 15)
    , fontWeight bold
    , lineHeight (px 30)
    , margin zero
    , firstOfType
        [ borderTopLeftRadius (px 8)
        , borderBottomLeftRadius (px 8)
        , borderLeft3 (px 1) solid Colors.azure
        ]
    , lastOfType
        [ borderTopRightRadius (px 8)
        , borderBottomRightRadius (px 8)
        ]
    , border3 (px 1) solid Colors.azure
    , borderLeft (px 0)
    , boxSizing borderBox
    , cursor pointer
    , property "transition" "background-color 0.2s, color 0.2s, box-shadow 0.2s, border 0.2s, border-width 0s"
    , textDecoration none
    , hover [ textDecoration none ]
    , focus [ textDecoration none ]
    ]
        |> Css.batch


focusedSegmentStyles : Style
focusedSegmentStyles =
    [ backgroundColor Colors.glacier
    , boxShadow5 inset zero (px 3) zero (withAlpha 0.2 Colors.gray20)
    , color Colors.navy
    ]
        |> Css.batch


unFocusedSegmentStyles : Style
unFocusedSegmentStyles =
    [ backgroundColor Colors.white
    , boxShadow5 inset zero (px -2) zero Colors.azure
    , color Colors.azure
    , hover [ backgroundColor Colors.frost ]
    ]
        |> Css.batch


expandingTabStyles : Style
expandingTabStyles =
    [ flexGrow (int 1)
    , textAlign center
    ]
        |> Css.batch