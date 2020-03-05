require 'open_chain/custom_handler/api_sync_client'
require 'open_chain/api/product_api_client'

# This is a simple base class to extend for instance/company specific 
# syncing of data meant for syncing to VFI Track.

# The methods you must implement are:
# query_row_map - returns a hash of column keys IN QUERY SELECT ORDER that will be utilized in the SQL query. The keys utilized must be one of those found in the "valid_columns" method's return value
# query - the SQL query to execute to determine which products to sync with the remote system
# vfitrack_importer_syscode - The importer system code the products should be stored under in VFI Track.
module OpenChain; module CustomHandler; class VfiTrackProductApiSyncClient < OpenChain::CustomHandler::ApiSyncClient

  def initialize opts = {}
    super
    # This is primarily just here as a guard so we only actually automate the api endpoint in production
    if Rails.env.production? && opts[:api_client].nil?
      client_id = MasterSetup.secrets.api_client&.keys&.first.presence || 'vfitrack'
      @api_client = OpenChain::Api::ProductApiClient.new client_id
    else
      raise "You must pass an api_client as an ops key." unless opts[:api_client]
      @api_client = opts[:api_client]
    end
    validate_query_row_map

    if opts[:sync_classifications]
      @sync_classifications = opts[:sync_classifications]
    end
  end

  def self.run_schedulable opts = {}
    new(opts).sync
  end

  def sync_code
    "vfitrack"
  end

  def syncable_type
    "Product"
  end

  def validate_query_row_map
    map = query_row_map
    # Allow for an array to easily define column order based on the array index
    unless map.is_a?(Hash)
      temp_map = {}
      map.each_with_index do |v, x|
        temp_map[v] = x
      end
      map = temp_map
    end

    mappings = map.keys
    mappings.each {|field| raise "#{field} is not a valid mapping column." unless valid_columns.include?(field)}
    raise "You must provide a mapping for :product_id, :prod_uid, :class_cntry_iso, :hts_line_number" unless mappings.include?(:product_id) && mappings.include?(:prod_uid) && mappings.include?(:class_cntry_iso) && mappings.include?(:hts_line_number)
    @query_map = map
  end

  def valid_columns 
    [:product_id, :prod_uid, :prod_name, :prod_country_of_origin, :fda_product_code, :class_cntry_iso, :class_customs_description, :hts_line_number, :hts_hts_1, :hts_hts_2, :hts_hts_3]
  end

  def process_query_result row, opts
    @previous_product ||= nil

    to_return = []
    product_id = row[@query_map[:product_id]]

    if @previous_product && @previous_product['id'] == product_id
      add_classification_tariff_fields_to_local_data row, @previous_product
    else
      to_return << ApiSyncObject.new(@previous_product['id'], @previous_product) if @previous_product
      @previous_product = {}

      @previous_product['id'] = product_id
      @previous_product['prod_imp_syscode'] = vfitrack_importer_syscode(row)
      @previous_product['prod_uid'] = row[@query_map[:prod_uid]]
      @previous_product['prod_part_number'] = row[@query_map[:prod_uid]]
      @previous_product['prod_name'] = row[@query_map[:prod_name]] if @query_map[:prod_name]
      @previous_product['fda_product_code'] = row[@query_map[:fda_product_code]] if @query_map[:fda_product_code]
      @previous_product['prod_country_of_origin'] = row[@query_map[:prod_country_of_origin]] if @query_map[:prod_country_of_origin]

      add_classification_tariff_fields_to_local_data row, @previous_product
    end

    if opts[:last_result] && @previous_product.size > 0
      to_return << ApiSyncObject.new(@previous_product['id'], @previous_product)
      @previous_product = nil
    end

    to_return.size > 0 ? to_return : nil
  end


  def add_classification_tariff_fields_to_local_data row, product_data
    # The tariff line / hts # is the only piece of data we're 
    # sharing across multiple result rows to form a single product result
    classification = Array.wrap(product_data["classifications"]).find {|c| c["class_cntry_iso"] == row[@query_map[:class_cntry_iso]] }
    if classification.nil?
      classification = {}
      classification['class_cntry_iso'] = row[@query_map[:class_cntry_iso]]
      classification['class_customs_description'] = row[@query_map[:class_customs_description]] if @query_map[:class_customs_description]
      product_data["classifications"] ||= []
      product_data["classifications"] << classification
    end

    tariff = Array.wrap(classification["tariff_records"]).find {|t| t["hts_line_number"].to_i == row[@query_map[:hts_line_number]].to_i}
    if tariff.nil?
      # I'm not sure what situation, we'd have where the same hts_line_number is referenced multiple times by the query, but it's simple enough
      # to handle it here
      tariff = {}
      classification["tariff_records"] ||= []
      classification["tariff_records"] << tariff
    end
    
    tariff['hts_line_number'] = row[@query_map[:hts_line_number]]
    tariff['hts_hts_1'] = row[@query_map[:hts_hts_1]] if @query_map[:hts_hts_1]
    tariff['hts_hts_2'] = row[@query_map[:hts_hts_2]] if @query_map[:hts_hts_2]
    tariff['hts_hts_3'] = row[@query_map[:hts_hts_3]] if @query_map[:hts_hts_3]

    nil
  end

  def retrieve_remote_data local_data
    remote_data = api_client.find_by_uid "#{local_data['prod_imp_syscode']}-#{local_data['prod_uid']}", fields_to_request

    # Unwrap the product data from the outer wrapper
    if remote_data && remote_data['product']
      remote_data['product']
    else
      nil
    end
  end

  def merge_remote_data_with_local remote_data, local_data
    # Basically, what we're doing here is taking the 
    # local data representation of the product and merging it
    # together with the remote json one.  It's important
    # that the local is merged INTO the remote so that the 
    # ids in the remote are retained.    

    # The only data we really should push is Classification country / HTS 1 / FDA Product Code
    if remote_data.blank?
      remote_data = create_remote_product local_data
    else
      remote_data = merge_remote_product remote_data, local_data
    end

    remote_data
  end

  def send_remote_data remote_data
    to_send = {'product' => remote_data}

    if remote_data['id'].nil?
      api_client.create to_send
    else
      api_client.update to_send
    end
  end


  private

    def fields_to_request
      # VFI Track Custom Fields
      # 43 = "Part Number" (Alliance / Fenix) = string
      # 77 = "FDA Product?" (Alliance) = boolean
      # 78 = "FDA Product Code" (Alliance) = string
      # 41 = Country of Origin (Alliance / Fenix) = string
      # 99 = Customs Description (for Fenix) = string
      custom_field_map = {
        prod_uid: ['prod_uid', '*cf_43'],
        prod_name: 'prod_name',
        prod_country_of_origin: '*cf_41',
        fda_product_code: ['*cf_78', '*cf_77'],
        class_cntry_iso: 'class_cntry_iso',
        class_customs_description: '*cf_99',
        hts_line_number: 'hts_line_number',
        hts_hts_1: 'hts_hts_1',
        hts_hts_2: 'hts_hts_2',
        hts_hts_3: 'hts_hts_3'
      }.with_indifferent_access
      fields = @query_map.keys.map {|k| custom_field_map[k]}.compact.flatten
      fields << 'prod_imp_syscode'

      fields
    end

    def create_remote_product local_data
      remote_data = {
        "prod_uid" => "#{local_data["prod_imp_syscode"]}-#{local_data['prod_uid']}",
        "prod_imp_syscode" => local_data["prod_imp_syscode"],
        "*cf_43" => local_data['prod_part_number']
      }

      if @query_map.has_key?(:fda_product_code)
        remote_data["*cf_78"] = local_data['fda_product_code']
        remote_data["*cf_77"] = (local_data['fda_product_code'].blank? ? false : true)
      end

      remote_data["prod_name"] = local_data["prod_name"] if @query_map.has_key?(:prod_name)
      remote_data["*cf_41"] = local_data["prod_country_of_origin"] if @query_map.has_key?(:prod_country_of_origin)

      Array.wrap(local_data["classifications"]).each do |local_classification|
        remote_data["classifications"] ||= []
        update_classification_data remote_data["classifications"], local_classification
      end

      remote_data
    end

    def merge_remote_product remote_data, local_data
      # The header level stuff we can just do a straight replace on...
      remote_data["prod_imp_syscode"] = local_data["prod_imp_syscode"]
      remote_data["*cf_43"] = local_data['prod_part_number']

      if @query_map.has_key?(:fda_product_code)
        set_data(remote_data, "*cf_78", local_data['fda_product_code'])
        remote_data["*cf_77"] = (local_data['fda_product_code'].blank? ? false : true)
      end

      set_data(remote_data, "prod_name", local_data["prod_name"]) if @query_map.has_key?(:prod_name)
      set_data(remote_data, "*cf_41", local_data["prod_country_of_origin"]) if @query_map.has_key?(:prod_country_of_origin)

      remote_classifications = remote_data['classifications']
      if remote_classifications.nil? || remote_classifications.size == 0
        remote_classifications = []
      end

      local_tariff_isos = Set.new

      Array.wrap(local_data["classifications"]).each do |local_classification|
        update_classification_data(remote_classifications, local_classification)
        local_tariff_isos << local_classification['class_cntry_iso'] unless local_classification['class_cntry_iso'].blank?
      end

      if @sync_classifications
        # Mark any country not referenced locally to be destroyed..
        remote_classifications.each do |remote_classification|
          country = remote_classification['class_cntry_iso']
          mark_as_destroyed(remote_classification) unless local_tariff_isos.include?(country)
        end
      end
      

      if remote_classifications.length > 0
        remote_data["classifications"] = remote_classifications
      end

      remote_data
    end
  
    def update_classification_data remote_classifications, local_classification
      return unless local_classification['class_cntry_iso']

      remote_classification = remote_classifications.find {|c| c["class_cntry_iso"] == local_classification["class_cntry_iso"]}

      if remote_classification.nil?
        remote_classification = {'class_cntry_iso' => local_classification['class_cntry_iso']}
        remote_classifications << remote_classification
      end
      
      set_data(remote_classification, '*cf_99', local_classification["class_customs_description"]) if @query_map.has_key?(:class_customs_description)

      local_tariff_rows = Set.new
      Array.wrap(local_classification['tariff_records']).each do |local_tariff|
        next unless local_tariff["hts_line_number"]
        update_tariff_data remote_classification, local_tariff
        local_tariff_rows << local_tariff["hts_line_number"].to_i
      end

      # destroy any remote tariff rows that were not locally referenced.
      Array.wrap(remote_classification["tariff_records"]).each do |tr|
        mark_as_destroyed(tr) unless local_tariff_rows.include?(tr["hts_line_number"].to_i)
      end
      nil
    end

    def update_tariff_data remote_classification, local_tariff
      remote_tariff = Array.wrap(remote_classification['tariff_records']).find {|t| t["hts_line_number"].to_i == local_tariff["hts_line_number"].to_i}
      if remote_tariff.nil?
        remote_tariff = {"hts_line_number" => local_tariff['hts_line_number'].to_i}
        remote_classification["tariff_records"] ||= []
        remote_classification["tariff_records"] << remote_tariff
      end

      remote_tariff['hts_hts_1'] = local_tariff["hts_hts_1"].hts_format if @query_map.has_key?(:hts_hts_1)
      remote_tariff['hts_hts_2'] = local_tariff["hts_hts_2"]&.hts_format if @query_map.has_key?(:hts_hts_2)
      remote_tariff['hts_hts_3'] = local_tariff["hts_hts_3"]&.hts_format if @query_map.has_key?(:hts_hts_3)
      nil
    end

    def set_data remote, key, local_data
      # If the remote data isn't present and the local data is nil, then don't send the data
      # This is primarily to prevent generating blank custom values objects for nil values.
      # (Whose labels then get shown on screen).
      unless local_data.nil? && remote[key].nil?
        remote[key] = local_data
      end

    end

    def mark_as_destroyed obj
      obj["_destroy"] = true
    end

    def api_client
      @api_client
    end

end; end; end;
