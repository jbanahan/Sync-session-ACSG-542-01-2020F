class CreateDocumentRequestQueueItem < ActiveRecord::Migration
  def change
    create_table :document_request_queue_items do |t|
      t.string :system
      t.string :identifier
      t.datetime :request_at
      t.string :locked_by
      t.datetime :locked_at
      
      t.timestamps
    end

    add_index(:document_request_queue_items, [:system, :identifier], unique: true)
    add_index(:document_request_queue_items, [:updated_at])
  end
end
