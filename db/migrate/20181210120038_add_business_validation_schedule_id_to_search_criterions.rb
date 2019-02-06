class AddBusinessValidationScheduleIdToSearchCriterions < ActiveRecord::Migration
  def change
    add_column :search_criterions, :business_validation_schedule_id, :integer
  end
end
