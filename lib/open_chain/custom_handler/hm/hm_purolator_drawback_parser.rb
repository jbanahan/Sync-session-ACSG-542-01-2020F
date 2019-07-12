require 'open_chain/integration_client_parser'
require 'open_chain/custom_handler/csv_excel_parser'

# Matches up to data received via the I2 drawback parser, updating a single flag field if a match can be made.
# The Purolator data file is temporary and is only needed for the timeframe covering 4Q/2016 and 1Q/2017.
module OpenChain; module CustomHandler; module Hm; class HmPurolatorDrawbackParser
  include OpenChain::IntegrationClientParser
  include OpenChain::CustomHandler::CsvExcelParser

  def self.parse_file file_content, log, opts = {}
    self.new.parse_file file_content
  end

  def file_reader file_content
    csv_reader StringIO.new(file_content), col_sep: ","
  end

  def parse_file file_content
    inbound_file.company = Company.importers.where(system_code: "HENNE").first

    missing_tracking_numbers = []
    lines = foreach(file_content, skip_blank_lines: true)
    lines.each do |line|
      # We don't care about most of the data in this file.  Event code tells us whether to skip the line or not.
      # Carrier tracking number is used to match up to existing I2 drawback lines ('export'-type only; 'returns' are
      # excluded from this check).
      event_code = text_value(line[2])
      if receipt_event_code? event_code
        carrier_tracking_number = text_value(line[1])

        # Although they were meant to match exactly, the Purolator tracking number seems contain only a portion of the
        # I2 tracking number.  "Like" matching must be used here.  The Purolator tracking numbers, since they involve
        # a substring match, will potentially match to multiple I2 records.  In that event, all of the matching I2
        # records must be updated.
        i2_lines = HmI2DrawbackLine.where(shipment_type:'export').where("DATE(shipment_date) <= ?", "#{line[3]}").where("carrier_tracking_number LIKE ?", "%#{carrier_tracking_number}%")
        if i2_lines.length > 0
          i2_lines.each do |i2_line|
            i2_line.export_received = true
            i2_line.save!
          end
        else
          missing_tracking_numbers << carrier_tracking_number
        end
      end
    end

    # Alert support if any tracking numbers in the file didn't match up to existing I2 drawback lines.
    if missing_tracking_numbers.length > 0
      write_file_content_to_temp_file(missing_tracking_numbers, file_content) do |missing_tracking_numbers, content_temp_file|
        generate_missing_i2_lines_email missing_tracking_numbers, content_temp_file
      end
    end
  end

  private
    # Lines that don't have one of these event codes are supposed to be ignored for the purposes of this parser.
    def receipt_event_code? event_code
      ['0100','0104','0105','0170'].include? event_code
    end

    def write_file_content_to_temp_file missing_tracking_numbers, file_content
      tmp = Tempfile.new('')
      tmp << file_content
      tmp.flush
      Attachment.add_original_filename_method tmp, 'purolator_drawback.csv'
      begin
        yield missing_tracking_numbers, tmp
      ensure
        tmp.close! if !tmp.closed?
      end
    end

    def generate_missing_i2_lines_email missing_tracking_numbers, content_temp_file
      body_text = "<p>The following Tracking Numbers do not exist in the VFI Track Drawback Database:<br><ul>"
      missing_tracking_numbers.each do |tracking_number|
        body_text << "<li>#{tracking_number}</li>"
      end
      body_text << "</ul></p>"
      body_text << "<p>Please forward this information to the Purolator Carrier for further review.</p>"
      OpenMailer.send_simple_html('support@vandegriftinc.com', 'H&M Drawback  - Purolator data file contains Tracking Numbers not in VFI Track', body_text.html_safe, [content_temp_file]).deliver_now
    end

end;end;end;end