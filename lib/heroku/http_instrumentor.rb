class HTTPInstrumentor
  class << self
    def filter_parameter(parameter)
      @filter_parameters ||= []
      @filter_parameters << parameter
    end

    def instrument(name, params={}, &block)
      headers = params[:headers]
      case name
      when "excon.error"
        $stderr.puts params[:error].message
      when "excon.request"
        $stderr.print "HTTP #{params[:method].upcase} #{params[:scheme]}://#{params[:host]}#{params[:path]} "
        $stderr.print "[auth] " if headers['Authorization'] && headers['Authorization'] != 'Basic Og=='
        $stderr.print "[2fa] " if headers['Heroku-Two-Factor-Code']
        $stderr.puts filter(params[:query])
      when "excon.response"
        $stderr.puts "#{params[:status]} #{params[:reason_phrase]}"
        $stderr.puts "request-id: #{headers['Request-id']}" if headers['Request-Id']
        if headers['Content-Encoding'] == 'gzip'
          $stderr.puts filter(ungzip(params[:body]))
        else
          $stderr.puts filter(params[:body])
        end
      else
        $stderr.puts name
      end
      yield if block_given?
    end

    private

    def ungzip(string)
      Zlib::GzipReader.new(StringIO.new(string)).read()
    end

    def filter(obj)
      string = obj.to_s
      (@filter_parameters || []).each do |parameter|
        string.gsub! parameter, '[FILTERED]'
      end
      string
    end
  end
end
