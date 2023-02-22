module Examples.BreadCrumbs exposing (example, State, Msg)

{-|

@docs example, State, Msg

-}

import Accessibility.Styled exposing (..)
import Category exposing (Category(..))
import Code
import CommonControls
import Css
import Debug.Control as Control exposing (Control)
import Debug.Control.Extra as ControlExtra
import Debug.Control.View as ControlView
import Example exposing (Example)
import Html.Styled.Attributes exposing (css, href)
import Nri.Ui.BreadCrumbs.V2 as BreadCrumbs exposing (BreadCrumbAttribute, BreadCrumbs)
import Nri.Ui.Colors.V1 as Colors
import Nri.Ui.Fonts.V1 as Fonts
import Nri.Ui.Heading.V3 as Heading
import Nri.Ui.Html.V3 exposing (viewJust)
import Nri.Ui.Svg.V1 as Svg
import Nri.Ui.Table.V6 as Table
import Nri.Ui.UiIcon.V1 as UiIcon


{-| -}
type alias State =
    Control Settings


moduleName : String
moduleName =
    "BreadCrumbs"


version : Int
version =
    2


{-| -}
example : Example State Msg
example =
    { name = moduleName
    , version = version
    , categories = [ Layout ]
    , keyboardSupport = []
    , state = init
    , update = update
    , subscriptions = \_ -> Sub.none
    , preview =
        [ previewContainer [ previewText "🏠 Home" ]
        , previewContainer [ previewText "🏠 Home", previewArrowRight, previewText "🟠 Category " ]
        , previewContainer [ previewText "🏠", previewArrowRight, previewText "🟠", previewArrowRight, previewText "🟣 Sub-Category " ]
        ]
    , view =
        \ellieLinkConfig state ->
            let
                settings =
                    Control.currentValue state

                createBreadCrumbs ( initializeStr, initialize ) =
                    List.foldl
                        (\crumb acc ->
                            let
                                ( defs, addStr, add ) =
                                    case acc of
                                        Nothing ->
                                            ( "", initializeStr, initialize )

                                        Just ( ( definitions, preExisitingVarName ), preExisting ) ->
                                            ( definitions
                                            , "BreadCrumbs.after " ++ preExisitingVarName
                                            , BreadCrumbs.after preExisting
                                            )
                            in
                            ( ( defs
                                    ++ Code.newlines
                                    ++ (addStr
                                            :: Code.recordMultiline
                                                [ ( "id", Code.string crumb.id )
                                                , ( "text", Code.string crumb.text )
                                                , ( "route", Code.string crumb.route )
                                                ]
                                                2
                                            :: List.map Tuple.first crumb.attributes
                                            |> String.join ""
                                            |> Code.var crumb.varName 1
                                       )
                              , crumb.varName
                              )
                            , add { id = crumb.id, text = crumb.text, route = crumb.route }
                                (List.map Tuple.second crumb.attributes)
                            )
                                |> Just
                        )
                        Nothing

                primaryBreadCrumbs : Maybe ( ( String, String ), BreadCrumbs String )
                primaryBreadCrumbs =
                    createBreadCrumbs ( "BreadCrumbs.init", BreadCrumbs.init )
                        settings.breadCrumbs

                breadCrumbs : Maybe ( ( String, String ), BreadCrumbs String )
                breadCrumbs =
                    case ( primaryBreadCrumbs, settings.secondaryBreadCrumbs ) of
                        ( Just ( ( definitions, lastVar ), primary ), Just secondary ) ->
                            createBreadCrumbs
                                ( "BreadCrumbs.initSecondary " ++ lastVar
                                , BreadCrumbs.initSecondary primary
                                )
                                secondary
                                |> Maybe.map
                                    (Tuple.mapFirst
                                        (\( newDefs, newLastVar ) ->
                                            ( definitions ++ newDefs, newLastVar )
                                        )
                                    )

                        _ ->
                            primaryBreadCrumbs
            in
            [ ControlView.view
                { ellieLinkConfig = ellieLinkConfig
                , name = moduleName
                , version = version
                , update = UpdateControl
                , settings = state
                , mainType = Just "RootHtml.Html msg"
                , extraCode = [ "import Html.Styled.Attributes exposing (href)" ]
                , renderExample =
                    \body ->
                        Code.newlineWithIndent 1
                            ++ "toUnstyled view"
                            ++ Code.newlines
                            ++ body
                , toExampleCode =
                    \_ ->
                        [ { sectionName = moduleName ++ ".view"
                          , code =
                                Maybe.map (Tuple.first >> viewExampleCode settings.currentRoute) breadCrumbs
                                    |> Maybe.withDefault ""
                          }
                        , { sectionName = moduleName ++ ".viewSecondary"
                          , code =
                                Maybe.map (Tuple.first >> viewSecondaryExampleCode settings.currentRoute) breadCrumbs
                                    |> Maybe.withDefault ""
                          }
                        ]
                }
            , section [ css [ Css.margin2 (Css.px 20) Css.zero ] ]
                [ Heading.h2 [ Heading.plaintext "view Example" ]
                , viewJust (Tuple.second >> viewExample settings.currentRoute) breadCrumbs
                ]
            , section [ css [ Css.margin2 (Css.px 20) Css.zero ] ]
                [ Heading.h2 [ Heading.plaintext "viewSecondary Example" ]
                , viewJust (Tuple.second >> viewSecondaryExample settings.currentRoute) breadCrumbs
                ]
            , Table.view
                [ Table.string
                    { header = "Name"
                    , value = .name
                    , width = Css.pct 15
                    , cellStyles = always []
                    , sort = Nothing
                    }
                , Table.string
                    { header = "About"
                    , value = .about
                    , width = Css.px 200
                    , cellStyles = always []
                    , sort = Nothing
                    }
                , Table.string
                    { header = "Result"
                    , value = \{ result } -> Maybe.withDefault "" (Maybe.map (Tuple.second >> result) breadCrumbs)
                    , width = Css.px 50
                    , cellStyles = always []
                    , sort = Nothing
                    }
                ]
                [ { name = "headerId"
                  , about = "When changing routes in a SPA, moving focus to the heading of the new page orients screenreader users to the new location."
                  , result = BreadCrumbs.headerId
                  }
                , { name = "toPageTitle"
                  , about = "When changing routes in a SPA, the HTML title of the page should be updated to match the new route."
                  , result = BreadCrumbs.toPageTitle
                  }
                ]
            ]
    }


previewContainer : List (Html msg) -> Html msg
previewContainer =
    span
        [ css
            [ Css.displayFlex
            , Css.alignItems Css.center
            , Fonts.baseFont
            , Css.fontSize (Css.px 10)
            , Css.fontWeight (Css.int 600)
            , Css.color Colors.navy
            ]
        ]


previewText : String -> Html msg
previewText name =
    span [ css [ Css.margin (Css.px 2) ] ] [ text name ]


previewArrowRight : Html msg
previewArrowRight =
    UiIcon.arrowRight
        |> Svg.withColor Colors.gray75
        |> Svg.withHeight (Css.px 10)
        |> Svg.withWidth (Css.px 8)
        |> Svg.withCss [ Css.flexShrink Css.zero ]
        |> Svg.toHtml


viewExampleCode : String -> ( String, String ) -> String
viewExampleCode currentRoute ( crumbDefinitions, currentCrumb ) =
    crumbDefinitions
        ++ Code.newlines
        ++ (Code.var "view" 1 <|
                "BreadCrumbs.view"
                    ++ Code.recordMultiline
                        [ ( "aTagAttributes", "\\route -> [ href route ]" )
                        , ( "isCurrentRoute", "\\route -> route == " ++ Code.string currentRoute )
                        , ( "label", Code.string "breadcrumbs" )
                        ]
                        2
                    ++ Code.newlineWithIndent 2
                    ++ currentCrumb
           )


viewExample : String -> BreadCrumbs String -> Html msg
viewExample currentRoute breadCrumbs =
    BreadCrumbs.view
        { aTagAttributes = \route -> [ href route ]
        , isCurrentRoute = \route -> route == currentRoute
        , label = "breadcrumbs example"
        }
        breadCrumbs


viewSecondaryExampleCode : String -> ( String, String ) -> String
viewSecondaryExampleCode currentRoute ( crumbDefinitions, currentCrumb ) =
    crumbDefinitions
        ++ Code.newlines
        ++ (Code.var "viewSecondary" 1 <|
                "BreadCrumbs.view"
                    ++ Code.recordMultiline
                        [ ( "aTagAttributes", "\\route -> [ href route ]" )
                        , ( "isCurrentRoute", "\\route -> route == " ++ Code.string currentRoute )
                        , ( "label", Code.string "breadcrumbs" )
                        ]
                        2
                    ++ Code.newlineWithIndent 2
                    ++ currentCrumb
           )


viewSecondaryExample : String -> BreadCrumbs String -> Html msg
viewSecondaryExample currentRoute breadCrumbs =
    BreadCrumbs.viewSecondary
        { aTagAttributes = \route -> [ href route ]
        , isCurrentRoute = \route -> route == currentRoute
        , label = "secondary breadcrumbs example"
        }
        breadCrumbs


{-| -}
type Msg
    = UpdateControl (Control Settings)


update : Msg -> State -> ( State, Cmd Msg )
update msg state =
    case msg of
        UpdateControl control ->
            ( control, Cmd.none )


type alias Settings =
    { currentRoute : String
    , breadCrumbs : List BreadCrumbSetting
    , secondaryBreadCrumbs : Maybe (List BreadCrumbSetting)
    }


type alias BreadCrumbSetting =
    { varName : String
    , id : String
    , text : String
    , route : String
    , attributes : List ( String, BreadCrumbAttribute String )
    }


init : Control Settings
init =
    Control.record Settings
        |> Control.field "currentRoute" (Control.string "/breadcrumb-category-1")
        |> Control.field "primary" (controlBreadCrumbs_ "Category" 1)
        |> Control.field "secondary" (Control.maybe False (controlBreadCrumbs_ "SubCategory" 1))


controlBreadCrumbs_ : String -> Int -> Control (List BreadCrumbSetting)
controlBreadCrumbs_ name index =
    Control.record
        (\text attributes maybeNextBreadCrumbs ->
            { varName = String.toLower name ++ String.fromInt index
            , id = String.toLower name ++ "-breadcrumb-id-" ++ String.fromInt index
            , text = text
            , route = "/breadcrumb-" ++ String.toLower name ++ "-" ++ String.fromInt index
            , attributes = Maybe.withDefault [] attributes
            }
                :: Maybe.withDefault [] maybeNextBreadCrumbs
        )
        |> Control.field "text" (Control.string (name ++ " " ++ String.fromInt index))
        |> Control.field "optional attributes"
            (Control.maybe False
                (ControlExtra.list
                    |> CommonControls.customIcon
                        (CommonControls.choice "UiIcon"
                            [ ( "homeInCircle", UiIcon.homeInCircle )
                            , ( "home", UiIcon.home )
                            ]
                        )
                        moduleName
                        BreadCrumbs.icon
                    |> ControlExtra.optionalListItem "iconSize"
                        (Control.map
                            (\v ->
                                ( "BreadCrumbs.iconSize (Css.px " ++ String.fromFloat v ++ ")"
                                , BreadCrumbs.iconSize (Css.px v)
                                )
                            )
                            (ControlExtra.float 40)
                        )
                )
            )
        |> Control.field (String.toLower name ++ " " ++ String.fromInt (index + 1))
            (Control.maybe False
                (Control.lazy
                    (\() -> controlBreadCrumbs_ name (index + 1))
                )
            )