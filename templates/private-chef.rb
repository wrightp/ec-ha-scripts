topology "ha"

server "be1.local",
  :ipaddress => "",
  :role => "backend",
  :bootstrap => true,
  :cluster_ipaddress => ""

server "be2.local",
  :ipaddress => "",
  :role => "backend",
  :cluster_ipaddress => ""

# back end load balancer IP
backend_vip "",
  :ipaddress => "",
  :device => "eth0",
  :heartbeat_device => "eth1"

server "fe1.local",
  :ipaddress => "",
  :role => "frontend"

server "fe2.local",
  :ipaddress => "",
  :role => "frontend"

# front end load balancer IP
api_fqdn ""
 