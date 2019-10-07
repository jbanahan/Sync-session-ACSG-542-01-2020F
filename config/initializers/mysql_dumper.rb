# Let's monkey patch Brillo.
# Brillo is a bit stupid because it doesn't take database port into consideration
# when running mysqldump.
#
require 'brillo'
module Brillo; class Scrubber
  private

  def explore_class(klass, tactic_or_ids, associations)
    ActiveRecord::Base.connection_pool.with_connection do
      ids = tactic_or_ids.is_a?(Symbol) ? TACTICS.fetch(tactic_or_ids).call(klass) : tactic_or_ids
      logger.info("Scrubbing #{ids.length} #{klass} rows with associations #{associations}")
      ActiveRecord::Base.connection.uncached do
        Polo.explore(klass, ids, associations).each do |row|
          yield "#{row};"
        end
      end
    end
  end
end; end

module Brillo; module Dumper; class MysqlDumper
  def dump
    db = config.db
    execute!(
        "mysqldump",
        host_arg,
        port_arg,
        "-u #{db["username"]}",
        password_arg,
        "--no-data",
        "--single-transaction", # InnoDB only. Prevent MySQL locking the whole database during dump.
        "#{db["database"]}",
        "> #{config.dump_path}"
    )
  end

  private

  def port_arg
    if (port = config.db["port"])
      "--port=#{port}"
    else
      ""
    end
  end
end; end; end
