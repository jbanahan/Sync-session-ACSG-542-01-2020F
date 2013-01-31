class AddHtmlContentToEmail < ActiveRecord::Migration
  def change
    add_column :emails, :html_content, :text
  end
end
