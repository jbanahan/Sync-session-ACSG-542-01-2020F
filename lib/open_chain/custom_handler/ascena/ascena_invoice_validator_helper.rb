module OpenChain; module CustomHandler; module Ascena; class AscenaInvoiceValidatorHelper
  
  # assumptions: No commercial_invoice_line on the entry has more than one commercial_invoice_tariff
  #              No hts/coo combination appears on a fenix invoice more than once
  def audit entry, style_list
    invoice_numbers = entry.commercial_invoice_numbers.split("\n").map(&:strip).join(", ")
    unrolled = gather_unrolled(invoice_numbers, entry.importer_id)
    fenix = gather_entry entry
    unrolled_by_hts_coo = sum_per_hts_coo(unrolled)
    fenix_by_hts_coo = arrange_by_hts_coo(fenix)
    run_tests(unrolled, fenix, unrolled_by_hts_coo, fenix_by_hts_coo, style_list)
  end

  def run_tests unrolled, fenix, unrolled_by_hts_coo, fenix_by_hts_coo, style_list=nil
    errors = []
    errors << invoice_list_diff(unrolled, fenix)
    if errors.first.blank?
      errors << total_per_hts_coo_diff(:value, unrolled_by_hts_coo, fenix_by_hts_coo)
      errors << total_per_hts_coo_diff(:quantity, unrolled_by_hts_coo, fenix_by_hts_coo)
      errors << total_diff(:value, unrolled, fenix)
      errors << total_diff(:quantity, unrolled, fenix)
      errors << hts_list_diff(unrolled, fenix, fenix_by_hts_coo)
      errors << style_list_match(unrolled, style_list) if style_list
    end
    errors.reject{ |err| err.empty? }.join("\n")
  end

  def invoice_list_diff unrolled, fenix
    unrolled_inv_numbers, fenix_inv_numbers = Set.new, Set.new
    unrolled.each { |row| unrolled_inv_numbers.add(filter(row['invoice_number'], "BLANK")) }
    fenix.each { |row| fenix_inv_numbers.add(filter(row['invoice_number'], "BLANK")) }
    if unrolled_inv_numbers == fenix_inv_numbers
      ""
    else 
      only_fenix = fenix_inv_numbers - unrolled_inv_numbers
      "Missing unrolled invoices: #{only_fenix.to_a.join(", ")}"
    end
  end

  def total_per_hts_coo_diff field, unrolled_by_hts_coo, fenix_by_hts_coo
    error = check_fenix_against_unrolled(field, unrolled_by_hts_coo, fenix_by_hts_coo)
              .concat check_unrolled_against_fenix(field, unrolled_by_hts_coo, fenix_by_hts_coo)   
    error.presence ? "Total #{field.to_s} per HTS/country-of-origin:\n" << (error.join("\n") + "\n") : ""
  end

  # collects missing hts/coo combinations, value/quantity discrepancies from unrolled
  def check_fenix_against_unrolled field, unrolled_by_hts_coo, fenix_by_hts_coo
    error = []
    fenix_by_hts_coo.each do |hts, outer|
      outer.each do |coo, inner|
        fenix = inner[field]
        unrolled = unrolled_by_hts_coo[hts][coo] ? unrolled_by_hts_coo[hts][coo][field] : 0
        if fenix != unrolled
          error << "B3 Sub Hdr # #{inner[:subheader_number]} / B3 Line # #{inner[:customs_line_number]} has #{string_format(field, fenix)} #{field.to_s} for #{hts.hts_format} / #{coo}. Unrolled Invoice has #{string_format(field, unrolled)}."
        end
      end
    end
    error
  end

  # collects only missing hts/coo combinations from fenix
  def check_unrolled_against_fenix field, unrolled_by_hts_coo, fenix_by_hts_coo 
    error = []
    unrolled_by_hts_coo.each do |hts, outer|
      outer.each do |coo, inner|
        fenix = fenix_by_hts_coo[hts][coo] ? fenix_by_hts_coo[hts][coo][field] : nil
        unrolled = string_format(field, inner[field])
        error << "B3 has #{string_format(field, 0)} #{field.to_s} for #{hts.hts_format} / #{coo}. Unrolled Invoice has #{unrolled}." if fenix.blank?
      end
    end
    error
  end

  def total_diff field, unrolled, fenix
    unrolled_field = total(field, unrolled)
    fenix_field = total(field, fenix)
    unrolled_field == fenix_field ? "" : "B3 has total #{field.to_s} of #{string_format(field, fenix_field)}. Unrolled Invoices have #{string_format(field, unrolled_field)}.\n"
  end

  def hts_list_diff unrolled, fenix, fenix_by_hts_coo
    error = []
    unrolled_hts = hts_list(unrolled)
    fenix_hts = hts_list(fenix)
    missing_fenix_hts = unrolled_hts - fenix_hts
    error << "B3 missing HTS code(s) on Unrolled Invoices: #{missing_fenix_hts.map(&:hts_format).join(', ')}" unless missing_fenix_hts.empty?
    unexpected_hts_errors = []
    missing_unrolled_hts = fenix_hts - unrolled_hts
    missing_unrolled_hts.each do |hts|
      line_info = []
      fenix_by_hts_coo[hts].each do |coo, line|
        line_info << "B3 Sub Hdr # #{line[:subheader_number]} / B3 Line # #{line[:customs_line_number]}"
      end
      unexpected_hts_errors << "#{hts.hts_format} (#{line_info.join('; ')})"
    end
    error << ("Unrolled Invoices missing HTS code(s) on B3: " << unexpected_hts_errors.join(", ")) if unexpected_hts_errors.presence
    error.presence ? error.join("\n") + "\n" : ""
  end
  
  def style_list_match unrolled, style_list
    flagged = get_style_list(unrolled) & style_list
    flagged.empty? ? "" : "Unrolled Invoices include flagged style(s): #{flagged.to_a.join(', ')}\n"
  end
  
  def arrange_by_hts_coo fenix
    converted = Hash.new { |h, k| h[k] = {} }
    fenix.each do |row|
      hts = filter(row["hts_code"], "BLANK")
      coo = filter(row["country_origin_code"], "BLANK")
      converted[hts][coo] = {invoice_number: filter(row["invoice_number"], "BLANK"), quantity: filter(row["quantity"], 0), 
                             value: filter(row["value"], 0), subheader_number: filter(row["subheader_number"], "BLANK"), 
                             customs_line_number: filter(row["customs_line_number"], "BLANK")}
    end
    converted
  end

  def sum_per_hts_coo unrolled
    result = Hash.new do |h, k| 
      h[k] = Hash.new { |h2, k2| h2[k2] = {quantity: 0, value: 0} }
    end
    unrolled.each do |row|
      hts = filter(row["hts_code"], "BLANK")
      coo = filter(row["country_origin_code"], "BLANK")
      result[hts][coo][:quantity] += filter(row["quantity"], 0)
      result[hts][coo][:value] += filter(row["value"], 0)
    end
    result
  end
  

  private

  def filter num, default
    num.presence || default
  end

  def string_format type, amount
    type == :value ? '$' + sprintf('%0.02f', amount) : amount.to_s
  end

  def total field, results
    results.inject(0){ |acc, row| acc + filter(row[field.to_s], 0) }
  end

  def get_style_list results
    styles = []
    results.each { |row| styles << row['part_number'].split("-").first if row['part_number'].presence  }
    styles.uniq
  end

  def hts_list results
    list = []
    results.each { |row| list << filter(row['hts_code'], "BLANK") }
    list.uniq
  end

  def gather_unrolled invoice_numbers, importer_id
    query = "SELECT ci.invoice_number, cil.part_number, cil.country_origin_code, cit.hts_code, cil.quantity, cil.value " \
            "FROM commercial_invoices AS ci " \
            "  INNER JOIN commercial_invoice_lines AS cil ON ci.id = cil.commercial_invoice_id " \
            "  INNER JOIN commercial_invoice_tariffs AS cit ON cil.id = cit.commercial_invoice_line_id " \
            "WHERE ci.entry_id IS NULL AND ci.importer_id = ? AND ci.invoice_number IN (?)"
  
    ActiveRecord::Base.connection.exec_query(ActiveRecord::Base.sanitize_sql_array([query, importer_id, invoice_numbers]))
  end

  def gather_entry entry
    query = "SELECT ci.invoice_number, cil.part_number, cil.country_origin_code, cit.hts_code, cil.quantity, cil.value, cil.customs_line_number, cil.subheader_number " \
            "FROM commercial_invoices AS ci " \
            "  INNER JOIN commercial_invoice_lines AS cil ON ci.id = cil.commercial_invoice_id " \
            "  INNER JOIN commercial_invoice_tariffs AS cit ON cil.id = cit.commercial_invoice_line_id " \
            "WHERE ci.entry_id = ?"

    ActiveRecord::Base.connection.exec_query(ActiveRecord::Base.sanitize_sql_array([query, entry.id]))
  end

end; end; end; end
