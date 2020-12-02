module ActiveRecord; class Base
  # This file was originally meant to be removed, however Rails 5 protects the methods still.
  public_class_method :sanitize_sql_array
  public_class_method :sanitize_sql_like
end; end;