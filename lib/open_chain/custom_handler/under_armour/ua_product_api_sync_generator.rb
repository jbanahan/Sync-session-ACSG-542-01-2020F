require 'open_chain/custom_handler/vfitrack_product_api_sync_client'
require 'open_chain/custom_handler/under_armour/under_armour_custom_definition_support'

module OpenChain; module CustomHandler; module UnderArmour; class UaProductApiSyncGenerator < OpenChain::CustomHandler::VfiTrackProductApiSyncClient
  include UnderArmourCustomDefinitionSupport

  def initialize opts = {}
    super
    defs = self.class.prep_custom_definitions([:plant_codes, :colors])
    @plant_cd = defs[:plant_codes]
    @colors_cd = defs[:colors]
  end

  def process_query_result row, opts
    @us_plant_codes ||= Set.new(DataCrossReference.where(cross_reference_type: DataCrossReference::UA_PLANT_TO_ISO, value: "US").pluck :key)
    
    # UA stores their data at the style level, but UA's unique product identifier (from an entry standpoint) 
    # is Style + Color.  Because of this we need to examine the colors custom value associated w/ the product
    # figure out from the plant xref which ones are valid and then expload each line potentially into multiple
    # style - color combinations.
    plants = row[5].to_s.split(/\s*\r?\n\s*/)
    colors = row[6].to_s.split(/\s*\r?\n\s*/)

    api_objects = []

    # We can skip any colors we've already generated data for the product
    sent_codes = Set.new
    plants.each do |plant|
      next unless @us_plant_codes.include?(plant)

      colors.each do |color|
        unique_identifier = "#{row[1]}-#{color}"
        next if sent_codes.include?(unique_identifier)
        next unless DataCrossReference.find_ua_material_color_plant(row[1], color, plant)

        product = {}
        product['id'] = row[0]
        product['prod_imp_syscode'] = vfitrack_importer_syscode(nil)
        product['prod_uid'] = unique_identifier
        product["prod_part_number"] = unique_identifier
        product['class_cntry_iso'] = row[2]
        tariff = {}
        product['tariff_records'] = [tariff]
        tariff['hts_line_number'] = row[3]
        tariff['hts_hts_1'] = row[4]

        api_objects << ApiSyncObject.new(row[0], product)
        sent_codes << unique_identifier
      end
    end

    # If there's no records to send, then we want to make sure that we still log a sync record against this product 
    # otherwise we'll get a pile-up of records indicating they need syncing but no sync records being built for them.
    if api_objects.length == 0
      sr = SyncRecord.where(syncable_id: row[0], syncable_type: syncable_type, trading_partner: sync_code).first_or_create!
      sr.update_attributes! sent_at: Time.zone.now, confirmed_at: (Time.zone.now + 1.minute), fingerprint: nil, confirmation_file_name: "No US data to send."
    end


    return api_objects
  end

  def query_row_map
    # Even though we're handling our own query parsing, rather than use the parent class', the parent
    # does also use the query map's keys for determining which fields need to be queried from VFI Track while 
    # syncing.
    {
      product_id: nil,
      prod_uid: nil,
      class_cntry_iso: nil,
      hts_line_number: nil,
      hts_hts_1: nil
    }
  end

  def query
    # We only want 1 row per product, we're handling exploading out the records in the query processing method
    qry = <<-QRY
SELECT products.id, products.unique_identifier, iso.iso_code, r.line_number, r.hts_1, plant.text_value, color.text_value
FROM products products
INNER JOIN classifications c on products.id = c.product_id
INNER JOIN tariff_records r on r.classification_id = c.id and line_number = 1
INNER JOIN countries iso on iso.id = c.country_id and iso.iso_code = 'US'
INNER JOIN custom_values plant on plant.customizable_id = products.id and plant.customizable_type = 'Product' and plant.custom_definition_id = #{@plant_cd.id} and length(plant.text_value) > 0
INNER JOIN custom_values color on color.customizable_id = products.id and color.customizable_type = 'Product' and color.custom_definition_id = #{@colors_cd.id} and length(color.text_value) > 0
QRY
    if @custom_where.blank?
      qry += "\n" + Product.need_sync_join_clause(sync_code)
      qry += "\nWHERE " + Product.need_sync_where_clause + "\n AND r.hts_1 <> ''"
    else
      qry += "\nWHERE " + @custom_where
    end

    qry += " LIMIT 1000"
  end

  def vfitrack_importer_syscode query_row
    "UNDAR"
  end

  def local_data_fingerprint local_data
    # Disable the localized data fingerprinting...because we have 1 + n records to sync to VFI Track
    # per product, there's little point in trying to utilize a single fingerprint in the sync record 
    # across multiple remote products.
    nil
  end

end; end; end; end;