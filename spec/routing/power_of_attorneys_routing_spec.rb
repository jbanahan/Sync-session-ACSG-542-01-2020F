require "spec_helper"

describe PowerOfAttorneysController do
  describe "routing" do

    it "routes to #index" do
      get("/companies/1/power_of_attorneys").should route_to("power_of_attorneys#index", :company_id=>"1")
    end

    it "routes to #new" do
      get("/companies/1/power_of_attorneys/new").should route_to("power_of_attorneys#new", :company_id=>"1")
    end

    it "routes to #create" do
      post("/companies/1/power_of_attorneys").should route_to("power_of_attorneys#create", :company_id=>"1")
    end

    it "routes to #destroy" do
      delete("/companies/1/power_of_attorneys/1").should route_to("power_of_attorneys#destroy", :company_id=>"1", :id => "1")
    end

  end
end
