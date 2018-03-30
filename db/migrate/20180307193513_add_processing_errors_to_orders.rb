class AddProcessingErrorsToOrders < ActiveRecord::Migration
  def change
    add_column :orders, :processing_errors, :text
  end
end
