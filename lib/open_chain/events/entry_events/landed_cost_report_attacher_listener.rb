require 'tempfile'

# This entry event listener runs a landed cost report for the entry 
# and then attaches the output of the report to entry as an attachment.
# 
module OpenChain; module Events; module EntryEvents
  class LandedCostReportAttacherListener

    def accepts? event, entry
      process = false
      if entry
        process = jjill_with_0600_charges entry
      end
      process
    end

    def receive event, entry
      landed_cost_report = LocalLandedCostsController.new.show(entry.id)
      Tempfile.open(["LandedCost", ".html"]) do |f|
        Attachment.add_original_filename_method f
        f.original_filename = "Landed Cost - #{entry.broker_reference}.html"
        f << landed_cost_report
        f.flush

        att = entry.attachments.build
        att.attached = f
        att.attachment_type = "Landed Cost Report"
        att.save!

        # Delete any other existing landed cost report
        entry.attachments.where("NOT attachments.id = ?",att.id).where(:attachment_type=>att.attachment_type).destroy_all

        # Reload the entry attachments so we have the correct attachments list for anyhting later in the 
        # listener call chain
        entry.attachments.reload
      end

      # Return the entry so anything running after this will see the updated attachments
      entry
    end

    private 

      def jjill_with_0600_charges entry
        if entry.customer_number == "JILL"
          # Make sure we have a broker invoice charge with a code of '0600'
          entry.broker_invoices.each do |inv|
            inv.broker_invoice_lines.each do |line|
              return true if line.charge_code == "0600"
            end
          end
        end
        return false
      end
  end
end; end; end