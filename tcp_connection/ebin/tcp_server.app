{application, tcp_server,
[{description, "A simple TCP server"},
{vsn, "0.1.0"},
{modules, [
	ts_root_sup,
	ts_app 
	]},
{registered,[ts_root_sup]},
{applications, [kernel]},
{mod, {ts_app,[]}}
]}.         
