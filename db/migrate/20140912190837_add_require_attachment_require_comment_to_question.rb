class AddRequireAttachmentRequireCommentToQuestion < ActiveRecord::Migration
  def change
    add_column :questions, :require_attachment, :boolean, default: false
    add_column :questions, :require_comment, :boolean, default: false

    execute "UPDATE questions SET require_attachment = false, require_comment = false"
  end
end
