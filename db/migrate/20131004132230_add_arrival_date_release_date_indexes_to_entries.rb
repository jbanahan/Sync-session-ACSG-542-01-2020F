class AddArrivalDateReleaseDateIndexesToEntries < ActiveRecord::Migration
  def up
      add_index :entries, :release_date
      add_index :entries, :arrival_date
    end

    def down
      if index_exists? :entries, :release_date
        remove_index :entries, :release_date
      end

      if index_exists? :entries, :arrival_date
        remove_index :entries, :arrival_date
      end
    end
end
