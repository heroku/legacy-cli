def mock_openssl
  @ctx_mock        = mock "SSLContext", :key= => nil, :cert= => nil
  @tcp_socket_mock = mock "TCPSocket", :close => true
  @ssl_socket_mock = mock "SSLSocket", :sync= => true, :connect => true, :close => true, :to_io => $stdin
  
  OpenSSL::SSL::SSLSocket.stub(:new).and_return(@ssl_socket_mock)
  OpenSSL::SSL::SSLContext.stub(:new).and_return(@ctx_mock)
end
