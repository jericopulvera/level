module File exposing (File, Data, init, request, receive, input, avatarInput)

import File.Types exposing (Data)
import Html exposing (Html, Attribute, label, text, button)
import Html.Attributes as Attributes exposing (type_, id, class)
import Html.Events exposing (on)
import Json.Decode as Decode
import Ports


-- TYPES


type File
    = File Data


type alias Data =
    File.Types.Data


init : Data -> File
init data =
    File data



-- PORTS


request : String -> Cmd msg
request nodeId =
    Ports.requestFile nodeId


receive : (Data -> msg) -> Sub msg
receive toMsg =
    Ports.receiveFile toMsg



-- HTML


input : String -> msg -> List (Attribute msg) -> Html msg
input name onChange attrs =
    let
        defaultAttrs =
            [ id name
            , type_ "file"
            , Attributes.name name
            , on "change" (Decode.succeed onChange)
            ]
    in
        Html.input (defaultAttrs ++ attrs) []


avatarInput : String -> Maybe String -> msg -> Html msg
avatarInput nodeId maybeSrc changeMsg =
    case maybeSrc of
        Just src ->
            label [ class "flex w-32 h-32 border rounded-full cursor-pointer" ]
                [ text "Upload an avatar"
                , input nodeId changeMsg [ class "invisible-file" ]
                ]

        Nothing ->
            label [ class "flex items-center text-center text-md leading-tight text-dusty-blue font-black w-32 h-32 border-2 rounded-full border-dashed cursor-pointer no-select" ]
                [ text "Upload an avatar..."
                , input nodeId changeMsg [ class "invisible-file" ]
                ]
