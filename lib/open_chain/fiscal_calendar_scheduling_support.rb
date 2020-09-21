module OpenChain; module FiscalCalendarSchedulingSupport

  MONTHLY_SCHEDULING = 1
  QUARTERLY_SCHEDULING = 2
  BIANNUAL_SCHEDULING = 3

  # This method can be used from scheduled jobs, it's essentially a passthrough to #run_if_fiscal_day with
  # the parameters for that method coming from a scheduled job's config hash.
  #
  # The typical way you'd utilize this method is to use this method in your run_scheduled method implemention:
  #
  # def self.run_scheduled config
  #   run_if_configured(config) do |fiscal_month, fiscal_date|
  #      run_my_job(fiscal_month)
  #   end
  # end
  #
  # By default this method will execute if the current date is the 'fiscal_day' of the current fiscal month.
  # i.e. if you want to run on the 5th fiscal day of the month, provide a 'fiscal_day' value of '5'.
  # Alternatively, this can be run on day x of a fiscal quarter, rather than monthly, by specifying a 'true'
  # value for 'quarterly'.  Similarly, a report can be run on day x of a fiscal half-year with 'biannually'.
  # 'biannually' beats 'quarterly' if both are true.
  def run_if_configured config
    timezone = config["relative_to_timezone"].presence || "America/New_York"
    relative_to_start = (config["relative_to_start"].presence || true).to_s.to_boolean
    fiscal_day = config["fiscal_day"].to_i.zero? ? 1 : config["fiscal_day"].to_i
    sched_type = scheduling_type(config)

    run_if_fiscal_day(config["company"], fiscal_day, relative_to_timezone: timezone, relative_to_start: relative_to_start, scheduling_type: sched_type) do |fiscal_month, fiscal_date|
      yield fiscal_month, fiscal_date
    end
  end

  def run_if_fiscal_day importer, day, current_time: Time.zone.now, relative_to_timezone: "America/New_York", relative_to_start: true, scheduling_type: MONTHLY_SCHEDULING
    fiscal_month, fiscal_date = FiscalCalculations.current_fiscal_month(importer, current_time, relative_to_timezone, scheduling_type)
    return false unless fiscal_month

    # Subtract 1 from day to ensure that the first day of the fiscal month corresponds to 1 rather than 0
    day_count = relative_to_start ? (fiscal_month.start_date + (day - 1).days) : (fiscal_month.end_date - (day - 1).days)

    if day_count == fiscal_date
      yield fiscal_month, fiscal_date
      return true
    else
      return false
    end
  end

  # Gets the starting and ending dates to the fiscal quarter the provided fiscal month belongs to.
  # It is assumed that fiscal_month is not nil.
  def self.get_fiscal_quarter_start_end_dates fiscal_month
    first_month = FiscalCalculations.get_first_month_of_quarter fiscal_month
    last_month = FiscalCalculations.get_last_month_of_quarter fiscal_month
    [first_month&.start_date, last_month&.end_date]
  end

  # Gets the starting and ending dates to the fiscal half the provided fiscal month belongs to.
  # It is assumed that fiscal_month is not nil.
  def self.get_fiscal_half_start_end_dates fiscal_month
    first_month = FiscalCalculations.get_first_month_of_half fiscal_month
    last_month = FiscalCalculations.get_last_month_of_half fiscal_month
    [first_month&.start_date, last_month&.end_date]
  end

  def scheduling_type settings
    if (settings["biannually"].presence || false).to_s.to_boolean
      BIANNUAL_SCHEDULING
    elsif (settings["quarterly"].presence || false).to_s.to_boolean
      QUARTERLY_SCHEDULING
    else
      MONTHLY_SCHEDULING
    end
  end

  # This class is here mostly here to avoid polluting the method namespace with methods that the scheduling
  # support uses exclusively (.ie they'd be private methods if modules supported that)
  class FiscalCalculations

    # If scheduling type is quarterly or biannually, the month returned this will be the first month of the fiscal
    # *quarter* or *half*, which is not necessarily the current fiscal month.
    def self.current_fiscal_month importer, current_time, relative_to_timezone, scheduling_type
      importer = with_importer(importer)

      # Convert the time to the timezone we want to utilize to check the fiscal date
      if current_time.is_a?(Date)
        fiscal_date = current_time
      else
        fiscal_date = current_time.in_time_zone(relative_to_timezone).to_date
      end

      fiscal_months = importer.fiscal_months.where("start_date <= ? AND end_date >= ?", fiscal_date, fiscal_date).all
      return nil if fiscal_months.length == 0
      raise "Multiple Fiscal Months found for #{importer.name} for #{fiscal_date}." if fiscal_months.length > 1

      # If dealing with quarters or halves, return the first month of the fiscal quarter/half rather than the
      # current fiscal month.  They could very well be the same thing.
      base_month = fiscal_months.first
      case scheduling_type
      when BIANNUAL_SCHEDULING
        month = get_first_month_of_half base_month
      when QUARTERLY_SCHEDULING
        month = get_first_month_of_quarter base_month
      else
        month = base_month
      end

      [month, fiscal_date]
    end

    def self.with_importer importer
      if importer.is_a?(ActiveRecord::Base)
        importer
      elsif importer.to_i > 0
        Company.find_by_id(importer)
      else
        Company.where(system_code: importer).first
      end
    end

    def self.get_first_month_of_quarter month
      get_first_month(month, :is_first_month_of_quarter)
    end

    def self.get_first_month month, is_first_month_method
      while !send(is_first_month_method, month) do
        prev_month = month.back 1
        return nil if prev_month.nil?
        month = prev_month
      end
      month
    end

    def self.get_first_month_of_half month
      get_first_month(month, :is_first_month_of_half)
    end

    def self.get_last_month_of_quarter month
      get_last_month month, 2, :get_first_month_of_quarter
    end

    def self.get_last_month month, increment, first_month_method
      first_month = send(first_month_method, month)
      last_month = first_month&.forward increment
      last_month
    end

    def self.get_last_month_of_half month
      get_last_month month, 5, :get_first_month_of_half
    end

    # Returns true if the provided month, an integer 1-12, represents the first month of a quarter.
    # Basically, returns true if month is 1, 4, 7 or 10.
    def self.is_first_month_of_quarter month
      (month.month_number % 3) == 1
    end

    # Returns true if the provided month, an integer 1-12, represents the first month of a year half.
    # That means it's returning true if month is 1 or 7.
    def self.is_first_month_of_half month
      (month.month_number % 6) == 1
    end
  end

end; end
