class AddHiddenToMailingLists < ActiveRecord::Migration
  def change
    add_column :mailing_lists, :hidden, :boolean, default: false
  end
end
