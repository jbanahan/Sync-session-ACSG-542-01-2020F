module OpenChain; module CustomHandler; module Pepsi   
  class QuakerValidationRuleInvoiceNumberUnique < BusinessValidationRule

    def run_validation entry
      to_be_checked = entry.commercial_invoices.map{ |inv| inv.invoice_number if inv.invoice_number =~ /^C\d{6}$/ }.compact
      matches = find_other_entry_matches(entry.id, to_be_checked) if to_be_checked.presence
      message = ""
      if matches.presence
        list = []
        matches.each { |m| list << "#{m['invoice_number']} on entry #{m['entry_number']}" }
        message << "The following invoice numbers appear on other entries:\n#{list.join(", ")}"
      end
      message.presence
    end

    private

    def find_other_entry_matches entry_id, invoice_nums
      qry = <<-SQL
        SELECT ci.invoice_number, e.entry_number
        FROM entries e
          INNER JOIN commercial_invoices ci ON e.id = ci.entry_id
        WHERE (e.customer_number = "QSD" OR e.customer_number = "QSDI")
          AND ci.invoice_number IN (#{invoice_nums.map{ |num| "\"#{num}\"" }.join(", ")})
          AND e.id <> #{entry_id}
      SQL
      results = ActiveRecord::Base.connection.exec_query qry
      results unless results.count.zero?
    end
  end
end; end; end