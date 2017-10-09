%% @doc A simple example callback module for `device_payload_parser' that also serves as
%% documentation for the required callback API.
%% Responsible for parsing sensor payloads and extract all usefull information
%% from them.
%% This data will then be transferred to any endpoint by forwarders.

-module(device_payload_parser_example).
-author('yoan@ytotech.com').
% TODO https://stackoverflow.com/questions/32336854/how-to-create-and-use-a-custom-erlang-behavior
% -behaviour(device_payload_parser).

%% API
-export([parse/3]).

-spec parse(Body :: binary(), User :: map(), Devices :: map()) -> {'ok', map(), map()} | {'error', atom()}.
parse(Body, User, Devices) ->
	% Get the sensor type from user config
	% and transfert to the appropriate parsing module.
	case maps:find(maps:get(device, User), Devices) of
		{ok, Device} ->
			case Device of
				#{manufacturer := <<"Ercogener">>, range := <<"GenLoc">>} ->
					{ok, ParsedPayload} = parse_genloc(Body, User, Device),
					{ok, ParsedPayload, Device};
				_ ->
					io:format("No parser for device ~p: ignore~n", [Device]),
					{error, no_device_parser}
			end;
		_ ->
			io:format("No device for user: ignore~n"),
			{error, no_device}
	end.

-spec parse_genloc(Body :: binary(), User :: map(), Device :: map()) -> {'ok', map()} | {'error', atom()}.
parse_genloc(Body, User, Device) ->
	io:format("~p~n", [Body]),
	% Prepare input: split by lines and trim them.
	Lines = string:split(Body, <<"\n">>, all),
	TrimedLines = lists:map(fun (Line) -> string:trim(Line) end, Lines),
	% We consider only (non-empty) lines.
	PayloadLines = lists:filtermap(
		fun (Line) -> not string:is_empty(Line) end,
		TrimedLines
	),
	% TODO Create meta-mapping for parsing NMEA trames.
	% Or use http://nmea.io/ with a NIF.
	% Implement custom parsers.
	% Parsing in C is ok if it return fast and return an error / null when
	% the parsing fail.
	% It is in any case a good idea to code these trame parsing from meta
	% configuration that describe the format, as it is basically pair
	% of key-value.
	% --> So we can make it configurable.
	% Also Python alternative: https://github.com/Knio/pynmea2
	% Other way is to create a micro-HTTP service dedicated to the task.
	% --> This can help others and may be a service for geo-gateway.com.
	io:format("~p~n", [PayloadLines]),
	Payload = lists:map(
		fun (Line) ->
			io:format("Line: ~s~n", [Line]),
			case string:split(Line, <<",">>) of
				[<<"$GPLOC">>,_] ->
					parse_nmea(<<"GPLOC">>, Line);
				[<<"$GPRMC">>,_] ->
					parse_nmea(<<"GPRMC">>, Line);
				_ ->
					% TODO Do something: the forwarder may choose to alert
					% on failed parsing.
					io:format("momatch: ~p~n", [string:split(Line, ",")]),
					{momatch, Line}
			end
		end,
		PayloadLines
	),
	io:format("~p~n", [Payload]),
	{ok, Payload}.

-spec parse_nmea(Type :: binary(), Line :: binary()) -> {'ok', map()} | {'error', atom()}.
parse_nmea(<<"GPLOC">>, Line) ->
	io:format("GPLOC: ~s~n", [Line]),
	Splitted = string:split(Line, <<",">>, all),
	Elements = array:from_list(Splitted),
	{ok, #{
		format => <<"GPLOC">>,
		status => array:get(1, Elements),
		fix_quality => array:get(2, Elements),
		% TODO Get a normalized timestamp.
		time => array:get(3, Elements),
		% TODO Get normalized lat and long.
		latitude => sexagesimalTodecimal(array:get(4, Elements), array:get(5, Elements)),
		longitude => sexagesimalTodecimal(array:get(6, Elements), array:get(7, Elements)),
		raw => Line
	}};
parse_nmea(<<"GPRMC">>, Line) ->
	io:format("GPRMC: ~s~n", [Line]),
	Splitted = string:split(Line, <<",">>, all),
	Elements = array:from_list(Splitted),
	{ok, #{
		format => <<"GPRMC">>,
		% TODO Get a normalized timestamp.
		time => array:get(1, Elements),
		status => array:get(2, Elements),
		% TODO Get normalized lat and long.
		latitude => sexagesimalTodecimal(array:get(3, Elements), array:get(4, Elements)),
		longitude => sexagesimalTodecimal(array:get(5, Elements), array:get(6, Elements)),
		date => array:get(9, Elements),
		raw => Line
	}}.

% TODO Create a library for doing geo conversion in Erlang.
% https://github.com/manuelbieh/Geolib#geolibsexagesimal2decimalstring-coord
% TODO Manage error cases.
-spec sexagesimalTodecimal(Sexagesimal :: binary(), Cardinality :: binary()) -> float() | nil().
sexagesimalTodecimal(<<"">>, <<"">>) ->
	nil;
sexagesimalTodecimal(Sexagesimal, Cardinality) ->
	io:format("Sexagesimal: ~p Cardinality: ~p ~n", [Sexagesimal,Cardinality]),
	[Ddmm, Mmmmm] = string:split(Sexagesimal, <<".">>),
	{Degrees, _} = string:to_integer(string:slice(Ddmm, 0, 2)),
	{Minutes, _} = string:to_integer(string:slice(Ddmm, 2)),
	{Secondes, _} = string:to_integer(Mmmmm),
	io:format("Degrees: ~p Minutes: ~p Secondes: ~p~n", [Degrees,Minutes,Secondes]),
	DecimalNoCardinality = Degrees + Minutes / 60 + Secondes / 3600,
	case Cardinality of
		<<"S">> -> -DecimalNoCardinality;
		<<"W">> -> -DecimalNoCardinality;
		<<"N">> -> DecimalNoCardinality;
		<<"E">> -> DecimalNoCardinality
	end.
