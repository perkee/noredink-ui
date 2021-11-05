module Main exposing (init, main)

import Accessibility.Styled as Html exposing (Html, img, text)
import Browser exposing (Document, UrlRequest(..))
import Browser.Dom
import Browser.Navigation exposing (Key)
import Category
import Css exposing (..)
import Css.Media exposing (withMedia)
import Dict exposing (Dict)
import Example exposing (Example)
import Examples
import Html as RootHtml
import Html.Attributes
import Html.Styled.Attributes as Attributes exposing (..)
import Html.Styled.Events as Events
import Nri.Ui.Colors.V1 as Colors
import Nri.Ui.CssVendorPrefix.V1 as VendorPrefixed
import Nri.Ui.Fonts.V1 as Fonts
import Nri.Ui.Heading.V2 as Heading
import Nri.Ui.MediaQuery.V1 exposing (mobile, notMobile)
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
    , moduleStates : Dict String (Example Examples.State Examples.Msg)
    , navigationKey : Key
    }


init : () -> Url -> Key -> ( Model, Cmd Msg )
init () url key =
    ( { route = Routes.fromLocation url
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
            ( { model | route = Routes.fromLocation route }, Cmd.none )

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

        mainContentHeader heading =
            Heading.h1
                [ Heading.customAttr (id "maincontent")
                , Heading.customAttr (tabindex -1)
                , Heading.css [ marginBottom (px 30) ]
                ]
                [ Html.text heading ]
    in
    Html.div
        [ css
            [ displayFlex
            , withMedia [ mobile ] [ flexDirection column, alignItems stretch ]
            , alignItems flexStart
            , minHeight (vh 100)
            ]
        ]
        [ navigation model.route
        , Html.main_ [ css [ flexGrow (int 1), sectionStyles ] ]
            (case model.route of
                Routes.Doodad doodad ->
                    case List.head (examples (\m -> m.name == doodad)) of
                        Just example ->
                            [ mainContentHeader ("Viewing " ++ doodad ++ " doodad only")
                            , Html.div [ id (String.replace "." "-" example.name) ]
                                [ Example.view example
                                    |> Html.map (UpdateModuleStates example.name)
                                ]
                            ]

                        Nothing ->
                            [ Html.text <| "Oops! We couldn't find " ++ doodad ]

                Routes.Category category ->
                    [ mainContentHeader (Category.forDisplay category)
                    , examples
                        (\doodad ->
                            Set.memberOf
                                (Set.fromList Category.sorter doodad.categories)
                                category
                        )
                        |> List.map
                            (\example ->
                                Example.preview example
                                    |> Html.map (UpdateModuleStates example.name)
                            )
                        |> Html.div [ id (Category.forId category) ]
                    ]

                Routes.All ->
                    [ mainContentHeader "All"
                    , examples (\_ -> True)
                        |> List.map
                            (\example ->
                                Example.preview example
                                    |> Html.map (UpdateModuleStates example.name)
                            )
                        |> Html.div []
                    ]
            )
        ]


navigation : Route -> Html Msg
navigation route =
    let
        isActive category =
            case route of
                Routes.Category routeCategory ->
                    category == routeCategory

                _ ->
                    False

        link active hash displayName =
            Html.a
                [ css
                    [ backgroundColor transparent
                    , borderStyle none
                    , textDecoration none
                    , if active then
                        color Colors.navy

                      else
                        color Colors.azure
                    , Fonts.baseFont
                    ]
                , Attributes.href hash
                ]
                [ Html.text displayName ]

        navLink category =
            link (isActive category)
                ("#/category/" ++ Debug.toString category)
                (Category.forDisplay category)

        toNavLi element =
            Html.li
                [ css
                    [ margin2 (px 10) zero
                    , listStyle none
                    , textDecoration none
                    ]
                ]
                [ element ]
    in
    Html.nav
        [ css
            [ backgroundColor Colors.gray96
            , withMedia [ notMobile ]
                [ VendorPrefixed.value "position" "sticky"
                , top (px 55)
                , flexShrink zero
                , borderRadius (px 8)
                , marginRight (px 40)
                , padding (px 20)
                , flexBasis (px 200)
                ]
            ]
        , attribute "aria-label" "Main Navigation"
        ]
        [ Html.button
            [ css
                [ backgroundColor transparent
                , borderStyle none
                , textDecoration none
                , color Colors.azure
                , Fonts.baseFont
                , Css.marginBottom (px 20)
                , Css.pseudoClass "not(:focus)"
                    [ Css.property "clip" "rect(1px, 1px, 1px, 1px)"
                    , Css.position Css.absolute
                    , Css.height (Css.px 1)
                    , Css.width (Css.px 1)
                    , Css.overflow Css.hidden
                    , Css.margin (Css.px -1)
                    , Css.padding Css.zero
                    , Css.border Css.zero
                    ]
                ]
            , Events.onClick SkipToMainContent
            , id "skip"
            ]
            [ Html.text "Skip to main content" ]
        , Heading.h4 [] [ Html.text "Categories" ]
        , (link (route == Routes.All) "#/" "All"
            :: List.map navLink Category.all
          )
            |> List.map toNavLi
            |> Html.ul
                [ css [ margin4 zero zero (px 40) zero, padding zero ]
                , id "categories"
                ]
        ]


sectionStyles : Css.Style
sectionStyles =
    Css.batch [ margin2 (px 40) zero ]
