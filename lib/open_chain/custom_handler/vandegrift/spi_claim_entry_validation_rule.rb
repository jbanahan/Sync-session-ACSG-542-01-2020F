module OpenChain; module CustomHandler; module Vandegrift; class SpiClaimEntryValidationRule < BusinessValidationRule
  include ValidatesCommercialInvoiceLine

  def run_validation entry
    if has_available_spi?(entry)
      super entry
    end
  end

  def run_child_validation cil
    msg = nil
    if spi_not_set?(cil)
      msg = "Invoice #{cil.commercial_invoice.invoice_number}, Line #{cil.line_number}: No SPI claimed. Please review for applicability."
    end
    msg
  end

  private
    # For the purposes of this rule, we are assuming it's necessary for any one tariff under a commercial
    # invoice line, in the event of multiple, to have primary SPI set.
    def spi_not_set? cil
      spi_set = cil.commercial_invoice_tariffs.find_all{ |tar| tar.spi_primary.present? }.length == 0
    end

    def has_available_spi? entry
      # While there are generally only one origin and export code per entry, it's possible to have multiple
      # codes  joined together with newlines (and whitespace - see EntryParserSupport.multi_value_separator).
      # We want to loop through all country combos until a data xref match is made, indicating that the
      # country combo has SPI available for it.  After that, there's no need to keep checking other combos.
      entry.export_country_codes.to_s.split("\n").collect(&:strip).each do |export_iso|
        entry.origin_country_codes.to_s.split("\n").collect(&:strip).each do |origin_iso|
          key = DataCrossReference.make_compound_key(export_iso, origin_iso)
          if DataCrossReference.where(cross_reference_type: DataCrossReference::SPI_AVAILABLE_COUNTRY_COMBINATION, key: key).first
            return true
          end
        end
      end
      return false
    end

end; end; end; end