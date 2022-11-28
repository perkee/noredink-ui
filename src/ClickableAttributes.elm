module ClickableAttributes exposing
    ( ClickableAttributes, init
    , onClick, submit, opensModal
    , toButtonAttributes
    , href, linkWithMethod, linkWithTracking
    , linkSpa
    , linkExternal, linkExternalWithTracking
    , toLinkAttributes
    )

{-|

@docs ClickableAttributes, init


# For buttons

@docs onClick, submit, opensModal
@docs toButtonAttributes


# For links

@docs href, linkWithMethod, linkWithTracking
@docs linkSpa
@docs linkExternal, linkExternalWithTracking
@docs toLinkAttributes

-}

import Accessibility.Styled.Aria as Aria
import Accessibility.Styled.Role as Role
import EventExtras
import Html.Styled exposing (Attribute)
import Html.Styled.Attributes as Attributes
import Html.Styled.Events as Events
import Json.Decode
import Nri.Ui.Html.Attributes.V2 as AttributesExtra exposing (targetBlank)


{-| -}
type alias ClickableAttributes route msg =
    { linkType : Link
    , buttonType : String
    , url : Maybe route
    , urlString : Maybe String
    , onClick : Maybe msg
    , opensModal : Bool
    }


type Link
    = Default
    | WithTracking
    | SinglePageApp
    | WithMethod String
    | External
    | ExternalWithTracking


{-| -}
init : ClickableAttributes route msg
init =
    { linkType = Default
    , buttonType = "button"
    , url = Nothing
    , urlString = Nothing
    , onClick = Nothing
    , opensModal = False
    }


{-| -}
onClick : msg -> ClickableAttributes route msg -> ClickableAttributes route msg
onClick msg clickableAttributes =
    { clickableAttributes | onClick = Just msg }


{-| -}
submit : ClickableAttributes route msg -> ClickableAttributes route msg
submit clickableAttributes =
    { clickableAttributes | buttonType = "submit" }


{-| -}
opensModal : ClickableAttributes route msg -> ClickableAttributes route msg
opensModal clickableAttributes =
    { clickableAttributes | opensModal = True }


{-| -}
href : route -> ClickableAttributes route msg -> ClickableAttributes route msg
href url clickableAttributes =
    { clickableAttributes | url = Just url }


{-| -}
linkSpa : route -> ClickableAttributes route msg -> ClickableAttributes route msg
linkSpa url clickableAttributes =
    { clickableAttributes | linkType = SinglePageApp, url = Just url }


{-| -}
linkWithMethod : { method : String, url : route } -> ClickableAttributes route msg -> ClickableAttributes route msg
linkWithMethod { method, url } clickableAttributes =
    { clickableAttributes | linkType = WithMethod method, url = Just url }


{-| -}
linkWithTracking : { track : msg, url : route } -> ClickableAttributes route msg -> ClickableAttributes route msg
linkWithTracking { track, url } clickableAttributes =
    { clickableAttributes
        | linkType = WithTracking
        , url = Just url
        , onClick = Just track
    }


{-| -}
linkExternal : String -> ClickableAttributes route msg -> ClickableAttributes route msg
linkExternal url clickableAttributes =
    { clickableAttributes | linkType = External, urlString = Just url }


{-| -}
linkExternalWithTracking : { track : msg, url : String } -> ClickableAttributes route msg -> ClickableAttributes route msg
linkExternalWithTracking { track, url } clickableAttributes =
    { clickableAttributes
        | linkType = ExternalWithTracking
        , urlString = Just url
        , onClick = Just track
    }


{-| -}
toButtonAttributes : ClickableAttributes route msg -> List (Attribute msg)
toButtonAttributes clickableAttributes =
    [ AttributesExtra.maybe Events.onClick clickableAttributes.onClick
    , Attributes.type_ clickableAttributes.buttonType
    , -- why "aria-haspopup=true" instead of "aria-haspopup=dialog"?
      -- AT support for aria-haspopup=dialog is currently (Nov 2022) limited.
      -- See https://html5accessibility.com/stuff/2021/02/02/haspopup-haspoop/
      -- If time has passed, feel free to revisit and see if dialog support has improved!
      AttributesExtra.includeIf clickableAttributes.opensModal
        (Attributes.attribute "aria-haspopup" "true")
    ]


{-| -}
toLinkAttributes : { routeToString : route -> String, isDisabled : Bool } -> ClickableAttributes route msg -> ( String, List (Attribute msg) )
toLinkAttributes { routeToString, isDisabled } clickableAttributes =
    let
        ( linkTypeName, attributes ) =
            toEnabledLinkAttributes routeToString clickableAttributes
    in
    ( linkTypeName
    , if isDisabled then
        [ Role.link
        , Aria.disabled True
        ]

      else
        attributes
    )


toEnabledLinkAttributes : (route -> String) -> ClickableAttributes route msg -> ( String, List (Attribute msg) )
toEnabledLinkAttributes routeToString clickableAttributes =
    let
        stringUrl =
            case ( clickableAttributes.urlString, clickableAttributes.url ) of
                ( Just url, _ ) ->
                    url

                ( _, Just route ) ->
                    routeToString route

                ( Nothing, Nothing ) ->
                    "#"
    in
    case clickableAttributes.linkType of
        Default ->
            ( "link"
            , [ Attributes.href stringUrl
              , Attributes.target "_self"
              ]
            )

        SinglePageApp ->
            ( "linkSpa"
            , case clickableAttributes.onClick of
                Just handler ->
                    [ Attributes.href stringUrl
                    , EventExtras.onClickPreventDefaultForLinkWithHref handler
                    ]

                Nothing ->
                    [ Attributes.href stringUrl ]
            )

        WithMethod method ->
            ( "linkWithMethod"
            , [ Attributes.href stringUrl
              , Attributes.attribute "data-method" method
              ]
            )

        WithTracking ->
            ( "linkWithTracking"
            , case clickableAttributes.onClick of
                Just track ->
                    [ Attributes.href stringUrl
                    , Events.preventDefaultOn "click"
                        (Json.Decode.succeed ( track, True ))
                    ]

                Nothing ->
                    [ Attributes.href stringUrl ]
            )

        External ->
            ( "linkExternal"
            , Attributes.href stringUrl
                :: targetBlank
            )

        ExternalWithTracking ->
            ( "linkExternalWithTracking"
            , case clickableAttributes.onClick of
                Just handler ->
                    [ Attributes.href stringUrl
                    , Events.onClick handler
                    , Events.on "auxclick" (Json.Decode.succeed handler)
                    ]
                        ++ targetBlank

                Nothing ->
                    Attributes.href stringUrl
                        :: targetBlank
            )
