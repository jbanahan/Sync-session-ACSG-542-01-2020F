class MakeFakeFileImportResults < ActiveRecord::Migration
  def self.up
    ImportedFile.all.each do |f|
      if(f.file_import_results.blank?)
        execute "INSERT INTO file_import_results (imported_file_id,started_at,finished_at,run_by_id,created_at,updated_at) VALUES ('#{f.id}','1900-01-01','1900-01-01',#{f.user_id},'#{Time.now}','#{Time.now}');"
      end
    end
  end

  def self.down
  end
end
