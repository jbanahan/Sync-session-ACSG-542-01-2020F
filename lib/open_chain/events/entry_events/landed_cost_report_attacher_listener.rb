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
        process = jjill_with_freight_charges entry
      end
      process && MasterSetup.get.system_code == 'www-vfitrack-net'
    end

    def receive event, entry
      landed_cost_data = OpenChain::Report::LandedCostDataGenerator.new.landed_cost_data_for_entry entry

      # This is here since we're changing the checksum algorithm.  I don't want older files
      # to be affected by the change.  So anything logged after 2016-3-6 will get the new style calculations.
      if entry.file_logged_date.nil? || entry.file_logged_date.to_date >= Date.new(2016, 9, 12)
        landed_cost_checksum = calculate_landed_cost_checksum_v3 landed_cost_data
      elsif entry.file_logged_date.to_date >= Date.new(2016, 3, 6)
        landed_cost_checksum = calculate_landed_cost_checksum_v2 landed_cost_data
      else
        landed_cost_checksum = calculate_landed_cost_checksum landed_cost_data
      end

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

      per_unit_columns_to_copy = [:entered_value, :duty, :fee, :international_freight, :inland_freight, :brokerage, :other].sort

      # First, copy all the data we're after to a new structure.
      lc_data = ""
      landed_cost_data[:entries].sort_by {|e| e[:broker_reference]}.each do |entry_data|
        lc_data << entry_data[:broker_reference].to_s
        entry_data[:commercial_invoices].sort_by {|ci| ci[:invoice_number]}.each do |invoice_data|
          lc_data << invoice_data[:invoice_number].to_s
          invoice_data[:commercial_invoice_lines].sort_by {|l| l[:po_number].to_s + l[:part_number].to_s + l[:quantity].to_s}.each do |line_data|
            per_unit_columns_to_copy.each do |c|
              lc_data << line_data[:per_unit][c].to_s("F")
            end
          end
        end
      end

      Digest::SHA1.hexdigest(lc_data)
    end

    def calculate_landed_cost_checksum_v2 landed_cost_data
      # Ultimately, what we care about checksum'ing is the data that's ACTUALLY on the report we're generating.
      # The data in the landed_cost_data variable is from the backend generator that generates generic data used on multiple
      # different reports that pick and choose what data to present.  We could just to_json the hash and make a sha
      # hash from that, BUT, then if we add an data elements for some other report to the backend hash, we'll instantly invalidate
      # the hashes for this attachment printout and cause a ton of extra files to generate, which will cause a bunch of extra work
      # for our desk clerks.

      # We have to make sure that we always process the data in the same order (regardless of how the actual backend
      # splits it out) so we're going to make sure to sort the invoices and invoice lines from the result before
      # processing a checksum for them.

      entry_level = [:entry_number, :broker_reference, :customer_references]
      invoice_level = [:invoice_number]
      line_level = [:part_number, :po_number, :country_origin_code, :mid, :quantity]
      per_unit_level = [:entered_value, :duty, :fee, :international_freight, :inland_freight, :brokerage, :other]

      lc_data = []
      landed_cost_data[:entries].sort_by {|e| e[:broker_reference]}.each do |entry_data|
        lc_data.push *collect_fingerprint_field(entry_data, entry_level)
        entry_data[:commercial_invoices].sort_by {|ci| ci[:invoice_number]}.each do |invoice_data|
          lc_data.push *collect_fingerprint_field(invoice_data, invoice_level)
          invoice_data[:commercial_invoice_lines].sort_by {|l| l[:po_number].to_s + l[:part_number].to_s + l[:quantity].to_s}.each do |line_data|
            lc_data.push *collect_fingerprint_field(line_data, line_level)
            lc_data.push *collect_fingerprint_field(line_data[:per_unit], per_unit_level)
          end
        end
      end

      Digest::SHA1.hexdigest(lc_data.join("***"))
    end

    def calculate_landed_cost_checksum_v3 landed_cost_data
      # Ultimately, what we care about checksum'ing is the data that's ACTUALLY on the report we're generating.
      # The data in the landed_cost_data variable is from the backend generator that generates generic data used on multiple
      # different reports that pick and choose what data to present.  We could just to_json the hash and make a sha
      # hash from that, BUT, then if we add an data elements for some other report to the backend hash, we'll instantly invalidate
      # the hashes for this attachment printout and cause a ton of extra files to generate, which will cause a bunch of extra work
      # for our desk clerks.

      # We have to make sure that we always process the data in the same order (regardless of how the actual backend
      # splits it out) so we're going to make sure to sort the invoices and invoice lines from the result before
      # processing a checksum for them.

      # This fingerprint varies from V2 in that it includes the total row per line too.  By just including the per unit amounts, V2
      # was missing some small adjustments to the entry due to the difference amounting to changes of hundredths of a cent at
      # the per unit level.  For instance, a change in cotten fee of 1.70 over 3K units was not changing the actual fee amount at the per
      # unit level (being a 1/10th of a cent), but the fee totals are different so a new report should have printed.

      entry_level = [:entry_number, :broker_reference, :customer_references]
      invoice_level = [:invoice_number]
      line_level = [:part_number, :po_number, :country_origin_code, :mid, :quantity, :entered_value, :duty, :fee, :international_freight, :inland_freight, :brokerage, :other]
      per_unit_level = [:entered_value, :duty, :fee, :international_freight, :inland_freight, :brokerage, :other]

      lc_data = []
      landed_cost_data[:entries].sort_by {|e| e[:broker_reference]}.each do |entry_data|
        lc_data << collect_fingerprint_field(entry_data, entry_level)
        entry_data[:commercial_invoices].sort_by {|ci| ci[:invoice_number]}.each do |invoice_data|
          lc_data << collect_fingerprint_field(invoice_data, invoice_level)
          invoice_data[:commercial_invoice_lines].sort_by {|l| l[:po_number].to_s + l[:part_number].to_s + l[:quantity].to_s}.each do |line_data|
            lc_data << collect_fingerprint_field(line_data, line_level)
            lc_data << collect_fingerprint_field(line_data[:per_unit], per_unit_level)
          end
        end
      end

      Digest::SHA1.hexdigest(lc_data.flatten.join("***"))
    end

    def collect_fingerprint_field data_hash, fields
      values = []
      fields.each do |field|
        value = data_hash[field]
        if value.respond_to?(:join)
          value = value.join("***")
        elsif value.respond_to?(:round)
          value = value.round(2).to_s("F")
        else
          value = value.to_s
        end
        values << value
      end

      values
    end

    private

      def jjill_with_freight_charges entry
        if entry.customer_number == "JILL"
          # Make sure we have a broker invoice charge with a code of '0600' or one of our internal freight charge lines
          entry.broker_invoices.each do |inv|
            inv.broker_invoice_lines.each do |line|
              return true if line.charge_code == "0600" || freight_charge?(line.charge_code)
            end
          end
        end
        return false
      end

      def freight_charge? charge_code
        @freight_charges ||= DataCrossReference.hash_for_type DataCrossReference::ALLIANCE_FREIGHT_CHARGE_CODE
        @freight_charges.has_key? charge_code
      end
  end
end; end; end
