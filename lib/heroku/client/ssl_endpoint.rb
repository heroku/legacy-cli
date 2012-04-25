class Heroku::Client
  def ssl_endpoint_add(app, pem, key)
    json_decode(post("apps/#{app}/ssl-endpoints", :accept => :json, :pem => pem, :key => key).to_s)
  end

  def ssl_endpoint_info(app, cname)
    json_decode(get("apps/#{app}/ssl-endpoints/#{escape(cname)}", :accept => :json).to_s)
  end

  def ssl_endpoint_list(app)
    json_decode(get("apps/#{app}/ssl-endpoints", :accept => :json).to_s)
  end

  def ssl_endpoint_remove(app, cname)
    json_decode(delete("apps/#{app}/ssl-endpoints/#{escape(cname)}", :accept => :json).to_s)
  end

  def ssl_endpoint_rollback(app, cname)
    json_decode(post("apps/#{app}/ssl-endpoints/#{escape(cname)}/rollback", :accept => :json).to_s)
  end

  def ssl_endpoint_update(app, cname, pem, key)
    json_decode(put("apps/#{app}/ssl-endpoints/#{escape(cname)}", :accept => :json, :pem => pem, :key => key).to_s)
  end
end
