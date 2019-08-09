require 'open_chain/custom_handler/product_generator'
require 'open_chain/custom_handler/ann_inc/ann_custom_definition_support'
require 'open_chain/custom_handler/ann_inc/ann_related_styles_support'
require 'open_chain/custom_handler/ann_inc/ann_ftz_generator_helper'
require 'open_chain/gpg'

module OpenChain; module CustomHandler; module AnnInc; class AnnBomProductGenerator < OpenChain::CustomHandler::ProductGenerator
  include OpenChain::CustomHandler::AnnInc::AnnCustomDefinitionSupport
  include OpenChain::CustomHandler::AnnInc::AnnRelatedStylesSupport
  include OpenChain::CustomHandler::AnnInc::AnnFtzGeneratorHelper

  SYNC_CODE ||= "ANN-BOM"

  def self.run_schedulable opts = {}
    self.new(opts).generate "118340_BOM_VFI_"
  end

  def cdefs
    @cdefs ||= self.class.prep_custom_definitions [:classification_type, :key_description, :set_qty, :percent_of_value, :related_styles, :approved_date]
  end

  # Integration Point requires each file to be under 25MB. Each line is under 199 bytes, but must be multipled by the number of related styles.
  # It appears that no product has more than three related styles with 4 tariffs each, so if 25 MB = 2.5e7 bytes a conservative estimate would be
  # (2.5e7 bytes / 200 bytes) / 16 lines = 10416 lines
  def max_results
    10000
  end

  def sync_code
    SYNC_CODE
  end

  def ftp_credentials
    folder = MasterSetup.get.production? ? "BOM" : "BOM_TEST"
    connect_vfitrack_net("to_ecs/Ann/#{folder}")
  end

  # called by #preprocess_row in AnnFtzGeneratorHelper
  def explode_lines row, exploded_rows
    explode_lines_with_related_styles(row, unique_identifier: 4, related: -1) do |row|
      local_row = row.dup
      local_row[5] = local_row[4] + "-" + ('%02d' % (local_row[-2] - 1))
      exploded_rows[local_row[4]] << [local_row] unless local_row.blank?
    end
  end

  # negative indices are not included in outbound file
  def remap row
    {
     -2 => row[4], # line_number
     -1 => row[1], # related_styles
      0 => 118340,
      1 => timestamp,
      2 => nil,
      3 => nil,
      4 => row[0], # unique_identifier
      5 => nil, # assigned in #preprocess_row
      6 => nil,
      7 => row[3], # hts_1
      8 => 'Y',
      9 => clean_description(row[7]), # key_description
     10 => nil,
     11 => 0,
     12 => (row[5] > 1) ? row[5] : 1, # set_qty
     13 => row[6] || 0, # percent_of_value
     14 => nil,
     15 => nil,
     16 => nil,
     17 => 0,
     18 => 0,
     19 => 0,
     20 => starts_with_91?(row[3]) ? "Y" : "N", # tariff
     21 => nil,
     22 => nil,
     23 => "LADIES",
     24 => starts_with_91?(row[3]) ? row[4] : 0 # tariff, line_number
    }
  end

  def starts_with_91? hts
    hts.to_s.match(/^91/)
  end
  
  def query
    q = <<-SQL
          SELECT products.id,
                 products.unique_identifier,
                 SUBSTR(related_styles.text_value,1,50),
                 classification_type.string_value,
                 tr.hts_1,
                 tr.line_number,
                 IFNULL(set_qty.integer_value, 0),
                 IFNULL(percent_of_value.integer_value, 0),
                 SUBSTR(key_description.text_value,1,50)
          FROM products
            LEFT OUTER JOIN custom_values related_styles ON related_styles.customizable_id = products.id 
              AND related_styles.customizable_type = "Product" AND related_styles.custom_definition_id = ?
            INNER JOIN classifications cl ON products.id = cl.product_id
            LEFT OUTER JOIN custom_values AS classification_type ON cl.id = classification_type.customizable_id 
              AND classification_type.customizable_type = "Classification" AND classification_type.custom_definition_id = ?
            LEFT OUTER JOIN custom_values AS approved_date ON cl.id = approved_date.customizable_id
              AND approved_date.customizable_type = "Classification" AND approved_date.custom_definition_id = ?
            INNER JOIN tariff_records AS tr ON cl.id = tr.classification_id
            LEFT OUTER JOIN custom_values AS set_qty ON tr.id = set_qty.customizable_id
              AND set_qty.customizable_type = "TariffRecord" AND set_qty.custom_definition_id = ?
            LEFT OUTER JOIN custom_values AS percent_of_value ON tr.id = percent_of_value.customizable_id
              AND percent_of_value.customizable_type = "TariffRecord" AND percent_of_value.custom_definition_id = ?
            LEFT OUTER JOIN custom_values AS key_description ON tr.id = key_description.customizable_id
              AND key_description.customizable_type = "TariffRecord" AND key_description.custom_definition_id = ?
          #{where_clause}
          ORDER BY products.id, tr.line_number
          LIMIT ?
        SQL
    ActiveRecord::Base.sanitize_sql_array([q, cdefs[:related_styles].id,cdefs[:classification_type].id,cdefs[:approved_date].id,cdefs[:set_qty].id,cdefs[:percent_of_value].id,cdefs[:key_description].id,max_results])
  end

  def where_clause
    sql = ""
    if @custom_where.blank?
      sql << Product.need_sync_join_clause(sync_code)
      sql << " WHERE #{Product.need_sync_where_clause()}"
      sql << " AND cl.country_id = ? AND classification_type.string_value = 'Multi'"
      sql << " AND approved_date.date_value IS NOT NULL "
      sql << " AND IF(sync_records.sent_at IS NULL, approved_date.date_value < CURRENT_DATE(), 1) "
    else
      sql << @custom_where
    end
    ActiveRecord::Base.sanitize_sql_array([sql, us.id])
  end

end; end; end; end
