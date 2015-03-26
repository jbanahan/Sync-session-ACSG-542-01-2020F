class AddCheckoutInfoToSurveyResponses < ActiveRecord::Migration
  def change
    add_column :survey_responses, :checkout_by_user_id, :integer
    add_column :survey_responses, :checkout_token, :string
    add_column :survey_responses, :checkout_expiration, :datetime
  end
end
