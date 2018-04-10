# == Schema Information
#
# Table name: business_validation_rules
#
#  business_validation_template_id :integer
#  created_at                      :datetime         not null
#  delete_pending                  :boolean
#  description                     :string(255)
#  disabled                        :boolean
#  fail_state                      :string(255)
#  group_id                        :integer
#  id                              :integer          not null, primary key
#  name                            :string(255)
#  notification_recipients         :text
#  notification_type               :string(255)
#  rule_attributes_json            :text
#  type                            :string(255)
#  updated_at                      :datetime         not null
#
# Indexes
#
#  template_id  (business_validation_template_id)
#

class ValidationRuleEntryInvoiceChargeCode < BusinessValidationRule
  
  # options: 
  # {'charge_codes': [...]} white-listed
  # {'blacklist_charge_codes': [...]} blacklisted (overridden by 'charge_codes')
  # {'filter': 'suffix' | 'no_suffix'} applies check only to invoices with/without a suffix. All are included by default

  def run_validation entry
    if rule_attributes['charge_codes']
      list = rule_attributes['charge_codes']
      list_type = :white
    else
      list = rule_attributes['blacklist_charge_codes']
      list_type = :black
    end
    code_count = query(entry.id, rule_attributes['filter'])
    invalid_codes = check_list(code_count, list, list_type)
    if invalid_codes.presence
      "The following invalid charge codes were found: #{invalid_codes.join(', ')}" 
    end
  end

  def check_list code_count, list, list_type
    invalid_codes = []
    code_count.each do |tally| 
      unless tally['amount'].zero?
        if list_type == :white
          invalid_codes << tally['charge_code'] if !list.include? tally['charge_code']
        else
          invalid_codes << tally['charge_code'] if list.include? tally['charge_code']
        end
      end
    end
    invalid_codes
  end

  def query entry_id, filter=nil
    if filter == 'suffix'
      clause = "AND (bi.suffix IS NOT NULL AND bi.suffix <> '')"
    elsif filter == 'no_suffix'
      clause = "AND (bi.suffix IS NULL OR bi.suffix = '')"
    else
      clause = ''
    end
    ActiveRecord::Base.connection.exec_query(sql entry_id, clause)
  end

  private
  
  def sql entry_id, clause
    <<-SQL
      SELECT bil.charge_code, SUM(bil.charge_amount) amount
      FROM entries e 
        INNER JOIN broker_invoices bi ON e.id = bi.entry_id
        INNER JOIN broker_invoice_lines bil ON bi.id = bil.broker_invoice_id
      WHERE e.id = #{entry_id}
      #{clause}
      GROUP BY bil.charge_code
      ORDER BY bil.charge_code
    SQL
  end
end
