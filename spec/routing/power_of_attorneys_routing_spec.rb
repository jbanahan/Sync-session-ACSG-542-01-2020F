describe PowerOfAttorneysController do
  describe "routing" do

    it "routes to #index" do
      expect(get("/companies/1/power_of_attorneys")).to route_to("power_of_attorneys#index", :company_id=>"1")
    end

    it "routes to #new" do
      expect(get("/companies/1/power_of_attorneys/new")).to route_to("power_of_attorneys#new", :company_id=>"1")
    end

    it "routes to #create" do
      expect(post("/companies/1/power_of_attorneys")).to route_to("power_of_attorneys#create", :company_id=>"1")
    end

    it "routes to #destroy" do
      expect(delete("/companies/1/power_of_attorneys/1")).to route_to("power_of_attorneys#destroy", :company_id=>"1", :id => "1")
    end

  end
end
