#A Julia interface to Mongrel2

Mongrel2.jl is a package that enables writing [Mongrel2] (http://mongrel2.org/) handlers in the [Julia] (http://julialang.org) programming language. 

## Installation
```julia
Pkg.add("Mongrel2")
```

This will also install the dependent Julia packages: [ZMQ] (https://github.com/aviks/ZMQ.jl) and [JSON] (https://github.com/JuliaLang/JSON.jl)

Install Mongrel2 and ZMQ libraries for your OS using your favourite package manager

##Usage

Start Mongrel2 in the usual fashion with a relevant configuration. [Example] (https://raw.github.com/aviks/Mongrel2.jl/master/example/mongrel2.config)

```julia
load("Mongrel2")
using Mongrel2

t = run_server("6DFF1523-C091-49B8-B635-598640E864B3", "tcp://127.0.0.1:9997", "tcp://127.0.0.1:9996")

 while true                                                                                            
    (conn, req) = consume (t) 
    response = "<html><body>Sender: $(req.sender_id)<br>ConnectionId: $(req.connection_id)<br>
                  Path: $(req.path)<br>Headers: $(string(req.headers))<br> Body: $(req.body)</html></body>"
       
    if is_disconnected(req); print("Disconnected $(req.connection_id) \n");continue; end
    reply_http(conn, req, response); disconnect_client(conn,req);
end
```

Navigate to http://localhost:6767/handlertest/
