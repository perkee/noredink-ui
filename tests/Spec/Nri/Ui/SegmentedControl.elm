module Spec.Nri.Ui.SegmentedControl exposing (..)

import Expect
import Html.Attributes as Attributes
import Html.Styled
import Json.Encode as Encode
import Nri.Ui.SegmentedControl.V11 as SegmentedControl
import Test exposing (..)
import Test.Html.Query as Query
import Test.Html.Selector as Selector


spec : Test
spec =
    describe "segmented controls"
        [ describe "radio groups indicate when they're selected" <|
            -- nb. this is tested especially since QA is including this
            -- attribute in their automated tests. Make sure it doesn't break
            -- them!
            let
                selected =
                    "I'm Selected!"

                notSelected =
                    "I'm Not Selected!"

                control =
                    SegmentedControl.viewRadioGroup
                        { onSelect = identity
                        , toString = identity
                        , options =
                            List.map
                                (\value ->
                                    { value = value
                                    , label = value
                                    , attributes = []
                                    , icon = Nothing
                                    }
                                )
                                [ selected, notSelected ]
                        , selected = Just selected
                        , width = SegmentedControl.FitContent
                        , legend = "A Segmented Control Example"
                        }
            in
            [ test "a checked=true attribute is added to the selected control" <|
                \_ ->
                    Html.Styled.toUnstyled control
                        |> Query.fromHtml
                        |> Query.has
                            [ Selector.all
                                [ Selector.tag "label"
                                , Selector.containing [ Selector.text selected ]
                                , Selector.containing
                                    [ Selector.tag "input"
                                    , Selector.attribute (Attributes.type_ "radio")
                                    , Selector.attribute (Attributes.attribute "data-nri-checked" "true")
                                    ]
                                ]
                            ]
            , test "a checked=false attribute is added to a non-selected control" <|
                \_ ->
                    Html.Styled.toUnstyled control
                        |> Query.fromHtml
                        |> Query.has
                            [ Selector.all
                                [ Selector.tag "label"
                                , Selector.containing [ Selector.text notSelected ]
                                , Selector.containing
                                    [ Selector.tag "input"
                                    , Selector.attribute (Attributes.type_ "radio")
                                    , Selector.attribute (Attributes.attribute "data-nri-checked" "false")
                                    ]
                                ]
                            ]
            ]
        ]
