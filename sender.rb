$ROOT = File.expand_path(File.dirname(__FILE__))
$:.unshift($ROOT)

# System Requirements
require 'yaml'
require 'json'
require 'open-uri'

# Gem Requirements
require 'rbczmq'

# Local Requirements
require 'helpers'

# Initializations
ctx = ZMQ::Context.new

# Get relevant config options.
config = YAML::load_file(File.join($ROOT, 'messages.yml'))
host = config['server_hostname']
prefix = config['server_prefix']
job_port = config['zmq_job_port']

job_socket = ctx.connect("tcp://#{host}:#{job_port}")
loop do
  message = job_socket.recv
  msg = JSON.parse(message) rescue next

  # Get the attachment if one was specified.
  attachment = open("#{host}#{prefix && '/' + prefix || ''}/#{prefix['attachments']}") if msg['attachment'].exists?

  # Initial setup for sending script.
  applescript = <<-SCRIPT
      tell application "Messages"
        set targetService to 1st service whose service type = iMessage
        set targetBuddy to buddy "#{msg['to']}" of targetService
  SCRIPT

  # Send the message if it exists.
  if msg['message'].exists?
    applescript += <<-SCRIPT
        \nset targetMessage to "#{msg['message']}"
        send targetMessage to targetBuddy
    SCRIPT
  end

  # Send the attachment if it exists.
  if attachment.exists?
    applescript += <<-SCRIPT
        \nset targetPath to "#{attachment.path}"
        set targetFile to targetPath as POSIX file
        send targetFile to targetBuddy
    SCRIPT
  end

  # Terminate the script.
  applescript += "\nend tell"

  # Create a tempfile for the script.
  script = Tempfile.new
  begin
    # Write the generated script into the file.
    script.write(applescript)
    script.close

    # Execute the script.
    `osascript #{script.path}`
  ensure
    # Cleanup the tempfile.
    script.unlink
  end
end
