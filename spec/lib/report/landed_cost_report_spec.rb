describe OpenChain::Report::LandedCostReport do
  before :each do
    @user = Factory :master_user
    @entry1 = Factory(:entry, :customer_number=>"CUST", :broker_reference => "BROK REF 1", :release_date=>(Time.zone.now - 1.day), :entry_number=>"1", :transport_mode_code=>"2", :customer_references=>"3\n4")
    @entry2 = Factory(:entry, :customer_number=>"CUST", :broker_reference => "BROK REF 2", :release_date=>Time.zone.now, :entry_number=>"5", :transport_mode_code=>"6", :customer_references=>"7\n8")
  end

  after :each do
    @tempfile.close! if @tempfile && !@tempfile.closed?
  end

  def check_header sheet
    # don't really care about the header names, just make sure they're there
    expect(sheet.row(0)[0]).to eq("Broker Reference")
    expect(sheet.row(0)[19]).to eq("Total Per Unit")
  end

  def check_first_row sheet
    expect(sheet.row(1)[0]).to eq(@entry1.broker_reference)
    expect(sheet.row(1)[1]).to eq(@entry1.entry_number)
    expect(sheet.row(1)[2].strftime("%Y-%m-%d")).to eq(@entry1.release_date.strftime("%Y-%m-%d"))
    expect(sheet.row(1)[3]).to eq(@entry1.transport_mode_code)
    expect(sheet.row(1)[4]).to eq(@entry1.customer_references.split("\n").join(", "))
    # This info is all hardcoded in the generator_data method
    expect(sheet.row(1)[5]).to eq("1234.56.7890, 9876.54.3210")
    expect(sheet.row(1)[6]).to eq("CO")
    expect(sheet.row(1)[7]).to eq("PO")
    expect(sheet.row(1)[8]).to eq("1234")
    expect(sheet.row(1)[9]).to eq(1)
    expect(sheet.row(1)[10]).to eq(BigDecimal.new("1"))
    expect(sheet.row(1)[11]).to eq(BigDecimal.new("2"))
    expect(sheet.row(1)[12]).to eq(BigDecimal.new("3"))
    expect(sheet.row(1)[13]).to eq(BigDecimal.new("4"))
    expect(sheet.row(1)[14]).to eq(BigDecimal.new("5"))
    expect(sheet.row(1)[15]).to eq(BigDecimal.new("6"))
    expect(sheet.row(1)[16]).to eq(BigDecimal.new("7"))
    expect(sheet.row(1)[17]).to eq(BigDecimal.new("8"))
    expect(sheet.row(1)[18]).to eq(BigDecimal.new("9"))
    expect(sheet.row(1)[19]).to eq(BigDecimal.new("10.99")) # landed cost is rounded to 2 decimal places
   end

  def generator_data entry
    {:entries=>[{:broker_reference=>entry.broker_reference, :entry_number=>entry.entry_number, :release_date=>entry.release_date,
      :transport_mode_code=>entry.transport_mode_code, :customer_reference=>entry.customer_references.split("\n"),
      :commercial_invoices=>[
        {:commercial_invoice_lines=>[
          :hts_code =>["1234567890", "9876543210"], :country_origin_code => "CO", :po_number=>"PO", :part_number=>"1234", :quantity => 1, :entered_value=>BigDecimal.new("1"),
          :brokerage=>BigDecimal.new("2"), :other=>BigDecimal.new("3"), :international_freight=>BigDecimal.new("4"),
          :hmf=>BigDecimal.new("5"), :mpf=>BigDecimal.new("6"), :cotton_fee=>BigDecimal.new("7"), :duty=>BigDecimal.new("8"),
          :landed_cost=>BigDecimal.new("9"), :per_unit=>{:landed_cost=>BigDecimal.new("10.987")}
          ]}
        ]
    }]}
  end

  context "run" do
    # All the underlying logic for getting the report values is
    # handled by the landed cost data generator and is tested in its spec.
    # So just make sure we're calling that and handling the appropriate values
    # coming back out of there.
    it "should run a landed cost report" do
      start_date = (Time.zone.now - 2.days).strftime("%Y-%m-%d")
      end_date = (Time.zone.now + 1.day).strftime("%Y-%m-%d")
      c = described_class.new @user, 'customer_number'=>"CUST", 'start_date' => start_date, 'end_date' => end_date
      expect_any_instance_of(OpenChain::Report::LandedCostDataGenerator).to receive(:landed_cost_data_for_entry).with(@entry1.id).and_return(generator_data(@entry1))
      expect_any_instance_of(OpenChain::Report::LandedCostDataGenerator).to receive(:landed_cost_data_for_entry).with(@entry2.id).and_return(generator_data(@entry2))

      @tempfile = c.run

      expect(File.basename(@tempfile)).to match /^Landed Cost CUST/

      sheet = Spreadsheet.open(@tempfile.path).worksheet "CUST #{start_date} - #{end_date}"

      check_header sheet
      check_first_row sheet

      # Just make sure the second entry's row is there
      expect(sheet.row(2)[0]).to eq(@entry2.broker_reference)
    end

    it "should not find an entry for different customer" do
      start_date = (Time.zone.now - 2.days).strftime("%Y-%m-%d")
      end_date = (Time.zone.now + 1.day).strftime("%Y-%m-%d")
      c = described_class.new @user, 'customer_number'=>"DIFFERENT", 'start_date' => start_date, 'end_date' => end_date
      @tempfile = c.run

      sheet = Spreadsheet.open(@tempfile.path).worksheet 0
      expect(sheet.row(1)[0]).to be_nil
    end

    it "should not find an entry outside date range" do
      start_date = (Time.zone.now - 3.days).strftime("%Y-%m-%d")
      end_date = (Time.zone.now - 2.days).strftime("%Y-%m-%d")
      c = described_class.new @user, 'customer_number'=>"CUST", 'start_date' => start_date, 'end_date' => end_date
      @tempfile = c.run

      sheet = Spreadsheet.open(@tempfile.path).worksheet 0
      expect(sheet.row(1)[0]).to be_nil
    end

    it "should not find entries a user can't view" do
      # We didn't set importer_id in the entries, so none should match
      user = Factory(:importer_user)

      start_date = (Time.zone.now - 2.days).strftime("%Y-%m-%d")
      end_date = (Time.zone.now + 1.day).strftime("%Y-%m-%d")
      c = described_class.new user, 'customer_number'=>"CUST", 'start_date' => start_date, 'end_date' => end_date
      @tempfile = c.run

      sheet = Spreadsheet.open(@tempfile.path).worksheet 0
      expect(sheet.row(1)[0]).to be_nil
    end
  end

  context "run_from_lc_data" do
    it "runs a landed cost report" do
      c = described_class.new @user, {'entry_number' => "1"}

      @tempfile = c.run_from_lc_data generator_data(@entry1)

      expect(File.basename(@tempfile)).to match(/^Landed Cost/)

      sheet = Spreadsheet.open(@tempfile.path).worksheet "1"

      check_header sheet
      check_first_row sheet
    end
  end
end
