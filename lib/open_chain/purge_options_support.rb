module OpenChain; module PurgeOptionsSupport
  extend ActiveSupport::Concern

  module ClassMethods

    def execute_purge opts, default_years_ago:
      start_date = parse_date_from_options(opts, default_years_ago: default_years_ago)
      self.purge older_than: start_date
    end

    def default_timezone
      "America/New_York"
    end

    # All methods after this should really be considered private - they're implementation details
    # of the options parsing

    def parse_date_from_options options, default_years_ago:, current_time: Time.zone.now
      tz = timezone_from_opts(options, default_timezone)
      tz = default_timezone if tz.nil?

      current_time = current_time.in_time_zone(tz).beginning_of_day

      if options["years_old"]
        years_ago = counter_value_from_opts(options["years_old"])
      else
        years_ago = default_years_ago
      end

      start_date = current_time - years_ago.years

      start_date
    end

    def counter_value_from_opts opts_value
      if opts_value.to_s =~ /^\d+$/
        opts_value.to_i
      else
        raise ArgumentError, "Invalid year counter value: #{opts_value}."
      end
    end

    def timezone_from_opts opts, default_timezone
      ActiveSupport::TimeZone[(opts["time_zone"].presence || default_timezone)]
    end

  end

end; end
