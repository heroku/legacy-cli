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
    #   cedar
    # * cedar-14
    #
    def index
      validate_arguments!

      stacks_data = api.get_stack(app).body

      styled_header("#{app} Available Stacks")
      stacks = stacks_data.map do |stack|
        row = [stack['current'] ? '*' : ' ', stack['name']]
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
      unless stack = shift_argument
        error("Usage: heroku stack:set STACK.\nMust specify target stack.")
      end

      api.put_stack(app, stack)
      display "Stack set. Next release on #{app} will use #{stack}."
      display "Run `git push heroku master` to create a new release on #{stack}."
    end

    alias_command "stack:migrate", "stack:set"
  end
end
