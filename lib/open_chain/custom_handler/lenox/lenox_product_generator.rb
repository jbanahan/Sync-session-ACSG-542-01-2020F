require 'open_chain/custom_handler/product_generator'
require 'open_chain/custom_handler/vfitrack_custom_definition_support'

module OpenChain; module CustomHandler; module Lenox; class LenoxProductGenerator < ProductGenerator
  include VfitrackCustomDefinitionSupport

  SYNC_CODE ||= 'lenox_hts'

  def self.run_schedulable opts={}
    g = self.new(opts)
    g.ftp_file g.sync_fixed_position
  end

  def initialize opts = {}
    super
    @env = (opts[:env] ? opts[:env] : 'production')
    @cdefs = self.class.prep_custom_definitions [:prod_fda_product_code, :prod_part_number, :class_set_type]
  end

  def ftp_credentials
    {server:'ftp.lenox.com',username:"vanvendor#{@env=='production' ? '' : 'test'}",password:'$hipments',folder:'.', remote_file_name: "Item_HTS"}
  end

  def preprocess_row row, opts
    # For each product, find all the HTS #'s asscociated with it and then spawn out a row for each one of them
    rows = []
    counter = 0

    c = Classification.includes(:custom_values).where(id: row[5]).first
    set_type = c.get_custom_value(@cdefs[:class_set_type]).value

    if set_type.to_s.strip.upcase == "XVV"
      # Return the second tariff record - the first should be the set hts, which isn't what Lenox wants...they want the hts that will determine the duty rate
      component_tariff = c.tariff_records.order("line_number ASC").second
      if component_tariff && !component_tariff.hts_1.blank?
        rows << [row[0], row[1], component_tariff.hts_1, (counter += 1).to_s.rjust(3, "0"), row[4]]
      end
    else
      c.tariff_records.order("line_number ASC").each do |t|
        # HTS codes in chapter 98 are all special case tariffs, Lenox only wants 
        # this code as it's the one used to determine the duty rate
        if t.hts_1.to_s.strip[0, 2] == "98"
          rows << [row[0], row[1], t.hts_1, (counter += 1).to_s.rjust(3, "0"), row[4]]
        else
          if !t.hts_1.blank?
            rows << [row[0], row[1], t.hts_1, (counter += 1).to_s.rjust(3, "0"), row[4]]
          end

          if !t.hts_2.blank?
            rows << [row[0], row[1], t.hts_2, (counter += 1).to_s.rjust(3, "0"), row[4]]
          end

          if !t.hts_3.blank?
            rows << [row[0], row[1], t.hts_3, (counter += 1).to_s.rjust(3, "0"), row[4]]
          end
        end
      end
    end

    if rows.length == 1
      # They want the row counter for single tariff lines to be zero, not 1, so just
      # change it "post facto" when there's only a single tariff line
      rows[0][3] = "000"
    elsif rows.length > 1
      # Add a "header" row if there's more than one tariff to send
      rows = rows.insert(0, [row[0], row[1], "MULTI", "000", row[4]])
    end

    rows
  end

  def sync_code
    SYNC_CODE
  end

  def fixed_position_map
    [
      {len: 18}, # Part Number
      {len: 2}, # Classification Country ISO
      {len: 10}, # HTS Number
      {len: 3}, # Line Number
      {len: 10}, # FDA Container Number
    ]
  end

  def query
    fda_code = @cdefs[:prod_fda_product_code]
    part_number = @cdefs[:prod_part_number]

    qry = <<-QRY
SELECT products.id, v.string_value, cod.iso_code, '', '', cv.string_value, c.id
FROM products products
INNER JOIN companies i ON i.id = products.importer_id AND i.system_code = 'LENOX'
INNER JOIN custom_values v on products.id = v.customizable_id and v.customizable_type = 'Product' and v.custom_definition_id = #{part_number.id} and v.string_value <> ''
LEFT OUTER JOIN custom_values cv on products.id = cv.customizable_id and cv.customizable_type = 'Product' and cv.custom_definition_id = #{fda_code.id} and cv.string_value <> ''
INNER JOIN classifications c on products.id = c.product_id
INNER JOIN countries cod on cod.id = c.country_id
QRY
    if custom_where
      qry += custom_where
    else
      qry += " " + Product.need_sync_join_clause(SYNC_CODE) + "\nWHERE " + Product.need_sync_where_clause
    end

    qry += "\nORDER BY v.string_value, cod.iso_code"
    qry
  end

end; end; end; end

