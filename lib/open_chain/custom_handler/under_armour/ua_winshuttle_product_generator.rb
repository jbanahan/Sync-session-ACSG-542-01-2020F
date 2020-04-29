require 'open_chain/custom_handler/product_generator'
require 'open_chain/custom_handler/under_armour/under_armour_custom_definition_support'
require 'digest/md5'

module OpenChain; module CustomHandler; module UnderArmour
  class UaWinshuttleProductGenerator < OpenChain::CustomHandler::ProductGenerator
    include OpenChain::CustomHandler::UnderArmour::UnderArmourCustomDefinitionSupport

    def self.run_and_email email_address
      ActiveRecord::Base.transaction do # if the file isn't sent and archived, then it never happened
        g = self.new
        f = g.sync_xls
        return if f.nil?
        g.email_file f, email_address
        ArchivedFile.make_from_file! f, 'Winshuttle Output', "Sent to #{email_address} at #{Time.now} (UTC)"
      end
    end

    def initialize options = {}
      defs = self.class.prep_custom_definitions([:plant_codes, :colors])
      @plant_cd = defs[:plant_codes]
      @colors_cd = defs[:colors]
      @plant_code_country_map = {}
      DataCrossReference.hash_for_type(DataCrossReference::UA_PLANT_TO_ISO).each do |k, v|
        @plant_code_country_map[k] = Country.find_by_iso_code(v).id
      end
      @custom_where = options[:custom_where]
    end
    def sync_code
      'winshuttle'
    end
    def can_view?(user)
      user.company.master? && user.edit_products? && MasterSetup.get.custom_feature?('UA SAP')
    end

    def email_file f, email_address
      Attachment.add_original_filename_method f
      f.original_filename = "winshuttle_#{Time.now.strftime('%Y%m%d')}.xls"
      OpenMailer.send_simple_html(email_address, 'Winshuttle Product Output File', 'Your Winshuttle product output file is attached.  For assistance, please email support@vandegriftinc.com', [f]).deliver_now
    end

    def preprocess_row base_row, opts = {}
      r = []
      country_id = base_row.delete 4
      plant_codes = base_row[2]
      plant_codes.lines.each do |pc|
        pc.strip!
        # only use the plant code(s) for the country that is returned in the classification record
        next unless @plant_code_country_map[pc] == country_id
        good_row = base_row.clone
        good_row[2] = pc
        # format hts values
        good_row[3] = good_row[3].hts_format
        color_list = good_row.delete(5)
        next if color_list.blank?
        colors = color_list.split("\n")
        colors.each do |c|
          next unless DataCrossReference.find_ua_material_color_plant good_row[1], c, pc
          to_write = good_row.clone
          to_write[1] = "#{to_write[1]}-#{c}"

          fingerprint = data_fingerprint to_write
          xref_value = DataCrossReference.find_ua_winshuttle_fingerprint good_row[1], c, pc
          next if xref_value == fingerprint

          DataCrossReference.create_ua_winshuttle_fingerprint! good_row[1], c, pc, fingerprint
          r << to_write
        end
      end
      r
    end

    def data_fingerprint output
      Digest::MD5.hexdigest output.values.join("~")
    end

    def query
      q = "SELECT products.id,
      '' as 'Log Winshuttle RUNNER for TRANSACTION 10.2\nMM02-Change HTS Code.TxR\n#{Time.now.strftime('%-m/%-d/%Y %l:%M %p')}\nMode:  Batch\nPRD-100, pmckeldin',
      products.unique_identifier as 'Material Number',
      plant.text_value as 'Plant',
      tr.hts_1 as 'HTS Code',
      classifications.country_id as '',
      color.text_value as ''
      FROM products
      #{Product.need_sync_join_clause(sync_code)}
      INNER JOIN classifications on products.id = classifications.product_id AND classifications.country_id in (select distinct countries.id from countries inner join data_cross_references on data_cross_references.cross_reference_type = '#{DataCrossReference::UA_PLANT_TO_ISO}' AND countries.iso_code = data_cross_references.value)
      INNER JOIN (select * FROM tariff_records where line_number = 1) as tr on classifications.id = tr.classification_id
      INNER JOIN custom_values as plant on plant.customizable_type = 'Product' AND plant.customizable_id = products.id AND plant.custom_definition_id = #{@plant_cd.id} AND length(plant.text_value) > 0
      INNER JOIN custom_values as color on color.customizable_type = 'Product' AND color.customizable_id = products.id AND color.custom_definition_id = #{@colors_cd.id} AND length(color.text_value) > 0
      "
      if @custom_where.blank?
        q << "WHERE #{Product.need_sync_where_clause()}"
      else
        q << @custom_where
      end
      q
    end

  end
end; end; end
