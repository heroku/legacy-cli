module Excon

  def self.get_with_redirect(url, options={})
    res = Excon.get(url, options)
    if [301, 302].include?(res.status)
      return self.get_with_redirect(res.headers["Location"], options)
    end
    res
  end

end
