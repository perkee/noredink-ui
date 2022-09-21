module Examples.RingGauge exposing (Msg, State, example)

{-|

@docs Msg, State, example

-}

import Category exposing (Category(..))
import Code
import CommonControls
import Css
import Debug.Control as Control exposing (Control)
import Debug.Control.Extra as ControlExtra
import Debug.Control.View as ControlView
import Example exposing (Example)
import Examples.IconExamples as IconExamples
import Nri.Ui.Colors.Extra exposing (fromCssColor)
import Nri.Ui.Colors.V1 as Colors
import Nri.Ui.Heading.V3 as Heading
import Nri.Ui.RingGauge.V1 as RingGauge
import Nri.Ui.Svg.V1 as Svg
import Nri.Ui.Table.V6 as Table
import Round
import SolidColor.Accessibility


moduleName : String
moduleName =
    "RingGauge"


version : Int
version =
    1


{-| -}
example : Example State Msg
example =
    { name = moduleName
    , version = version
    , state = controlSettings
    , update = update
    , subscriptions = \_ -> Sub.none
    , categories = [ Progress, Icons ]
    , keyboardSupport = []
    , preview =
        [ 25, 50, 75, 99 ]
            |> List.map
                (\percentage ->
                    RingGauge.view
                        { backgroundColor = Colors.gray96
                        , emptyColor = Colors.gray96
                        , filledColor = Colors.gray45
                        , percentage = percentage
                        }
                )
            |> IconExamples.preview
    , view =
        \ellieLinkConfig state ->
            let
                settings =
                    Control.currentValue state
            in
            [ ControlView.view
                { ellieLinkConfig = ellieLinkConfig
                , name = moduleName
                , version = version
                , update = UpdateControl
                , settings = state
                , mainType = Just "RootHtml.Html msg"
                , extraCode = [ "import Nri.Ui.Colors.V1 as Colors" ]
                , renderExample = Code.unstyledView
                , toExampleCode =
                    \_ ->
                        [ { sectionName = "Example"
                          , code =
                                "RingGauge.view"
                                    ++ Code.record
                                        [ ( "backgroundColor", Tuple.first settings.backgroundColor )
                                        , ( "emptyColor", Tuple.first settings.emptyColor )
                                        , ( "filledColor", Tuple.first settings.filledColor )
                                        , ( "percentage", String.fromFloat settings.percentage )
                                        ]
                                    ++ ([ Code.newlineWithIndent 1
                                        , "|> Svg.withWidth (Css.px 200)"
                                        , "|> Svg.withHeight (Css.px 200)"
                                        , "|> Svg.toHtml"
                                        ]
                                            |> String.join (Code.newlineWithIndent 1)
                                       )
                          }
                        ]
                }
            , Heading.h2 [ Heading.plaintext "Example" ]
            , RingGauge.view
                { backgroundColor = Tuple.second settings.backgroundColor
                , emptyColor = Tuple.second settings.emptyColor
                , filledColor = Tuple.second settings.filledColor
                , percentage = settings.percentage
                }
                |> Svg.withWidth (Css.px 200)
                |> Svg.withHeight (Css.px 200)
                |> Svg.toHtml
            , Table.view
                [ Table.string
                    { header = "Color contrast against"
                    , value = .name
                    , width = Css.px 50
                    , cellStyles = always []
                    , sort = Nothing
                    }
                , Table.string
                    { header = "backgroundColor"
                    , value = .value >> contrast settings.backgroundColor >> Round.floor 2
                    , width = Css.px 50
                    , cellStyles = always []
                    , sort = Nothing
                    }
                , Table.string
                    { header = "emptyColor"
                    , value = .value >> contrast settings.emptyColor >> Round.floor 2
                    , width = Css.px 50
                    , cellStyles = always []
                    , sort = Nothing
                    }
                , Table.string
                    { header = "filledColor"
                    , value = .value >> contrast settings.filledColor >> Round.floor 2
                    , width = Css.px 50
                    , cellStyles = always []
                    , sort = Nothing
                    }
                ]
                [ { name = "backgroundColor", value = settings.backgroundColor }
                , { name = "emptyColor", value = settings.emptyColor }
                , { name = "filledColor", value = settings.filledColor }
                ]
            ]
    }


contrast : ( a, Css.Color ) -> ( a, Css.Color ) -> Float
contrast ( _, a ) ( _, b ) =
    SolidColor.Accessibility.contrast (fromCssColor a) (fromCssColor b)


{-| -}
type Msg
    = UpdateControl (Control Settings)


update : Msg -> State -> ( State, Cmd msg )
update msg state =
    case msg of
        UpdateControl control ->
            ( control, Cmd.none )


{-| -}
type alias State =
    Control Settings


type alias Settings =
    { backgroundColor : ( String, Css.Color )
    , emptyColor : ( String, Css.Color )
    , filledColor : ( String, Css.Color )
    , percentage : Float
    }


controlSettings : Control Settings
controlSettings =
    Control.record Settings
        |> Control.field "backgroundColor" CommonControls.color
        |> Control.field "emptyColor" CommonControls.color
        |> Control.field "filledColor" CommonControls.color
        |> Control.field "percentage" (ControlExtra.float 15)