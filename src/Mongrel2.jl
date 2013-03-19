require("ZMQ")
require("JSON")

module Mongrel2
using ZMQ
import JSON

export M2Request,M2Connection,
		parse_request, is_disconnected, connect, reply, reply_http, run_server, disconnect_client

type M2Request
	sender_id
	connection_id
	path
	headers
	body
	json_data

	function M2Request(s,c,p,h,b) 
		if h["METHOD"] == "JSON"
			new(s,c,p,h,b,JSON.parse(b))
		else
			new(s,c,p,h,b,Dict())
		end
	end
end

type M2Connection
	ctx::ZMQContext
	reqs::ZMQSocket
	resp::ZMQSocket
	sub_addr::String
	pub_addr::String

end

function parse_netstring (str::String)
	 i = search(str, ':')
	 s = str[i+1:end]
	 len = int(str[1:i-1])
	 if s[len+1] != ','; error ("Netstring does not end with comma : $str"); end
	 if len==0
	 	return "", ""
	 else 
		return s[1:len], s[len+2:end]
	end
end

function parse_request(msg::ZMQMessage)
	s=ASCIIString[msg]
	#Uncomment for debug: 
	#print ("Recd message: $s \n\n");flush(stdout_stream)
	
	r = split(s, ' ')
	sender = r[1]
	connection_id = r[2]
	path = r[3]
	rest = r[4]
	if length(r) > 4
		for i = r[5:end]
			rest = string(rest, " ", i)
		end
	end

	headers, head_rest = parse_netstring(rest)

	(body, ) = parse_netstring(head_rest)

	return M2Request(sender, connection_id, path, JSON.parse(headers), body)
end

function is_disconnected(req::M2Request) 
	if req.headers["METHOD"] == "JSON"
		return req.json_data["type"] == "disconnect"
	else
		return false
	end

end

function connect(sender_id::String, sub_addr::String, pub_addr::String)
	ctx = ZMQContext(1)
	reqs = ZMQSocket(ctx, ZMQ_UPSTREAM)
	ZMQ.connect(reqs, sub_addr)
	resp = ZMQSocket(ctx, ZMQ_PUB)
	ZMQ.connect(resp, pub_addr)
	ZMQ.set_identity(resp, sender_id)
	return M2Connection(ctx, reqs, resp, sub_addr, pub_addr)
end

#internal function
function send_resp(conn::M2Connection, uuid, conn_id, msg)
	str = "$uuid $(length(conn_id)):$(conn_id), $msg"
	ZMQ.send(conn.resp, ZMQMessage(str))
	#Uncomment for debug: 
	#print("Sent Reply to $conn_id: $str \n\n");flush(stdout_stream)
end

recv(conn::M2Connection) = parse_request(ZMQ.recv(conn.reqs))::M2Request

#This shouldnt be required  except for HTTP 1.0 clients, or websockets. 
#Normally, Let the browser manage keepalive. 
disconnect_client(conn::M2Connection, req::M2Request) = send_resp(conn, req.sender_id, req.connection_id, "")

reply(conn::M2Connection, req::M2Request, msg::String) = send_resp(conn, req.sender_id, req.connection_id, msg)
reply_http (conn::M2Connection, req::M2Request, body, code, headers::Dict{String, String}) = 
								reply(conn, req, http_response(body, code, headers))
reply_http (conn::M2Connection, req::M2Request, body, headers) = reply_http(conn, req, body, 200, headers)
reply_http (conn::M2Connection, req::M2Request, body) = reply_http(conn, req, body, 200, Dict{String, String}())


function http_response(body, code, headers::Dict{String, String})
	headers["Content-Length"] = string(length(body))
	headers_s = ""
	for (k, v) = headers
		headers_s = string(headers_s, "$(k): $(v)\r\n")
	end
	return "HTTP/1.1 $code $(StatusMessage[int(code)])\r\n$(headers_s)\r\n\r\n$(body)"
end

function run_server(sender_id, sub_addr, pub_addr)
	conn::M2Connection = connect(sender_id, sub_addr, pub_addr)

	function runner() 
		while true
			request::M2Request = recv(conn)
			produce((conn, request))
		end
	end
	print("Julia Mongrel2 hander started, connecting back on [$sub_addr] and [$pub_addr] \n")
	#flush(stdout_stream)
	return Task(runner)
end

const StatusMessage = Dict{Int, String}()
StatusMessage[100] = "Continue"
StatusMessage[101] = "Switching Protocols"
StatusMessage[200] = "OK"
StatusMessage[201] = "Created"
StatusMessage[202] = "Accepted"
StatusMessage[203] = "Non-Authoritative Information"
StatusMessage[204] = "No Content"
StatusMessage[205] = "Reset Content"
StatusMessage[206] = "Partial Content"
StatusMessage[300] = "Multiple Choices"
StatusMessage[301] = "Moved Permanently"
StatusMessage[302] = "Found"
StatusMessage[303] = "See Other"
StatusMessage[304] = "Not Modified"
StatusMessage[305] = "Use Proxy"
StatusMessage[307] = "Temporary Redirect"
StatusMessage[400] = "Bad Request"
StatusMessage[401] = "Unauthorized"
StatusMessage[402] = "Payment Required"
StatusMessage[403] = "Forbidden"
StatusMessage[404] = "Not Found"
StatusMessage[405] = "Method Not Allowed"
StatusMessage[406] = "Not Acceptable"
StatusMessage[407] = "Proxy Authentication Required"
StatusMessage[408] = "Request Timeout"
StatusMessage[409] = "Conflict"
StatusMessage[410] = "Gone"
StatusMessage[411] = "Length Required"
StatusMessage[412] = "Precondition Failed"
StatusMessage[413] = "Request Entity Too Large"
StatusMessage[414] = "Request-URI Too Large"
StatusMessage[415] = "Unsupported Media Type"
StatusMessage[416] = "Request Range Not Satisfiable"
StatusMessage[417] = "Expectation Failed"
StatusMessage[500] = "Internal Server Error"
StatusMessage[501] = "Not Implemented"
StatusMessage[502] = "Bad Gateway"
StatusMessage[503] = "Service Unavailable"
StatusMessage[504] = "Gateway Timeout"
StatusMessage[505] = "HTTP Version Not Supported"

end
