module Component.Mention
    exposing
        ( Model
        , Msg(..)
        , fragment
        , decoder
        , setup
        , teardown
        , update
        , handleReplyCreated
        , view
        )

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Component.Post
import Connection exposing (Connection)
import Data.Mention as Mention exposing (Mention)
import Data.Post as Post exposing (Post)
import Data.Reply as Reply exposing (Reply)
import Data.SpaceUser as SpaceUser exposing (SpaceUser)
import Date exposing (Date)
import GraphQL exposing (Fragment)
import Icons
import Json.Decode as Decode exposing (Decoder, field, string)
import ListHelpers
import Mutation.DismissMentions as DismissMentions
import Repo exposing (Repo)
import Route
import Session exposing (Session)
import Task
import View.Helpers exposing (displayName, smartFormatDate)


-- MODEL


type alias Model =
    { id : String
    , post : Component.Post.Model
    , mentions : List Mention
    }


fragment : Fragment
fragment =
    GraphQL.fragment
        """
        fragment MentionedPostFields on Post {
          ...PostFields
          replies(last: 3) {
            ...ReplyConnectionFields
          }
          mentions {
            ...MentionFields
          }
        }
        """
        [ Post.fragment
        , Connection.fragment "ReplyConnection" Reply.fragment
        , Mention.fragment
        ]


decoder : Decoder Model
decoder =
    Decode.map3 Model
        (field "id" string)
        (Component.Post.decoder Component.Post.Feed True)
        (field "mentions" (Decode.list Mention.decoder))



-- LIFECYCLE


setup : Model -> Cmd Msg
setup model =
    Component.Post.setup model.post
        |> Cmd.map PostComponentMsg


teardown : Model -> Cmd Msg
teardown model =
    Component.Post.teardown model.post
        |> Cmd.map PostComponentMsg



-- UPDATE


type Msg
    = PostComponentMsg Component.Post.Msg
    | DismissClicked String
    | Dismissed String (Result Session.Error ( Session, DismissMentions.Response ))


update : Msg -> String -> Session -> Model -> ( ( Model, Cmd Msg ), Session )
update msg spaceId session model =
    case msg of
        PostComponentMsg msg ->
            let
                ( ( newPost, cmd ), newSession ) =
                    Component.Post.update msg spaceId session model.post
            in
                ( ( { model | post = newPost }
                  , Cmd.map PostComponentMsg cmd
                  )
                , newSession
                )

        DismissClicked id ->
            let
                cmd =
                    session
                        |> DismissMentions.request spaceId id
                        |> Task.attempt (Dismissed id)
            in
                ( ( model, cmd ), session )

        Dismissed id (Ok ( session, _ )) ->
            -- TODO
            ( ( model, Cmd.none ), session )

        Dismissed _ (Err Session.Expired) ->
            redirectToLogin session model

        Dismissed _ (Err _) ->
            ( ( model, Cmd.none ), session )


redirectToLogin : Session -> Model -> ( ( Model, Cmd Msg ), Session )
redirectToLogin session model =
    ( ( model, Route.toLogin ), session )



-- EVENT HANDLERS


handleReplyCreated : Reply -> Model -> ( Model, Cmd Msg )
handleReplyCreated reply model =
    let
        ( newPost, cmd ) =
            Component.Post.handleReplyCreated reply model.post
    in
        ( { model | post = newPost }
        , Cmd.map PostComponentMsg cmd
        )



-- VIEW


view : Repo -> SpaceUser -> Date -> Model -> Html Msg
view repo currentUser now { post, mentions } =
    div [ class "flex py-4" ]
        [ div [ class "flex-0 pr-3" ]
            [ button
                [ class "flex items-center"
                , onClick (DismissClicked post.id)
                , rel "tooltip"
                , title "Dismiss"
                ]
                [ Icons.open ]
            ]
        , div [ class "flex-1" ]
            [ div [ class "mb-6" ]
                [ a [ Route.href (Route.Post post.id), class "text-base font-bold no-underline text-dusty-blue-darker" ]
                    [ text <| mentionersSummary repo (mentioners mentions) ]
                , span [ class "mx-3 text-sm text-dusty-blue" ]
                    [ text <| smartFormatDate now (lastOccurredAt now mentions) ]
                ]
            , postView repo currentUser now post
            ]
        ]


mentioners : List Mention -> List SpaceUser
mentioners mentions =
    mentions
        |> List.map (Mention.getCachedData)
        |> List.map .mentioner


lastOccurredAt : Date -> List Mention -> Date
lastOccurredAt now mentions =
    mentions
        |> List.map (Mention.getCachedData)
        |> List.map .occurredAt
        |> List.map Date.toTime
        |> List.maximum
        |> Maybe.withDefault (Date.toTime now)
        |> Date.fromTime


postView : Repo -> SpaceUser -> Date -> Component.Post.Model -> Html Msg
postView repo currentUser now postComponent =
    postComponent
        |> Component.Post.view repo currentUser now
        |> Html.map PostComponentMsg


mentionersSummary : Repo -> List SpaceUser -> String
mentionersSummary repo mentioners =
    case mentioners of
        firstUser :: others ->
            let
                firstUserName =
                    firstUser
                        |> Repo.getSpaceUser repo
                        |> displayName

                otherCount =
                    ListHelpers.size others
            in
                case otherCount of
                    0 ->
                        firstUserName ++ " mentioned you"

                    1 ->
                        firstUserName ++ " and 1 other person mentioned you"

                    _ ->
                        firstUserName ++ " and " ++ (toString otherCount) ++ " others mentioned you"

        [] ->
            ""
