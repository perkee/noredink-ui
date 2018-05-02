module Examples.Table exposing (Msg, State, example, init, update)

{- \
   @docs Msg, State, example, init, update
-}

import Html
import ModuleExample as ModuleExample exposing (Category(..), ModuleExample)
import Nri.Ui.Button.V2 as Button
import Nri.Ui.Table.V1 as Table


{-| -}
type Msg
    = NoOp


{-| -}
type alias State =
    ()


{-| -}
example : (Msg -> msg) -> State -> ModuleExample msg
example parentMessage state =
    { filename = "Nri/Table.elm"
    , category = Layout
    , content =
        let
            columns =
                [ Table.string
                    { header = "First Name"
                    , value = .firstName
                    , width = 125
                    }
                , Table.string
                    { header = "Last Name"
                    , value = .lastName
                    , width = 125
                    }
                , Table.custom
                    { header = Html.text "Actions"
                    , width = 150
                    , view =
                        \_ ->
                            Button.button
                                { size = Button.Small
                                , style = Button.Primary
                                , onClick = NoOp
                                , width = Nothing
                                }
                                { label = "Action"
                                , state = Button.Enabled
                                , icon = Nothing
                                }
                    }
                ]

            data =
                [ { firstName = "First1", lastName = "Last1" }
                , { firstName = "First2", lastName = "Last2" }
                , { firstName = "First3", lastName = "Last3" }
                , { firstName = "First4", lastName = "Last4" }
                , { firstName = "First5", lastName = "Last5" }
                ]
        in
        [ Table.keyframeStyles
        , Html.h4 [] [ Html.text "With header" ]
        , Table.view columns data
        , Html.h4 [] [ Html.text "Without header" ]
        , Table.viewWithoutHeader columns data
        , Html.h4 [] [ Html.text "Loading" ]
        , Table.viewLoading columns
        , Html.h4 [] [ Html.text "Loading without header" ]
        , Table.viewLoadingWithoutHeader columns
        ]
            |> List.map (Html.map parentMessage)
    }


{-| -}
init : State
init =
    ()


{-| -}
update : Msg -> State -> ( State, Cmd Msg )
update msg state =
    case msg of
        NoOp ->
            ( state, Cmd.none )