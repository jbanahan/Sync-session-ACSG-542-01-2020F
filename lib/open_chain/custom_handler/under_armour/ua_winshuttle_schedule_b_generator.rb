require 'open_chain/custom_handler/product_generator'
require 'open_chain/custom_handler/under_armour/under_armour_custom_definition_support'

module OpenChain; module CustomHandler; module UnderArmour
  class UaWinshuttleScheduleBGenerator < OpenChain::CustomHandler::ProductGenerator
    include OpenChain::CustomHandler::UnderArmour::UnderArmourCustomDefinitionSupport

    def self.run_and_email email_address
      ActiveRecord::Base.transaction do #if the file isn't sent and archived, then it never happened
        g = self.new
        f = g.sync_xls
        return if f.nil?
        g.email_file f, email_address
        ArchivedFile.make_from_file! f, 'Winshuttle Schedule B Output', "Sent to #{email_address} at #{Time.now} (UTC)"
      end
    end

    def initialize options = {}
      @colors_cd = self.class.prep_custom_definitions([:colors])[:colors]
      @custom_where = options[:custom_where]
    end
    def can_view?(user)
      user.company.master? && user.edit_products? && MasterSetup.get.custom_feature?('UA SAP')
    end
    def sync_code
      'winshuttle-b'
    end
    def email_file f, email_address
      Attachment.add_original_filename_method f
      f.original_filename = "winshuttle_schedule_b_#{Time.now.strftime('%Y%m%d')}.xls"
      OpenMailer.send_simple_html(email_address,'Winshuttle Schedule B Output File','Your Winshuttle schedule b output file is attached.  For assistance, please email support@vandegriftinc.com',[f]).deliver
    end
    def preprocess_row base_row
      r = []
      base_row[4] = base_row[4].hts_format
      color_codes = base_row.delete 5
      return [] if color_codes.blank?
      color_codes.split("\n").each do |c|
        next if c.blank?
        good_row = base_row.clone
        good_row[1] = "#{base_row[1]}-#{c.strip}"
        r << good_row
      end
      r
    end
    def query
      q = "SELECT products.id,
      '' as 'Log Winshuttle RUNNER for TRANSACTION 10.5\nZM30-Add-Code.TxR\n#{Time.now.strftime('%-m/%-d/%Y %l:%M %p')}\nMode:  Batch\nPRD-100, pmckeldin',
      products.unique_identifier as 'ZMMHSCONV-MATNR(01)\nMaterial number, without search help',
      '0050' as 'ZMMHSCONV-WERKS(01)\nPlant', 
      'CA' as 'ZMMHSCONV-LAND2(01)\nCountry Key',
      tariff_records.schedule_b_1 as 'ZMMHSCONV-STAWN2(01)\nCommodity code / Import code number for foreign trade',
      (SELECT text_value FROM custom_values where custom_definition_id = #{@colors_cd.id} AND customizable_id = products.id) as ''
      FROM products
      #{Product.need_sync_join_clause(sync_code)} 
      INNER JOIN classifications on products.id = classifications.product_id AND classifications.country_id = (select id from countries where iso_code = 'US') 
      INNER JOIN tariff_records on tariff_records.classification_id = classifications.id and length(tariff_records.schedule_b_1) > 0 and tariff_records.line_number = 1 
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
