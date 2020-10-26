module OpenChain; module Report; module ReportDateHelperSupport
  extend ActiveSupport::Concern

  # Provides a standard parsing scheme for passing date ranges via opts (Hash) params used in scheduled jobs
  # or reports
  #
  # The keys available to use are:
  # 'previous_week' - if used and the key's value is an integer, this will control how many weeks back to report on.
  #                   by default, only the specific week referenced will be reported on.
  # 'previous_month' - if used and the key's value is an integer, this will control how many months back to report on
  #                   by default, only the specific month referenced will be reported on.
  # 'previous_year' - if used and the key's value is an integer, this will control how many weeks back to report on
  #                   by default, only the specific year referenced will be reported on.
  # 'start_date' / 'end_date' - provide a specific date range.
  #
  # If 'end_date' is utilized with any of the 'previous_*' values, then the end_date returned will override the calculated
  # end_date of the previous_* algorithm.  This is how you can adjust the ending date if you want the previous_ calculation
  # to include more than just the single week/month/year calculated (like if you want to report on the last 4 years)
  #
  # Default start / end dates are utilized only if start_date / end_date values are not found.  If present and no
  # start or end date is given in the opts, then these values will be used instead.
  #
  def parse_date_range_from_opts opts, basis_date:, end_date_inclusive: true, override_start_date: nil, override_end_date: nil
    start_date = nil
    end_date = nil

    if opts['previous_day'].present?
      week_count = counter_value_from_opts(opts['previous_day'])
      start_date = (basis_date - week_count.days)
      end_date = start_date
    elsif opts['previous_week'].present?
      week_count = counter_value_from_opts(opts['previous_week'])
      start_date = (basis_date - week_count.weeks).beginning_of_week(:sunday)
      end_date = start_date.end_of_week(:sunday)
    elsif opts['previous_month'].present?
      month_count = counter_value_from_opts(opts['previous_month'])
      start_date = (basis_date - month_count.months).beginning_of_month
      end_date = start_date.end_of_month
    elsif opts['previous_year'].present?
      year_count = counter_value_from_opts(opts['previous_year'])
      start_date = (basis_date - year_count.years).beginning_of_year
      end_date = start_date.end_of_year
    else
      start_date = date_value(opts['start_date'])
    end

    # If the end date should not be considered inclusive of the range then we want to add a single day
    # This would take the range from something like 2020-01-01 thru 2020-01-31 to 2020-01-01 thru 2020-02-01
    if end_date && !end_date_inclusive
      end_date += 1.day
    end

    # If an actual end date is given, we don't want to adjust it w/ inclusivity
    end_date = date_value(opts['end_date']) if opts['end_date'].present?

    start_date = override_start_date if override_start_date.present?
    end_date = override_end_date if override_end_date.present?

    raise ArgumentError, "Could not determine start / end date range from given parameters: #{opts}" if start_date.nil? || end_date.nil?

    [start_date, end_date]
  end

  def date_value value
    # TODO - Allow parsing some expressions like "now", "beginning_of_week", "end_of_week", etc using the basis_date value given to the opts
    # in parse_date_range_from_opts
    return default_value if value.blank?

    Date.parse(value)
  end

  def counter_value_from_opts opts_value
    opts_value.respond_to?(:to_i) ? opts_value.to_i : 1
  end

end; end; end