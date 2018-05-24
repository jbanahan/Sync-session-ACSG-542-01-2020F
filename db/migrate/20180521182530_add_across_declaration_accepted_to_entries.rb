class AddAcrossDeclarationAcceptedToEntries < ActiveRecord::Migration
  def change
    add_column :entries, :across_declaration_accepted, :datetime
  end
end
