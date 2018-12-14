require 'open_chain/ftp_file_support'
require 'open_chain/fixed_width_layout_based_generator'

module OpenChain; module CustomHandler; module Vandegrift; module FenixInvoice810GeneratorSupport
  extend ActiveSupport::Concern
  include OpenChain::FtpFileSupport
  include OpenChain::FixedWidthLayoutBasedGenerator

  def ftp_connection_info
    connect_vfitrack_net(ftp_folder)
  end

  def ftp_folder
    "to_ecs/fenix_invoices"
  end

  def output_mapping_for map
    if map == :header
      return invoice_header_map()
    elsif map == :detail
      return invoice_detail_map()
    elsif map == :party
      return invoice_party_map()
    end
  end

  def header_format
    @header ||= {
      map_name: :header,
      fields: [
        {field: :record_type, length: 1},
        {field: :invoice_number, length: 25},
        {field: :invoice_date, length: 10, data_type: :date, format: {justification: :left}},
        {field: :country_origin_code, length: 10},
        {field: :country_ultimate_destination, length: 10},
        {field: :currency, length: 4},
        {field: :number_of_cartons, length: 15, format: {justification: :left}},
        {field: :gross_weight, length: 15, format: {justification: :left}},
        {field: :total_units, length: 15, format: {justification: :left}},
        {field: :total_value, length: 15, format: {justification: :left}},
        {field: :shipper, sub_layout: party_format},
        {field: :consignee, sub_layout: party_format},
        {field: :importer, sub_layout: party_format},
        {field: :po_number, length: 50},
        {field: :mode_of_transportation, length: 1},
        {field: :reference_identifier, length: 50},
        {field: :customer_name, length: 50},
        {field: :scac, length: 4},
        {field: :master_bill, length: 30}
      ]
    }
  end

  def detail_format 
    @detail ||= {
      map_name: :detail,
      fields: [
        {field: :record_type, length: 1},
        {field: :part_number, length: 50},
        {field: :country_origin_code, length: 10},
        {field: :hts_code, length: 12},
        {field: :tariff_description, length: 50},
        {field: :quantity, length: 15, format: {justification: :left}},
        {field: :unit_price, length: 15, format: {justification: :left}},
        {field: :po_number, length: 50},
        {field: :tariff_treatment, :length=> 10}
      ]
    }
  end

  def party_format
    @party ||= {
      map_name: :party,
      fields: [
        {field: :name, length: 50},
        {field: :name_2, length: 50},
        {field: :address_1, length: 50},
        {field: :address_2, length: 50},
        {field: :city, length: 50},
        {field: :state, length: 50},
        {field: :postal_code, length: 50}
      ]
    }
  end

  # Override the standard string output to handle transliteration and stripping some chars that trip
  # up Fenix (! and | for some reason)
  def output_string value, length, format_hash
    if !value.nil?
      # We need to make sure we're only exporting ASCII chars so add a ? for any character that can't 
      # be transliterated
      value = ActiveSupport::Inflector.transliterate(value)

      # B3 data apparently can't contain ! or | in them.  Remove them
      value = value.gsub(/[!|]/, " ")
    end

    super(value, length, format_hash)
  end


end; end; end; end