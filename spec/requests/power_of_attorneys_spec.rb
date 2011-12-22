require 'spec_helper'

describe "PowerOfAttorneys" do
  describe "GET /power_of_attorneys" do
    it "works! (now write some real specs)" do
      # Run the generator again with the --webrat flag if you want to use webrat methods/matchers
      get power_of_attorneys_path
      response.status.should be(200)
    end
  end
end
