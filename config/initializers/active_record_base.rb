# This is simply meant to change the visibility of the following functions to match what they are in Rails 5.
module ActiveRecord; class Base
  if ActiveRecord::VERSION::MAJOR < 5
    public_class_method :sanitize_sql_array
    public_class_method :sanitize_sql_like
  elsif ActiveRecord::VERSION::MAJOR >= 5
    raise "Remove this initializer..it's no longer needed."
  end
end; end;