require 'open_chain/custom_handler/ann_inc/ann_custom_definition_support'
require 'open_chain/custom_handler/ann_inc/ann_sap_product_handler'
class CustomReportAnnSapChanges < CustomReport
  include OpenChain::CustomHandler::AnnInc::AnnCustomDefinitionSupport 
  def self.template_name
    'SAP Changes'
  end

  def self.description
    "Show all SAP records that have had key fields changes since they were approved."
  end

  def self.column_fields_available user
    CoreModule::PRODUCT.model_fields(user).values + CoreModule::CLASSIFICATION.model_fields(user).values
  end

  def self.criterion_fields_available user
    column_fields_available user
  end

  def self.can_view? user
    user.company.master? && MasterSetup.get.custom_feature?('Ann SAP')
  end

  def run run_by, row_limit=nil
    raise "User #{run_by.username} does not have permission to view this report." unless self.class.can_view?(run_by) 
    left_columns_count = 0
    rpf = OpenChain::CustomHandler::AnnInc::AnnSapProductHandler::SAP_REVISED_PRODUCT_FIELDS
    cdefs = self.class.prep_custom_definitions rpf + [:approved_date,:sap_revised_date]
    qry = "
#{make_select(cdefs)}
FROM products
INNER JOIN classifications on products.id = classifications.product_id
INNER JOIN custom_values appr on appr.customizable_id = classifications.id and appr.custom_definition_id = #{cdefs[:approved_date].id}
INNER JOIN custom_values sap on sap.customizable_id = products.id and sap.custom_definition_id = #{cdefs[:sap_revised_date].id}
#{make_where} #{row_limit.blank? ? "" : " LIMIT #{row_limit}"}"
    r = ActiveRecord::Base.connection.execute qry
    row_cursor = 0
    col_cursor = 0
    heading_row 0
    if self.include_links?
      left_columns_count += 1
      write row_cursor, col_cursor, "Web Links"
      col_cursor += 1
    end
    left_columns_count += search_columns.size
    search_columns.each do |sc|
      write row_cursor, col_cursor, sc.model_field.label
      col_cursor += 1
    end
    rpf.each do |d|
      mf = cdefs[d].model_field
      write row_cursor, col_cursor, "Old #{mf.label}"
      col_cursor += 1
      write row_cursor, col_cursor, "New #{mf.label}"
      col_cursor += 1
    end
    row_cursor += 1
    request_host = MasterSetup.get.request_host
    r.each do |row|
      col_cursor = 0
      if self.include_links?
        write row_cursor, col_cursor, "#{request_host}/products/#{row.last}"
        col_cursor += 1
      end
      search_columns.each_with_index do |sc,idx|
        write row_cursor, col_cursor, sc.model_field.process_query_result(row[idx],run_by)
        col_cursor += 1
      end
      es_json = row[search_columns.size + rpf.size]
      es_hash = es_json.blank? ? {'entity'=>{'model_fields'=>{}}} : JSON.parse(es_json)
      rpf.each_with_index do |d,i|
        mf = cdefs[d].model_field
        new_col = left_columns_count+1+(i*2)
        new_val_position = left_columns_count+i
        write row_cursor, new_col, mf.process_query_result(row[new_val_position],run_by)

        old_col = left_columns_count+(i*2)
        old_val = ""
        old_val = es_hash['entity']['model_fields'][mf.uid.to_s] unless es_hash['entity']['model_fields'][mf.uid.to_s].blank?
        write row_cursor, old_col, old_val
      end
      row_cursor += 1
    end
  end

  private
  def make_select cdefs
    flds = []
    search_columns.each_with_index {|sc,idx| flds << "#{sc.model_field.qualified_field_name} AS \"#{idx}\""}
    OpenChain::CustomHandler::AnnInc::AnnSapProductHandler::SAP_REVISED_PRODUCT_FIELDS.each do |uid|
      mf = cdefs[uid].model_field
      flds << "#{mf.qualified_field_name} AS \"CD#{cdefs[uid].id}\""
    end
    flds << "(IF(appr.date_value is null,null,(SELECT snapshot FROM entity_snapshots WHERE recordable_id = products.id AND recordable_type = 'Product' AND created_at <= appr.date_value ORDER BY created_at DESC LIMIT 1))) as 'ES'"
    flds << "products.id"
    "SELECT #{flds.join(", ")} "
  end
  def make_where 
    wheres = self.search_criterions.collect do |sc| 
      v = sc.where_value
      if v.respond_to? :collect
        v = v.collect {|val| ActiveRecord::Base.sanitize val}.join(",")
      else
        v = ActiveRecord::Base.sanitize v
      end
      sc.where_clause(v).gsub("?",v)
    end
    wheres << "appr.date_value < sap.date_value" 
    "WHERE (#{wheres.join(") AND (")})"
  end
end
