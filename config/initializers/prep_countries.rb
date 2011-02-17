if Rails.env=='production' && ActiveRecord::Base.connection.tables.include?("countries")
  Country.load_default_countries
end
