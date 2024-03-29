%% -------------------------------------------------------------------
%%
%% Copyright (c) 2019 Carlos Gonzalez Florido.  All Rights Reserved.
%%
%% This file is provided to you under the Apache License,
%% Version 2.0 (the "License"); you may not use this file
%% except in compliance with the License.  You may obtain
%% a copy of the License at
%%
%%   http://www.apache.org/licenses/LICENSE-2.0
%%
%% Unless required by applicable law or agreed to in writing,
%% software distributed under the License is distributed on an
%% "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
%% KIND, either express or implied.  See the License for the
%% specific language governing permissions and limitations
%% under the License.
%%
%% -------------------------------------------------------------------

%% @doc NkDomain library for nkdomain_callbacks
-module(nkactor_api_util).
-author('Carlos Gonzalez <carlosj.gf@gmail.com>').
-export([get_paths/2, get_api_resources/2]).
-export([core_api_event/2, launch_auto_activated/1, get_auto_activated/1]).

-include_lib("nkserver/include/nkserver.hrl").
-include_lib("nkactor/include/nkactor.hrl").

-define(LLOG(Type, Txt, Args), lager:Type("NkDOMAIN LIB: "++Txt, Args)).


%% ===================================================================
%% Types
%% ===================================================================




%% ===================================================================
%% Public
%% ===================================================================




%% ===================================================================
%% Callback support
%% ===================================================================


%% @private
get_paths(SrvId, Acc) ->
    [
        <<"/apis">>,
        <<"/apis-ws">>,
        <<"/openapi">>,
        <<"/graphql">>,
        get_api_paths(SrvId),
        Acc
    ].


%% @private
get_api_paths(SrvId) ->
    lists:foldl(
        fun(Map, Acc) ->
            case Map of
                #{<<"versions">>:=Versions} ->
                    GV1 = [<<"/apis/", V/binary>> || #{<<"groupVersion">>:=V} <- Versions],
                    GV2 = [nkactor_api_lib:remove_vsn(G) || G <-GV1],
                    Acc++GV1++GV2;
                _ ->
                    Acc
            end
        end,
        [],
        nkactor_api_lib:api_groups(SrvId)).



%% @private
get_api_resources(SrvId, Modules) ->
    lists:map(
        fun(Module) ->
            Config = nkactor_actor:get_config(SrvId, Module),
            #{
                resource := Resource,
                singular := Singular,
                camel := Kind,
                verbs := Verbs,
                short_names := ShortNames
            } = Config,
            #{
                <<"name">> => Resource,
                <<"singularName">> => Singular,
                <<"kind">> => Kind,
                <<"verbs">> => Verbs,
                <<"shortNames">> => ShortNames
            }
        end,
        Modules).


%% @doc
core_api_event(Event, #actor_st{srv=SrvId, actor=Actor}=ActorSt) ->
    Reason = case Event of
        created ->
            <<"ActorCreated">>;
        {updated, _UpdActor} ->
            <<"ActorUpdated">>;
        deleted ->
            <<"ActorDeleted">>
    end,
    Body = case Event of
        deleted ->
            #{};
        _ ->
            case nkdomain_api:actor_to_external(SrvId, Actor) of
                {ok, ApiActor} ->
                    #{<<"actor">> => ApiActor};
                {error, _} ->
                    #{}
            end
    end,
    ApiEvent = #{reason => Reason, body => Body},
    nkdomain_actor_util:api_event(ApiEvent, ActorSt).


%% @doc Perform an activation of objects in database belonging to actors
%% having auto_activate=true and not yet activated
%% Actors that are expired will be deleted on activation
%% Size must be big enough so that last record has a newer date than first record
%% (so it cannot be 1)
-spec launch_auto_activated(nkservice:id()) ->
    [#actor_id{}].

launch_auto_activated(SrvId) ->
    ClassTypes = get_auto_activated(SrvId),
    OrSpec = [#{field=><<"group+resource">>, value=>ClassType} || ClassType <- ClassTypes],
    launch_auto_activated(SrvId, <<>>, 5, OrSpec, []).


%% @private
launch_auto_activated(SrvId, From, Size, OrSpec, Acc) ->
    Spec = #{
        deep => true,
        totals => false,
        filter => #{
            'or' => OrSpec,
            'and' => [#{field=><<"metadata.update_time">>, op=>gte, value=>From}]
        },
        sort => [#{field=><<"metadata.update_time">>, order=>asc}],
        size => Size
    },
    case nkactor:search_actors(SrvId, Spec) of
        {ok, Actors, #{last_updated:=Last}} ->
            Acc2 = activate_actors(SrvId, Actors, Acc),
            case length(Actors) >= Size of
                true when Last > From ->
                    launch_auto_activated(SrvId, Last, Size, OrSpec, Acc2);
                true ->
                    ?LLOG(warning, "too many records for auto activation: ~p", [From]),
                    {error, too_many_records};
                false ->
                    Acc2
            end;
        {error, Error} ->
            {error, Error}
    end.


%% @private
activate_actors(_SrvId, [], Acc) ->
    Acc;

activate_actors(SrvId, [Actor|Rest], Acc) ->
    #{group:=Group, resource:=Res, name:=Name, namespace:=Namespace} = Actor,
    Acc2 = case lists:member(Actor, Acc) of
        true ->
            % lager:error("NKLOG SKIPPING:~p", [Name]),
            Acc;
        false ->
            ActorId = #actor_id{group=Group, resource=Res, name=Name, namespace=Namespace},
            case nkactor_namespace:find_registered_actor(ActorId) of
                {true, _, _} ->
                    ?LLOG(debug, "actor ~s/~s/~s/~s already activated",
                          [SrvId, Group, Res, Name]),
                    Acc;
                false ->
                    case nkactor:activate(ActorId) of
                        {ok, _} ->
                            ?LLOG(notice, "activated actor ~s/~s/~s/~s",
                                  [SrvId, Group, Res, Name]);
                        {error, Error} ->
                            ?LLOG(warning, "could not activate actor ~s/~s/~s/~s: ~p",
                                  [SrvId, Group, Res, Name, Error])
                    end,
                    [ActorId|Acc]
            end
    end,
    activate_actors(SrvId, Rest, Acc2).



%% @private
-spec get_auto_activated(nkservice:id()) ->
    [binary()].

get_auto_activated(SrvId) ->
    lists:foldl(
        fun(Group, Acc1) ->
            lists:foldl(
                fun(Type, Acc2) ->
                    case nkdomain_actor_util:get_config(SrvId, Group, Type) of
                        {ok, #{auto_activate:=true}} ->
                            [<<Group/binary, $+, Type/binary>>|Acc2];
                        _ ->
                            Acc2
                    end
                end,
                Acc1,
                nkdomain_plugin:get_resources(SrvId, Group))
        end,
        [],
        nkdomain_plugin:get_groups(SrvId)).





%%%% @private
%%to_bin(Term) when is_binary(Term) -> Term;
%%to_bin(Term) -> nklib_util:to_binary(Term).