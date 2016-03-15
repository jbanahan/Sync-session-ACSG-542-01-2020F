module OpenChain; module CustomHandler; module Ascena
  class AscenaInvoiceValidatorHelper

    # run first
    # assumption: No commercial_invoice_line on the entry has more than one commercial_invoice_tariff
    def run_queries entry 
      invoice_numbers = entry.commercial_invoice_numbers.split("\n").map{ |x| x.strip.inspect }.join(", ")
      @unrolled_results = gather_unrolled invoice_numbers, entry.importer_id
      @fenix_results = gather_entry entry
    end

    def invoice_list_diff
      unrolled_inv_numbers, fenix_inv_numbers = [].to_set, [].to_set
      @unrolled_results.each { |row| unrolled_inv_numbers.add row['invoice_number'] }
      @fenix_results.each { |row| fenix_inv_numbers.add row['invoice_number'] }
      if unrolled_inv_numbers == fenix_inv_numbers
        ""
      else 
        only_fenix = relative_complement unrolled_inv_numbers, fenix_inv_numbers
        "Missing unrolled invoices: #{only_fenix.to_a.join(", ")}"
      end
    end

    def total_value_per_hts_coo_diff
      unrolled = (flatten accumulate_per_hts_coo(@unrolled_results, 'value'), true).to_set
      fenix = (flatten accumulate_per_hts_coo(@fenix_results, 'value'), true).to_set
      errors = create_diff_messages unrolled, fenix
      errors.empty? ? "" : "Total value per HTS/country-of-origin:\n" + errors
    end

    def total_qty_per_hts_coo_diff
      unrolled = (flatten accumulate_per_hts_coo(@unrolled_results, 'quantity')).to_set
      fenix = (flatten accumulate_per_hts_coo(@fenix_results, 'quantity')).to_set
      errors = create_diff_messages unrolled, fenix
      errors.empty? ? "" : "Total quantity per HTS/country-of-origin:\n" + errors
    end

    def total_value_diff
      unrolled = total_value(@unrolled_results)
      fenix = total_value(@fenix_results)
      unrolled == fenix ? "" : "Expected total value = #{currency_format(unrolled)}, found total value = #{currency_format(fenix)}\n"
    end

    def total_qty_diff
      unrolled = total_qty(@unrolled_results)
      fenix = total_qty(@fenix_results)
      unrolled == fenix ? "" : "Expected total quantity = #{unrolled}, found total quantity = #{fenix}\n"
    end

    def hts_set_diff
      unrolled = hts_set(@unrolled_results)
      fenix = hts_set(@fenix_results)
      only_unrolled = relative_complement fenix, unrolled
      only_fenix = relative_complement unrolled, fenix
      errors = []
      errors << "Missing HTS code(s): #{only_unrolled.to_a.join(', ')}\n" unless only_unrolled.empty?
      errors << "Unexpected HTS code(s): #{only_fenix.to_a.join(', ')}\n" unless only_fenix.empty?
      errors.join('')
    end

    def style_set_match style_set
      flagged = style_set(@unrolled_results) & style_set
      flagged.empty? ? "" : "Flagged style(s): #{flagged.to_a.join(', ')}\n"
    end
    
    def create_diff_messages unrolled_results, fenix_results
      only_unrolled = relative_complement fenix_results, unrolled_results
      only_fenix = relative_complement unrolled_results, fenix_results
      compare_disjoint_hts_coo_sets only_unrolled, only_fenix
    end

    private

    def compare_disjoint_hts_coo_sets unrolled, fenix
      errors = []
      fenix_arr = fenix.to_a
      unrolled.to_a.each do |unr_hts_coo_v|
        i = fenix_arr.index{ |fen_hts_coo_v| fen_hts_coo_v.first == unr_hts_coo_v.first }
        found = fenix_arr.delete_at(i).last if i
        errors << "Expected #{unr_hts_coo_v.first} = #{unr_hts_coo_v.last}, found #{unr_hts_coo_v.first} = #{found ? found : 0}\n"
      end
      fenix_arr.each { |fen_hts_coo_v| errors << "Did not expect to find #{fen_hts_coo_v.first} = #{fen_hts_coo_v.last}\n" }
      errors.join ''
    end

    def relative_complement(set_b, set_a) # "relative complement of b in a"
      (set_a | set_b) - set_b
    end

    def accumulate_per_hts_coo results, field
      out = Hash.new { |h, k| h[k] = Hash.new(0) }
      results.each { |row| out[row['hts_code']][row['country_origin_code']] += row[field] }
      out
    end

    def flatten results, currency=nil
      out = {}
      results.each do |hts, coo_hsh|
        coo_hsh.each { |coo, val| out[hts + "/#{coo}"] = currency ? currency_format(val) : val.to_s }
      end
      out
    end

    def currency_format amount
      sprintf("%0.02f", amount)
    end

    def total_value results
      total = 0
      results.each { |row| total += row['value'] }
      total
    end

    def total_qty results
      total = 0
      results.each { |row| total += row['quantity'] }
      total
    end

    def hts_set results
      set = Set.new
      results.each { |row| set.add row['hts_code'] }
      set
    end

    def style_set results
      set = Set.new
      results.each do |row| 
        style = row['part_number'].split("-").first
        set.add style
      end
      set
    end

    def gather_unrolled invoice_numbers, importer_id
      query = "SELECT ci.invoice_number, cil.part_number, cil.country_origin_code, cit.hts_code, cil.quantity, cil.value " \
              "FROM commercial_invoices AS ci " \
              "  INNER JOIN commercial_invoice_lines AS cil ON ci.id = cil.commercial_invoice_id " \
              "  INNER JOIN commercial_invoice_tariffs AS cit ON cil.id = cit.commercial_invoice_line_id " \
              "WHERE ci.entry_id IS NULL AND ci.importer_id = #{importer_id} AND ci.invoice_number IN (#{invoice_numbers})"
    
      ActiveRecord::Base.connection.exec_query(query)
    end

    def gather_entry entry
      query = "SELECT ci.invoice_number, cil.part_number, cil.country_origin_code, cit.hts_code, cil.quantity, cil.value " \
              "FROM commercial_invoices AS ci " \
              "  INNER JOIN commercial_invoice_lines AS cil ON ci.id = cil.commercial_invoice_id " \
              "  INNER JOIN commercial_invoice_tariffs AS cit ON cil.id = cit.commercial_invoice_line_id " \
              "WHERE ci.entry_id = #{entry.id}"

      ActiveRecord::Base.connection.exec_query(query)
    end

  end
end; end; end