class AddUserIdToSearchRun < ActiveRecord::Migration
  def self.up
    add_column :search_runs, :user_id, :integer
    SearchRun.all.each do |sr|
      ss = sr.search_setup
      sr.user_id = ss.user_id unless ss.nil?
      f = sr.imported_file
      sr.user_id = f.user_id unless f.nil?
      sr.save!
    end
  end

  def self.down
    remove_column :search_runs, :user_id
  end
end
