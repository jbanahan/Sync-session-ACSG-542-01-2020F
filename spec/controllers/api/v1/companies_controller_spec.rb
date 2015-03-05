require 'spec_helper'

describe Api::V1::CompaniesController do
  before :each do
    @c = Factory(:company, name:'c1',importer:true,system_code:'A')
    @u = Factory(:user, company:@c)
    allow_api_access @u
  end
  describe :index do
    it "should only return self and linked companies" do
      c2 = Factory(:company,name:'c2',importer:true,system_code:'B')
      c3 = Factory(:company,name:'a3',vendor:true,system_code:'C')
      Factory(:company,name:'bad',system_code:'BAD') #don't find this
      [c2,c3].each {|c| @c.linked_companies << c}
      get :index
      expect(response).to be_success
      j = JSON.parse(response.body)['companies']
      expect(j.size).to eql 3
      expect(j.collect {|c| c['name']}).to eql ['a3','c1','c2']
      expect(j[0]['vendor']).to be_true
      expect(j[2]['vendor']).to be_false
      expect(j[2]['importer']).to be_true
    end
    it "should only return companies with system codes" do
      c2 = Factory(:company,name:'c2')
      @c.linked_companies << c2
      get :index
      expect(response).to be_success
      j = JSON.parse(response.body)['companies']
      expect(j.size).to eql 1
      expect(j[0]['id']).to eql @c.id
    end
    it "should find all companies for master" do
      @c.master = true
      @c.save!
      Factory(:company,name:'c2',importer:true,system_code:'c2')
      get :index
      expect(response).to be_success
      j = JSON.parse(response.body)['companies']
      expect(j.collect {|c| c['name']}).to include 'c2'
    end
    context :role do
      it "should return self if matches role" do
        c2 = Factory(:company,name:'c2',importer:true,system_code:'c2')
        @c.linked_companies << c2
        get :index, roles:'importer'
        expect(response).to be_success
        j = JSON.parse(response.body)
        expect(j.keys.to_a).to eq ['importers']
        expect(j['importers'].size).to eq 2
        expect(j['importers'].collect {|x| x['id']}).to eq [@c.id,c2.id]
      end
      it "should return multiple roles" do
        c2 = Factory(:company,name:'c2',importer:true,vendor:true,system_code:'c2')
        @c.linked_companies << c2
        get :index, roles:'importer,vendor'
        expect(response).to be_success
        j = JSON.parse(response.body)
        expect(j.keys.to_a.sort).to eq ['importers','vendors']
        expect(j['importers'].collect {|x| x['id']}).to eq [@c.id,c2.id]
        expect(j['vendors'].collect {|x| x['id']}).to eq [c2.id]
      end
    end
  end
end
