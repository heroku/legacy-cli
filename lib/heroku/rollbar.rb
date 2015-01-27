module Rollbar
  extend Heroku::Helpers

  def self.error(e)
    payload = json_encode(build_payload(e))
    response = Excon.post('https://api.rollbar.com/api/1/item/', :body => payload)
    response = json_decode(response.body)
    raise response if response["err"] != 0
    response["result"]["uuid"]
  rescue => e
    $stderr.puts "Error submitting error."
    error_log(e.message, e.backtrace.join("\n"))
    nil
  end

  private

  def self.build_payload(e)
    if e.is_a? Exception
      build_trace_payload(e)
    else
      build_message_payload(e.to_s)
    end
  end

  def self.build_trace_payload(e)
    payload = base_payload
    payload[:data][:body] = {:trace => trace_from_exception(e)}
    payload
  end

  def self.build_message_payload(message)
    payload = base_payload
    payload[:data][:body] = {:message => {:body => message}}
    payload
  end

  def self.base_payload
    {
      :access_token => 'f9ca108fdb4040479d539c7a649e2008',
      :data => {
        :platform => 'client',
        :environment => 'production',
        :code_version => Heroku::VERSION,
        :client => { :platform => RUBY_PLATFORM },
        :request => { :command => ARGV[0] }
      }
    }
  end

  def self.trace_from_exception(e)
    {
      :frames => frames_from_exception(e),
      :exception => {
        :class => e.class.to_s,
        :message => e.message
      }
    }
  end

  def self.frames_from_exception(e)
    e.backtrace.map do |line|
      filename, lineno, method = line.scan(/(.+):(\d+):in `(.*)'/)[0]
      { :filename => filename, :lineno => lineno.to_i, :method => method }
    end
  end
end
