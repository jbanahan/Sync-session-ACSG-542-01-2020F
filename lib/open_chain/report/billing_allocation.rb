class OpenChain::Report::BillingAllocation
  QUERY = 

  def self.run params
    BillingAllocation.new(params).execute
  end

  def init params
    @start_date = params[:start_date]
    @end_date = params[:end_date]
    @customer_numbers = params[:customer_numbers]
    @country_ids = params[:country_ids]
    @country_ids = Country.pluck(:id).where("iso_code IN (\"US\",\"CA\")") if @coutntry_ids.nil?
  end

  def execute
    res = get_result
  end

  def get_result
    qry = "SELECT ent.entry_number, bi.invoice_date, ent.release_date, bi.id, bil.id, bil.charge_type, ci.id, cil.id, 
bi.suffix, bil.charge_description, bil.charge_code, bil.charge_amount, ent.entered_value,
cit.entered_value, cil.po_number, cil.part_number, cil.quantity, cit.duty_amount,
ent.master_bills_of_lading, ent.container_numbers, ent.arrival_date, ent.release_date, ci.invoice_number
FROM broker_invoices bi
LEFT OUTER JOIN entries ent ON bi.entry_id = ent.id
LEFT OUTER JOIN commercial_invoices ci ON ci.entry_id = ent.id
LEFT OUTER JOIN commercial_invoice_lines cil ON cil.commercial_invoice_id = ci.id
LEFT OUTER JOIN commercial_invoice_tariffs cit ON cit.commercial_invoice_line_id = cil.id
LEFT OUTER JOIN broker_invoice_lines bil ON bil.broker_invoice_id = bi.id
WHERE ent.import_country_id IN (#{ActiveRecord::Base.sanitize(@country_ids)}) and length(cil.po_number) > 0
AND (NOT bil.charge_type = \"D\")
AND bi.invoice_date between #{ActiveRecord::Base.sanitize(@start_date)} 
AND #{ActiveRecord::Base.sanitize(@end_date)} 
AND ent.customer_number IN (#{ActiveRecord::Base.sanitize(@customer_numbers)})
ORDER BY ent.entry_number, ci.id, cil.id, bi.id, bil.id"  
  end
end
