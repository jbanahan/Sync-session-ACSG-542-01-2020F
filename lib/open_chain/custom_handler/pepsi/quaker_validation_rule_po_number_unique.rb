module OpenChain; module CustomHandler; module Pepsi   
  class QuakerValidationRulePoNumberUnique < BusinessValidationRule

    def run_validation entry
      to_be_checked = entry.commercial_invoice_lines.map{ |cil| cil.po_number if cil.po_number =~ /^C\d{6}$/ }.compact
      matches = find_other_entry_matches(entry.id, to_be_checked) if to_be_checked.presence
      message = ""
      if matches.presence
        list = []
        matches.each { |m| list << "#{m['po_number']} on entry #{m['entry_number']}" }
        message << "The following po numbers appear on other entries:\n#{list.join(", ")}"
      end
      message.presence
    end

    private

    def find_other_entry_matches entry_id, po_nums
      qry = <<-SQL
        SELECT cil.po_number, e.entry_number
        FROM entries e
          INNER JOIN commercial_invoices ci ON e.id = ci.entry_id
          INNER JOIN commercial_invoice_lines cil ON ci.id = cil.commercial_invoice_id
        WHERE (e.customer_number = "QSD" OR e.customer_number = "QSDI")
          AND cil.po_number IN (#{po_nums.map{ |num| "\"#{num}\"" }.join(", ")})
          AND e.id <> #{entry_id}
      SQL
      results = ActiveRecord::Base.connection.exec_query qry
      results unless results.count.zero?
    end
  end
end; end; end