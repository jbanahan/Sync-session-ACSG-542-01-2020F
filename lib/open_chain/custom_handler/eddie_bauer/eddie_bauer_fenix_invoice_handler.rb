require 'open_chain/custom_handler/fenix_commercial_invoice_spreadsheet_handler'

module OpenChain; module CustomHandler; module EddieBauer
  class EddieBauerFenixInvoiceHandler < OpenChain::CustomHandler::FenixCommercialInvoiceSpreadsheetHandler

    def prep_header_row row
      row = convert_to_utf8(row)
      add_default_header_info row
    end

    def prep_line_row row
      row = convert_to_utf8(row)
      add_default_header_info row
      add_default_line_level_info row
    end

    def csv_reader_options
      # Disable quoting, using Windows-1252 since that's what the file is in.  Fenix also handles this
      # fine, so it should be ok to pass through any 1252 only chars directly.
      {col_sep: "|", quote_char: "\007", encoding: "Windows-1252"}
    end

    def has_header_line?
      false
    end

    private 

      def add_default_header_info row
        ensure_line_length row

        row[0] = "855157855RM0001"
        row[3] = "UOH"

        row
      end

      def add_default_line_level_info row
        ensure_line_length row

        tr = TariffRecord.joins(:classification=>[:product, :country])
              .where(:products=>{:unique_identifier => "EDDIE-#{row[4]}"})
              .where(:countries => {:iso_code => "CA"})
              .where("tariff_records.hts_1 IS NOT NULL AND tariff_records.hts_1 <> ''")
              .first

        row[5] = "UOH" if row[5].to_s.upcase == "US"
        row[6] = tr.hts_1 if tr

        row
      end

      def ensure_line_length row
        # Ensure the row is at least 12 positions long
        row << "" while row.length < 13
        row.each {|v| v.strip! if v}
        row
      end

      def convert_to_utf8 row
        row.map {|v| v.to_s.encode("UTF-8", invalid: :replace, undef: :replace, replace: "") }
      end
  end
end; end; end