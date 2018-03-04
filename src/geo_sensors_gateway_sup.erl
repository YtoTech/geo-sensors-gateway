%%%-------------------------------------------------------------------
%% @doc geo_sensors_gateway top level supervisor.
%% @end
%%%-------------------------------------------------------------------

-module(geo_sensors_gateway_sup).

-behaviour(supervisor).

%% API
-export([start_link/0]).

%% Supervisor callbacks
-export([init/1]).

-define(SERVER, ?MODULE).

%%====================================================================
%% API functions
%%====================================================================

start_link() ->
	% TODO What gives this ?SERVER const?
	supervisor:start_link({local, ?SERVER}, ?MODULE, []).

%%====================================================================
%% Supervisor callbacks
%%====================================================================

%% Child :: {Id,StartFunc,Restart,Shutdown,Type,Modules}
init([]) ->
	% io:format("Env is ~p~n", [application:get_all_env()]),
	% Load application configuration.
	% io:format("Env is ~p~n", [application:get_env(gateway_config_loader)]),
	{ok, ConfigLoaderName} = application:get_env(gateway_config_loader),
	ConfigLoader = list_to_atom(ConfigLoaderName),
	{module, _} = code:ensure_loaded(ConfigLoader),
	% TODO Access the configuration directly in
	% the app modules to allows hot configuration reloading.
	% Trigger a first configuration load here to ensure the config loader works.
	% TODO Return a bad_configuration error in case of bad match, without making the code ugly?
	#{
		smtp_gateway := SmtpGateway,
		users := Users,
		devices := Devices,
		forwarders := Forwarders
	} = ConfigLoader:load_config(),
	% io:format("Users are ~p~n", [Users]),
	% TODO Use the new supervisor spec using a Map to be more readable.
	% http://erlang.org/doc/man/supervisor.html
	% http://erlang.org/doc/design_principles/sup_princ.html
	SmtpServer = {
		gen_smtp_server,
		{gen_smtp_server, start_link, [smtp_server, [[
			{port, maps:get(port, SmtpGateway, 25)},
			{sessionoptions,
				[{callbackoptions,
					[
						{auth, true},
						{dumps_incoming, maps:get(dumps_incoming, SmtpGateway, false)},
						{dumps_directory, maps:get(dumps_directory, SmtpGateway, "dumps/")},
						{users, Users},
						{devices, Devices},
						{forwarders, Forwarders}
					]
				}]
			}
		]]]},
		permanent,
		2000,
		worker,
		[gen_smtp_server]
	},
	ForwardingServer = {
		forwarding_server,
		{forwarding_server, start_link, []},
		permanent,
		10000,
		worker,
		[forwarding_server]
	},
	Children = [SmtpServer, ForwardingServer],
	RestartStrategy = {one_for_one, 2, 5},
	{ok, { RestartStrategy, Children} }.

%%====================================================================
%% Internal functions
%%====================================================================
