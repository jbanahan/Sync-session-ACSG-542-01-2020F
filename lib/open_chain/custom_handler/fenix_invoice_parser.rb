module OpenChain
  module CustomHandler
    class FenixInvoiceParser
      def self.parse file_content
        last_invoice_number = ''
        rows = []
        CSV.parse(file_content,:headers=>true) do |row|
          next if row.length==0
          my_invoice_number = row[3]
          if last_invoice_number!=my_invoice_number && !rows.empty?
            self.new rows
            rows = []
          end
          rows << row
          last_invoice_number = my_invoice_number
        end
        self.new rows unless rows.empty?
      end
      
      #don't call this, use the static parse method
      def initialize rows
        BrokerInvoice.transaction do
          invoice = make_header rows.first
          invoice.invoice_total = BigDecimal('0.00')
          rows.each do |r|
            line = add_detail(invoice, r)
            invoice.invoice_total += line.charge_amount unless line.charge_type=='D'
          end
          ent = Entry.find_by_source_system_and_broker_reference invoice.source_system, invoice.broker_reference
          invoice.entry = ent if ent
          invoice.save!
        end
      end

      private 
      def make_header row
        inv = BrokerInvoice.where(:source_system=>'Fenix',:invoice_number=>row[3].strip).first_or_create!
        inv.broker_invoice_lines.destroy_all #clear existing lines
        inv.broker_reference = row[9].strip
        inv.currency = row[10].strip
        inv.invoice_date = Date.strptime row[0].strip, '%m/%d/%Y'
        inv
      end

      def add_detail invoice, row
        line = invoice.broker_invoice_lines.build(:charge_description=>row[7].strip,:charge_code=>row[6].strip,:charge_amount=>BigDecimal(row[8].strip))
        line.charge_type = (line.charge_code == '2' ? 'D' : 'R')
        line
      end
    end
  end
end
