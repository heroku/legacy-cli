require "heroku/command/base"

module Heroku::Command

  # manage the stack for an app
  class Stack < Base

    # stack
    #
    # show the list of available stacks
    #
    #Example:
    #
    # $ heroku stack
    # === example Available Stacks
    #   cedar-10
    # * cedar-14
    #
    def index
      validate_arguments!

      stacks_data = api.get_stack(app).body

      styled_header("#{app} Available Stacks")
      stacks = stacks_data.map do |stack|
        row = [stack['current'] ? '*' : ' ', Codex.out(stack['name'])]
        row << '(beta)' if stack['beta']
        row << '(deprecated)' if stack['deprecated']
        row << '(prepared, will migrate on next git push)' if stack['requested']
        row.join(' ')
      end
      styled_array(stacks)
    end

    # stack:set STACK
    #
    # set new app stack
    #
    def set
      unless stack = Codex.in(shift_argument)
        error("Usage: heroku stack:set STACK.\nMust specify target stack.")
      end

      api.put_stack(app, stack)
      display "Stack set. Next release on #{app} will use #{Codex.out(stack)}."
      display "Run `git push heroku master` to create a new release on #{Codex.out(stack)}."
    end

    alias_command "stack:migrate", "stack:set"

    module Codex
      def self.in(stack)
        IN[stack] || stack
      end

      def self.out(stack)
        OUT[stack] || stack
      end

      # Legacy translations for cedar => cedar-10
      # only here for UX purposes to avoid confusion
      # when we say `Sunsetting cedar`.
      IN = {
        "cedar-10" => "cedar"
      }

      OUT = {
        "cedar" => "cedar-10"
      }
    end
  end
end
