class ValidationRuleEntryHtsMatchesPo < ValidationRuleEntryInvoiceLineMatchesPoLine

  def validate_product?
    @validate_product ||= begin
      rule_attrs = self.rule_attributes
      {'validate_product' => true}.merge(rule_attrs.nil? ? {} : rule_attrs)['validate_product'].to_s.downcase == "true"
    end

    @validate_product
  end

  def product_classification_country
    @class_country ||= begin
      rule_attrs = self.rule_attributes
      {'classification_country' => "US"}.merge(rule_attrs.nil? ? {} : rule_attrs)['classification_country']
    end

    @class_country
  end

  def validate_invoice_and_po_fields invoice_line, po_number, part_number, order_lines
    # Validate each tariff line matches by Country of Origin and HTS against the PO and the product linked to the PO.
    # All the order lines passed in here already are verified to have the same po # / part number as the invoice line.
    messages = []
    tariffs = invoice_line.commercial_invoice_tariffs.map {|t| t.hts_code}.uniq.compact
    tariffs.each do |tariff|
      # We should be as specific as possible regarding the message(s), since the PO coo/hts may match but the Product may not.
      # Every order line passed in matches the part number for our specific line, so just look for one that also has the same
      # COO / HTS.
      matching_order_lines = order_lines.find_all {|l| tariffs.include?(l.hts) && l.country_of_origin.try(:upcase) == invoice_line.country_origin_code.try(:upcase) }

      if matching_order_lines.length == 0
        messages << "Invoice Line for PO #{po_number} / Part #{part_number} does not match any Order line's Tariff and Country of Origin."
      elsif validate_product?
        product_ids = matching_order_lines.map {|l| l.product_id}.uniq.compact
        matching_product_count = Product.joins(classifications: [:country, :tariff_records]).
                                  includes(classifications: [:tariff_records]).
                                  where(id: product_ids, countries: {iso_code: product_classification_country}, 
                                          tariff_records: {hts_1: tariffs}).
                                  size

        if matching_product_count == 0
          messages << "Invoice Line for PO #{po_number} / Part #{part_number} matches to an Order line, but not to any Product associated with the Order."
        end
      end
    end

    messages
  end
end