-ifndef(NKACTOR_API_HRL_).
-define(NKACTOR_API_HRL_, 1).

%% ===================================================================
%% Defines
%% ===================================================================

-define(PACKAGE_NKACTOR_API, <<"ActorAPI">>).

-define(GROUP_SEARCH, <<"search">>).
-define(GROUP_BULK, <<"bulk">>).

-define(API_DEBUG(Txt, Args),
    case erlang:get(nkactor_api_debug) of
        true -> ?API_LOG(debug, Txt, Args);
        _ -> ok
    end).

-define(API_DEBUG(Txt, Args, ApiReq),
    case erlang:get(nkactor_api_debug) of
        true -> ?API_LOG(debug, Txt, Args, ApiReq);
        _ -> ok
    end).


-define(API_LOG(Type, Txt, Args, ApiReq),
    lager:Type(
        [
            {verb, maps:get(verb, ApiReq, get)},
            {group, maps:get(group, ApiReq, <<>>)},
            {resource, maps:get(resource, ApiReq, <<>>)},
            {name, maps:get(name, ApiReq, <<>>)}
        ],
        "NkDOMAIN API (~s ~s/~s/~s) " ++ Txt,
        [
            maps:get(verb, ApiReq, get),
            maps:get(group, ApiReq, <<>>),
            maps:get(resource, ApiReq, <<>>),
            maps:get(name, ApiReq, <<>>) |
            Args
        ]
    )).

-define(API_LOG(Type, Txt, Args),
    lager:Type( "NkDOMAIN API " ++ Txt, Args)).


-endif.