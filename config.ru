$ROOT = File.expand_path(File.dirname(__FILE__))
$:.unshift($ROOT)

# System Requirements
require 'yaml'
require 'thread'
require 'securerandom'
require 'set'
require 'fileutils'

# Gem Requirements
require 'sinatra'
require 'puma'
require 'rbczmq'
require 'redis'
require 'byebug'

# Local Requirements
require 'helpers'

Thread.abort_on_exception = true

# Initializations

module Messages
  CONFIG = YAML::load_file(File.join($ROOT, 'messages.yml'))
  SERVER_PORT = CONFIG['server_port']
  SERVER_BIND = CONFIG['server_bind']
  ZMQ_STARTUP_PORT = CONFIG['zmq_startup_port']
  ZMQ_JOB_PORT = CONFIG['zmq_job_port']
  REDIS_HOST = CONFIG['redis_host']
  REDIS_PORT = CONFIG['redis_port']
end

Dir.mkdir(File.join($ROOT, 'attachments'))

require 'server'

run Messages::Server
