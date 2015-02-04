require 'open_chain/custom_handler/api_sync_client'
require 'open_chain/api/product_api_client'

# This is a simple base class to extend for instance/company specific 
# syncing of data meant for syncing to VFI Track.
module OpenChain; module CustomHandler; class VfiTrackProductApiSyncClient < OpenChain::CustomHandler::ApiSyncClient

  attr_reader :api_client

  def initialize opts = {}
    # This is primarily just here as a guard so we only actually automate the api endpoint in production
    if Rails.env.production? && opts[:api_client].nil?
      @api_client = OpenChain::Api::ProductApiClient.new("vfitrack")
    else
      raise "You must pass an api_client as an ops key." unless opts[:api_client]
      @api_client = opts[:api_client]
    end
    validate_query_row_map
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

    mappings = map.keys
    mappings.each {|field| raise "#{field} is not a valid mapping column." unless valid_columns.include?(field)}
    raise "You must provide a mapping for :product_id, :prod_uid, :class_cntry_iso, :hts_line_number" unless mappings.include?(:product_id) && mappings.include?(:prod_uid) && mappings.include?(:class_cntry_iso) && mappings.include?(:hts_line_number)
    @query_map = map
  end

  def valid_columns 
    [:product_id, :prod_uid, :prod_name, :prod_country_of_origin, :fda_product_code, :class_cntry_iso, :class_customs_description, :hts_line_number, :hts_hts_1]
  end

  def process_query_result row, opts
    @previous_product ||= nil

    to_return = []
    product_id = row[@query_map[:product_id]]

    if @previous_product && @previous_product['id'] == product_id
      # The tariff line / hts # is the only piece of data we're 
      # sharing across multiple result rows to form a single product result
      tariff = {}
      @previous_product['tariff_records'] << tariff
      tariff['hts_line_number'] = row[@query_map[:hts_line_number]]
      tariff['hts_hts_1'] = row[@query_map[:hts_hts_1]] if @query_map[:hts_hts_1]
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
      @previous_product['class_cntry_iso'] = row[@query_map[:class_cntry_iso]]
      @previous_product['class_customs_description'] = row[@query_map[:class_customs_description]] if @query_map[:class_customs_description]

      tariff = {}
      @previous_product['tariff_records'] = [tariff]
      tariff['hts_line_number'] = row[@query_map[:hts_line_number]]
      tariff['hts_hts_1'] = row[@query_map[:hts_hts_1]]
    end

    if opts[:last_result] && @previous_product.size > 0
      to_return << ApiSyncObject.new(@previous_product['id'], @previous_product)
      @previous_product = nil
    end

    to_return.size > 0 ? to_return : nil
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
      @api_client.create to_send
    else
      @api_client.update to_send
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
        hts_hts_1: 'hts_hts_1'
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

      if @query_map[:fda_product_code]
        remote_data["*cf_78"] = local_data['fda_product_code']
        remote_data["*cf_77"] = (local_data['fda_product_code'].blank? ? false : true)
      end

      remote_data["prod_name"] = local_data["prod_name"] if @query_map[:prod_name]
      remote_data["*cf_41"] = local_data["prod_country_of_origin"] if @query_map[:prod_country_of_origin]

      insert_classification_data remote_data, local_data

      remote_data
    end

    def merge_remote_product remote_data, local_data
      # The header level stuff we can just do a straight replace on...
      remote_data["prod_imp_syscode"] = local_data["prod_imp_syscode"]
      remote_data["*cf_43"] = local_data['prod_part_number']

      if @query_map[:fda_product_code]
        remote_data["*cf_78"] = local_data['fda_product_code']
        remote_data["*cf_77"] = (local_data['fda_product_code'].blank? ? false : true)
      end

      remote_data["prod_name"] = local_data["prod_name"] if @query_map[:prod_name]
      remote_data["*cf_41"] = local_data["prod_country_of_origin"] if @query_map[:prod_country_of_origin]

      if remote_data['classifications'] && remote_data['classifications'].size > 0
        # Find the corresponding classification recore
        country = local_data['class_cntry_iso']
        if country
          classification = remote_data['classifications'].find {|c| c['class_cntry_iso'] == country}
          if classification
            # if we found the classification, then insert the classification description, if needed, then sync the tariff data
            classification['*cf_99'] = local_data["class_customs_description"] if @query_map[:class_customs_description]

            if classification['tariff_records'] && classification['tariff_records'].size > 0
              if local_data["tariff_records"].blank? || local_data["tariff_records"].size == 0
                # Since we don't have any local tariff records, mark all the remote ones to be destroyed
                classification['tariff_records'].each {|tr| tr["_destroy"] = true}
              else
                line_numbers = Set.new
                local_data["tariff_records"].each do |tr|
                  line_number = tr["hts_line_number"].to_i
                  remote_tariff = classification['tariff_records'].find {|t| t["hts_line_number"].to_i == line_number}

                  if remote_tariff
                    # Just use this method so we are sure we're retaining the same data output formatting
                    new_tariff = new_tariff_data(tr)
                    line_numbers << new_tariff['hts_line_number']
                    remote_tariff['hts_line_number'] = new_tariff['hts_line_number']
                    remote_tariff['hts_hts_1'] = new_tariff['hts_hts_1'] if @query_map[:hts_hts_1]
                  else
                    new_tariff = new_tariff_data(tr)
                    line_numbers << new_tariff['hts_line_number']
                    classification['tariff_records'] << new_tariff
                  end
                end

                # Now go through the remote records and mark to destroy those that were not locally utilized
                classification['tariff_records'].each {|tr| tr["_destroy"] = true unless line_numbers.include?(tr["hts_line_number"].to_i)}
              end
            else
              insert_tariff_data classification, local_data
            end
          else
            insert_classification_data remote_data, local_data
          end
        end
      else
        # Add in classification data, since it didn't exist 
        insert_classification_data remote_data, local_data
      end
      remote_data
    end
  
    def insert_classification_data remote_data, local_data
      return unless local_data['class_cntry_iso']

      # We're only expecting to sync US data at this point, so there's only a single 
      # US classification in our own data, hence no classification looping required
      classification = {'class_cntry_iso' => local_data['class_cntry_iso']}
      if @query_map[:class_customs_description]
        classification['*cf_99'] = local_data["class_customs_description"]
      end
      if remote_data['classifications']
        remote_data['classifications'] << classification
      else
        remote_data['classifications'] = [ classification ]
      end

      insert_tariff_data classification, local_data
    end

    def insert_tariff_data remote_classification_hash, local_data
      if local_data['tariff_records']
        tariff_records = []
        remote_classification_hash['tariff_records'] = tariff_records

        local_data['tariff_records'].each do |tr|
          tariff_records << new_tariff_data(tr)
        end
      end
    end

    def new_tariff_data local_data
      # Use hts format so we're retaining the same data formatting in and out
      # otherwise we'll break the local fingerprinting being done
      tariff = {"hts_line_number" => local_data['hts_line_number'].to_i}
      tariff['hts_hts_1'] = local_data["hts_hts_1"].hts_format if @query_map[:hts_hts_1]

      tariff
    end

end; end; end;