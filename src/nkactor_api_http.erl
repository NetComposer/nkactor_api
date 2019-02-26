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

%% @doc NkACTOR HTTP API processing
-module(nkactor_api_http).
-author('Carlos Gonzalez <carlosj.gf@gmail.com>').

-export([request/5]).
%-export([event_stream_start/1, event_stream_heartbeat/1, event_stream_stop/2, new_event/2]).
% -behavior(nkactor_api_watch).


-define(MAX_BODY_SIZE, 1000000).
-define(MAX_UPLOAD_SIZE, 100000000).

-include("nkactor_api.hrl").
-include_lib("nkserver/include/nkserver.hrl").

%% ===================================================================
%% REST API Invocation
%% ===================================================================


%% @private
request(SrvId, ActorSrvId, Verb, Path, Req) ->
    set_debug(SrvId),
    lager:error("NKLOG PATH ~p", [Path]),
    try do_rest_api(SrvId, ActorSrvId, Verb, Path, Req) of
        ok ->
            rest_api_reply(200, #{}, Req);
        {ok, Map} when is_map(Map) ->
            rest_api_reply(200, Map, Req);
        {ok, _, #{meta:=#{nkdomain_http_stream:=true, nkrest_req:=HttpReq}}} ->
            {stop, HttpReq};
        {ok, Reply, #{meta:=#{nkrest_req:=HttpReq}}} ->
            rest_api_reply(200, Reply, HttpReq);
        created ->
            rest_api_reply(201, #{}, Req);
        {created, Reply} when is_map(Reply) ->
            rest_api_reply(201, Reply, Req);
        {created, Reply, #{meta:=#{nkrest_req:=HttpReq}}} when is_map(Reply) ->
            rest_api_reply(201, Reply, HttpReq);
        {status, Status} ->
            #{<<"code">>:=Code} = Status = nkactor_api_lib:status(SrvId, Status),
            rest_api_reply(Code, Status, Req);
        {status, Status, Meta} when is_map(Meta) ->
            #{<<"code">>:=Code} = Status = nkactor_api_lib:status(SrvId, Status, Meta),
            rest_api_reply(Code, Status, Req);
        {status, Status, Meta, #{meta:=#{nkrest_req:=HttpReq}}} when is_map(Meta) ->
            #{<<"code">>:=Code} = Status = nkactor_api_lib:status(SrvId, Status, Meta),
            rest_api_reply(Code, Status, HttpReq);
        {error, Error} ->
            #{<<"code">>:=Code} = Status = nkactor_api_lib:status(SrvId, Error),
            rest_api_reply(Code, Status, Req);
        {error, _, #{meta:=#{nkdomain_http_stream:=true, nkrest_req:=HttpReq}}} ->
            {stop, HttpReq};
        {error, #{<<"code">>:=Code}=Status, #{meta:=#{nkrest_req:=HttpReq}}} ->
            rest_api_reply(Code, Status, HttpReq);
        {error, Msg, #{meta:=#{nkrest_req:=HttpReq}}} ->
            #{<<"code">>:=Code} = Status = nkactor_api_lib:status(SrvId, Msg),
            rest_api_reply(Code, Status, HttpReq);
        {raw, {CT, Bin}, #{meta:=#{nkrest_req:=HttpReq}}} ->
            Hds = #{
                <<"Content-Type">> => CT,
                <<"Server">> => <<"NetComposer">>
            },
            {http, 200, Hds, Bin, HttpReq};
        {http, Code, Hds, Body, HttpReq} ->
            {http, Code, Hds, Body, HttpReq}
    catch
        throw:{error, Error} ->
            #{<<"code">>:=Code} = Status = nkactor_api_lib:status(SrvId, Error),
            rest_api_reply(Code, Status, Req)
    end.


%% ===================================================================
%% Callbacks
%% ===================================================================

%%
%%%% @doc
%%event_stream_start(#{meta:=#{nkrest_req:=Req}=Meta}=ApiReq) ->
%%    Hds = #{
%%        <<"Content-Type">> => <<"application/json">>,
%%        <<"Server">> => <<"NetComposer">>
%%    },
%%    Req2 = nkrest_http:stream_start(200, Hds, Req),
%%    Meta2 = Meta#{
%%        nkdomain_http_stream => true,
%%        nkrest_req := Req2
%%    },
%%    {ok, ApiReq#{meta:=Meta2}}.
%%
%%
%%%% @doc
%%event_stream_stop(_Reason, #{meta:=#{nkrest_req:=Req}}=ApiReq) ->
%%    lager:error("NKLOG EVENT STREAM STOP"),
%%    nkrest_http:stream_stop(Req),
%%    {ok, ApiReq}.
%%
%%
%%%% @doc
%%event_stream_heartbeat(#{meta:=#{nkrest_req:=Req}}=ApiReq) ->
%%    lager:error("NKLOG EVENT STREAM HEARTBEAT"),
%%    ok = nkrest_http:stream_body(<<"\r\n">>, Req),
%%    {ok, ApiReq}.
%%
%%
%%%% @doc
%%new_event(Event, #{meta:=#{nkrest_req:=Req}}=ApiReq) ->
%%    Body = nklib_json:encode(Event),
%%    nkrest_http:stream_body(Body, Req),
%%    {ok, ApiReq}.


%% ===================================================================
%% Internal
%% ===================================================================


%% @doc
set_debug(SrvId) ->
    Debug = nkserver:get_plugin_config(SrvId, nkactor_api, debug)==true,
    put(nkactor_api_debug, Debug),
    ?API_DEBUG("HTTP debug started", []).


%% @private
rest_api_reply(Code, Body, Req) ->
    Hds = #{
        <<"Content-Type">> => <<"application/json">>,
        <<"Server">> => <<"NetComposer">>
    },
    Body2 = nklib_json:encode_sorted(Body),
    {http, Code, Hds, Body2, Req}.



%% @private
% /
do_rest_api(SrvId, _ActorSrvId, <<"GET">>, [], _Req) ->
    Paths1 = ?CALL_SRV(SrvId, api_get_paths, [SrvId, []]),
    Paths2 = lists:usort(lists:flatten(Paths1)),
    {ok, #{<<"paths">>=>Paths2}};

do_rest_api(SrvId, ActorSrvId, <<"GET">>, [<<>>], _Req) ->
    do_rest_api(SrvId, ActorSrvId, <<"GET">>, [], _Req);

do_rest_api(_SrvId, _ActorSrvId, <<"GET">>, [<<"favicon.ico">>], _Req) ->
    {error, {resource_invalid, <<"favicon.ico">>}};


% /apis
do_rest_api(SrvId, _ActorSrvId, <<"GET">>, [<<"apis">>], _Req) ->
    {ok, nkactor_api_lib:api_group_list(SrvId)};

do_rest_api(SrvId, ActorSrvId, <<"GET">>, [<<"apis">>, <<>>], Req) ->
    do_rest_api(SrvId, ActorSrvId, <<"GET">>, [<<"apis">>], Req);


% /apis/Api
do_rest_api(SrvId, _ActorSrvId, <<"GET">>, [<<"apis">>, Group], _Req) ->
    Groups = nkactor_api_lib:api_groups(SrvId),
    case [Info || #{<<"name">>:=N}=Info <-Groups, N==Group] of
        [Info] ->
            {ok, Info};
        _ ->
            {error, {api_group_unknown, Group}}
    end;


% /apis/Api/Vsn
do_rest_api(SrvId, ActorSrvId, <<"GET">>, [<<"apis">>, Group, Vsn], _Req) ->
    case nkactor_api:get_api_modules(SrvId, Group, Vsn) of
        {ok, Modules} ->
            lager:error("NKLOG NOD1"),
            Resources = nkactor_api_util:get_api_resources(ActorSrvId, Modules),
            ApiVsn = <<Group/binary, $/, Vsn/binary>>,
            lager:error("NKLOG NOD2"),
            {ok, nkactor_api_lib:api_resources_list(ApiVsn, Resources)};
        {error, Error} ->
            {error, Error}
    end;

do_rest_api(SrvId, ActorSrvId, <<"GET">>, [<<"apis">>, Group, Vsn, <<>>], Req) ->
    do_rest_api(SrvId, ActorSrvId, <<"GET">>, [<<"apis">>, Group, Vsn], Req);


% /apis/core/v1/namespaces
do_rest_api(SrvId, ActorSrvId, Verb, [<<"apis">>, Group, Vsn, <<"namespaces">>], Req) ->
    Namespace = nkactor:base_namespace(ActorSrvId),
    do_rest_api(SrvId, ActorSrvId, Verb, [<<"apis">>, Group, Vsn, <<"namespaces">>, Namespace, <<"namespaces">>], Req);

% /apis/core/v1/namespaces/Namespace
do_rest_api(SrvId, ActorSrvId, Verb, [<<"apis">>, Group, Vsn, <<"namespaces">>, Name], Req) ->
    Namespace = nkactor:base_namespace(ActorSrvId),
    do_rest_api(SrvId, ActorSrvId, Verb, [<<"apis">>, Group, Vsn, <<"namespaces">>, Namespace, <<"namespaces">>, Name], Req);

% /apis/core/v1/namespaces/Namespace/ResType
do_rest_api(SrvId, ActorSrvId, Verb, [<<"apis">>, Group, Vsn, <<"namespaces">>, Namespace, ResType], Req) ->
    launch_rest_api(SrvId, ActorSrvId, Verb, #{group=>Group, vsn=>Vsn, namespace=>Namespace, resource=>ResType}, Req);

% /apis/core/v1/namespaces/Namespace/ResType/_upload
do_rest_api(SrvId, ActorSrvId, Verb, [<<"apis">>, Group, Vsn, <<"namespaces">>, Namespace, ResType, <<"_upload">>], Req) ->
    launch_rest_upload(SrvId, ActorSrvId, Verb, #{group=>Group, vsn=>Vsn, namespace=>Namespace, resource=>ResType}, Req);

% /apis/core/v1/namespaces/Namespace/ResType/Name/SubRes/_upload
do_rest_api(SrvId, ActorSrvId, Verb, [<<"apis">>, Group, Vsn, <<"namespaces">>, Namespace, ResType, Name, RestType2, <<"_upload">>], Req) ->
    ApiReq = #{group=>Group, vsn=>Vsn, namespace=>Namespace, resource=>ResType, name=>Name, subresource=>[RestType2]},
    launch_rest_upload(SrvId, ActorSrvId, Verb, ApiReq, Req);

% /apis/core/v1/namespaces/Namespace/ResType/Name...
do_rest_api(SrvId, ActorSrvId, Verb, [<<"apis">>, Group, Vsn, <<"namespaces">>, Namespace, ResType, Name|SubRes], Req) ->
    case lists:reverse(SubRes) of
        [<<"_upload">>|SubRes2] ->
            ApiReq = #{group=>Group, vsn=>Vsn, namespace=>Namespace, resource=>ResType, name=>Name, subresource=>lists:reverse(SubRes2)},
            launch_rest_upload(SrvId, ActorSrvId, Verb, ApiReq, Req);
        _ ->
            ApiReq = #{group=>Group, vsn=>Vsn, namespace=>Namespace, resource=>ResType, name=>Name, subresource=>SubRes},
            launch_rest_api(SrvId, ActorSrvId, Verb, ApiReq, Req)
    end;

% /apis/core/v1/ResType (implicit namespace)
do_rest_api(SrvId, ActorSrvId, Verb, [<<"apis">>, Group, Vsn, ResType], Req) ->
    Namespace = nkactor:base_namespace(ActorSrvId),
    do_rest_api(SrvId, ActorSrvId, Verb, [<<"apis">>, Group, Vsn, <<"namespaces">>, Namespace, ResType], Req);

% /apis/core/v1/ResType/Name (implicit namespace)
do_rest_api(SrvId, ActorSrvId, Verb, [<<"apis">>, Group, Vsn, ResType, Name|SubRes], Req) ->
    Namespace = nkactor:base_namespace(ActorSrvId),
    do_rest_api(SrvId, ActorSrvId, Verb, [<<"apis">>, Group, Vsn, <<"namespaces">>, Namespace, ResType, Name|SubRes], Req);


% /search/v1
do_rest_api(SrvId, ActorSrvId, Verb, [?GROUP_SEARCH, Vsn], Req) ->
    Namespace = nkactor:base_namespace(ActorSrvId),
    do_rest_api(SrvId, ActorSrvId, Verb, [?GROUP_SEARCH, Vsn, <<"namespaces">>, Namespace], Req);

% /search/v1/namespaces/Namespace
do_rest_api(SrvId, ActorSrvId, Verb, [?GROUP_SEARCH, Vsn, <<"namespaces">>, Namespace], Req) ->
    launch_rest_search(SrvId, ActorSrvId, Verb, #{vsn=>Vsn, namespace=>Namespace}, Req);


% /graphql
do_rest_api(_SrvId, _ActorSrvId, <<"POST">>, [<<"graphql">>], _) ->
    {error, {resource_invalid, <<>>}};

do_rest_api(_SrvId, _ActorSrvId, Verb, [<<"_test">>, <<"faxin">>|Rest], Req) ->
    BodyOpts = #{max_size=>?MAX_BODY_SIZE},
    {Body, _Req2} = case nkrest_http:get_body(Req, BodyOpts) of
        {ok, B0, R0} ->
            {B0, R0};
        {error, Error} ->
            ?API_LOG(warning, "error reading body: ~p" , [Error]),
            throw({error, request_body_invalid})
    end,
    Qs = nkrest_http:get_qs(Req),
    Hds = nkrest_http:get_headers(Req),
    lager:error("NKLOG HTTP FAX IN (~s)\nPath: ~p\nQs: ~p\nHeaders: ~p\nBody: ~p\n",
        [Verb, Rest, Qs, Hds, Body]),
    Rep = <<"<Response><Receive action=\"/fax/received\"/></Response>">>,
    {binary, <<"application/xml">>, Rep};


% /bulk
do_rest_api(SrvId, ActorSrvId, Verb, [?GROUP_BULK], Req) ->
    launch_rest_bulk(SrvId, ActorSrvId, Verb, Req);


% /_test
do_rest_api(_SrvId, _ActorSrvId, Verb, [<<"_test">>|Rest], Req) ->
    BodyOpts = #{max_size=>?MAX_BODY_SIZE},
    {Body, _Req2} = case nkrest_http:get_body(Req, BodyOpts) of
        {ok, B0, R0} ->
            {B0, R0};
        {error, Error} ->
            ?API_LOG(warning, "error reading body: ~p" , [Error]),
            throw({error, request_body_invalid})
    end,
    Qs = nkrest_http:get_qs(Req),
    Hds = nkrest_http:get_headers(Req),
    lager:error("NKLOG HTTP _TEST (~s)\nPath: ~p\nQs: ~p\nHeaders: ~p\nBody: ~p\n",
                [Verb, Rest, Qs, Hds, Body]),
    {ok, #{}};

do_rest_api(_SrvId, _ActorSrvId, _Verb, Path, _Req) ->
    {error, {resource_invalid, nklib_util:bjoin(Path, $/)}}.


%% @doc
launch_rest_api(SrvId, ActorSrvId, Verb, ApiReq, Req) ->
    ?API_DEBUG("HTTP incoming: ~s ~p", [Verb, ApiReq]),
    Qs = maps:from_list(nkrest_http:get_qs(Req)),
    Hds = nkrest_http:get_headers(Req),
    Token = case maps:get(<<"x-nkdomain-token">>, Hds, <<>>) of
        <<>> ->
            maps:get(<<"adminToken">>, Qs, <<>>);
        HdToken ->
            HdToken
    end,
    BodyOpts = #{max_size=>?MAX_BODY_SIZE, parse=>true},
    {Body, Req2} = case nkrest_http:get_body(Req, BodyOpts) of
        {ok, B0, R0} ->
            {B0, R0};
        {error, Error} ->
            ?API_LOG(warning, "error reading body: ~p" , [Error]),
            throw({error, request_body_invalid})
    end,
    ToWatch = maps:get(<<"watch">>, Qs, undefined) == <<"true">>,
    Name = maps:get(name, ApiReq, <<>>),
    Verb2 = case Verb of
        <<"GET">> when ToWatch ->
            watch;
        <<"GET">> when Name == <<>> ->
            list;
        <<"POST">> when Name == <<>> ->
            list;
        <<"GET">> ->
            get;
        <<"HEAD">> when ToWatch ->
            watch;
        <<"HEAD">> when Name == <<>> ->
            list;
        <<"HEAD">> ->
            get;
        <<"POST">> ->
            create;
        <<"PUT">> ->
            update;
        <<"PATCH">> when Name == <<>> ->
            throw({error, method_not_allowed});
        <<"PATCH">> ->
            patch;
        <<"DELETE">> when Name == <<>> ->
            deletecollection;
        <<"DELETE">> ->
            delete;
        _ ->
            throw({error, method_not_allowed})
    end,
    ApiReq2 = ApiReq#{
        verb => Verb2,
        params => Qs,
        body => Body,
        srv => ActorSrvId,
        auth => #{token => Token},
        callback => ?MODULE,
        external_url => nkrest_http:get_external_url(Req),
        meta => #{
            nkrest_req => Req2
        }
    },
    nkactor_api:api_request(SrvId, ApiReq2).


%% @doc
launch_rest_upload(_SrvId, ActorSrvId, Verb, ApiReq, Req) ->
    ?API_DEBUG("HTTP incoming upload: ~s ~p", [Verb, ApiReq]),
    Qs = maps:from_list(nkrest_http:get_qs(Req)),
    Hds = nkrest_http:get_headers(Req),
    Token = case maps:get(<<"x-nkdomain-token">>, Hds, <<>>) of
        <<>> ->
            maps:get(<<"adminToken">>, Qs, <<>>);
        HdToken ->
            HdToken
    end,
    BodyOpts = #{max_size=>?MAX_UPLOAD_SIZE, parse=>false},
    {Body, Req2} = case nkrest_http:get_body(Req, BodyOpts) of
        {ok, B0, R0} ->
            {B0, R0};
        {error, Error} ->
            ?API_LOG(warning, "error reading body: ~p" , [Error]),
            throw({error, request_body_invalid})
    end,
    Verb2 = case Verb of
        <<"POST">> ->
            upload;
        _ ->
            throw({error, method_not_allowed})
    end,
    #{content_type:=CT} = Req,
    ApiReq2 = ApiReq#{
        verb => Verb2,
        params => Qs,
        body => Body,
        auth => #{token => Token},
        callback => ?MODULE,
        external_url => nkrest_http:get_external_url(Req),
        meta => #{
            nkdomain_http_content_type => CT,
            nkrest_req => Req2
        }
    },
    nkactor_api:api_request(ActorSrvId, ApiReq2).


%% @private
launch_rest_search(_SrvId, ActorSrvId, Verb, ApiReq, Req) ->
    Qs = maps:from_list(nkrest_http:get_qs(Req)),
    Hds = nkrest_http:get_headers(Req),
    Token = case maps:get(<<"x-nkdomain-token">>, Hds, <<>>) of
        <<>> ->
            maps:get(<<"adminToken">>, Qs, <<>>);
        HdToken ->
            HdToken
    end,
    BodyOpts = #{max_size=>?MAX_BODY_SIZE, parse=>true},
    {Body, Req2} = case nkrest_http:get_body(Req, BodyOpts) of
        {ok, B0, R0} ->
            {B0, R0};
        {error, Error} ->
            ?API_LOG(warning, "error reading body: ~p" , [Error]),
            throw({error, request_body_invalid})
    end,
    Delete = maps:get(<<"delete">>, Qs, undefined) == <<"true">>,
    Verb2 = case Verb of
        <<"POST">> when Delete ->
            deletecollection;
        <<"POST">> ->
            list;
        _ ->
            throw({error, method_not_allowed})
    end,
    ApiReq2 = ApiReq#{
        verb => Verb2,
        group => ?GROUP_SEARCH,
        body => Body,
        auth => #{token => Token},
        external_url => nkrest_http:get_external_url(Req),
        meta => #{
            nkrest_req => Req2
        }
    },
    nkactor_api:api_request(ActorSrvId, ApiReq2).


%% @private
launch_rest_bulk(SrvId, _ActorSrvId, <<"PUT">>, Req) ->
    Qs = maps:from_list(nkrest_http:get_qs(Req)),
    Hds = nkrest_http:get_headers(Req),
    Token = case maps:get(<<"x-nkdomain-token">>, Hds, <<>>) of
        <<>> ->
            maps:get(<<"adminToken">>, Qs, <<>>);
        HdToken ->
            HdToken
    end,
    BodyOpts = #{max_size=>?MAX_BODY_SIZE, parse=>true},
    {Body, Req2} = case nkrest_http:get_body(Req, BodyOpts) of
        {ok, B0, R0} ->
            {B0, R0};
        {error, Error} ->
            ?API_LOG(warning, "error reading body: ~p" , [Error]),
            throw({error, request_body_invalid})
    end,
    Status = case nkdomain:load_actor_data(Body, Token) of
        {ok, Res} ->
            lists:map(
                fun
                    ({Name, created}) -> #{name=>Name, result=>created};
                    ({Name, updated}) -> #{name=>Name, result=>updated};
                    ({Name, {error, Error}}) -> #{name=>Name, result=>error, error=>nklib_util:to_binary(Error)}
                end,
                Res);
        {error, LoadError} ->
            nkactor_api_lib:status(SrvId, {error, LoadError})
    end,
    rest_api_reply(200, Status, Req2);

launch_rest_bulk(_SrvId, _ActorSrvId, _Verb, _Req) ->
    throw({error, method_not_allowed}).


%%%% @private
%%to_bin(Term) when is_binary(Term) -> Term;
%%to_bin(Term) -> nklib_util:to_binary(Term).