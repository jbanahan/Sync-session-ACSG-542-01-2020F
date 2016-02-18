class AddCustomViewTemplateIdToSearchCriterion < ActiveRecord::Migration
  def change
    add_column :search_criterions, :custom_view_template_id, :integer
    add_index :search_criterions, :custom_view_template_id
  end
end
