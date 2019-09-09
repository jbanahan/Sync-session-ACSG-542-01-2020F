describe PortsController do
  let! (:user) {
    u = Factory(:admin_user)
    sign_in_as u
  }
  
  describe "index" do
    it "should only allow admins" do
      user.admin = false
      user.save!
      get :index
      expect(response).to be_redirect
      expect(flash[:errors].size).to eq(1)
    end

    it "should show ports" do
      3.times {|i| Port.create!(:name=>"p#{i}")}
      get :index
      expect(assigns[:ports].size).to eq(3)
      expect(assigns[:ports].first.name).to eq("p0")
    end

  end
  describe "create" do
    let (:us) { Factory(:country, iso_code: "US") }
    let (:port) {
      {
        port: {
          name: "X",
          unlocode: "USLOC"
        }
      }
    }

    let (:port_with_address) do 
      port[:port][:address] = {
        line_1: "Address 1",
        line_2: "Address 2",
        line_3: "Address 3",
        city: "City",
        state: "State",
        postal_code: "12345",
        country_iso_code: us.iso_code
      }
      port
    end

    it "should only allow admins" do
      user.admin = false
      user.save!
      post :create, {'port'=>{'name'=>'x'}}
      expect(response).to be_redirect
      expect(flash[:errors].size).to eq(1)
      expect(Port.all).to be_empty
    end

    it "should create port" do
      post :create, port
      expect(response).to be_redirect
      p = Port.first
      expect(p.name).to eq('X')
      expect(p.unlocode).to eq "USLOC"
      # There's no address data, so it shouldn't create one
      expect(p.address).to be_nil
      expect(flash[:notices]).to include("Port successfully created.")
    end

    it "should create a port with address data" do
      post :create, port_with_address
      expect(response).to be_redirect
      expect(flash[:errors]).to be_blank
      p = Port.first
      expect(p.address).not_to be_nil
      a = p.address
      expect(a.line_1).to eq "Address 1"
      expect(a.line_2).to eq "Address 2"
      expect(a.line_3).to eq "Address 3"
      expect(a.city).to eq "City"
      expect(a.state).to eq "State"
      expect(a.postal_code).to eq "12345"
      expect(a.country).to eq us
    end
  end

  describe "destroy" do
    let (:port) { Factory(:port) }
    it "should only allow admins" do
      user.admin = false
      user.save!
      delete :destroy, :id=>port.id
      expect(response).to be_redirect
      expect(flash[:errors].size).to eq(1)
    end
    it "should destroy port" do
      delete :destroy, :id=>port.id
      expect(response).to be_redirect
      expect(flash[:notices].size).to eq(1)
      expect(Port.all).to be_empty
      expect(flash[:notices]).to include("Port successfully deleted.")
    end
  end

  describe "update" do
    let (:us) { Factory(:country, iso_code: "US") }
    let! (:port) { Factory(:port, name: 'old name', unlocode: "LOCOD", schedule_d_code: "1234", schedule_k_code: "12345", cbsa_port: "9876", iata_code: "ABC", cbsa_sublocation: "1234") }
    let (:port_param) {
      {
        id: port.id,
        port: {
          name: "my port",
          unlocode: "LOCOD"
        }
      }
    }

    let (:port_param_with_address) do 
      port_param[:port][:address] = {
        line_1: "Address 1",
        line_2: "Address 2",
        line_3: "Address 3",
        city: "City",
        state: "State",
        postal_code: "12345",
        country_iso_code: us.iso_code
      }
      port_param
    end


    it "should only allow admins" do
      user.admin = false
      user.save!
      put :update, port_param
      expect(response).to be_redirect
      expect(flash[:errors].size).to eq(1)
      port.reload
      expect(port.name).to eq('old name')
    end

    it "should update port" do
      put :update, port_param
      expect(response).to be_redirect
      expect(flash[:notices]).to include("Port successfully updated.")
      port.reload
      expect(port.name).to eq('my port')
    end

    it "updates port, creating an address if port doesn't already have one" do
      put :update, port_param_with_address
      expect(flash[:notices]).to include("Port successfully updated.")
      port.reload
      expect(port.address).not_to be_nil
      a = port.address
      expect(a.line_1).to eq "Address 1"
      expect(a.line_2).to eq "Address 2"
      expect(a.line_3).to eq "Address 3"
      expect(a.city).to eq "City"
      expect(a.state).to eq "State"
      expect(a.postal_code).to eq "12345"
      expect(a.country).to eq us
    end

    it "deletes address record if update removes address data" do
      address = port.create_address line_1: "Testing"
      port_param_with_address[:port][:address].each_pair {|k, v| port_param_with_address[:port][:address][k] = " " }

      put :update, port_param_with_address
      expect(flash[:notices]).to include("Port successfully updated.")
      port.reload
      expect(port.address).to be_nil
      expect(address).not_to exist_in_db
    end

    it "updates address record" do
      address = port.create_address line_1: "Testing"
      put :update, port_param_with_address
      expect(flash[:notices]).to include("Port successfully updated.")
      port.reload
      expect(port.address).not_to be_nil
      address.reload
      expect(address.line_1).to eq "Address 1"
    end

    it "nulls blank parameter values" do
      [:schedule_k_code, :schedule_d_code, :unlocode, :cbsa_port, :cbsa_sublocation, :iata_code].each {|k| port_param[:port][k] = " " }
      put :update, port_param
      port.reload
      expect(flash[:errors]).to be_blank
      expect(port.schedule_k_code).to be_nil
      expect(port.schedule_d_code).to be_nil
      expect(port.unlocode).to be_nil
      expect(port.cbsa_port).to be_nil
      expect(port.cbsa_sublocation).to be_nil
      expect(port.iata_code).to be_nil
    end
  end
end
