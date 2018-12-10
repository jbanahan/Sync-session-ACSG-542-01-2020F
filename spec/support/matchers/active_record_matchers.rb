RSpec::Matchers.define :exist_in_db do
  match do |obj|
    # The easiest way to determine if an object exists in the database is just call reload on it and see if it raises an error or not
    begin
      # We don't actually want to reload the given object, that might cause unintended side-effects..so just find it
      obj.class.find obj.id
      return true
    rescue ActiveRecord::RecordNotFound
      return false
    end
  end
end