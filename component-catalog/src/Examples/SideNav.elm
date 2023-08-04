module Examples.SideNav exposing (Msg, State, example)

{-|

@docs Msg, State, example

-}

import Accessibility.Styled exposing (..)
import Category exposing (Category(..))
import Code
import CommonControls
import Css
import Debug.Control as Control exposing (Control)
import Debug.Control.Extra as ControlExtra
import Debug.Control.View as ControlView
import EllieLink
import Example exposing (Example)
import Html.Styled.Attributes exposing (css)
import Nri.Ui.Colors.V1 as Colors
import Nri.Ui.SideNav.V5 as SideNav


version : Int
version =
    5


{-| -}
example : Example State Msg
example =
    { name = moduleName
    , version = version
    , state = init
    , update = update
    , subscriptions = \_ -> Sub.none
    , categories = [ Layout, Navigation ]
    , keyboardSupport = []
    , preview = [ viewPreview ]
    , view = view
    }


moduleName : String
moduleName =
    "SideNav"


viewPreview : Html msg
viewPreview =
    div
        [ css
            [ Css.height (Css.px 80)
            , Css.backgroundColor Colors.white
            , Css.padding (Css.px 8)
            , Css.displayFlex
            ]
        ]
        [ div
            [ css
                [ Css.flexGrow (Css.int 1)
                , Css.backgroundColor Colors.gray96
                , Css.borderRadius (Css.px 2)
                ]
            ]
            [ div
                [ css
                    [ Css.height (Css.px 8)
                    , Css.backgroundColor Colors.glacier
                    , Css.borderRadius (Css.px 2)
                    , Css.margin2 (Css.px 8) (Css.px 4)
                    ]
                ]
                []
            ]
        , div [ css [ Css.flexGrow (Css.int 2) ] ] []
        ]


view : EllieLink.Config -> State -> List (Html Msg)
view ellieLinkConfig state =
    let
        settings =
            Control.currentValue state.settings
    in
    [ ControlView.view
        { ellieLinkConfig = ellieLinkConfig
        , name = moduleName
        , version = version
        , update = SetControls
        , settings = state.settings
        , mainType = Just "RootHtml.Html msg"
        , extraCode = []
        , renderExample = Code.unstyledView
        , toExampleCode =
            \{ navAttributes, entries } ->
                [ { sectionName = "View"
                  , code =
                        Code.fromModule moduleName "view"
                            ++ Code.recordMultiline
                                [ ( "isCurrentRoute", "(==) \"" ++ settings.currentRoute ++ "\"" )
                                , ( "routeToString", "identity" )
                                , ( "onSkipNav", "SkipToContent" )
                                ]
                                1
                            ++ Code.listMultiline (List.map Tuple.first navAttributes) 1
                            ++ Code.listMultiline (List.map Tuple.first entries) 1
                  }
                ]
        }
    , SideNav.view
        { isCurrentRoute = (==) settings.currentRoute
        , routeToString = identity
        , onSkipNav = SkipToContent
        }
        (List.map Tuple.second settings.navAttributes)
        (List.map Tuple.second settings.entries)
    ]


{-| -}
type alias State =
    { settings : Control Settings
    }


type alias Settings =
    { currentRoute : String
    , navAttributes : List ( String, SideNav.NavAttribute Msg )
    , entries : List ( String, SideNav.Entry String Msg )
    }


{-| -}
init : State
init =
    { settings =
        Control.record Settings
            |> Control.field "currentRoute" (Control.string "#some-route")
            |> Control.field "navAttributes" controlNavAttributes
            |> Control.field "entries" (Control.map List.singleton (controlEntryType 2 "#some-route"))
    }


controlNavAttributes : Control (List ( String, SideNav.NavAttribute Msg ))
controlNavAttributes =
    ControlExtra.list
        |> ControlExtra.optionalListItemDefaultChecked "navLabel"
            (Control.map
                (\val ->
                    ( "SideNav.navLabel \"" ++ val ++ "\""
                    , SideNav.navLabel val
                    )
                )
                (Control.string "Example")
            )
        |> ControlExtra.optionalListItem "navNotMobileCss"
            (Control.choice
                [ ( "maxWidth"
                  , Control.value
                        ( "SideNav.navNotMobileCss [ Css.maxWidth (Css.px 300) ]"
                        , SideNav.navNotMobileCss [ Css.maxWidth (Css.px 300) ]
                        )
                  )
                , ( "purple border"
                  , Control.value
                        ( "SideNav.navNotMobileCss [ Css.border3 (Css.px 3) Css.dotted Colors.purple ]"
                        , SideNav.navNotMobileCss [ Css.border3 (Css.px 3) Css.dotted Colors.purple ]
                        )
                  )
                ]
            )
        |> ControlExtra.optionalListItem "navMobileCss"
            (Control.value
                ( "SideNav.navMobileCss [ Css.width (Css.pct 100) ]"
                , SideNav.navMobileCss [ Css.width (Css.pct 100) ]
                )
            )


controlEntryType : Int -> String -> Control ( String, SideNav.Entry String Msg )
controlEntryType level href =
    Control.choice
        [ ( "entry", controlEntry level href )
        , ( "entryWithChildren", controlEntryWithChildren level href )
        , ( "html", controlHtml level )
        ]


controlEntry : Int -> String -> Control ( String, SideNav.Entry String Msg )
controlEntry level href =
    Control.record
        (\title attributes ->
            ( "SideNav.entry \""
                ++ title
                ++ Code.listMultiline (List.map Tuple.first attributes) level
            , SideNav.entry title (List.map Tuple.second attributes)
            )
        )
        |> Control.field "title" (Control.string "Entry Category")
        |> Control.field "attributes" (controlEntryAttributes href)


controlEntryWithChildren : Int -> String -> Control ( String, SideNav.Entry String Msg )
controlEntryWithChildren level href =
    Control.record
        (\title attributes children ->
            ( "SideNav.entryWithChildren "
                ++ title
                ++ Code.listMultiline (List.map Tuple.first attributes) level
                ++ Code.listMultiline (List.map Tuple.first children) level
            , SideNav.entryWithChildren title
                (List.map Tuple.second attributes)
                (List.map Tuple.second children)
            )
        )
        |> Control.field "title" (Control.string "Entry Category")
        |> Control.field "attributes" (controlEntryAttributes href)
        |> Control.field "children"
            (Control.lazy
                (\() ->
                    Control.map List.singleton (controlEntryType (level + 1) (href ++ "-child"))
                )
            )


controlHtml : Int -> Control ( String, SideNav.Entry String Msg )
controlHtml level =
    Control.map
        (\html ->
            ( "SideNav.html " ++ Code.list (List.map Tuple.first html)
            , SideNav.html (List.map Tuple.second html)
            )
        )
        -- TODO: support HTML examples
        (Control.value [])


controlEntryAttributes : String -> Control (List ( String, SideNav.Attribute String Msg ))
controlEntryAttributes href =
    ControlExtra.list
        |> ControlExtra.listItem "href"
            (Control.map (\v -> ( "SideNav.href \"" ++ v ++ "\"", SideNav.href v ))
                (Control.string href)
            )
        |> CommonControls.css { moduleName = "SideNav", use = SideNav.css }
        |> CommonControls.iconNotCheckedByDefault "SideNav" SideNav.icon
        |> CommonControls.rightIcon "SideNav" SideNav.rightIcon
        |> ControlExtra.optionalBoolListItem "secondary" ( "SideNav.secondary", SideNav.secondary )
        |> ControlExtra.optionalListItem "premiumDisplay"
            (Control.map
                (\( displayStr, display ) ->
                    ( "SideNav.premiumDisplay " ++ displayStr
                    , SideNav.premiumDisplay display (ConsoleLog "Premium pennant clicked")
                    )
                )
                CommonControls.premiumDisplay
            )


{-| -}
type Msg
    = SetControls (Control Settings)
    | SkipToContent
    | ConsoleLog String


{-| -}
update : Msg -> State -> ( State, Cmd Msg )
update msg state =
    case msg of
        SetControls settings ->
            ( { state | settings = settings }, Cmd.none )

        SkipToContent ->
            ( state, Cmd.none )

        ConsoleLog message ->
            ( Debug.log "SideNav" message |> always state, Cmd.none )
