require 'open_chain/custom_handler/vfitrack_custom_definition_support'

module ConfigMigrations; module Www; class ShoesForCrewsSow1520
  include OpenChain::CustomHandler::VfitrackCustomDefinitionSupport

  def up
    cdefs = self.class.prep_custom_definitions([:ord_destination_codes, :ord_line_destination_code])
    ActiveRecord::Base.connection.execute insert_query cdefs
  end

  def insert_query cdefs
    <<-QRY
      INSERT INTO custom_values (customizable_id, customizable_type, string_value, custom_definition_id, created_at, updated_at) 
      SELECT 
        ord.id, 
        'Order', 
        GROUP_CONCAT(DISTINCT cv_det.string_value ORDER BY cv_det.string_value SEPARATOR ","), 
        #{cdefs[:ord_destination_codes].id}, 
        NOW(), 
        NOW() 
      FROM 
        custom_values AS cv_det 
        INNER JOIN order_lines AS ol ON 
          cv_det.customizable_id = ol.id 
        INNER JOIN orders AS ord ON 
          ol.order_id = ord.id 
        LEFT OUTER JOIN custom_values AS cv_head ON 
          ord.id = cv_head.customizable_id AND 
          cv_head.custom_definition_id = #{cdefs[:ord_destination_codes].id}
      WHERE 
        ord.importer_id = (SELECT id FROM companies WHERE system_code = 'SHOES') AND 
        cv_det.custom_definition_id = #{cdefs[:ord_line_destination_code].id} AND 
        cv_head.id IS NULL 
      GROUP BY 
        ord.id
    QRY
  end

  def down
    cdefs = self.class.prep_custom_definitions([:ord_destination_codes])
    CustomValue.where("custom_definition_id = #{cdefs[:ord_destination_codes].id}").delete_all
  end

end;end;end