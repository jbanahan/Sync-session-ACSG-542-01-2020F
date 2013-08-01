class MoveReadOnlyFlags < ActiveRecord::Migration
  def up
    rs = execute "SELECT id, module_type FROM custom_definitions WHERE read_only = 1"
    rs.each do |r|
      cd_id = r[0]
      if execute("SELECT id FROM field_validator_rules WHERE model_field_uid = '*cf_#{cd_id}'").first
        execute "UPDATE field_validator_rules SET read_only = 1 WHERE model_field_uid = '*cf_#{cd_id}'"
      else
        execute "INSERT INTO field_validator_rules (model_field_uid, custom_definition_id, read_only, module_type) VALUES ('*cf_#{cd_id}',#{cd_id},1,'#{r[1]}')"
      end
    end
  end

  def down
    execute "UPDATE field_validator_rules set read_only = null"
  end
end
