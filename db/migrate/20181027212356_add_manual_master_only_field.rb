class AddManualMasterOnlyField < ActiveRecord::Migration
  def change
    add_column :user_manuals, :master_company_only, :boolean, default: false
  end
end
