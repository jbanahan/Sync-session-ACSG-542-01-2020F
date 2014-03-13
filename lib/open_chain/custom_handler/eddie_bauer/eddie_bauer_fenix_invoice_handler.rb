require 'open_chain/custom_handler/fenix_commercial_invoice_spreadsheet_handler'

module OpenChain; module CustomHandler; module EddieBauer
  class EddieBauerFenixInvoiceHandler < OpenChain::CustomHandler::FenixCommercialInvoiceSpreadsheetHandler

    def prep_header_row row
      add_default_header_info row
    end

    def prep_line_row row
      add_default_header_info row
      add_default_line_level_info row
    end

    def csv_client_options
      {col_sep: "|"}
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

        row[6] = tr.hts_1 if tr

        row
      end

      def ensure_line_length row
        # Ensure the row is at least 12 positions long
        row << "" while row.length < 13
        row.each {|v| v.strip!}
        row
      end
  end
end; end; end