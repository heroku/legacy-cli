module Heroku::Command
  class Tail < Logs
    def index
      if args.any? { |a| a.downcase == '-f' }
        args << "--tail"
      end
      super
    end
  end
end