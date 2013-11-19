class AddLastExportedFromSourceToSecurityFilings < ActiveRecord::Migration
  def change
    add_column :security_filings, :last_exported_from_source, :datetime
  end
end
