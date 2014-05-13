class AddExpirationDaysToSurveys < ActiveRecord::Migration
  def change
    add_column :surveys, :expiration_days, :integer
  end
end
