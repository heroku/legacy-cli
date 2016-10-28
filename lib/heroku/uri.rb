require 'uri'
require 'addressable/uri'

# http://stackoverflow.com/a/17108137/255982
class URI::Parser
  def split(url)
    a = Addressable::URI::parse(url)
    [a.scheme, a.userinfo, a.host, a.port, nil, a.path, nil, a.query, a.fragment]
  end
end
