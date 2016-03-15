require 'spec_helper'

describe OpenChain::Report::XLSSearch do
  before(:each) { @u = Factory(:user,:company_id=>Factory(:company,:master=>true).id,:product_view=>true) }
  
  describe :run_report do
    it "runs report" do
      search = Factory(:search_setup,:user=>@u,:module_type=>'Product')
      described_class.should_receive(:run).with(@u, search.id)
      described_class.run_report(@u, 'search_setup_id' => search.id)
    end
  end

  describe :run_and_email_report do
    before :each do
      @mail_fields = { to: 'sthubbins@hellhole.co.uk', :subject => 'amp', body: "Goes up to 11."}
      @search = Factory(:search_setup,:user=>@u,:module_type=>'Product')
    end

    it "runs report" do
      described_class.should_receive(:run).with(@u, @search.id)
      described_class.run_and_email_report(@u, @search.id, @mail_fields)
    end

    it "sends an email and closes tempfile afterwards" do
      report_double = double("report")
      report_double.stub(:path).and_return "some/path"
      described_class.stub(:run).and_return report_double
      report_double.should_receive(:close!)
      OpenMailer.should_receive(:send_search_result_manually).with(@mail_fields[:to], @mail_fields[:subject],
                                                                    "Goes up to 11.", "some/path", @u)
      described_class.run_and_email_report(@u, @search.id, @mail_fields)
    end

    it "logs exceptions, sends user message" do
      described_class.stub(:run).and_raise "ALARM!"
      described_class.run_and_email_report(@u, @search.id, @mail_fields)
      user_message = @u.messages.first

      expect(user_message.subject).to eq "Report FAILED: Search-results email"
      expect(user_message.body).to eq "<p>Your report failed to run due to a system error.</p>"
      expect(ErrorLogEntry.first.error_message).to eq "ALARM!"
    end

  end

  describe :run do
  
    context "execute" do
      before :each do
        @product = Factory(:product,:name=>'abc123')
        @search = Factory(:search_setup,:user=>@u,:module_type=>'Product')
        @search.search_columns.create(:model_field_uid=>'prod_name',:rank=>0)
        @search.search_criterions.create!(:model_field_uid=>'prod_name',:operator=>'eq',:value=>@product.name)
      end

      it 'should run a simple search' do
        wb = Spreadsheet.open described_class.run @u, @search.id
        sheet = wb.worksheet 0
        sheet.last_row_index.should == 1 #2 total rows
        sheet.row(0)[0].should == ModelField.find_by_uid('prod_name').label
        sheet.row(1)[0].should == @product.name
      end
      it 'should fail if run_by is different than search setup user' do
        u2 = Factory(:user)
        expect {
          described_class.run u2, @search.id
        }.to raise_error
      end
    end
    
    context "spreadsheet" do
      before :each do
        @xl_out = mock("Spreadsheet")
        @xl_out.stub(:write)
        @xl_maker = mock("XlsMaker")
        @xl_maker.should_receive(:make_from_search_query_by_search_id_and_user_id).and_return([@xl_out, 3])
      end
      
      it "should include links" do
        ss = Factory(:search_setup,:include_links=>true,:user=>@u)
        XlsMaker.should_receive(:new).with({:include_links=>true,:no_time=>false}).and_return(@xl_maker)  
        described_class.run @u, ss.id
      end
      it "should include 'no time' flag" do
        ss = Factory(:search_setup,:no_time=>true,:user=>@u)
        XlsMaker.should_receive(:new).with({:include_links=>false,:no_time=>true}).and_return(@xl_maker)  
        described_class.run @u, ss.id
      end 
    end
  end

end