module Nri.Ui.Text.V6 exposing
    ( caption, mediumBody, mediumBodyGray, smallBody, smallBodyGray
    , ugMediumBody, ugSmallBody
    , Attribute, noBreak, css
    , noWidow
    )

{-| Changes from V5:


## Understanding spacing

  - All text styles have a specific line-height. This is set so that when text in the given style
    is long enough to wrap, the spacing between wrapped lines looks good.
  - No text styles have padding.
  - **Paragraph styles** only have bottom margin, but with **:last-child bottom margin set to zero**.
    This bottom margin is set to look good when multiple paragraphs of the same style follow one another.
      - If you want content after the paragraph and don't want the margin, put the paragraph in a `div` so that it will be the last-child, which will get rid of the bottom margin.
  - **User-authored content blocks** preserve line breaks and do not have margin.


## Headings

You're in the wrong place! Headings live in Nri.Ui.Heading.V2.


## Paragraph styles

@docs caption, mediumBody, mediumBodyGray, smallBody, smallBodyGray


## User-authored content blocks:

@docs ugMediumBody, ugSmallBody


## Customizations

@docs Attribute, noBreak, css


## Modifying strings to display nicely:

@docs noWidow

-}

import Css exposing (..)
import Css.Global exposing (a, descendants)
import Html.Styled exposing (..)
import Html.Styled.Attributes as Attrs
import Nri.Ui.Colors.V1 exposing (..)
import Nri.Ui.Fonts.V1 as Fonts


{-| -}
type Attribute
    = Attribute (Settings -> Settings)


type alias Settings =
    { noBreak : Bool
    , styles : List Css.Style
    }


defaultSettings : Settings
defaultSettings =
    { noBreak = False
    , styles = []
    }


buildSettings : List Attribute -> Settings
buildSettings =
    List.foldl (\(Attribute f) acc -> f acc) defaultSettings


{-| Text with this attribute will never wrap.
-}
noBreak : Attribute
noBreak =
    Attribute (\config -> { config | noBreak = True })


{-| Add some custom CSS to the text. If you find yourself using this a lot,
please add a stricter attribute to noredink-ui!
-}
css : List Style -> Attribute
css styles =
    Attribute (\config -> { config | styles = config.styles ++ styles })


styleForAttributes : Settings -> Style
styleForAttributes config =
    batch
        [ if config.noBreak then
            whiteSpace noWrap

          else
            batch []
        , batch config.styles
        ]


{-| This is some medium body copy.
-}
mediumBody : List Attribute -> List (Html msg) -> Html msg
mediumBody attributes content =
    let
        settings : Settings
        settings =
            buildSettings attributes
    in
    p
        [ paragraphStyles
            settings
            { font = Fonts.baseFont
            , color = gray20
            , size = 18
            , lineHeight = 28
            , weight = 400
            , margin = 10
            }
        ]
        content


{-| `mediumBody`, but with a lighter gray color than the default.
-}
mediumBodyGray : List Attribute -> List (Html msg) -> Html msg
mediumBodyGray attributes content =
    mediumBody (css [ Css.color gray45 ] :: attributes) content


{-| This is some small body copy.
-}
smallBody : List Attribute -> List (Html msg) -> Html msg
smallBody attributes content =
    let
        settings : Settings
        settings =
            buildSettings attributes
    in
    p
        [ paragraphStyles
            settings
            { font = Fonts.baseFont
            , color = gray20
            , size = 15
            , lineHeight = 23
            , weight = 400
            , margin = 7
            }
        ]
        content


{-| This is some small body copy but it's gray.
-}
smallBodyGray : List Attribute -> List (Html msg) -> Html msg
smallBodyGray attributes content =
    let
        settings : Settings
        settings =
            buildSettings attributes
    in
    p
        [ paragraphStyles settings
            { font = Fonts.baseFont
            , color = gray45
            , size = 15
            , lineHeight = 23
            , weight = 400
            , margin = 7
            }
        ]
        content


paragraphStyles :
    Settings
    ->
        { color : Color
        , font : Style
        , lineHeight : Float
        , margin : Float
        , size : Float
        , weight : Int
        }
    -> Html.Styled.Attribute msg
paragraphStyles settings config =
    Attrs.css
        [ config.font
        , fontSize (px config.size)
        , color config.color
        , lineHeight (px config.lineHeight)
        , fontWeight (int config.weight)
        , padding zero
        , textAlign left
        , margin4 (px 0) (px 0) (px config.margin) (px 0)
        , Css.Global.descendants
            [ Css.Global.a
                [ textDecoration none
                , color azure
                , borderBottom3 (px 1) solid azure
                , visited
                    [ color azure ]
                ]
            ]
        , lastChild
            [ margin zero
            ]
        , styleForAttributes settings
        ]


{-| This is a little note or caption.
-}
caption : List Attribute -> List (Html msg) -> Html msg
caption attributes content =
    let
        settings : Settings
        settings =
            buildSettings attributes
    in
    p
        [ paragraphStyles settings
            { font = Fonts.baseFont
            , color = gray45
            , size = 13
            , lineHeight = 18
            , weight = 400
            , margin = 5
            }
        ]
        content


{-| User-generated text.
-}
ugMediumBody : List Attribute -> List (Html msg) -> Html msg
ugMediumBody attributes =
    let
        settings : Settings
        settings =
            buildSettings attributes
    in
    p
        [ Attrs.css
            [ Fonts.quizFont
            , fontSize (px 18)
            , lineHeight (px 30)
            , whiteSpace preLine
            , color gray20
            , margin zero
            , styleForAttributes settings
            ]
        ]


{-| User-generated text.
-}
ugSmallBody : List Attribute -> List (Html msg) -> Html msg
ugSmallBody attributes =
    let
        settings : Settings
        settings =
            buildSettings attributes
    in
    p
        [ Attrs.css
            [ Fonts.quizFont
            , fontSize (px 16)
            , lineHeight (px 25)
            , whiteSpace preLine
            , color gray20
            , margin zero
            , styleForAttributes settings
            ]
        ]


{-| Eliminate widows (single words on their own line caused by
wrapping) by inserting a non-breaking space if there are at least two
words.
-}
noWidow : String -> String
noWidow inputs =
    let
        -- this value is a unicode non-breaking space since Elm
        -- doesn't support named character entities
        nbsp =
            "\u{00A0}"

        words =
            String.split " " inputs

        insertPoint =
            List.length words - 1
    in
    words
        |> List.indexedMap
            (\i word ->
                if i == 0 then
                    word

                else if i == insertPoint && insertPoint > 0 then
                    nbsp ++ word

                else
                    " " ++ word
            )
        |> String.join ""
