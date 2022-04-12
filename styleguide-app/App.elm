module App exposing (Effect(..), Model, Msg(..), init, perform, subscriptions, update, view)

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
import Html.Styled.Attributes exposing (..)
import Http
import Json.Decode as Decode
import Nri.Ui.CssVendorPrefix.V1 as VendorPrefixed
import Nri.Ui.Heading.V2 as Heading
import Nri.Ui.MediaQuery.V1 exposing (mobile)
import Nri.Ui.Page.V3 as Page
import Nri.Ui.SideNav.V3 as SideNav
import Nri.Ui.Sprite.V1 as Sprite
import Routes exposing (Route)
import Sort.Set as Set
import Task
import Url exposing (Url)


type alias Model key =
    { -- Global UI
      route : Route
    , previousRoute : Maybe Route
    , moduleStates : Dict String (Example Examples.State Examples.Msg)
    , navigationKey : key
    , elliePackageDependencies : Result Http.Error (Dict String String)
    }


init : () -> Url -> key -> ( Model key, Effect )
init () url key =
    ( { route = Routes.fromLocation url
      , previousRoute = Nothing
      , moduleStates =
            Dict.fromList
                (List.map (\example -> ( example.name, example )) Examples.all)
      , navigationKey = key
      , elliePackageDependencies = Ok Dict.empty
      }
    , Cmd.batch
        [ loadPackage
        , loadApplicationDependencies
        ]
        |> Command
    )


type Msg
    = UpdateModuleStates String Examples.Msg
    | OnUrlRequest Browser.UrlRequest
    | OnUrlChange Url
    | ChangeRoute Route
    | SkipToMainContent
    | LoadedPackages (Result Http.Error (Dict String String))
    | Focused (Result Browser.Dom.Error ())


update : Msg -> Model key -> ( Model key, Effect )
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
                        |> Tuple.mapSecond (Cmd.map (UpdateModuleStates key) >> Command)

                Nothing ->
                    ( model, None )

        OnUrlRequest request ->
            case request of
                Internal loc ->
                    ( model, GoToUrl loc )

                External loc ->
                    ( model, Load loc )

        OnUrlChange route ->
            ( { model
                | route = Routes.fromLocation route
                , previousRoute = Just model.route
              }
            , None
            )

        ChangeRoute route ->
            ( model
            , GoToRoute route
            )

        SkipToMainContent ->
            ( model
            , FocusOn "maincontent"
            )

        LoadedPackages newPackagesResult ->
            let
                -- Ellie gets really slow to compile if we include all the packages, unfortunately!
                -- feel free to adjust the settings here if you need more packages for a particular example.
                removedPackages =
                    [ "avh4/elm-debug-controls"
                    , "BrianHicks/elm-particle"
                    , "elm-community/random-extra"
                    , "elm/browser"
                    , "elm/http"
                    , "elm/json"
                    , "elm/parser"
                    , "elm/random"
                    , "elm/regex"
                    , "elm/svg"
                    , "elm/url"
                    , "elm-community/string-extra"
                    , "Gizra/elm-keyboard-event"
                    , "pablohirafuji/elm-markdown"
                    , "rtfeldman/elm-sorter-experiment"
                    , "tesk9/accessible-html-with-css"
                    , "tesk9/palette"
                    , "wernerdegroot/listzipper"
                    ]
            in
            ( { model
                | elliePackageDependencies =
                    List.foldl (\name -> Result.map (Dict.remove name))
                        (Result.map2 Dict.union model.elliePackageDependencies newPackagesResult)
                        removedPackages
              }
            , None
            )

        Focused _ ->
            ( model, None )


type Effect
    = GoToRoute Route
    | GoToUrl Url
    | Load String
    | FocusOn String
    | None
    | Command (Cmd Msg)


perform : Key -> Effect -> Cmd Msg
perform navigationKey effect =
    case effect of
        GoToRoute route ->
            Browser.Navigation.pushUrl navigationKey (Routes.toString route)

        GoToUrl url ->
            Browser.Navigation.pushUrl navigationKey (Url.toString url)

        Load loc ->
            Browser.Navigation.load loc

        FocusOn id ->
            Task.attempt Focused (Browser.Dom.focus id)

        None ->
            Cmd.none

        Command cmd ->
            cmd


subscriptions : Model key -> Sub Msg
subscriptions model =
    Dict.values model.moduleStates
        |> List.map (\example -> Sub.map (UpdateModuleStates example.name) (example.subscriptions example.state))
        |> Sub.batch


view : Model key -> Document Msg
view model =
    let
        findExampleByName name =
            Dict.values model.moduleStates
                |> List.filter (\m -> m.name == name)
                |> List.head

        toBody view_ =
            List.map Html.toUnstyled
                [ view_
                , Html.map never Sprite.attach
                ]
    in
    case model.route of
        Routes.Doodad doodad ->
            case findExampleByName doodad of
                Just example ->
                    { title = example.name ++ " in the NoRedInk Style Guide"
                    , body =
                        viewExample model example
                            |> Html.map (UpdateModuleStates example.name)
                            |> toBody
                    }

                Nothing ->
                    { title = "Not found in the NoRedInk Style Guide"
                    , body = toBody notFound
                    }

        Routes.Category category ->
            { title = Category.forDisplay category ++ " Category in the NoRedInk Style Guide"
            , body = toBody (viewCategory model category)
            }

        Routes.All ->
            { title = "NoRedInk Style Guide"
            , body = toBody (viewAll model)
            }


viewExample : Model key -> Example a msg -> Html msg
viewExample model example =
    Html.div [ css [ maxWidth (Css.px 1400), margin auto ] ]
        [ Example.view model.previousRoute
            { packageDependencies = model.elliePackageDependencies }
            example
        ]


notFound : Html Msg
notFound =
    Page.notFound
        { link = ChangeRoute Routes.All
        , recoveryText = Page.ReturnTo "Component Library"
        }


viewAll : Model key -> Html Msg
viewAll model =
    withSideNav model.route
        [ mainContentHeader "All"
        , viewPreviews "all" (Dict.values model.moduleStates)
        ]


viewCategory : Model key -> Category -> Html Msg
viewCategory model category =
    withSideNav model.route
        [ mainContentHeader (Category.forDisplay category)
        , model.moduleStates
            |> Dict.values
            |> List.filter
                (\doodad ->
                    Set.memberOf
                        (Set.fromList Category.sorter doodad.categories)
                        category
                )
            |> viewPreviews (Category.forId category)
        ]


withSideNav : Route -> List (Html Msg) -> Html Msg
withSideNav currentRoute content =
    Html.div
        [ css
            [ displayFlex
            , withMedia [ mobile ] [ flexDirection column, alignItems stretch ]
            , alignItems flexStart
            , maxWidth (Css.px 1400)
            , margin auto
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
        categoryNavLinks : List (SideNav.Entry Route Msg)
        categoryNavLinks =
            List.map
                (\category ->
                    SideNav.entry (Category.forDisplay category)
                        [ SideNav.href (Routes.Category category) ]
                )
                Category.all
    in
    SideNav.view
        { isCurrentRoute = (==) currentRoute
        , routeToString = Routes.toString
        , onSkipNav = SkipToMainContent
        }
        [ SideNav.navNotMobileCss
            [ VendorPrefixed.value "position" "sticky"
            , top (px 55)
            ]
        ]
        (SideNav.entry "All" [ SideNav.href Routes.All ]
            :: categoryNavLinks
        )


loadPackage : Cmd Msg
loadPackage =
    Http.get
        { url = "/package.json"
        , expect =
            Http.expectJson
                LoadedPackages
                (Decode.map2 Dict.singleton
                    (Decode.field "name" Decode.string)
                    (Decode.field "version" Decode.string)
                )
        }


loadApplicationDependencies : Cmd Msg
loadApplicationDependencies =
    Http.get
        { url = "/application.json"
        , expect =
            Http.expectJson
                LoadedPackages
                (Decode.at [ "dependencies", "direct" ] (Decode.dict Decode.string))
        }
