class AddCountriesOfOriginToSecurityFiling < ActiveRecord::Migration
  def change
    add_column :security_filings, :countries_of_origin, :text
  end
end
