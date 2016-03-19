$ROOT = File.expand_path(File.dirname(__FILE__))
$:.unshift($ROOT)

# System Requirements
require 'yaml'
require 'json'

# Gem Requirements
require 'rbczmq'

def startup(addresses, ctx)
  startup_socket = ctx.connect("tcp://#{host}:#{startup_port}")
  startup_socket.send(addresses.to_json)
  startup_socket.close
end

# Initializations
ctx = ZMQ::Context.new

# Get relevant config options.
config = YAML::load_file(File.join($ROOT, 'messages.yml'))
host = config['server_hostname']
addresses = config['addresses']
startup_port = config['zmq_startup_port']
job_port = config['zmq_job_port']

# Send valid addresses to server.
startup(addresses, ctx)

job_socket = ctx.connect("tcp://#{host}:#{job_port}")
loop do
  message = job_socket.recv
  if message != 'bye!'
    # TODO: Actually send the message here.
  else
    job_socket.close
    startup(addresses, ctx)
    job_socket = ctx.connect("tcp://#{host}:#{job_port}")
  end
end
