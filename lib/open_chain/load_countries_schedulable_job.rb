module OpenChain; class LoadCountriesSchedulableJob
  def self.run_schedulable
    Country.load_default_countries
  end
end; end
