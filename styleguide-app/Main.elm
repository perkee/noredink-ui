module Main exposing (init, main)

import Accessibility.Styled as Html exposing (Html)
import Browser exposing (Document, UrlRequest(..))
import Browser.Dom
import Browser.Navigation exposing (Key)
import Category exposing (Category)
import Css exposing (..)
import Css.Media exposing (withMedia)
import Dict exposing (Dict)
import Example exposing (Example)
import Examples
import Html.Attributes
import Html.Styled.Attributes as Attributes exposing (..)
import Html.Styled.Events as Events
import Nri.Ui.ClickableText.V3 as ClickableText
import Nri.Ui.Colors.V1 as Colors
import Nri.Ui.CssVendorPrefix.V1 as VendorPrefixed
import Nri.Ui.Data.PremiumLevel as PremiumLevel
import Nri.Ui.Fonts.V1 as Fonts
import Nri.Ui.Heading.V2 as Heading
import Nri.Ui.MediaQuery.V1 exposing (mobile, notMobile)
import Nri.Ui.Page.V3 as Page
import Nri.Ui.SideNav.V1 as SideNav
import Nri.Ui.UiIcon.V1 as UiIcon
import Routes as Routes exposing (Route(..))
import Sort.Set as Set exposing (Set)
import Task
import Url exposing (Url)


main : Program () Model Msg
main =
    Browser.application
        { init = init
        , update = update
        , subscriptions = subscriptions
        , view = view
        , onUrlRequest = OnUrlRequest
        , onUrlChange = OnUrlChange
        }


type alias Model =
    { -- Global UI
      route : Route
    , previousRoute : Maybe Route
    , moduleStates : Dict String (Example Examples.State Examples.Msg)
    , navigationKey : Key
    }


init : () -> Url -> Key -> ( Model, Cmd Msg )
init () url key =
    ( { route = Routes.fromLocation url
      , previousRoute = Nothing
      , moduleStates =
            Dict.fromList
                (List.map (\example -> ( example.name, example )) Examples.all)
      , navigationKey = key
      }
    , Cmd.none
    )


type Msg
    = UpdateModuleStates String Examples.Msg
    | OnUrlRequest Browser.UrlRequest
    | OnUrlChange Url
    | ChangeRoute Route
    | SkipToMainContent
    | NoOp


update : Msg -> Model -> ( Model, Cmd Msg )
update action model =
    case action of
        UpdateModuleStates key exampleMsg ->
            case Dict.get key model.moduleStates of
                Just example ->
                    example.update exampleMsg example.state
                        |> Tuple.mapFirst
                            (\newState ->
                                { model
                                    | moduleStates =
                                        Dict.insert key
                                            { example | state = newState }
                                            model.moduleStates
                                }
                            )
                        |> Tuple.mapSecond (Cmd.map (UpdateModuleStates key))

                Nothing ->
                    ( model, Cmd.none )

        OnUrlRequest request ->
            case request of
                Internal loc ->
                    ( model, Browser.Navigation.pushUrl model.navigationKey (Url.toString loc) )

                External loc ->
                    ( model, Browser.Navigation.load loc )

        OnUrlChange route ->
            ( { model
                | route = Routes.fromLocation route
                , previousRoute = Just model.route
              }
            , Cmd.none
            )

        ChangeRoute route ->
            ( model
            , Browser.Navigation.pushUrl model.navigationKey
                (Routes.toString route)
            )

        SkipToMainContent ->
            ( model
            , Task.attempt (\_ -> NoOp) (Browser.Dom.focus "maincontent")
            )

        NoOp ->
            ( model, Cmd.none )


subscriptions : Model -> Sub Msg
subscriptions model =
    Dict.values model.moduleStates
        |> List.map (\example -> Sub.map (UpdateModuleStates example.name) (example.subscriptions example.state))
        |> Sub.batch


view : Model -> Document Msg
view model =
    { title = "Style Guide"
    , body = [ view_ model |> Html.toUnstyled ]
    }


view_ : Model -> Html Msg
view_ model =
    let
        examples filterBy =
            List.filter (\m -> filterBy m) (Dict.values model.moduleStates)
    in
    case model.route of
        Routes.Doodad doodad ->
            case List.head (examples (\m -> m.name == doodad)) of
                Just example ->
                    Html.main_ []
                        [ Example.view model.previousRoute example
                            |> Html.map (UpdateModuleStates example.name)
                        ]

                Nothing ->
                    Page.notFound
                        { link = ChangeRoute Routes.All
                        , recoveryText = Page.ReturnTo "Component Library"
                        }

        Routes.Category category ->
            withSideNav model.route
                [ mainContentHeader (Category.forDisplay category)
                , examples
                    (\doodad ->
                        Set.memberOf
                            (Set.fromList Category.sorter doodad.categories)
                            category
                    )
                    |> viewPreviews (Category.forId category)
                ]

        Routes.All ->
            withSideNav model.route
                [ mainContentHeader "All"
                , viewPreviews "all" (examples (\_ -> True))
                ]


withSideNav : Route -> List (Html Msg) -> Html Msg
withSideNav currentRoute content =
    Html.div
        [ css
            [ displayFlex
            , withMedia [ mobile ] [ flexDirection column, alignItems stretch ]
            , alignItems flexStart
            ]
        ]
        [ navigation currentRoute
        , Html.main_
            [ css
                [ flexGrow (int 1)
                , margin2 (px 40) zero
                , Css.minHeight (Css.vh 100)
                ]
            ]
            content
        ]


mainContentHeader : String -> Html msg
mainContentHeader heading =
    Heading.h1
        [ Heading.customAttr (id "maincontent")
        , Heading.customAttr (tabindex -1)
        , Heading.css [ marginBottom (px 30) ]
        ]
        [ Html.text heading ]


viewPreviews : String -> List (Example state msg) -> Html Msg
viewPreviews containerId examples =
    examples
        |> List.map (\example -> Example.preview ChangeRoute example)
        |> Html.div
            [ id containerId
            , css
                [ Css.displayFlex
                , Css.flexWrap Css.wrap
                , Css.property "gap" "10px"
                ]
            ]


navigation : Route -> Html Msg
navigation currentRoute =
    let
        toNavLinkConfig : Category -> SideNav.EntryConfig Route Msg
        toNavLinkConfig category =
            { icon = Nothing
            , title = Category.forDisplay category
            , route = Routes.Category category
            , attributes = [ href (Routes.toString (Routes.Category category)) ]
            , children = []
            , premiumLevel = PremiumLevel.Free
            }

        navLinks : List (SideNav.Entry Route Msg)
        navLinks =
            SideNav.entry
                { icon = Nothing
                , title = "All"
                , route = Routes.All
                , attributes = [ href (Routes.toString Routes.All) ]
                , children = []
                , premiumLevel = PremiumLevel.Free
                }
                :: List.map (toNavLinkConfig >> SideNav.entry) Category.all
                ++ [ SideNav.entry
                        { icon = Nothing
                        , title = "Example of Locked Premium content"
                        , route = Routes.All
                        , attributes = [ href (Routes.toString Routes.All) ]
                        , children = []
                        , premiumLevel = PremiumLevel.PremiumWithWriting
                        }
                   , SideNav.entry
                        { icon = Just UiIcon.gear
                        , title = "Create your own"
                        , route = Routes.All
                        , attributes =
                            [ href (Routes.toString Routes.All)
                            , css SideNav.withBorderStyles
                            ]
                        , children = []
                        , premiumLevel = PremiumLevel.Free
                        }
                   ]
    in
    SideNav.view
        { userPremiumLevel = PremiumLevel.Free
        , isCurrentRoute = (==) currentRoute
        , onSkipNav = SkipToMainContent
        , css =
            [ withMedia [ notMobile ]
                [ VendorPrefixed.value "position" "sticky"
                , top (px 55)
                ]
            ]
        }
        navLinks
