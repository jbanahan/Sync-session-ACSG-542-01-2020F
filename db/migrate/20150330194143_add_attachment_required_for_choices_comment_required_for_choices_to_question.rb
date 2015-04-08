class AddAttachmentRequiredForChoicesCommentRequiredForChoicesToQuestion < ActiveRecord::Migration
  def change
    add_column :questions, :attachment_required_for_choices, :string
    add_column :questions, :comment_required_for_choices, :string
  end
end
