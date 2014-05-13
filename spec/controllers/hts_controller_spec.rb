require 'spec_helper'
require 'json'

describe HtsController do

  describe :country do
    before :each do
      @usa = Factory(:country, "name"=> "United States", iso_code: "US")
      @tariff1 = Factory(:official_tariff, hts_code: "12345", chapter: 123, country: @usa)
    end

    it 'should return the correct hash of values' do
      get :country, "iso"=> "US", format: :json
      response.should be_success
      chapters = JSON.parse(response.body)["chapters"].first
      chapters.should_not be_nil
      chapters["num"].should == "12"
      chapters["name"].should == "123"
      chapters["sub_headings"].should == []
    end
  end

  describe :chapter do
    before :each do
      @usa = Factory(:country, "name"=> "United States", iso_code: "US")
      @tariff1 = Factory(:official_tariff, hts_code: "12345", chapter: 123, country: @usa)
    end

    it 'should return some stuff for the us' do
      get :chapter, "iso"=> "US", chapter: 12
      response.should be_success
      headings = JSON.parse(response.body)["headings"].first
      headings.should_not be_nil
      headings["num"].should == "34"
      headings["name"].should be_nil
    end

  end

  describe :heading do
    before :each do
      @usa = Factory(:country, "name"=> "United States", iso_code: "US")
      @tariff1 = Factory(:official_tariff, hts_code: "12345", chapter: 123, country: @usa)
    end

    it 'should return some stuff for the us' do
      get :heading, "iso"=> "US", heading: 34
      response.should be_success
      subheadings = JSON.parse(response.body)["sub_headings"]
      subheadings.should == []
    end
  end

  describe :subscribed_countries do
    before :each do
      @usa = Factory(:country, "name"=> "United States", iso_code: "US", import_location: true)
      @can = Factory(:country, "name"=> "Canada", iso_code: "CA", import_location: true)
      @vnm = Factory(:country, "name"=> "Vietnam", iso_code: "VN", import_location: true)
      @tariff1 = Factory(:official_tariff, hts_code: "12345", chapter: 123, country: @usa)
      @tariff2 = Factory(:official_tariff, hts_code: "23456", chapter: 234, country: @can)
      @tariff3 = Factory(:official_tariff, hts_code: "34567", chapter: 345, country: @vnm)
      @tariff4 = Factory(:official_tariff, hts_code: "45678", chapter: 456, country: @usa)
    end

    it "should return all countries in your local OfficialTariff table when logged in" do
      u = Factory(:user); sign_in_as u
      get :subscribed_countries
      response.should be_success
      countries = JSON.parse(response.body)["countries"]
      countries.should == [{"iso"=>"US", "name"=>"United States"}, {"iso"=>"CA", "name"=>"Canada"}, {"iso"=>"VN", "name"=>"Vietnam"}]
    end

    it "should return all countries available when logged out" do
      get :subscribed_countries
      response.should be_success
      countries = JSON.parse(response.body)["countries"]
      countries.should == 
        [
          {"iso"=>'US',"name"=>'United States'},{"iso"=>'CA',"name"=>'Canada'},{"iso"=>'AU',"name"=>'Australia'},{"iso"=>'CL',"name"=>'Chile'},{"iso"=>'CN',"name"=>'China'},{"iso"=>'HK',"name"=>'Hong Kong'},
          {"iso"=>'ID',"name"=>'Indonesia'},{"iso"=>'IT',"name"=>'Italy'},{"iso"=>'JP',"name"=>'Japan'},{"iso"=>'KR',"name"=>'Korea, Republic of'},{"iso"=>'MO',"name"=>'Macao'},{"iso"=>'MY',"name"=>'Malaysia'},
          {"iso"=>'MX',"name"=>'Mexico'},{"iso"=>'NZ',"name"=>'New Zealand'},{"iso"=>'NO',"name"=>'Norway'},{"iso"=>'PE',"name"=>'Peru'},{"iso"=>'PH',"name"=>'Philippines'},{"iso"=>'RU',"name"=>'Russian Federation'},
          {"iso"=>'SG',"name"=>'Singapore'},{"iso"=>'TW',"name"=>'Taiwan'},{"iso"=>'TH',"name"=>'Thailand'},{"iso"=>'TR',"name"=>'Turkey'},{"iso"=>'VN',"name"=>'Vietnam'}
        ]
    end
  end
end
