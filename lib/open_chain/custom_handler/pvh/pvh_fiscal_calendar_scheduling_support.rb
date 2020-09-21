require 'open_chain/fiscal_calendar_scheduling_support'

module OpenChain; module CustomHandler; module Pvh; module PvhFiscalCalendarSchedulingSupport

  # Pull period start/end values from the settings, or default to the start/end dates of the fiscal month
  # immediately preceding the current fiscal month/quarter/half if none are provided.
  # 'fiscal_month_choice' -> yyyy-MM string, as if selected from a dropdown
  # 'current_fiscal_month' -> This FiscalMonth value comes from FiscalCalendarSchedulingSupport#run_if_configured.
  #                           For monthly reports, it'll cover the full date range the report is meant to represent.
  #                           For quarterly or biannual, it's the first month of that period.
  # 'scheduling_type' -> One of the constants from FiscalCalendarSchedulingSupport.  Allows report to cover
  #                      one fiscal month or more.  Needs for 'current_fiscal_month' to have a value to really
  #                      work properly for some modes: a fully-defaulted quarterly or biannual report range might
  #                      represent the current period rather than the desired previous one otherwise.
  # 'company_system_code' -> Company record is looked up by this system code.  An error will be raised if it's not found.
  def get_fiscal_period_dates fiscal_month_choice, current_fiscal_month, scheduling_type, company_system_code
    pvh = Company.where(system_code: company_system_code).first
    # Extremely unlikely exception.
    raise "#{company_system_code} company account could not be found." unless pvh
    if fiscal_month_choice.blank?
      fm = current_fiscal_month || FiscalMonth.get(pvh, ActiveSupport::TimeZone[time_zone].now)
      fm = fm&.back 1
      # This should not be possible unless the FiscalMonth table has not been kept up to date or is misconfigured.
      raise "Fiscal month to use could not be determined." unless fm
    else
      fiscal_year, fiscal_month = fiscal_month_choice.scan(/\w+/).map(&:to_i)
      fm = FiscalMonth.where(company_id: pvh.id, year: fiscal_year, month_number: fiscal_month).first
      # This should not be possible since the screen dropdown contents are based on the FiscalMonth table.
      raise "Fiscal month #{fiscal_month_choice} not found." unless fm
    end

    # These dates are inclusive (i.e. entries with fiscal dates occurring on them should be matched up with this month).
    if scheduling_type == FiscalCalendarSchedulingSupport::BIANNUAL_SCHEDULING
      start_date, end_date = FiscalCalendarSchedulingSupport.get_fiscal_half_start_end_dates fm
      raise "Half-year boundaries could not be determined." if !start_date || !end_date
    elsif scheduling_type == FiscalCalendarSchedulingSupport::QUARTERLY_SCHEDULING
      start_date, end_date = FiscalCalendarSchedulingSupport.get_fiscal_quarter_start_end_dates fm
      raise "Quarter boundaries could not be determined." if !start_date || !end_date
    else
      start_date = fm.start_date
      end_date = fm.end_date
    end
    [start_date.strftime("%Y-%m-%d"), end_date.strftime("%Y-%m-%d"), fm.month_number, fm.year]
  end

  def time_zone
    "America/New_York"
  end

  def filename_fiscal_descriptor fiscal_year, fiscal_month, scheduling_type
    if scheduling_type == FiscalCalendarSchedulingSupport::BIANNUAL_SCHEDULING
      "Fiscal_#{fiscal_year}-Half-#{(((fiscal_month - 1) / 6) + 1)}"
    elsif scheduling_type == FiscalCalendarSchedulingSupport::QUARTERLY_SCHEDULING
      "Fiscal_#{fiscal_year}-Quarter-#{(((fiscal_month - 1) / 3) + 1)}"
    else
      "Fiscal_#{fiscal_year}-#{fiscal_month.to_s.rjust(2, "0")}"
    end
  end

end; end; end; end