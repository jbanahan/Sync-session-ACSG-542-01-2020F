require 'open_chain/report/report_helper'
module OpenChain
  module Report
    class DrawbackAuditReport
      include OpenChain::Report::ReportHelper

      def self.permission? user
        user.drawback_view?
      end

      def run(user, settings)
        wb = Spreadsheet::Workbook.new
        sheet = wb.create_worksheet :name=>"DrawbackClaim"
        table_from_query sheet, drawback_claim_query(user, settings['drawback_claim_id'])
        workbook_to_tempfile wb, 'DrawbackClaim-'
      end

      def drawback_claim_query(user, dc_id)
        <<-SQL
          SELECT substring(drawback_claims.entry_number,4,7) as 'Invoice', 
          drawback_claims.entry_number as 'Claim', 
          a.import_entry_number as 'Entry Number', 
          i.port_code as 'Import Port', 
          a.import_date as 'Import Date', 
          h.export_ref_1 as 'Export Ref', 
          h.export_date as 'Export Date', 
          i.hts_code as 'HTS Code', 
          h.part_number as 'Part',  
          i.description as 'Description', 
          a.quantity as 'Quantity', 
          i.unit_of_measure as 'UOM', 
          i.unit_price as 'Unit Price', 
          i.rate*100 as 'Duty Rate', 
          i.duty_per_unit as '100% Duty Per Piece', 
          i.duty_per_unit * a.quantity as '100% Duty Total', 
          truncate(round(a.quantity * i.duty_per_unit, 2) * .99,2) as 'Total Claimed'
          FROM drawback_claim_audits a
          INNER JOIN drawback_claims ON a.drawback_claim_id = drawback_claims.id
          LEFT OUTER JOIN drawback_export_histories h ON h.drawback_claim_id = a.drawback_claim_id AND h.part_number = a.export_part_number AND ifnull(h.export_ref_1,'') = ifnull(a.export_ref_1,'') AND h.export_date = a.export_date
          LEFT OUTER JOIN drawback_import_lines i ON i.entry_number = a.import_entry_number AND i.part_number = a.import_part_number 
          WHERE #{DrawbackClaim.search_where(user)} AND h.drawback_claim_id = #{dc_id}
          GROUP BY a.id
        SQL
      end

      def self.run_report(user, settings = {})
        self.new.run(user, settings)
      end
    end
  end
end