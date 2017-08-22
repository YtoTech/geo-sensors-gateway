%%%-------------------------------------------------------------------
%% @doc geo_sensors_gateway public API
%% @end
%%%-------------------------------------------------------------------

-module(geo_sensors_gateway_app).

-behaviour(application).

%% Application callbacks
-export([start/2, stop/1]).

%%====================================================================
%% API
%%====================================================================

% -export([ensure_all_started/1]).
%
%
% -spec ensure_all_started(atom()) -> ok | {error, term()}.
% ensure_all_started(App) ->
%     start_ok(App, application:start(App, permanent)).
%
% -spec start_ok(atom(), ok | {error, term()}) -> ok | {error, {term(), atom()}}.
% start_ok(_App, ok) -> ok;
% start_ok(_App, {error, {already_started, _App}}) -> ok;
% start_ok(App, {error, {not_started, Dep}}) ->
%     ok = ensure_all_started(Dep),
%     ensure_all_started(App);
% start_ok(App, {error, Reason}) ->
%     {error, {Reason, App}}.

start(_StartType, _StartArgs) ->
	% TODO Use http://erlang.org/doc/apps/kernel/application.html#ensure_all_started-1
	% TODO Is that to start in the supervision tree?
	{ok,_} = gen_smtp_server:start(smtp_server, [[
		% TODO Allows configuration of port. Default to 2525.
		{port, 2525},
		{sessionoptions,
			[{callbackoptions,
				[
					{auth, true},
					{dump, true},
					% TODO Load authorized usernames and passwords from a json map.
					% TODO Create a provider for that and allows hot-reloading.
					% The users are indexed by username, because we encounter
					% first the AUTH in the process of receiving a mail.
					% TODO Handle non-authenticated mode?
					% We make here the assumption that we have one email handled
					% by each username. (An username could allow to handle many
					% mails).
					% TODO Do we really care and want to filter by emails?
					% When the auth is right, we can assume we are fine.
					% Maybe we should just list users (with username, email, password)
					% and use the first match.
					{users,
						#{
							<<"annon">> => #{
								email => <<"test@ytotech.com">>,
								password => <<"coincoin">>
							}
						}
					}
				]
			}]
		}
	]]),
    % TODO Use the supervisor for hot-reloading?
    geo_sensors_gateway_sup:start_link().

%%--------------------------------------------------------------------
stop(_State) ->
	ok.

%%====================================================================
%% Internal functions
%%====================================================================