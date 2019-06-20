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

%% @doc Default plugin callbacks
-module(nkactor_api_callbacks).
-author('Carlos Gonzalez <carlosj.gf@gmail.com>').
-export([status/1]).
-export([api_get_groups/2, api_get_paths/2, api_get_modules/3, api_request/3]).

-include("nkactor_api.hrl").


%% ===================================================================
%% Status & Msgs  Callbacks
%% ===================================================================

%% @private
status(actor_deleted) -> {200, #{}};
status(actor_has_linked_actors) -> {422, #{}};
status(actor_is_not_activable) -> {422, #{}};
status(actor_not_found) -> {404, #{}};
status(actor_updated) -> {200, #{}};
status({actor_invalid, A}) -> {422, #{<<"actor">> => A}};
status({actor_invalid, Map}) when is_map(Map) -> {400, Map};
status({actor_not_found, A}) -> {404, #{<<"actor">> => A}};
status({actors_deleted, N}) -> {200, #{<<"deleted">>=>N}};
status({api_group_unknown, API}) -> {404, #{<<"group">>=>API}};
status({api_incompatible, A}) -> {422, #{<<"api">> => A}};
status({api_unknown, API}) -> {404, #{<<"api">>=>API}};
status(bad_request) -> {400, #{}};
status(conflict) -> {409, #{}};
status(content_type_invalid) -> {400, #{}};
status(data_value_invalid) -> {400, #{}};
status(domain_invalid) -> {404, #{}};
status({domain_is_disabled, D}) -> {422, #{<<"domain">> => D}};
status({domain_unknown, Domain}) -> {404, #{<<"domain">>=>Domain}};
status({field_invalid, Field}) -> {400, #{<<"field">>=>Field}};
status({field_missing, Field}) -> {400, #{<<"field">>=>Field}};
status({field_unknown, _}) -> {400, #{}};
status({kind_unknown, K}) -> {400, #{<<"kind">> => K}};
status(file_is_invalid) -> {400, #{}};
status(file_too_large) -> {400, #{}};
status(forbidden) -> {403, #{}};
status(gone) -> {410, #{}};
status(internal_error) -> {500, #{}};
status(linked_actor_unknown) -> {409, #{}};
status({linked_actor_unknown, Id}) -> {400, #{<<"link">>=>Id}};
status(method_not_allowed) -> {405, #{}};
status(not_found) -> {404, #{}};
status(nxdomain) -> {422, #{}};
status(ok) -> {200, #{}};
status({parameter_invalid, Param}) -> {400, #{<<"parameter">>=>Param}};
status({parameter_missing, Param}) -> {400, #{<<"parameter">>=>Param}};
status(password_invalid) -> {200, #{}};
status(password_valid) -> {200, #{}};
status(provider_class_unknown) -> {400, #{}};
status({provider_unknown, Name}) -> {400, #{<<"provider">>=>Name}};
status(redirect) -> {307, #{}};
status(request_body_invalid) -> {400, #{}};
status(resource_invalid) -> {404, #{}};
status({resource_invalid, Group, Path}) -> {404, #{<<"group">>=>Group, <<"resource">>=>Path}};
status({resource_invalid, Res}) -> {404, #{<<"resource">>=>Res}};
status({service_not_available, Srv}) -> {422, #{<<"service">>=>Srv}};
status(service_unavailable) -> {503, #{}};
status({syntax_error, Error}) -> {400, #{<<"error">>=>Error}};
status(storage_class_invalid) -> {422, #{}};
status(task_max_tries_reached) -> {422, #{}};
status(timeout) -> {504, #{}};
status(too_many_records) -> {422, #{}};
status(too_many_requests) -> {429, #{}};
status(ttl_missing) -> {400, #{}};
status(uid_not_allowed) -> {409, #{}};
status(unauthorized) -> {401, #{}};
status(uniqueness_violation) -> {409, #{}};
status(unprocessable) -> {422, #{}};
status(user_unknown) -> {404, #{}};
status({user_unknown, UserId}) -> {404, #{<<"user">> => UserId}};
status({updated_invalid_field, F}) -> {422, #{field=>F}};
status(utf8_error) -> {400, #{}};
status(verb_not_allowed) -> {405, #{}};
status(watch_stop) -> {200, #{}};
status(_) -> {500, #{}}.



%% ===================================================================
%% API Callbacks
%% ===================================================================


%% @doc Called when the list of base paths of the server is requested
-spec api_get_paths(nkservice:id(), [binary()]) ->
    [binary()].

api_get_paths(SrvId, Acc) ->
    nkactor_api_util:get_paths(SrvId, Acc).


%% @doc Called to add info about all supported APIs
%% Must be implemented by new APIs
-spec api_get_groups(nkserver:id(), #{nkactor_api:group() => [nkactor_api:vsn()]}) ->
    {continue, #{nkactor_api:group() => [nkactor_api:vsn()]}}.

api_get_groups(_SrvId, GroupsAcc) ->
    GroupsAcc.


%% @doc Called to add info about all supported APIs
-spec api_get_modules(nkservice:id(), nkactor_api:group(), nkactor_api:vsn()) ->
    {ok, [module()]} | {error, term()}.

api_get_modules(_SrvId, Group, ApiVsn) ->
    {error, {api_incompatible, <<Group/binary, $/, ApiVsn/binary>>}}.


%% @doc Called to process and incoming API
-spec api_request(nkservice:id(), nkactor_api:group(), nkactor_api:request()) ->
    nkactor_api:response().

api_request(_SrvId, Group, _ApiReq) ->
    {error, {api_unknown, Group}}.

