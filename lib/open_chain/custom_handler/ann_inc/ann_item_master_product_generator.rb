require 'open_chain/custom_handler/product_generator'
require 'open_chain/custom_handler/ann_inc/ann_custom_definition_support'
require 'open_chain/custom_handler/ann_inc/ann_related_styles_support'
require 'open_chain/custom_handler/ann_inc/ann_ftz_generator_helper'
require 'open_chain/gpg'

module OpenChain; module CustomHandler; module AnnInc; class AnnItemMasterProductGenerator < OpenChain::CustomHandler::ProductGenerator
  include OpenChain::CustomHandler::AnnInc::AnnCustomDefinitionSupport
  include OpenChain::CustomHandler::AnnInc::AnnRelatedStylesSupport
  include OpenChain::CustomHandler::AnnInc::AnnFtzGeneratorHelper

  SYNC_CODE ||= "ANN-ITEM-MASTER"

  def self.run_schedulable opts = {}
    self.new(opts).generate "118340_ITEMMASTER_VFI_"
  end

  def cdefs
    @cdefs ||= self.class.prep_custom_definitions [:classification_type, :long_desc_override, :approved_long, :related_styles, :set_qty]
  end

  # Integration Point requires each file to be under 25MB. Each line is under 199 bytes, but must be multipled by the number of related styles.
  # It appears that no product has more than three related styles, so if 25 MB = 2.5e7 bytes a conservative estimate would be
  # (2.5e7 bytes / 200 bytes) / 4 lines = 31250 lines
  def max_results
    30000
  end

  #superclass requires this method
  def sync_code
    SYNC_CODE
  end
  
  def generate file_stem
    r_count = nil
    file_count = 0
    now = timestamp.delete("T")
    begin
      file = sync_csv
      file_count += 1
      # At least one file should be sent, even if it's blank
      if (r_count = self.row_count) > 0 || (file_count == 1)
        encrypt_file(file) { |enc_file| ftp_file enc_file, remote_file_name: "#{file_stem}#{now}#{suffix(file_count)}.txt.gpg" }
        file.close
      end
    end while r_count > 0
  end

  def ftp_credentials
    folder = MasterSetup.get.production? ? "ITEM_MASTER" : "ITEM_MASTER_TEST"
    connect_vfitrack_net("to_ecs/Ann/#{folder}")
  end

  # called by #preprocess_row in AnnFtzGeneratorHelper
  def explode_lines row, exploded_rows
    explode_lines_with_related_styles(row, unique_identifier: 39, related: -1) do |row|
      local_row = [row]
      exploded_rows[row[-1]] << local_row unless local_row.blank?
    end
  end

  # negative indices are not included in outbound file
  def remap row
    {  
      -1 => row[5], # related_styles
       0 => 118340,
       1 => timestamp,
       2 => nil,
       3 => nil,
       4 => (row[1].presence || row[2])&.gsub(/\r?\n/, " "), # long_desc_override, approved_long
       5 => nil,
       6 => 0,
       7 => nil,
       8 => 0,
       9 => nil,
      10 => nil,
      11 => nil,
      12 => nil,
      13 => nil,
      14 => nil,
      15 => (row[6] > 1) ? row[6] : 1, # set_qty,
      16 => nil,
      17 => nil,
      18 => row[3], # hts_1
      19 => nil,
      20 => nil,
      21 => nil,
      22 => nil,
      23 => 0,
      24 => 0,
      25 => nil,
      26 => 0,
      27 => 0,
      28 => nil,
      29 => 0,
      30 => 0,
      31 => nil,
      32 => nil,
      33 => nil,
      34 => 0,
      35 => nil,
      36 => 0,
      37 => nil,
      38 => (row[4] == "Not Applicable") ? nil : row[4], # classification_type
      39 => row[0], # unique_identifier
      40 => "LADIES"
    }
  end

  def query
    <<-SQL
      SELECT products.id,
             products.unique_identifier,
             SUBSTR(long_desc_override.text_value,1, 50),
             SUBSTR(approved_long.text_value,1,50),
             tr.hts_1,
             classification_type.string_value,
             SUBSTR(related_styles.text_value,1,50),
             IFNULL(set_qty.integer_value, 0)
      FROM products
        LEFT OUTER JOIN custom_values AS related_styles ON products.id = related_styles.customizable_id 
          AND related_styles.customizable_type = "Product" AND related_styles.custom_definition_id = #{cdefs[:related_styles].id}
        LEFT OUTER JOIN custom_values AS approved_long ON products.id = approved_long.customizable_id 
          AND approved_long.customizable_type = "Product" AND approved_long.custom_definition_id = #{cdefs[:approved_long].id}
        INNER JOIN classifications cl ON products.id = cl.product_id
        LEFT OUTER JOIN custom_values AS long_desc_override ON cl.id = long_desc_override.customizable_id 
          AND long_desc_override.customizable_type = "Classification" AND long_desc_override.custom_definition_id = #{cdefs[:long_desc_override].id}
        LEFT OUTER JOIN custom_values AS classification_type ON cl.id = classification_type.customizable_id 
          AND classification_type.customizable_type = "Classification" AND classification_type.custom_definition_id = #{cdefs[:classification_type].id}
        INNER JOIN tariff_records AS tr ON cl.id = tr.classification_id
        LEFT OUTER JOIN custom_values AS set_qty ON tr.id = set_qty.customizable_id
          AND set_qty.customizable_type = "TariffRecord" AND set_qty.custom_definition_id = #{cdefs[:set_qty].id}
      #{where_clause}
      ORDER BY products.id, tr.line_number
      LIMIT #{max_results}
    SQL
  end

  def where_clause
    sql = ""
    if @custom_where.blank?
      sql << Product.need_sync_join_clause(sync_code)
      sql << " WHERE #{Product.need_sync_where_clause()}"
      sql << " AND tr.line_number = 1 AND cl.country_id = #{us.id}"
    else
      sql << @custom_where
    end
  end
  
end; end; end; end
