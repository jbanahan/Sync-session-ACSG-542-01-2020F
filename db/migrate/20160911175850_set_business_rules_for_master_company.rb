class SetBusinessRulesForMasterCompany < ActiveRecord::Migration
  def up
    execute "UPDATE companies SET show_business_rules = 1 WHERE master = 1"
  end

  def down
  end
end
