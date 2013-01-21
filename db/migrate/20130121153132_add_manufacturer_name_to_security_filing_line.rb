class AddManufacturerNameToSecurityFilingLine < ActiveRecord::Migration
  def change
    add_column :security_filing_lines, :manufacturer_name, :string
  end
end
