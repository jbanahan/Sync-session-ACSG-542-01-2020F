class CustomReportIsfStatus < CustomReport

  validate :criterions_contain_customer_number?

  def self.template_name
    "ISF Status"
  end

  def self.description
    "Shows ISF Data for customers on first tab and all unmatched ISFs for last 90 days for the same customer on a second tab."
  end

  def self.column_fields_available user
    CoreModule::SECURITY_FILING.model_fields(user).values
  end

  def self.criterion_fields_available user
    CoreModule::SECURITY_FILING.model_fields_including_children(user).values
  end

  def self.can_view? user
    user.view_security_filings?
  end

  def run run_by, row_limit = nil
    validate_access run_by
    criterions_contain_customer_number? true

    search_columns = self.search_columns
    isfs = setup_report_query SecurityFiling, run_by, row_limit

    add_tab "ISF Report Data"
    write_headers 0, search_columns, run_by
    write_query isfs, search_columns, run_by
    unless preview_run
      # The second tab shows all the unmatched ISF's for the customers returned by the customer number
      # search criterion from the last 90 days.
      days_ago = (Time.zone.now - 90.days).midnight
      cust_no = find_cust_number_criterion

      isfs = SecurityFiling.search_secure run_by, SecurityFiling.select("DISTINCT security_filings.*").where("file_logged_date > ?", days_ago).not_matched
      isfs = cust_no.apply isfs
      isfs.limit(row_limit) if row_limit

      add_tab "Unmatched #{days_ago.strftime("%m-%d-%y")} thru #{Time.zone.now.strftime("%m-%d-%y")}"
      write_headers 0, search_columns, run_by
      write_query isfs, search_columns, run_by
    end
  end

  private 

    def write_query isfs, search_columns, run_by
      row_number = 0
      isfs.each do |isf|
        write_row (row_number += 1), isf, search_columns, run_by
      end

      if row_number == 0
        write_no_data 1
      end
      nil
    end

    def criterions_contain_customer_number? raise_error = false
      cust_no = find_cust_number_criterion
      unless cust_no && !cust_no.marked_for_destruction?
        e = "This report must include the #{ModelField.find_by_uid(:sf_broker_customer_number).label} parameter."
        if raise_error
          raise e
        else
          errors[:base] << e
        end
      end
    end

    def find_cust_number_criterion
      search_criterions.find {|sc| sc.model_field_uid == "sf_broker_customer_number"}
    end
end