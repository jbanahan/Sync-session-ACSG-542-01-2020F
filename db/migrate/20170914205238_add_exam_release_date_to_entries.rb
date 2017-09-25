class AddExamReleaseDateToEntries < ActiveRecord::Migration
  def change
    add_column :entries, :exam_release_date, :datetime
  end
end
