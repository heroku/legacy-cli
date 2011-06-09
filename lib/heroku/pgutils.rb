require 'heroku/pg_resolver'

module PgUtils
  include PGResolver

  def deprecate_dash_dash_db(name)
    return unless args.include? "--db"
    display " !   The --db option has been deprecated"
    usage = Heroku::Command::Help.usage_for_command(name)
    error " !   #{usage}"
  end

  def spinner(ticks)
    %w(/ - \\ |)[ticks % 4]
  end

  def ticking
    ticks = 0
    loop do
      yield(ticks)
      ticks +=1
      sleep 1
    end
  end

  def display_info(label, info)
    display(format("%-12s %s", label, info))
  end

  def munge_fork_and_follow(addon)
    %w[fork follow].each do |opt|
      if index = args.index("--#{opt}")
        val = args.delete_at index+1
        args.delete_at index

        resolved = Resolver.new(val, config_vars)
        display resolved.message if resolved.message
        abort_with_database_list(val) unless resolved[:url]

        url = resolved[:url]

        args << "#{opt}=#{url}"
      end
    end
    return args
  end

end
