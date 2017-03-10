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

    run_if_fiscal_day(config["company"], config["fiscal_day"].to_i, relative_to_timezone: timezone, relative_to_start: relative_to_start) do |fiscal_month, fiscal_date|
      yield fiscal_month, fiscal_date
    end
  end


  # This method will yield the applicable fiscal month if the current_time occurs on the specified day 
  # of the importer's fiscal calendar.
  #
  # .ie if you want to run on the 5th fiscal day of the month for importer: run_if_fiscal_day(importer, 5) { |fm| run_report fm.start_date, fm.end_date }
  def run_if_fiscal_day importer, day, current_time: Time.zone.now, relative_to_timezone: "America/New_York", relative_to_start: true
    fiscal_month, fiscal_date = FiscalCalculations.current_fiscal_month(importer, current_time, relative_to_timezone)
    return false unless fiscal_month

    day_count = relative_to_start ? (fiscal_month.start_date + day.days) : (fiscal_month.end_date - day.days)

    if day_count == fiscal_date
      yield fiscal_month, fiscal_date
      return true
    else
      return false
    end
  end

  # This class is here mostly here to avoid polluting the method namespace with methods that the scheduling
  # support uses exclusively (.ie they'd be private methods if modules supported that)
  class FiscalCalculations

    def self.current_fiscal_month importer, current_time, relative_to_timezone
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

      [fiscal_months.first, fiscal_date]
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
  end
  
end; end