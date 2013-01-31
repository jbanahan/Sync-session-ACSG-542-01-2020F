class ChangeTextFieldsOnEmail < ActiveRecord::Migration
  def change
    change_column :emails, :body_text, :text, :limit => 4294967295
    change_column :emails, :json_content, :text, :limit => 4294967295
    change_column :emails, :mime_content, :text, :limit => 4294967295
    change_column :emails, :html_content, :text, :limit => 4294967295
  end
end
