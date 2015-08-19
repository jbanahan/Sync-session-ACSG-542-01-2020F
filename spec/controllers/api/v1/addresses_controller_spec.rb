require 'spec_helper'

describe Api::V1::AddressesController do

  describe "autocomplete" do
    before :each do
      @address = Factory(:full_address, in_address_book: true, name: "Test Address")
      @user = Factory(:user, company: @address.company)
      allow_api_access @user
    end

    it "returns address json if name matches request" do
      # Make sure we skip addresses not in the address book
      address2 = Factory(:full_address, in_address_book: false, name: "Test Address 2")
      get :autocomplete, n: "add"
      expect(response.status).to eq 200

      r = JSON.parse(response.body)
      expect(r.length).to eq 1
      expect(r.first).to eq( {"name"=> @address.name, "full_address"=> @address.full_address, "id"=> @address.id} )
    end

    it "returns addresses in linked companies" do
      user = Factory(:user)
      allow_api_access user
      user.company.linked_companies << @address.company

      get :autocomplete, n: "add"
      expect(response.status).to eq 200

      r = JSON.parse(response.body)
      expect(r.length).to eq 1
    end

    it "returns nothing if search term is blank" do
      get :autocomplete, n: ""
      expect(response.status).to eq 200

      r = JSON.parse(response.body)
      expect(r.length).to eq 0
    end

    it "limits results by company" do
      user = Factory(:user)
      allow_api_access user

      get :autocomplete, n: "add"
      expect(response.status).to eq 200

      r = JSON.parse(response.body)
      expect(r.length).to eq 0
    end

  end
end