def mock_openssl
  @ctx_mock        = double "SSLContext", :key= => nil, :cert= => nil, :ssl_version= => nil
  @tcp_socket_mock = double "TCPSocket", :close => true
  @ssl_socket_mock = double "SSLSocket", :sync= => true, :connect => true, :close => true, :to_io => $stdin
  
  allow(OpenSSL::SSL::SSLSocket).to receive(:new).and_return(@ssl_socket_mock)
  allow(OpenSSL::SSL::SSLContext).to receive(:new).and_return(@ctx_mock)
end
