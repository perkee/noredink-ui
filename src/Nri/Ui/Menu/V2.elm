module Nri.Ui.Menu.V2 exposing
    ( view, Alignment(..), TitleWrapping(..)
    , viewCustom
    , Entry, group, none, entry
    )

{-| Changes from V1:

  - Improves keyboard support
  - adds `focus` to configuration
  - renames `onToggle` to `toggle` (just for consistency)
  - remove `iconButton` and `iconLink` (use ClickableSvg instead)
  - replace iconButtonWithMenu helper with a custom helper
  - explicitly pass in a buttonId and a menuId (instead of the container id)
  - when wrapping the menu title, use the title in the description rather than an HTML id string
  - separate out the data for the viewCustom menu and the data used to make a nice looking shared default button

A togglable menu view and related buttons.

<https://zpl.io/a75OrE2>


## Menu buttons

@docs view, Alignment, TitleWrapping
@docs viewCustom


## Menu content

@docs Entry, group, none, entry

-}

import Accessibility.Styled.Aria as Aria
import Accessibility.Styled.Key as Key
import Accessibility.Styled.Role as Role
import Accessibility.Styled.Widget as Widget
import Css exposing (..)
import Css.Global exposing (descendants)
import Html.Styled as Html exposing (..)
import Html.Styled.Attributes as Attributes exposing (class, classList, css)
import Html.Styled.Events as Events
import Json.Decode
import Nri.Ui.Colors.V1 as Colors
import Nri.Ui.Fonts.V1
import Nri.Ui.Html.Attributes.V2 as AttributesExtra
import Nri.Ui.Html.V3 exposing (viewJust)
import Nri.Ui.Svg.V1 as Svg exposing (Svg)
import Nri.Ui.UiIcon.V1 as UiIcon
import String.Extra



-- ENTRIES


{-| Represents zero or more entries within the menu content
-}
type Entry msg
    = Single (Html msg)
    | Batch String (List (Entry msg))
    | None


{-| Represents a group of entries with a named legend
-}
group : String -> List (Entry msg) -> Entry msg
group =
    Batch


{-| Represents a single entry
-}
entry : Html msg -> Entry msg
entry =
    Single


{-| Represents no entries. Useful for conditionals
-}
none : Entry msg
none =
    None


{-| Determines how we deal with long titles. Should we make the menu expand in
height to show the full title or truncate it instead?
-}
type TitleWrapping
    = WrapAndExpandTitle
    | TruncateTitle


{-| Whether the menu content sticks to the left or right side of the button
-}
type Alignment
    = Left
    | Right


{-| Menu/pulldown configuration:

  - `entries`: the entries of the menu
  - `toggle`: a message to trigger when then menu wants to invert its open state
  - `focus`: a message to control the focus in the DOM, takes an HTML id string
  - `alignment`: where the menu popover should appear relative to the button
  - `isDisabled`: whether the menu can be openned
  - `menuWidth` : optionally fix the width of the popover
  - `buttonId`: a unique string identifier for the button that opens/closes the menu
  - `menuId`: a unique string identifier for the menu

Button configuration:

  - `icon`: display a particular icon to the left of the title
  - `title`: the text to display in the menu button
  - `wrapping`: WrapAndExpandTitle | TruncateTitle
  - `hasBorder`: whether the menu button has a border
  - `buttonWidth`: optionally fix the width of the button to a number of pixels

-}
view :
    { entries : List (Entry msg)
    , isOpen : Bool
    , toggle : Bool -> msg
    , focus : String -> msg
    , alignment : Alignment
    , isDisabled : Bool
    , menuWidth : Maybe Int
    , buttonId : String
    , menuId : String
    }
    ->
        { icon : Maybe Svg.Svg
        , title : String
        , wrapping : TitleWrapping
        , hasBorder : Bool
        , buttonWidth : Maybe Int
        }
    -> Html msg
view menuConfig buttonConfig =
    viewCustom menuConfig <|
        \buttonAttributes ->
            Html.button
                ([ classList [ ( "ToggleButton", True ), ( "WithBorder", buttonConfig.hasBorder ) ]
                 , css
                    [ Nri.Ui.Fonts.V1.baseFont
                    , fontSize (px 15)
                    , backgroundColor Colors.white
                    , border zero
                    , padding (px 4)
                    , textAlign left
                    , height (pct 100)
                    , fontWeight (int 600)
                    , cursor pointer
                    , disabled
                        [ opacity (num 0.4)
                        , cursor notAllowed
                        ]
                    , Css.batch <|
                        if buttonConfig.hasBorder then
                            [ border3 (px 1) solid Colors.gray75
                            , borderBottom3 (px 3) solid Colors.gray75
                            , borderRadius (px 8)
                            , padding2 (px 10) (px 15)
                            ]

                        else
                            []
                    , Maybe.map (\w -> Css.width (Css.px (toFloat w))) buttonConfig.buttonWidth
                        |> Maybe.withDefault (Css.batch [])
                    ]
                 ]
                    ++ buttonAttributes
                )
                [ div styleButtonInner
                    [ viewTitle { icon = buttonConfig.icon, wrapping = buttonConfig.wrapping, title = buttonConfig.title }
                    , viewArrow { isOpen = menuConfig.isOpen }
                    ]
                ]


viewArrow : { isOpen : Bool } -> Html msg
viewArrow { isOpen } =
    span
        [ classList [ ( "Arrow", True ), ( "Open", isOpen ) ]
        , css
            [ width (px 12)
            , height (px 7)
            , marginLeft (px 5)
            , color Colors.azure
            , Css.flexShrink (Css.num 0)
            , descendants
                [ Css.Global.svg [ display block ]
                ]
            , property "transform-origin" "center"
            , property "transition" "transform 0.1s"
            , if isOpen then
                transform (rotate (deg 180))

              else
                Css.batch []
            ]
        ]
        [ Svg.toHtml UiIcon.arrowDown ]


viewTitle :
    { icon : Maybe Svg.Svg
    , wrapping : TitleWrapping
    , title : String
    }
    -> Html msg
viewTitle config =
    div styleTitle
        [ viewJust (\icon -> span styleIconContainer [ Svg.toHtml icon ])
            config.icon
        , span
            (case config.wrapping of
                WrapAndExpandTitle ->
                    [ Attributes.attribute "data-nri-description" config.title ]

                TruncateTitle ->
                    [ class "Truncated"
                    , css
                        [ whiteSpace noWrap
                        , overflow hidden
                        , textOverflow ellipsis
                        ]
                    ]
            )
            [ Html.text config.title ]
        ]


viewDropdown :
    { alignment : Alignment
    , isOpen : Bool
    , isDisabled : Bool
    , menuId : String
    , buttonId : String
    , menuWidth : Maybe Int
    , entries : List (Entry msg)
    }
    -> Html msg
viewDropdown config =
    let
        contentVisible =
            config.isOpen && not config.isDisabled
    in
    div
        [ classList [ ( "Content", True ), ( "ContentVisible", contentVisible ) ]
        , styleContent contentVisible config.alignment
        , Role.menu
        , Aria.labelledBy config.buttonId
        , Attributes.id config.menuId
        , Widget.hidden (not config.isOpen)
        , css
            [ Maybe.map (\w -> Css.width (Css.px (toFloat w))) config.menuWidth
                |> Maybe.withDefault (Css.batch [])
            ]
        ]
        (List.map viewEntry config.entries)


viewEntry : Entry msg -> Html msg
viewEntry entry_ =
    case entry_ of
        Single child ->
            div (Role.menuItem :: styleMenuEntryContainer) [ child ]

        Batch title childList ->
            case childList of
                [] ->
                    Html.text ""

                _ ->
                    fieldset styleGroupContainer <|
                        legend styleGroupTitle
                            [ span styleGroupTitleText [ Html.text title ] ]
                            :: List.map viewEntry childList

        None ->
            Html.text ""


{-|

  - `entries`: the entries of the menu
  - `toggle`: a message to trigger when then menu wants to invert its open state
  - `focus`: a message to control the focus in the DOM, takes an HTML id string
  - `alignment`: where the menu popover should appear relative to the button
  - `isDisabled`: whether the menu can be openned
  - `menuWidth` : optionally fix the width of the popover
  - `buttonId`: a unique string identifier for the button that opens/closes the menu
  - `menuId`: a unique string identifier for the menu

-}
viewCustom :
    { entries : List (Entry msg)
    , isOpen : Bool
    , toggle : Bool -> msg
    , focus : String -> msg
    , alignment : Alignment
    , isDisabled : Bool
    , menuWidth : Maybe Int
    , buttonId : String
    , menuId : String
    }
    -> (List (Attribute msg) -> Html msg)
    -> Html msg
viewCustom config content =
    div
        (Attributes.id (config.buttonId ++ "__container")
            :: Key.onKeyDown [ Key.escape (config.toggle False) ]
            :: styleContainer
        )
        [ if config.isOpen then
            div
                (Events.onClick (config.toggle False)
                    :: class "Nri-Menu-Overlay"
                    :: styleOverlay
                )
                []

          else
            Html.text ""
        , div styleInnerContainer
            [ content
                [ Widget.disabled config.isDisabled
                , Widget.hasMenuPopUp
                , Widget.expanded config.isOpen
                , Aria.controls config.menuId
                , Attributes.id config.buttonId
                , if config.isDisabled then
                    AttributesExtra.none

                  else
                    Events.custom "click"
                        (Json.Decode.succeed
                            { preventDefault = True
                            , stopPropagation = True
                            , message = config.toggle (not config.isOpen)
                            }
                        )
                ]
            , viewDropdown
                { alignment = config.alignment
                , isOpen = config.isOpen
                , isDisabled = config.isDisabled
                , menuId = config.menuId
                , buttonId = config.buttonId
                , menuWidth = config.menuWidth
                , entries = config.entries
                }
            ]
        ]



-- STYLES


buttonLinkResets : List Style
buttonLinkResets =
    [ boxSizing borderBox
    , border zero
    , padding zero
    , margin zero
    , backgroundColor transparent
    , cursor pointer
    , display inlineBlock
    , verticalAlign middle
    ]


{-| -}
styleInnerContainer : List (Attribute msg)
styleInnerContainer =
    [ class "InnerContainer"
    , css [ position relative ]
    ]


styleOverlay : List (Attribute msg)
styleOverlay =
    [ class "Overlay"
    , css
        [ position fixed
        , width (pct 100)
        , height (pct 100)
        , left zero
        , top zero
        , zIndex (int 1)
        ]
    ]


styleMenuEntryContainer : List (Attribute msg)
styleMenuEntryContainer =
    [ class "MenuEntryContainer"
    , css
        [ padding2 (px 5) zero
        , position relative
        , firstChild
            [ paddingTop zero ]
        , lastChild
            [ paddingBottom zero ]
        ]
    ]


styleTitle : List (Attribute msg)
styleTitle =
    [ class "Title"
    , css
        [ width (pct 100)
        , overflow hidden
        , Css.displayFlex
        , Css.alignItems Css.center
        , color Colors.gray20
        ]
    ]


styleGroupTitle : List (Attribute msg)
styleGroupTitle =
    [ class "GroupTitle"
    , css
        [ Nri.Ui.Fonts.V1.baseFont
        , fontSize (px 12)
        , color Colors.gray45
        , margin zero
        , padding2 (px 5) zero
        , lineHeight initial
        , borderBottom zero
        , position relative
        , before
            [ property "content" "\"\""
            , width (pct 100)
            , backgroundColor Colors.gray75
            , height (px 1)
            , marginTop (px -1)
            , display block
            , top (pct 50)
            , position absolute
            ]
        ]
    ]


styleGroupTitleText : List (Attribute msg)
styleGroupTitleText =
    [ class "GroupTitleText"
    , css
        [ backgroundColor Colors.white
        , marginLeft (px 22)
        , padding2 zero (px 5)
        , zIndex (int 2)
        , position relative
        ]
    ]


styleGroupContainer : List (Attribute msg)
styleGroupContainer =
    [ class "GroupContainer"
    , css
        [ margin zero
        , padding zero
        , paddingBottom (px 15)
        , lastChild
            [ paddingBottom zero ]
        ]
    ]


styleButtonInner : List (Attribute msg)
styleButtonInner =
    [ class "ButtonInner"
    , css
        [ Css.displayFlex
        , Css.justifyContent Css.spaceBetween
        , Css.alignItems Css.center
        ]
    ]


styleIconContainer : List (Attribute msg)
styleIconContainer =
    [ class "IconContainer"
    , css
        [ width (px 21)
        , height (px 21)
        , marginRight (px 5)
        , display inlineBlock
        , Css.flexShrink (Css.num 0)
        , color Colors.azure
        ]
    ]


styleContent : Bool -> Alignment -> Attribute msg
styleContent contentVisible alignment =
    css
        [ padding (px 25)
        , border3 (px 1) solid Colors.gray85
        , minWidth (px 202)
        , position absolute
        , borderRadius (px 8)
        , marginTop (px 10)
        , zIndex (int 2)
        , backgroundColor Colors.white
        , listStyle Css.none
        , Css.property "box-shadow" "0 0 10px 0 rgba(0,0,0,0.1)"
        , zIndex (int 2)
        , before
            [ property "content" "\"\""
            , position absolute
            , top (px -12)
            , border3 (px 6) solid transparent
            , borderBottomColor Colors.gray85
            ]
        , after
            [ property "content" "\"\""
            , position absolute
            , top (px -10)
            , zIndex (int 2)
            , border3 (px 5) solid transparent
            , borderBottomColor Colors.white
            ]
        , case alignment of
            Left ->
                Css.batch
                    [ left zero
                    , before [ left (px 19) ]
                    , after [ left (px 20) ]
                    ]

            Right ->
                Css.batch
                    [ right zero
                    , before [ right (px 19) ]
                    , after [ right (px 20) ]
                    ]
        , if contentVisible then
            display block

          else
            display Css.none
        ]


styleContainer : List (Attribute msg)
styleContainer =
    [ class "Container"
    , css
        [ position relative
        , display inlineBlock
        ]
    ]
