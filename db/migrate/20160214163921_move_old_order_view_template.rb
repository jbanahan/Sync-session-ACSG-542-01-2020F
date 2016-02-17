class MoveOldOrderViewTemplate < ActiveRecord::Migration
  def up
    # migrate data to new data structure
    order_views = select_all('SELECT id, system_code, order_view_template FROM companies WHERE length(order_view_template) > 0')
    order_views.each do |c|
      template_id = insert("INSERT INTO custom_view_templates (template_identifier,template_path,created_at,updated_at) VALUES ('order_view','#{c['order_view_template']}',now(),now())")
      insert("INSERT INTO search_criterions (operator,value,model_field_uid,custom_view_template_id,created_at,updated_at) VALUES ('eq','#{c['system_code']}','ord_imp_syscode',#{template_id},now(),now())")
    end

    # drop column
    remove_column :companies, :order_view_template
  end

  def down

  end
end
