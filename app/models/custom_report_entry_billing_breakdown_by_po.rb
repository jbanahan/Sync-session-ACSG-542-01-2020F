class CustomReportEntryBillingBreakdownByPo < CustomReport

	def self.template_name
    "Entry Billing Breakdown By PO"
  end

  def self.description
    "Shows Broker Invoices with each charge in its own column and charge code amounts prorated across the number of PO's on the invoice."
  end

  def self.column_fields_available user
  	#Exclude all fields that start with "Total" as well as "Cotton Fee", "HMF", "MPF".
    CoreModule::BROKER_INVOICE.model_fields(user).values.select {|mf| valid_model_field mf}
  end

  def self.valid_model_field mf
    # This method is split out primarily just for testing...
    !["COTTON FEE", "HMF", "MPF"].include?(mf.label.upcase) && !(mf.label =~ /^total/i)
  end

  def self.criterion_fields_available user
    column_fields_available user
  end

  def self.can_view? user
    user.view_broker_invoices?
  end

  def run user, row_limit = nil
    raise "User #{user.email} does not have permission to view invoices and cannot run the #{CustomReportEntryBillingBreakdownByPo.template_name} report." unless user.view_broker_invoices?

    search_cols = self.search_columns.order("rank ASC")
    invoices = BrokerInvoice.select("distinct broker_invoices.*")
    self.search_criterions.each {|sc| invoices = sc.apply(invoices)}
    invoices = BrokerInvoice.search_secure user, invoices
    invoices = invoices.limit(row_limit) if row_limit
    # Make sure there's a defined order by here so that all the invoices for the same entry are grouped together
    invoices = invoices.order("entries.broker_reference, broker_invoices.invoice_date ASC")

    row = 1
    col = 0
    if invoices.empty?
      write row, col, "No data was returned for this report."
      row += 1
    end

    # The charge description columns stuff is done here so we can determine all the charge codes that are on the report
    # This allows us to know exactly how many columns the output of the charge codes
    # is going to be and allows us to then put user-defined columns after the hard coded ones.

    # Considering we've already got all the invoices in memory, doing this should be a negligable performance hit.
    description_columns = []
    invoices.each do |inv|
      iterate_invoice_lines(inv) do |line, description|
        description_columns << description unless description_columns.include?(description)
      end
    end

    invoices.each do |inv|
      invoice_number = fix_invoice_number inv
      po_numbers = split_po_numbers inv.entry

      charge_totals = {}
      iterate_invoice_lines(inv) do |line, description|
        unless charge_totals[description]
          charge_totals[description] = {}
          charge_totals[description][:total] = BigDecimal.new("0")
        end

        charge_totals[description][:total] += line.charge_amount
      end

      charge_totals.each_key do |k|
      	# This charge_values amount stuff is there to handle the case where, due to rounding the prorated amount you may
      	# be left with the need to tack on an extra penny on the last line for the PO (ie. 100 / 3 lines = 33.33, 33.33, 33.34)
      	charge_values = charge_totals[k]
      	charge_values[:remaining_invoice_amount] = BigDecimal.new(charge_values[:total])
      	charge_values[:even_split_amount] = (charge_values[:total] / po_numbers.length).round(2, BigDecimal::ROUND_DOWN)
    	end
      
      po_numbers.each_with_index do |po, i|
        col = 0
        cols = []

        if self.include_links?
          write_hyperlink row, col, inv.entry.view_url, "Web View"
          col += 1
        end

        cols << inv.entry.broker_reference
        cols << invoice_number 
        cols << po

        total_charges_per_po = BigDecimal.new("0")
        po_charge_amounts = []

        # We need to include every single charge descripion on each row of the report 
        # even if the invoice didn't have one of these charges on it to keep the report output having
        # the same # of cols per each invoice (othewise, chaos ensues - dogs and cats living together, mass hysteria)
        description_columns.each do |description|
        	po_value = 0.0
        	charge_values = charge_totals[description]
        	if charge_values
        		if i < (po_numbers.length - 1) 
		          po_value = charge_values[:even_split_amount]
		          charge_values[:remaining_invoice_amount] -= charge_values[:even_split_amount]
		        else 
		          po_value = charge_values[:remaining_invoice_amount]
		        end
        	end
	        total_charges_per_po += po_value
	        po_charge_amounts << po_value.round(2)
        end

        cols << total_charges_per_po
        po_charge_amounts.each do |amount|
        	cols << amount
        end

        search_cols.each do |c|
          cols << c.model_field.process_export(inv, user)
        end
        
        write_columns row, col, cols
        row += 1
      end
    end    

    col = 0
    heading_row 0
    if self.include_links?
      write 0, col, "Web Links"
      col += 1
    end

    write_columns 0, col, (["Broker Reference", "Invoice Number", "PO Number", "PO Total"] \
    		+ description_columns \
        + search_cols.collect {|c| c.model_field.label})
  end

  private

    def fix_invoice_number inv
      invoice_number = inv.invoice_number
      if invoice_number.blank?
        invoice_number = entry.broker_reference
        invoice_number << inv.suffix unless inv.suffix.blank?
      end
      invoice_number
    end

    def iterate_invoice_lines inv
      inv.broker_invoice_lines.each do |line|
        yield line, format_charge_description(line.charge_description) if useable_charge_type(line.charge_type)
      end
    end

	  def split_po_numbers entry 
	    # split returns a 0-length array on a blank string..hence the space
	    po_numbers = (entry.po_numbers.nil? || entry.po_numbers.length == 0) ? " " : entry.po_numbers
	    po_numbers.split("\n").collect! {|x| x.strip}
	  end

	  def useable_charge_type code
	  	#Skip all Duty (D), charge types
	  	code.nil? || code.upcase != "D"
	  end

	  def format_charge_description charge_description
	  	# We want all charges that are for ISF to appear under a single charge description
      if charge_description
        charge_description.upcase.starts_with?("ISF") ? "ISF" : charge_description
      else
        ""
      end
	  end


end