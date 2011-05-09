require "timeout"
require "socket"
require "uri"
require "heroku/client"
require "heroku/helpers"

class Heroku::Client::Rendezvous
  include Heroku::Helpers

  attr_reader :input, :output

  def initialize(input, output)
    @input = input
    @output = output
  end

  def on_connect(&blk)
    @on_connect = blk if block_given?
    @on_connect
  end

  def connect(rendezvous_url)
    uri = URI.parse(rendezvous_url)
    host, port, secret = uri.host, uri.port, uri.path[1..-1]

    socket = Timeout.timeout(30) do
      s = TCPSocket.open(host, port)
      s.puts(secret)
      s.readline; s.readline
      s
    end

    set_buffer(false)
    output.sync = true
    on_connect.call if on_connect

    loop do
      if o = IO.select([input, socket], nil, nil, nil)
        if o.first.first == input
          data = input.read_nonblock(1000)
          socket.write(data)
          socket.flush()
        elsif o.first.first == socket
          data = socket.read_nonblock(1000)
          output.write(data)
        end
      end
    end
  rescue Timeout::Error
    error "\nTimeout awaiting process"
  rescue Errno::ECONNREFUSED
    error "\nError connecting to process"
  rescue Interrupt, EOFError, Errno::EIO
  ensure
    set_buffer(true)
  end
end
