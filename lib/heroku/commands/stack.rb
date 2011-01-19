module Heroku::Command
  class Stack < BaseWithApp
    def list
      include_deprecated = true if extract_option("--all")

      list = heroku.list_stacks(app, :include_deprecated => include_deprecated)
      lines = list.map do |stack|
        row = [stack['current'] ? '*' : ' ', stack['name']]
        row << '(beta)' if stack['beta']
        row << '(prepared, will migrate on next git push)' if stack['requested']
        row.join(' ')
      end
      display lines.join("\n")
    end
    alias :index :list

    def migrate
      stack = args.shift.downcase.strip rescue nil
      if !stack
        display "Usage: heroku stack:migrate <target_stack>"
      else
        display heroku.migrate_to_stack(app, stack)
      end
    end
  end
end
