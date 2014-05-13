class AddExamOrderedDateToEntry < ActiveRecord::Migration
  def change
    add_column :entries, :exam_ordered_date, :datetime
  end
end
