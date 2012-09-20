module Excon

  def self.get_with_redirect(url, options={})
    res = Excon.get(url, options)
    return self.get_with_redirect(res.headers["Location"], options) if res.status == 302
    res
  end

end
