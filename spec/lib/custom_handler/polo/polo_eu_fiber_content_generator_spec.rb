describe OpenChain::CustomHandler::Polo::PoloEuFiberContentGenerator do

  describe "generate" do
    it "should email report" do
      u = Factory(:master_user, username:'EU Fiber Content', email:'a@sample.com')
      mail = double('mail')
      expect(mail).to receive(:deliver_now)
      d = described_class.new
      f = double('file')
      expect(d).to receive(:sync_xls).and_return(f)
      expect(OpenMailer).to receive(:send_simple_html).with('a@sample.com','VFI Track EU Fiber Content Report','Fiber content report is attached.',f).and_return(mail)
      d.generate
    end
    it "should create user" do
      master_company = Factory(:company, master:true)
      mail = double('mail')
      expect(mail).to receive(:deliver_now)
      d = described_class.new
      f = double('file')
      expect(d).to receive(:sync_xls).and_return(f)
      expect(OpenMailer).to receive(:send_simple_html).with('bug@vandegriftinc.com','VFI Track EU Fiber Content Report','Fiber content report is attached.',f).and_return(mail)
      expect{d.generate}.to change(User,:count).by(1)
      u = User.find_by(username: 'EU Fiber Content')
      expect(u.view_products?).to be_truthy
    end
  end

  describe "trim_fingerprint" do
    it "should return 3rd element as fingerprint" do
      expect(described_class.new.trim_fingerprint([1,'1','2','3','4'])).to eq ['3',[1,'1','2','3','4']]
    end
  end
  it "should auto_confirm" do
    expect(described_class.new.auto_confirm?).to be_truthy
  end
  describe "sync" do
    before :each do
      @italy = Factory(:country,iso_code:'IT')
      @cdefs = described_class.prep_custom_definitions([
        :merch_division,
        :fiber_content,
        :csm_numbers, 
        :season
      ])
      @headers = ['US Style','Name','Fiber Content','IT HTS','CSM', 'Merch Division', "Season"]
    end
    def do_sync 
      r = []
      described_class.new.sync {|row| r << row.values}
      r
    end
    it "should get new record" do
      p = Factory(:product,unique_identifier:'UID',name:'NM',updated_at:1.day.ago)
      p.update_custom_value!(@cdefs[:merch_division],'MD')
      p.update_custom_value!(@cdefs[:fiber_content],'FC')
      p.update_custom_value!(@cdefs[:csm_numbers],'CSM')
      p.update_custom_value!(@cdefs[:season],'SEA')
      c = Factory(:classification,country:@italy,product:p)
      t = Factory(:tariff_record,hts_1:'1234567890',classification:c)
      expect(do_sync).to eq [@headers,[
        'UID','NM','FC','1234567890','CSM','MD', 'SEA'
        ]]
      expect(p.sync_records.find_by(trading_partner: "eu_fiber_content").fingerprint).to eq 'FC'
    end
    it "should get changed record" do
      p = Factory(:product,unique_identifier:'UID',name:'NM',updated_at:1.second.ago)
      p.update_custom_value!(@cdefs[:merch_division],'MD')
      p.update_custom_value!(@cdefs[:fiber_content],'FC')
      p.update_custom_value!(@cdefs[:csm_numbers],'CSM')
      p.update_custom_value!(@cdefs[:season],'SEA')
      c = Factory(:classification,country:@italy,product:p)
      t = Factory(:tariff_record,hts_1:'1234567890',classification:c)
      p.sync_records.create!(trading_partner:'eu_fiber_content',fingerprint:'OTHER',sent_at:1.day.ago,confirmed_at:1.hour.ago)
      expect(do_sync).to eq [@headers,[
        'UID','NM','FC','1234567890','CSM','MD', 'SEA'
        ]]
      expect(p.sync_records.find_by(trading_partner: "eu_fiber_content").fingerprint).to eq 'FC'
    end
    it "should not get record not changed" do
      p = Factory(:product,unique_identifier:'UID',name:'NM',updated_at:1.day.ago)
      p.update_custom_value!(@cdefs[:merch_division],'MD')
      p.update_custom_value!(@cdefs[:fiber_content],'FC')
      p.update_custom_value!(@cdefs[:csm_numbers],'CSM')
      c = Factory(:classification,country:@italy,product:p)
      t = Factory(:tariff_record,hts_1:'1234567890',classification:c)
      p.sync_records.create!(trading_partner:'eu_fiber_content',fingerprint:'FC',sent_at:1.day.ago,confirmed_at:1.hour.ago)
      expect(do_sync).to eq []
    end
    it "should not get record without Italy HTS 1" do
      p = Factory(:product,unique_identifier:'UID',name:'NM',updated_at:1.day.ago)
      p.update_custom_value!(@cdefs[:merch_division],'MD')
      p.update_custom_value!(@cdefs[:fiber_content],'FC')
      p.update_custom_value!(@cdefs[:csm_numbers],'CSM')
      c = Factory(:classification,country:@italy,product:p)
      t = Factory(:tariff_record,hts_1:'',classification:c)
      expect(do_sync).to eq []
    end
  end

end