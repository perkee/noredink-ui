module Nri.Ui.Balloon.V1 exposing
    ( balloon
    , Attribute
    , green, purple, orange, white, navy
    , onBottom, onLeft, onRight, onTop
    , width, padding
    )

{-| You propably want to use `Nri.Tooltip` not this.
This is used to display a ballon-like container.

@docs balloon


## Customizations for Balloon

Use these if you don't want the standard green balloon

@docs Attribute
@docs green, purple, orange, white, navy
@docs onBottom, onLeft, onRight, onTop
@docs width, padding, smallArrow

    balloon [ green, onTop ] (text "hello")

-}

import Css exposing (..)
import Html.Styled as Html exposing (Html, div, styled)
import Nri.Ui.Colors.V1 as Colors
import Nri.Ui.Fonts.V1 as Fonts



-- TOOLTIP VIEWS


{-| Green balloon without an arrow by default.

     __________
    |         |
    |_________|

-}
balloon : List (Attribute width padding paddingUnits) -> Html msg -> Html msg
balloon customizations content =
    custom (customizationsToConfig customizations) content


{-| Balloon's attributes.
-}
type Attribute width padding paddingUnits
    = Theme Theme
    | Position Position
    | Width (LengthOrAuto width)
    | Padding (Length padding paddingUnits)


{-| Balloon with the arrow on the bottom.

     __________
    |         |
    |___  ____|
        \/

-}
onTop : Attribute width padding paddingUnits
onTop =
    Position OnTop


{-| Balloon with the arrow on the left.

      __________
     |         |
    <          |
     |_________|

-}
onRight : Attribute width padding paddingUnits
onRight =
    Position OnRight


{-| Balloon with the arrow on the top.

     ___/\_____
    |         |
    |_________|

-}
onBottom : Attribute width padding paddingUnits
onBottom =
    Position OnBottom


{-| Balloon with the arrow on the right.

      __________
     |         |
     |          >
     |_________|

-}
onLeft : Attribute width padding paddingUnits
onLeft =
    Position OnLeft


{-| Green theme (This is the default theme.)
-}
green : Attribute width padding paddingUnits
green =
    Theme Green


{-| Orange theme
-}
orange : Attribute width padding paddingUnits
orange =
    Theme Orange


{-| Purple theme
-}
purple : Attribute width padding paddingUnits
purple =
    Theme Purple


{-| White theme
-}
white : Attribute width padding paddingUnits
white =
    Theme White


{-| Navy theme
-}
navy : Attribute width padding paddingUnits
navy =
    Theme Navy


{-| Width of the balloon
-}
width : LengthOrAuto width -> Attribute width padding paddingUnits
width =
    Width


{-| Padding of the balloon
-}
padding : Length padding paddingUnits -> Attribute width padding paddingUnits
padding =
    Padding



-- INTERNALS


type alias Config width padding paddingUnits =
    { position : Position
    , theme : Theme
    , width : Maybe (LengthOrAuto width)
    , padding : Maybe (Length padding paddingUnits)
    , arrowSize : ArrowSize
    }


{-| Default configuration
-}
defaultConfig : Config width padding paddingUnits
defaultConfig =
    { position = NoArrow
    , theme = Green
    , width = Nothing
    , padding = Nothing
    , arrowSize = Medium
    }


{-| The Arrow may be positioned on any edge of the balloon, facing outward.
-}
type Position
    = OnTop
    | OnRight
    | OnBottom
    | OnLeft
    | NoArrow


{-| NOTE: Double check with the design team if the spec calls for something else.
-}
type Theme
    = Orange
    | Green
    | Purple
    | White
    | Navy


type ArrowSize
    = Medium


custom : Config width padding paddingUnits -> Html msg -> Html msg
custom config content =
    container config.position
        [ viewBalloon config.theme config.width config.padding [ content ]
        , case config.position of
            NoArrow ->
                Html.text ""

            _ ->
                viewArrow config.position config.theme <|
                    case config.arrowSize of
                        Medium ->
                            8 * 2
        ]


container : Position -> List (Html msg) -> Html msg
container position =
    styled div
        (case position of
            OnTop ->
                [ Css.display Css.inlineFlex
                , Css.flexDirection Css.column
                , Css.alignItems Css.center
                ]

            OnBottom ->
                [ Css.display Css.inlineFlex
                , Css.flexDirection Css.columnReverse
                , Css.alignItems Css.center
                ]

            OnLeft ->
                [ Css.display Css.inlineFlex
                , Css.flexDirection Css.row
                , Css.alignItems Css.center
                ]

            OnRight ->
                [ Css.display Css.inlineFlex
                , Css.flexDirection Css.rowReverse
                , Css.alignItems Css.center
                ]

            NoArrow ->
                []
        )
        []


viewBalloon : Theme -> Maybe (LengthOrAuto width) -> Maybe (Length padding paddingUnits) -> List (Html msg) -> Html msg
viewBalloon theme_ width_ paddingLength contents =
    styled div
        (List.filterMap identity
            [ Just (display inlineBlock)
            , Just (lineHeight (num 1.4))
            , Just (textAlign left)
            , Just (position relative)
            , Just (Css.borderRadius (px 8))
            , case paddingLength of
                Just pl ->
                    Just (Css.padding pl)

                Nothing ->
                    Just (Css.padding (px 20))
            , Just (balloonTheme theme_)
            , Maybe.map Css.width width_
            ]
        )
        []
        contents


balloonTheme : Theme -> Css.Style
balloonTheme theme =
    case theme of
        Orange ->
            batch
                [ backgroundColor Colors.sunshine
                , border3 (px 1) solid Colors.sunshine
                , Fonts.baseFont
                , fontSize (px 15)
                , color Colors.gray20
                ]

        Purple ->
            batch
                [ backgroundColor Colors.purple
                , border3 (px 1) solid Colors.purple
                , Fonts.baseFont
                , fontSize (px 15)
                , color Colors.white
                ]

        White ->
            batch
                [ backgroundColor Colors.white
                , border3 (px 1) solid Colors.white
                , Fonts.baseFont
                , fontSize (px 15)
                , color Colors.gray20
                ]

        Green ->
            batch
                [ backgroundColor Colors.greenDark
                , border3 (px 1) solid Colors.greenDark
                , Fonts.baseFont
                , fontSize (px 15)
                , color Colors.white
                ]

        Navy ->
            batch
                [ backgroundColor Colors.navy
                , border3 (px 1) solid Colors.navy
                , Fonts.baseFont
                , fontSize (px 15)
                , color Colors.white
                ]


viewArrow : Position -> Theme -> Float -> Html msg
viewArrow position theme diagonal =
    let
        arrowSideWidth =
            sqrt ((diagonal ^ 2) / 2)
    in
    styled div
        [ arrowPosition position
        , arrowTheme theme
        , Css.height (px arrowSideWidth)
        , Css.width (px arrowSideWidth)
        ]
        []
        []


arrowPosition : Position -> Css.Style
arrowPosition position =
    case position of
        OnTop ->
            batch
                [ Css.property "transform" "translateY(-50%) rotate(45deg)"
                , Css.property "transform-origin" "center"
                , Css.borderTop Css.zero
                , Css.borderLeft Css.zero
                , Css.borderTopLeftRadius (pct 100)
                , Css.flexShrink (Css.num 0)
                ]

        OnBottom ->
            batch
                [ Css.property "transform" "translateY(50%) rotate(45deg)"
                , Css.property "transform-origin" "center"
                , Css.borderRight Css.zero
                , Css.borderBottom Css.zero
                , Css.borderBottomRightRadius (pct 100)
                , Css.flexShrink (Css.num 0)
                ]

        OnLeft ->
            batch
                [ Css.property "transform" "translateX(-50%) rotate(45deg)"
                , Css.property "transform-origin" "center"
                , Css.borderBottom Css.zero
                , Css.borderLeft Css.zero
                , Css.borderBottomLeftRadius (pct 100)
                , Css.flexShrink (Css.num 0)
                ]

        OnRight ->
            batch
                [ Css.property "transform" "translateX(50%) rotate(45deg)"
                , Css.property "transform-origin" "center"
                , Css.borderRight Css.zero
                , Css.borderTop Css.zero
                , Css.borderTopRightRadius (pct 100)
                , Css.flexShrink (Css.num 0)
                ]

        NoArrow ->
            batch
                []


arrowTheme : Theme -> Css.Style
arrowTheme theme =
    case theme of
        Orange ->
            batch
                [ backgroundColor Colors.sunshine
                , border3 (px 1) solid Colors.sunshine
                , Fonts.baseFont
                , fontSize (px 15)
                , color Colors.gray20
                ]

        Purple ->
            batch
                [ backgroundColor Colors.purple
                , border3 (px 1) solid Colors.purple
                , Fonts.baseFont
                , fontSize (px 15)
                , color Colors.white
                ]

        White ->
            batch
                [ backgroundColor Colors.white
                , border3 (px 1) solid Colors.white
                , Fonts.baseFont
                , fontSize (px 15)
                , color Colors.gray20
                ]

        Green ->
            batch
                [ backgroundColor Colors.greenDark
                , border3 (px 1) solid Colors.greenDark
                , Fonts.baseFont
                , fontSize (px 15)
                , color Colors.white
                ]

        Navy ->
            batch
                [ backgroundColor Colors.navy
                , border3 (px 1) solid Colors.navy
                , Fonts.baseFont
                , fontSize (px 15)
                , color Colors.white
                ]


customizationsToConfig : List (Attribute width padding paddingUnits) -> Config width padding paddingUnits
customizationsToConfig customizations =
    List.foldl customize defaultConfig customizations


customize : Attribute width padding paddingUnits -> Config width padding paddingUnits -> Config width padding paddingUnits
customize customization config =
    case customization of
        Position position ->
            { config | position = position }

        Theme theme ->
            { config | theme = theme }

        Width width_ ->
            { config | width = Just width_ }

        Padding length ->
            { config | padding = Just length }
