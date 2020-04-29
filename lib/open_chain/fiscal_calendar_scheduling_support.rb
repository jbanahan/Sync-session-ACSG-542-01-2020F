module OpenChain; module FiscalCalendarSchedulingSupport

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
  def run_if_configured config
    timezone = config["relative_to_timezone"].presence || "America/New_York"
    relative_to_start = (config["relative_to_start"].presence || true).to_s.to_boolean
    quarterly = (config["quarterly"].presence || false).to_s.to_boolean
    fiscal_day = config["fiscal_day"].to_i.zero? ? 1 : config["fiscal_day"].to_i

    run_if_fiscal_day(config["company"], fiscal_day, relative_to_timezone: timezone, relative_to_start: relative_to_start, quarterly: quarterly) do |fiscal_month, fiscal_date|
      yield fiscal_month, fiscal_date
    end
  end

  # This method will yield the applicable fiscal month if the current_time occurs on the specified day
  # of the importer's fiscal calendar.
  #
  # .ie if you want to run on the 5th fiscal day of the month for importer: run_if_fiscal_day(importer, 5) { |fm| run_report fm.start_date, fm.end_date }
  #
  # Alternatively, this can be run on day x of a fiscal quarter, rather than monthly, by specifying a 'true' value for the quarterly argument.
  def run_if_fiscal_day importer, day, current_time: Time.zone.now, relative_to_timezone: "America/New_York", relative_to_start: true, quarterly: false
    fiscal_month, fiscal_date = FiscalCalculations.current_fiscal_month(importer, current_time, relative_to_timezone, quarterly)
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
  def get_fiscal_quarter_start_end_dates fiscal_month
    first_month = FiscalCalculations.get_first_month_of_quarter fiscal_month
    last_month = FiscalCalculations.get_last_month_of_quarter fiscal_month
    [first_month&.start_date, last_month&.end_date]
  end

  # This class is here mostly here to avoid polluting the method namespace with methods that the scheduling
  # support uses exclusively (.ie they'd be private methods if modules supported that)
  class FiscalCalculations

    # If 'quarterly' is true, the month returned this will be the first month of the fiscal *quarter*, which is not
    # necessarily the first day of the current fiscal month.
    def self.current_fiscal_month importer, current_time, relative_to_timezone, quarterly
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

      # If dealing with quarters, return the first month of the fiscal quarter rather than the current fiscal month.
      # They could very well be the same thing.
      month = fiscal_months.first
      if quarterly
        month = get_first_month_of_quarter month
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
      while !is_first_month_of_quarter(month) do
        prev_month = month.back 1
        return nil if prev_month.nil?
        month = prev_month
      end
      month
    end

    def self.get_last_month_of_quarter month
      first_month = get_first_month_of_quarter month
      last_month = first_month&.forward 2
      last_month
    end

    # Returns true if the provided month, an integer 1-12, represents the first month of a quarter.
    # Basically, returns true if month is 1, 4, 7 or 10.
    def self.is_first_month_of_quarter month
      (month.month_number % 3) == 1
    end
  end

end; end
