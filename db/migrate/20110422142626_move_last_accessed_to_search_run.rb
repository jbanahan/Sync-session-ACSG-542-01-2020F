class MoveLastAccessedToSearchRun < ActiveRecord::Migration
  def self.up
    add_column :search_runs, :last_accessed, :datetime
    move_last_accessed_data
  end

  def self.down
    undo_move_data
    remove_column :search_runs, :last_accessed
  end

  def self.move_last_accessed_data
    SearchSetup.all.each do |ss|
      sr = ss.search_run
      sr = SearchRun.new(:search_setup_id=>ss.id,:position=>0) if sr.nil?
      sr.last_accessed = ss.last_accessed
      sr.save!
    end
  end

  def self.undo_move_data
    SearchRun.all.each do |sr|
      ss = sr.search_setup
      unless ss.nil?
        ss.last_accessed = sr.last_accessed
        ss.save!
      end
    end
  end
end
