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


%% @doc
-module(nkactor_api).
-author('Carlos Gonzalez <carlosj.gf@gmail.com>').

-export([http_request/4]).
-export([get_actor_service/1]).
-export([api_request/2, get_api_groups/1, get_api_modules/3]).
-export([t1/1]).
-export_type([group/0, vsn/0]).

-include_lib("nkserver/include/nkserver.hrl").

%% ===================================================================
%% Types
%% ===================================================================

-type group() :: nkactor:group().
-type vsn() :: binary().

-type http_method() :: nkrest_http:method().
-type http_path() :: nkrest_http:path().
-type http_req() :: nkrest_http:req().
-type http_reply() :: nkrest_http:http_reply().


%% ===================================================================
%% Public
%% ===================================================================


%% @doc called when a new http request has been received
-spec http_request(nkserver:id(), http_method(), http_path(), http_req()) ->
    http_reply() |
    {redirect, Path::binary(), http_req()} |
    {cowboy_static, cowboy_static:opts()} |
    {cowboy_rest, Callback::module(), State::term()}.

http_request(SrvId, Method, Path, Req) ->
    ActorSrvId = nkactor_api:get_actor_service(SrvId),
    nkactor_api_http:request(SrvId, ActorSrvId, Method, Path, Req).


%% @doc
-spec api_request(nkserver:id(), nkactor_request:request()) ->
    nkactor_request:response().

api_request(SrvId, #{group:=Group}=ApiReq) ->
    ?CALL_SRV(SrvId, api_request, [SrvId, Group, ApiReq]).


%% @doc
-spec get_api_groups(nkserver:id()) ->
    #{group() => [vsn()]}.

get_api_groups(SrvId) ->
    ?CALL_SRV(SrvId, api_get_groups, [SrvId, #{}]).


%% @doc
-spec get_api_modules(nkserver:id(), group(), vsn()) ->
    {ok, [module()]} | {error, term()}.

get_api_modules(SrvId, Group, Vsn) ->
    ?CALL_SRV(SrvId, api_get_modules, [SrvId, Group, Vsn]).


%% @doc
-spec get_actor_service(nkserver:id()) ->
    nkserver:id().

get_actor_service(SrvId) ->
    nkserver:get_plugin_config(SrvId, nkactor_api, actor_service).


%% ===================================================================
%% Internal
%% ===================================================================



t1(Url) ->
    Url2 = list_to_binary(["http://127.0.0.1:9001/api", Url]),

    {ok, Code, _, B} = hackney:request(get, Url2, [], <<>>, [with_body]),
    {Code, nklib_json:decode(B)}.

