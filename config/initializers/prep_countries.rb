if Rails.env=='production'
  Country.load_default_countries
end
