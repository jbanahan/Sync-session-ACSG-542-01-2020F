require 'open_chain/custom_handler/vfitrack_product_api_sync_client'
require 'open_chain/custom_handler/ann_inc/ann_custom_definition_support'

module OpenChain; module CustomHandler; module AnnInc; class AnnProductApiSyncGenerator < OpenChain::CustomHandler::VfiTrackProductApiSyncClient
  include AnnCustomDefinitionSupport

  def initialize opts = {}
    super
    @custom_where = opts[:custom_where]
  end

  def process_query_result row, opts
    # We have a 1-many situation due to the exploding of styles (1 part in Ann's system can be up to 5 parts in VFI Track)
    # So we need to both track products by unique identifier in the foreign system and ALSO the id in the local system to know
    # when to release the buffered styles on a new product id
    @previous_products ||= {products: [], id: nil}

    api_objects = []
    if !@previous_products[:id].nil? && row[0] != @previous_products[:id]
      api_objects.push *drain_previous_products
    end

    # Ann can potentially have multiple "styles" associated with a single product record.  Each linked style is 
    # reference in the related styles custom field, so we need to expload all those relates styles out and send
    # distinct API calls to create/update each of those too.
    styles = [row[1]].push *row[5].to_s.split(/\s*\r?\n\s*/)
    
    styles.each do |style|
      next if style.blank?

      @previous_products[:id] ||= row[0]
      system_code = vfitrack_importer_syscode(nil)
      unique_identifier = "#{system_code}-#{style}"

      product = @previous_products[:products].find {|p| p["prod_uid"] == style}

      if product.nil?
        product = {}

        product['id'] = row[0]
        product['prod_imp_syscode'] = system_code
        product['prod_uid'] = style
        product["prod_part_number"] = style
        @previous_products[:products] << product
      end

      country = row[2]
      product["classifications"] ||= []
      # Since we're using inner joins in the query below for classification and tariff data, they should always be present in the 
      # row data..don't bother adding data protections for those cases
      classification = product["classifications"].find {|c| c["class_cntry_iso"] == country }
      if classification.nil?
        classification = {"class_cntry_iso" => country, "tariff_records" => []}
        product["classifications"] << classification
      end

      # We can't have more than 1 of the same line number, so we can always assume that each tariff record from the 
      # the query is a new one.
      classification["tariff_records"] << {"hts_line_number" => row[3], "hts_hts_1" => row[4]} unless row[6].to_s.to_boolean
    end

    # If this is the last row from the query, then we need to stop buffering and return everything
    if opts[:last_result]
      api_objects.push *drain_previous_products
    end

    api_objects
  end

  def drain_previous_products
    api_objects = []
    @previous_products[:products].each do |p|
      api_objects << ApiSyncObject.new(@previous_products[:id], prepare_product_json(p))
    end
    @previous_products = {products: [], id: nil}

    api_objects
  end

  def prepare_product_json p
    # What we need to do here is to delete tariff records from our local product representation
    # if ANY classification has multiple tariffs.  When pulling in products for multi-tariff items
    # operations decided they'd rather have no tariff records in the system for these than have 
    # them both (for some reason)
    p["classifications"].each do |c|
      tariffs = Array.wrap(c["tariff_records"])
      c["tariff_records"] = [] if tariffs.length > 1
    end

    p
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
SELECT products.id, products.unique_identifier, iso.iso_code, r.line_number, r.hts_1, related_style.text_value, manual.boolean_value
FROM products products
INNER JOIN classifications c on products.id = c.product_id
INNER JOIN tariff_records r on r.classification_id = c.id
INNER JOIN countries iso on iso.id = c.country_id and iso.iso_code in ('US', 'CA')
LEFT OUTER JOIN custom_values related_style on related_style.customizable_id = products.id and related_style.customizable_type = 'Product' and related_style.custom_definition_id = #{cdefs[:related_styles].id} and length(related_style.text_value) > 0
LEFT OUTER JOIN custom_values manual on manual.customizable_id = c.id and manual.customizable_type = 'Classification' and manual.custom_definition_id = #{cdefs[:manual_flag].id}
QRY
    if @custom_where.blank?
      qry += "\n" + Product.need_sync_join_clause(sync_code)
      qry += "\nWHERE " + Product.need_sync_where_clause + "\n AND r.hts_1 <> ''"
    else
      qry += "\nWHERE " + @custom_where
    end

    qry += " ORDER BY products.id, iso.iso_code"

    # If a custom where is given, it's assumed to be limiting the query to the exact results needed
    if @custom_where.blank?
      qry += " LIMIT 1000"
    end

    qry
  end

  def vfitrack_importer_syscode query_row
    "ATAYLOR"
  end

  def local_data_fingerprint local_data
    # Disable the localized data fingerprinting...because we have 1 + n records to sync to VFI Track
    # per product, there's little point in trying to utilize a single fingerprint in the sync record 
    # across multiple remote products.
    nil
  end

  def cdefs
    @cdefs ||= self.class.prep_custom_definitions([:related_styles, :manual_flag])
  end

  def continue_looping? loop_count
    # Don't keep looping if we used a custom where...that'll just result in the same values sent in an endless loop.
    @custom_where.blank? ? true : (loop_count < 1)
  end

end; end; end; end;
