class CreateSupportRequest < ActiveRecord::Migration
  def change
    create_table :support_requests do |t|
      t.string :ticket_number
      t.text :body
      t.string :severity
      t.string :referrer_url
      t.references :user, index: true
      t.string :external_link

      t.timestamps null: false
    end
  end
end
