class AddDepartmentToCommercialInvoiceLine < ActiveRecord::Migration
  def self.up
    add_column :commercial_invoice_lines, :department, :string
  end

  def self.down
    remove_column :commercial_invoice_lines, :department
  end
end
