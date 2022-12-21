module Position exposing (xOffsetPx)

{-| -}

import Browser.Dom as Dom


{-| Figure out how much an element needs to shift along the horizontal axis in order to not be cut off by the viewport.

Uses Brower.Dom's Element measurement.

-}
xOffsetPx : Dom.Element -> Float
xOffsetPx { element, viewport } =
    let
        xMax =
            viewport.x + viewport.width
    in
    -- if the element is cut off by the viewport on the left side,
    -- we need to adjust rightward by the cut-off amount
    if element.x < viewport.x then
        viewport.x - element.x

    else
    -- if the element is cut off by the viewport on the right side,
    -- we need to adjust leftward by the cut-off amount
    if
        xMax < (element.x + element.width)
    then
        xMax - (element.x + element.width)

    else
        0
