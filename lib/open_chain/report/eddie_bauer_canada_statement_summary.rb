module OpenChain; module Report; class EddieBauerCaStatementSummary

  def self.permission? user
    (Rails.env.development? || MasterSetup.get.system_code=='www-vfitrack-net') && user.company.master?
  end

  def self.run_report run_by, params = {}
    params = HashWithIndifferentAccess.new params
    start_date = params[:start_date].to_date
    end_date = params[:end_date].to_date

    customer_number = "EBCC"

    importer = Company.where(alliance_customer_number: customer_number).first

    raise "No company record found for customer number '#{customer_number}'" unless importer

    wb = XlsMaker.create_workbook "Billing Summary #{start_date} - #{end_date}", 
      ["Statement #","ACH #","Entry #","PO","Business","Invoice","Duty Rate","Duty","Taxes / Fees","Fees","ACH Date","Statement Date","Release Date","Unique ID", "LINK"]

    cursor = 0

    # TODO Make sure this runs relative to user's timezone for the user and uses same date semantics as the standard statement summary
    entries = Entry.where(customer_number: customer_number).
                joins(:broker_invoices).
                includes(:commercial_invoices => [:commercial_invoice_lines => [:commercial_invoice_tariffs]])
                where("entries.entry_filed_date >= ? ", start_date)
                where("entries.entry_filed_date <= ?", end_date).
                order("entries.entry_filed_date ASC")

    entries.each do |entry|
      row = []
      row << ent.monthly_statement_number
      row << ent.daily_statement_number
      row << ent.entry_number
      row << 
    end

  end


end; end; end