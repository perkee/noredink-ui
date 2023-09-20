module Nri.Ui.FocusLoop.V1 exposing (Config, view, addEvents)

{-| Sometimes, there are sets of interactive elements that we want users to be able to navigate
through with arrow keys rather than with tabs, and we want the final focus change to wrap.
This module makes it easier to set up this focus and wrapping behavior.

@docs Config, view, addEvents

-}

import Accessibility.Styled exposing (Html)
import Accessibility.Styled.Key as Key
import Nri.Ui.FocusLoop.Internal exposing (keyEvents, siblings)


{-| FocusLoop.view Configuration
-}
type alias Config id msg args =
    { id : args -> id
    , focus : id -> msg
    , view : List (Key.Event msg) -> args -> Html msg
    , leftRight : Bool
    , upDown : Bool
    }


{-| Helper for creating a list of elements navigable via arrow keys, with wrapping.

Your `view` function will be called for each item with the corresponding keyboard
event handlers, as well as the item itself.

e.g.

    FocusLoop.view
        { id = .id
        , focus = Focus
        , leftRight = True
        , upDown = True
        , view = viewFocusableItem
        }
        items

    viewFocusableItem handlers item =
        div
            [ handlers ]
            [ text item.name ]

Does your list support adding and removing items? If so, check out `FocusLoop.Lazy` which
will prevent the need to re-calculate event handlers for all items each time the list changes.

-}
view : Config id msg args -> args -> id -> id -> Html msg
view config current prevId nextId =
    config.view (keyEvents config ( prevId, nextId )) current


{-| Zip a list of items with its corresponding keyboard events.
-}
addEvents :
    { focus : a -> msg
    , leftRight : Bool
    , upDown : Bool
    }
    -> List a
    -> List ( a, List (Key.Event msg) )
addEvents config =
    siblings >> List.map (Tuple.mapSecond (Maybe.map (keyEvents config) >> Maybe.withDefault []))
