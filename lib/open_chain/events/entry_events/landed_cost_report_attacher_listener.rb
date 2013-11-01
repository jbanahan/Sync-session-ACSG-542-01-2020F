require 'tempfile'
require 'open_chain/report/landed_cost_data_generator'

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
      landed_cost_data = OpenChain::Report::LandedCostDataGenerator.new.landed_cost_data_for_entry entry
      landed_cost_checksum = calculate_landed_cost_checksum landed_cost_data

      attachment_type = "Landed Cost Report"

      # See if we have another landed cost file that matches this checksum, if we do, then 
      # we can just continue on as the landed cost report is already attached to this entry.
      unless entry.attachments.where(checksum: landed_cost_checksum, attachment_type: attachment_type).first

        landed_cost_report = LocalLandedCostsController.new.show_landed_cost_data landed_cost_data

        Tempfile.open(["LandedCost", ".html"]) do |f|
          Attachment.add_original_filename_method f
          f.original_filename = "Landed Cost - #{entry.broker_reference}.html"
          f << landed_cost_report
          f.flush

          att = entry.attachments.build
          att.attached = f
          att.attachment_type = attachment_type
          att.checksum = landed_cost_checksum
          att.save!

          # Delete any other existing landed cost report
          entry.attachments.where("NOT attachments.id = ?", att.id).where(:attachment_type=>att.attachment_type).destroy_all

          # Run this as a delayed job since downloading from S3 / Pushing to google will delay processing
          # for at least a second or two.  In the interest of keeping the execution time of this thing
          # down, we'll just push doing this off to another queue.
          Attachment.delay.push_to_google_drive "JJill Landed Cost", att.id

          # Reload the entry attachments so we have the correct attachments list for anyhting later in the 
          # listener call chain
          entry.attachments.reload
        end
      end

      # Return the entry so anything running after this will see the updated attachments
      entry
    end

    def calculate_landed_cost_checksum landed_cost_data
      # Ultimately, what we care about checksum'ing is the entry numbers + invoice numbers + per unit landed cost data.
      # Since all the other data on the sheet revolves around calculations using the per unit values as the basis, we
      # should be fine simply grabbing only this data to use as our fingerprint data.

      # We have to make sure that we always process the data in the same order (regardless of how the actual backend
      # splits it out) so we're going to make sure to sort the invoices and invoice lines from the result before 
      # processing a checksum for them.

      # We should then be able to keep the data formats consistent by extracting the values we want
      # and making json from it and calculating a SHA-1 hash from the resulting json string.

      per_unit_columns_to_copy = [:entered_value, :duty, :fee, :international_freight, :inland_freight, :brokerage, :other].sort

      # First, copy all the data we're after to a new structure.
      lc_copy = {}
      lc_copy[:entries] = []
      landed_cost_data[:entries].sort_by{|e| e[:broker_reference]}.each do |entry_data|
        lc_copy[:entries] << {}
        lc_copy[:broker_reference] = entry_data[:broker_reference]
        lc_copy[:commercial_invoices] = []
        entry_data[:commercial_invoices].sort_by{|ci| ci[:invoice_number]}.each do |invoice_data|
          inv_copy = {}
          lc_copy[:commercial_invoices] << inv_copy
          inv_copy[:invoice_number] = invoice_data[:invoice_number]
          inv_copy[:commercial_invoice_lines] = []
          invoice_data[:commercial_invoice_lines].sort_by {|l| l[:po_number].to_s + l[:part_number].to_s + l[:quantity].to_s}.each do |line_data|
            line_copy = {}
            inv_copy[:commercial_invoice_lines] << line_copy

            per_unit_columns_to_copy.each do |c|
              line_copy[c] = line_data[:per_unit][c]
            end
          end
        end
      end

      # Be careful, if anyting about the to_json implementation's encoded output is changed then the checksum here
      # is going to change too - for instance the recent ActiveSupport::JSON change to no longer escape unicode 
      # characters like \uXXXX would cause different checksums if there were unicode characters in the data 
      # stream (there won't be though since the data is from alliance and alliance doesn't support non-ascii charsets).
      Digest::SHA1.hexdigest(lc_copy.to_json)
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
