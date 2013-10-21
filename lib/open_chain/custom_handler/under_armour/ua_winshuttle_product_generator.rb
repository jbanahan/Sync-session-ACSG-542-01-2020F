require 'open_chain/custom_handler/product_generator'
require 'open_chain/custom_handler/under_armour/under_armour_custom_definition_support'

module OpenChain; module CustomHandler; module UnderArmour
  class UaWinshuttleProductGenerator < OpenChain::CustomHandler::ProductGenerator
    include OpenChain::CustomHandler::UnderArmour::UnderArmourCustomDefinitionSupport
    
    def self.run_and_email email_address
      ActiveRecord::Base.transaction do #if the file isn't sent and archived, then it never happened
        g = self.new
        f = g.sync_xls
        return if f.nil?
        g.email_file f, email_address
        ArchivedFile.make_from_file! f, 'Winshuttle Output', "Sent to #{email_address} at #{Time.now} (UTC)"
      end
    end

    def initialize options = {}
      @plant_cd = self.class.prep_custom_definitions([:plant_codes])[:plant_codes]
      @plant_code_country_map = {}
      DataCrossReference.hash_for_type(DataCrossReference::UA_PLANT_TO_ISO).each do |k,v|
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
      OpenMailer.send_simple_html(email_address,'Winshuttle Product Output File','Your Winshuttle product output file is attached.  For assistance, please email support@vandegriftinc.com',[f]).deliver
    end

    def preprocess_row base_row
      r = []
      country_id = base_row.delete 4
      plant_codes = base_row[2]
      plant_codes.lines.each do |pc|
        pc.strip!
        # only use the plant code(s) for the country that is returned in the classification record
        next unless @plant_code_country_map[pc] == country_id
        good_row = base_row.clone
        material_plant = "#{good_row[1]}#{pc}"
        used_hts = DataCrossReference.find_ua_winshuttle_hts material_plant
        next if used_hts == good_row[3]
        DataCrossReference.add_xref! DataCrossReference::UA_WINSHUTTLE, material_plant, good_row[3]
        good_row[2] = pc
        # format hts values
        good_row[3] = good_row[3].hts_format
        r << good_row
      end
      r
    end

    def query
      q = "SELECT products.id,
      '' as 'Log Winshuttle RUNNER for TRANSACTION 10.2\nMM02-Change HTS Code.TxR\n#{Time.now.strftime('%-m/%-d/%Y %l:%M %p')}\nMode:  Batch\nPRD-100, pmckeldin',
      products.unique_identifier as 'Material Number',
      custom_values.text_value as 'Plant', 
      tr.hts_1 as 'HTS Code',
      classifications.country_id as ''
      FROM products
      LEFT OUTER JOIN sync_records on products.id = sync_records.syncable_id AND sync_records.syncable_type = 'Product' AND sync_records.trading_partner = '#{sync_code}'
      INNER JOIN classifications on products.id = classifications.product_id AND classifications.country_id in (select countries.id from countries inner join data_cross_references on data_cross_references.cross_reference_type = '#{DataCrossReference::UA_PLANT_TO_ISO}' AND countries.iso_code = data_cross_references.value)
      INNER JOIN (select * FROM tariff_records where line_number = 1) as tr on classifications.id = tr.classification_id
      INNER JOIN custom_values on custom_values.customizable_type = 'Product' AND custom_values.customizable_id = products.id AND custom_values.custom_definition_id = #{@plant_cd.id} AND length(text_value) > 0
      "
      if @custom_where.blank?
        q << "WHERE (sync_records.confirmed_at IS NULL OR sync_records.sent_at IS NULL OR sync_records.sent_at > sync_records.confirmed_at OR  sync_records.sent_at < products.updated_at)"
      else
        q << @custom_where
      end
      q
    end

  end
end; end; end
