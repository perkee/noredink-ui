module Nri.Ui.FocusRing.V1 exposing (styles, focusVisibleStyles)

{-|

@docs styles, focusVisibleStyles

-}

import Css
import Css.Global
import Nri.Ui.Colors.Extra exposing (toCssString)
import Nri.Ui.Colors.V1 as Colors


{-| When :focus-visible, add the two-tone focus ring.
-}
focusVisibleStyles : Css.Global.Snippet
focusVisibleStyles =
    Css.Global.selector ":not(.custom-focus-ring):focus-visible" styles


{-| A two-tone focus ring that will be visually apparent for any background/element combination.
-}
styles : List Css.Style
styles =
    [ boxShadows
    , Css.outline Css.none

    -- TODO: it isn't safe to set the border radius on focus.
    -- learn/mastery has anchor tag cards with border radius 8px, for instance
    , Css.borderRadius (Css.px 4)
    ]


boxShadows : Css.Style
boxShadows =
    -- using `property` due to https://github.com/rtfeldman/elm-css/issues/265
    Css.property "box-shadow" <|
        "0 0 0px 3px "
            ++ toCssString Colors.white
            ++ ", 0 0 0 6px "
            ++ toCssString Colors.red
