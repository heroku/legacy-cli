class Heroku::Client
  def ssl_endpoint_add(app, pem, key)
    json_decode(post("v3/apps/#{app}/ssl_endpoints", :accept => :json, :pem => pem, :key => key).to_s)
  end

  def ssl_endpoint_info(app, cname)
    json_decode(get("v3/apps/#{app}/ssl_endpoints/#{escape(cname)}", :accept => :json).to_s)
  end

  def ssl_endpoint_list(app)
    json_decode(get("v3/apps/#{app}/ssl_endpoints", :accept => :json).to_s)
  end

  def ssl_endpoint_remove(app, cname)
    json_decode(delete("v3/apps/#{app}/ssl_endpoints/#{escape(cname)}", :accept => :json).to_s)
  end

  def ssl_endpoint_rollback(app, cname)
    json_decode(post("v3/apps/#{app}/ssl_endpoints/#{escape(cname)}/rollback", :accept => :json).to_s)
  end

  def ssl_endpoint_update(app, cname, pem, key)
    json_decode(put("v3/apps/#{app}/ssl_endpoints/#{escape(cname)}", :accept => :json, :pem => pem, :key => key).to_s)
  end
end
