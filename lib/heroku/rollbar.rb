module Rollbar
  extend Heroku::Helpers

  def self.error(e)
    payload = {
      :access_token => 'f9ca108fdb4040479d539c7a649e2008',
      :data => {
        :platform => 'client',
        :environment => 'production',
        :code_version => Heroku::VERSION,
        :client => { :platform => RUBY_PLATFORM },
        :request => { :command => ARGV.join(' ') },
        :body => { :trace => trace_from_exception(e) }
      }
    }
    response = Excon.post('https://api.rollbar.com/api/1/item/', :body => json_encode(payload))
    json_decode(response.body)["result"]["uuid"]
  rescue
    $stderr.puts "Error submitting error."
    nil
  end

  private

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
