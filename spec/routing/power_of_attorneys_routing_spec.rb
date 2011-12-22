require "spec_helper"

describe PowerOfAttorneysController do
  describe "routing" do

    it "routes to #index" do
      get("/power_of_attorneys").should route_to("power_of_attorneys#index")
    end

    it "routes to #new" do
      get("/power_of_attorneys/new").should route_to("power_of_attorneys#new")
    end

    it "routes to #show" do
      get("/power_of_attorneys/1").should route_to("power_of_attorneys#show", :id => "1")
    end

    it "routes to #edit" do
      get("/power_of_attorneys/1/edit").should route_to("power_of_attorneys#edit", :id => "1")
    end

    it "routes to #create" do
      post("/power_of_attorneys").should route_to("power_of_attorneys#create")
    end

    it "routes to #update" do
      put("/power_of_attorneys/1").should route_to("power_of_attorneys#update", :id => "1")
    end

    it "routes to #destroy" do
      delete("/power_of_attorneys/1").should route_to("power_of_attorneys#destroy", :id => "1")
    end

  end
end
