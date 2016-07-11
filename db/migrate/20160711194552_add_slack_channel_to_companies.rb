class AddSlackChannelToCompanies < ActiveRecord::Migration
  def change
    add_column :companies, :slack_channel, :string
  end
end
