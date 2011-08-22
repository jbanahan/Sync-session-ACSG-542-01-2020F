class MigrateUploadOptions < ActiveRecord::Migration
  def self.up
    execute "update imported_files set starting_row = (ifnull(ignore_first_row,0) + 1), starting_column = 1;"
    modes = ActiveRecord::Base.connection.select_rows("SELECT id, update_mode FROM search_setups")
    modes.each do |m|
      execute "UPDATE imported_files set update_mode = '#{m[1]}' WHERE search_setup_id = #{m[0]};"
    end
    execute "UPDATE imported_files set update_mode = 'any' WHERE update_mode is null;"
  end

  def self.down
    #noop
  end
end
