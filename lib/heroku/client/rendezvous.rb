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
    scheme, host, port, secret = uri.scheme, uri.host, uri.port, uri.path[1..-1]

    if (scheme == "tcp+ssl")
      tcp_socket, ssl_socket = Timeout.timeout(30) do
        ssl_context = OpenSSL::SSL::SSLContext.new
        if ((host =~ /heroku\.com$/) && !(ENV["HEROKU_SSL_VERIFY"] == "disable"))
          ssl_context.verify_mode = OpenSSL::SSL::VERIFY_PEER
        end
        tcp_socket = TCPSocket.open(host, port)
        ssl_socket = OpenSSL::SSL::SSLSocket.new(tcp_socket, ssl_context)
        ssl_socket.connect
        ssl_socket.puts(secret)
        ssl_socket.readline
        [tcp_socket, ssl_socket]
      end

      set_buffer(false)
      output.sync = true
      on_connect.call if on_connect

      loop do
        if o = IO.select([input, tcp_socket], nil, nil, nil)
          if o.first.first == input
            data = input.readpartial(1000)
            ssl_socket.write(data)
            ssl_socket.flush
          elsif o.first.first == tcp_socket
            data = ssl_socket.readpartial(1000)
            output.write(data)
          end
        end
      end

    else
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
    end
  rescue Timeout::Error
    error "\nTimeout awaiting process"
  rescue Errno::ECONNREFUSED, Errno::ECONNRESET, OpenSSL::SSL::SSLError
    error "\nError connecting to process"
  rescue Interrupt, EOFError, Errno::EIO
  ensure
    set_buffer(true)
  end
end
