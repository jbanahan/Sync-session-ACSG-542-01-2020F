require 'open_chain/custom_handler/lenox/lenox_custom_definition_support'
require 'open_chain/integration_client_parser'

module OpenChain; module CustomHandler; module Lenox; class LenoxProductParser
  extend OpenChain::IntegrationClientParser
  include LenoxCustomDefinitionSupport

  CUSTOM_DEFINITION_MAP ||= {
    part_number:[4,18],
    product_department:[131,20],
    product_pattern:[259,30],
    product_buyer_name:[459,25],
    product_units_per_set:[582,3],
    product_coo:[348,3]
  }

  def initialize
    @cdefs = self.class.prep_custom_definitions CUSTOM_DEFINITION_INSTRUCTIONS.keys
    @imp = Company.where(system_code:'LENOX').first_or_create!(name:'Lenox',importer:true)
  end

  def self.integration_folder
    "/opt/wftpserver/ftproot/www-vfitrack-net/_lenox_product"
  end

  def self.parse data, opts = {}
    LenoxProductParser.new.process data, User.find_by_username('integration')
  end

  def process data, user
    @user = user
    @hash_keys = DataCrossReference.get_all_pairs DataCrossReference::LENOX_ITEM_MASTER_HASH
    data.each_line.each do |ln|
      process_line ln
    end
  end

  def process_line ln
    part_number = ln[4,18].strip
    return unless line_changed?(ln,part_number)
    uid = "LENOX-#{part_number}"
    p = Product.where(unique_identifier:uid,importer_id:@imp.id).first_or_create!
    p.update_attributes(
      name:ln[22,40].strip,
      updated_at:0.seconds.ago) #updated_at forces save 

    batch_write_vals = []
    CUSTOM_DEFINITION_MAP.each do |k,v|
      cv = CustomValue.new(customizable_id:p.id,customizable_type:'Product',
        custom_definition_id:@cdefs[k].id)
      cv.value = ln[v.first,v.last].strip
      batch_write_vals << cv
    end
    pgroup_cv = CustomValue.new(customizable_id:p.id,customizable_type:'Product',
        custom_definition_id:@cdefs[:product_group].id)
    pgroup_cv.value = "#{ln[92,15].strip}-#{ln[109,20].strip}"
    batch_write_vals << pgroup_cv 
    CustomValue.batch_write! batch_write_vals
    p.create_snapshot @user
  end

  #has the md5 hash of the line changed since it was last processed
  def line_changed? ln, part_number
    hex = Digest::MD5.hexdigest ln
    xref_hex = @hash_keys[part_number] 
    return false if hex == xref_hex #no change, don't update anything
    DataCrossReference.create_lenox_item_master_hash! part_number, hex
    @hash_keys[part_number] = hex
    true
  end
end; end; end; end
