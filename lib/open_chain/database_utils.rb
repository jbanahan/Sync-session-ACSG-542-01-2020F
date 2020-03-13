module OpenChain; class DatabaseUtils

  def self.deadlock_error? error
    # We can return immediately if we got this error, it's the transaction_isolation gems
    # indicator for a deadlock
    return true if error.is_a?(ActiveRecord::TransactionIsolationConflict)

    # Stupid ActiveRecord returns basically every single error from your database as a StatementInvalid error, 
    # you can get at the underlying error through the Exception#cause method.  Extract that if there is one.
    if error.is_a?(ActiveRecord::StatementInvalid)
      error = error.cause unless error.cause.nil?
    end

    if error.is_a?(ActiveRecord::StatementInvalid)
      case error.message
      when /Mysql2::Error/
        return mysql_deadlock_error?(error)
      else
        return false
      end
    elsif error.is_a?(Mysql2::Error)
      mysql_deadlock_error?(error)
    else
      return false
    end
  end

  def self.primary_database_configuration
    parse_database_config
  end

  def self.mysql_deadlock_error_message? message
    [ "Deadlock found when trying to get lock",
          "Lock wait timeout exceeded"].any? do |error_message|
      message =~ /#{Regexp.escape( error_message )}/i
    end
  end

  # Private class methods
  class << self

    private

      def parse_database_config
        config = database_config.with_indifferent_access
        # Our database config can be a simple one or a complex one using distribute_reads / makara
        if config["makara"]
          parse_makara_config(config)
        else
          parse_standard_config(config)
        end
      end

      # Looking to create a hash with adapter, host, database, port, username
      def parse_standard_config config
        if config["url"]
          config = config.merge parse_url_db_connection(config["url"])
        end

        config_hash(config)
      end

      def parse_makara_config config
        # don't need to require makara...if the database config is using it then it should be required already
        mconfig = Makara::ConfigParser.new config
        master_config = Array.wrap(mconfig.master_configs).first.with_indifferent_access

        if master_config["url"]
          master_config = master_config.merge parse_url_db_connection master_config["url"]
        end

        # I want the outer adapter...the one that ends with _makara to be returned, not the inner adapter
        # for the primary
        if config["adapter"]
          master_config["adapter"] = config["adapter"]
        end
        config_hash(master_config)
      end

      def config_hash config
        {adapter: config["adapter"], host: config["host"], database: config["database"], port: config["port"], username: config["username"], encoding: config["encoding"], collation: config["collation"]}.with_indifferent_access
      end

      def database_config
        config = Rails.configuration.database_configuration[Rails.env]
        raise "No database configuration discovered!  Verify config/database.yml exists." if config.blank?
        config
      end

      def parse_url_db_connection url
        # Makara's url config parser is basically just the same as rails, I'm using it because apparently Rail's config parser's namespace
        # has jumped around through versions 3-5.  This provides a consistent location for a parser that handles url configs
        require 'makara/config_parser'
        Makara::ConfigParser::ConnectionUrlResolver.new(url).to_hash.with_indifferent_access
      end

      def mysql_deadlock_error? error
        mysql_deadlock_error_message?(error.message)
      end
  end

end; end;