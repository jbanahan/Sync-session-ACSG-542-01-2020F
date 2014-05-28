require 'spec_helper'

describe OpenChain::CustomHandler::FenixInvoiceParser do
  before :each do
    @content = File.read 'spec/support/bin/fenix_invoices.csv'
    @k = OpenChain::CustomHandler::FenixInvoiceParser
    @ent = Factory(:entry,:source_system=>'Fenix',:broker_reference=>'280952')
    @ent2 = Factory(:entry,:source_system=>'Fenix',:broker_reference=>'281350')
  end

  it "should set s3 info if passed" do
    @k.parse @content, {:bucket=>'bucket',:key=>'key'}
    b = BrokerInvoice.first
    b.last_file_bucket.should == 'bucket'
    b.last_file_path.should == 'key'
  end
  it "should write invoice" do
    @k.parse @content
    BrokerInvoice.count.should == 2
    bi = BrokerInvoice.find_by_broker_reference_and_source_system '280952', 'Fenix'
    bi.invoice_total.should == 50.85 #does not include GST (code 2)
    bi.suffix.should be_blank
    bi.currency.should == 'CAD'
    bi.invoice_date = Date.new(2013,1,14)
    bi.invoice_number.should == '9'
    bi.customer_number.should == "BOSSCI"
  end
  it "should write details" do
    @k.parse @content
    bi = BrokerInvoice.find_by_broker_reference_and_source_system '280952', 'Fenix'
    bi.should have(3).broker_invoice_lines

    billing = bi.broker_invoice_lines.find_by_charge_code '55' #should truncate the text if the invoice charge code starts with a number and a space
    billing.charge_description.should == 'BILLING'
    billing.charge_amount.should == 45
    billing.charge_type.should == 'R'
    
    hst = bi.broker_invoice_lines.find_by_charge_code '255'
    hst.charge_description.should == 'HST (ON)'
    hst.charge_amount.should == 5.85
    hst.charge_type.should == 'R'
    
    gst = bi.broker_invoice_lines.find_by_charge_code '21'
    gst.charge_description.should == 'GST ON IMPORTS'
    gst.charge_amount.should == 4523.98
    gst.charge_type.should == 'D'
  end
  it "should replace invoice" do
    #going to process, then delete a line, then reprocess and line should come back
    @k.parse @content
    bi = BrokerInvoice.find_by_broker_reference_and_source_system '280952', 'Fenix'
    bi.broker_invoice_lines.first.destroy
    bi.update_attributes(:invoice_total=>2)
    
    @k.parse @content
    bi.reload
    bi.should have(3).broker_invoice_lines
    bi.invoice_total.should == 50.85
  end
  it "should match to entry" do
    @k.parse @content
    bi = BrokerInvoice.find_by_broker_reference_and_source_system @ent.broker_reference, 'Fenix'
    bi.entry.should == @ent
    bi.entry.broker_invoice_total.should == bi.invoice_total
  end

  it "should update total broker invoice value from the entry" do

    # Set the broker reference to be the same for each broker invoice
    # so we're updating the same entry.
    @content = <<INV
INVOICE DATE,ACCOUNT#,BRANCH,INVOICE#,SUPP#,REFERENCE,CHARGE CODE,CHARGE DESC,AMOUNT,FILE NUMBER,INV CURR,CHARGE GL ACCT,CHARGE PROFIT CENTRE,PAYEE,DISB CODE,DISB AMT,DISB CURR,DISB GL ACCT,DISB PROFIT CENTRE,DISB REF
01/14/2013,BOSSCI, 1 , 9 , 0 ,11981001052312, 55 WITH TEXT ,BILLING, 45 ,#{@ent.broker_reference},CAD, 4000 , 1 ,,,,,,,,
01/14/2013,BOSSCI, 1 , 9 , 0 ,11981001052312, 255 ,HST (ON), 5.85 ,#{@ent.broker_reference},CAD, 4000 , 1 

01/14/2013,BOSSCI, 1 , 9 , 0 ,11981001052312, 21 GST ON B3 ,GST ON IMPORTS, 4523.98 ,#{@ent.broker_reference},CAD, 3100 , 1 ,RG01, 2 , 4523.98 ,CAD, 3100 , 1 ,11981001052312

01/16/2013,ADBAIR, 1 , 39009 , 0 ,11981001157739, 22 ,BROKERAGE, 37 ,#{@ent.broker_reference},CAD, 4000 , 1 ,,,,,,,,
01/16/2013,ADBAIR, 1 , 39009 , 0 ,11981001157739, 255 ,HST (ON), 4.81 ,#{@ent.broker_reference},CAD, 4000 , 1 

01/16/2013,ADBAIR, 1 , 39009 , 0 ,11981001157739, 34 ,BOND FEE, 10 ,#{@ent.broker_reference},CAD, 4000 , 1 ,,,,,,,,
01/16/2013,ADBAIR, 1 , 39009 , 0 ,11981001157739, 255 ,HST (ON), 1.3 ,#{@ent.broker_reference},CAD, 4000 , 1 

01/16/2013,ADBAIR, 1 , 39009 , 0 ,11981001157739, 20 DUTY ON B3 ,DUTY ON IMPORTS, 542.57 ,#{@ent.broker_reference},CAD, 3100 , 1 ,RG01, 2 , 542.57 ,CAD, 3100 , 1 ,11981001157739
INV

    @k.parse @content
    @ent.reload
    @ent.broker_invoices.should have(2).items
    @ent.broker_invoice_total.should == @ent.broker_invoices.inject(BigDecimal.new("0.0")){|sum, inv| sum += inv.invoice_total}
  end

  it "invoice total should not include codes 20 or 21" do
    @k.parse @content
    BrokerInvoice.find_by_broker_reference('280952').invoice_total.should == 50.85
    BrokerInvoice.find_by_broker_reference('281350').invoice_total.should == 53.11
  end

  it "should handle a minimal amount of information" do
    @k.parse "INVOICE DATE,ACCOUNT#,BRANCH,INVOICE#,SUPP#,REFERENCE,CHARGE CODE,CHARGE DESC,AMOUNT,FILE NUMBER,INV CURR,CHARGE GL ACCT,CHARGE PROFIT CENTRE,PAYEE,DISB CODE,DISB AMT,DISB CURR,DISB GL ACCT,DISB PROFIT CENTRE,DISB REF\n" +
              "04/27/2013,, 1 , INV# , ,,22 BROKERAGE,BROKERAGE, 55 ,#{@ent.broker_reference},  , 1 ,,,,,,,,"
    bi = BrokerInvoice.find_by_invoice_number_and_source_system 'INV#', 'Fenix'
    bi.broker_reference.should == @ent.broker_reference
  end

  it "should handle errors for each invoice individually" do
    StandardError.any_instance.should_receive(:log_me).with(["Failed to process Fenix Invoice # INV#2 from file 'path/to/file'."])

    @k.parse "INVOICE DATE,ACCOUNT#,BRANCH,INVOICE#,SUPP#,REFERENCE,CHARGE CODE,CHARGE DESC,AMOUNT,FILE NUMBER,INV CURR,CHARGE GL ACCT,CHARGE PROFIT CENTRE,PAYEE,DISB CODE,DISB AMT,DISB CURR,DISB GL ACCT,DISB PROFIT CENTRE,DISB REF\n" +
              # This line fails due to missing invoice date
              ",, 1 , INV#2 , ,,22 BROKERAGE,BROKERAGE, 55 ,REF#,,  , 1 ,,,,,,,,\n" +
              "04/27/2013,, 1 , INV# , ,,22 BROKERAGE,BROKERAGE, 55 ,#{@ent.broker_reference},,  , 1 ,,,,,,,,\n", {:key => "path/to/file"}
    bi = BrokerInvoice.find_by_invoice_number_and_source_system 'INV#', 'Fenix'
    bi.should_not be_nil
  end

  it "should raise an error if the broker reference is missing" do
    StandardError.any_instance.should_receive(:log_me).with(["Failed to process Fenix Invoice # INV#2."])
    
    @k.parse "INVOICE DATE,ACCOUNT#,BRANCH,INVOICE#,SUPP#,REFERENCE,CHARGE CODE,CHARGE DESC,AMOUNT,FILE NUMBER,INV CURR,CHARGE GL ACCT,CHARGE PROFIT CENTRE,PAYEE,DISB CODE,DISB AMT,DISB CURR,DISB GL ACCT,DISB PROFIT CENTRE,DISB REF\n" +
              # This line fails due to missing broker reference
              "04/27/2013,, 1 , INV#2 , ,,22 BROKERAGE,BROKERAGE, 55 ,,,  , 1 ,,,,,,,,"
    bi = BrokerInvoice.find_by_invoice_number_and_source_system 'INV#2', 'Fenix'
    bi.should be_nil
  end

  it "should skip lines that are missing invoice numbers" do
    @content = <<INV
    INVOICE DATE,ACCOUNT#,BRANCH,INVOICE#,SUPP#,REFERENCE,CHARGE CODE,CHARGE DESC,AMOUNT,FILE NUMBER,INV CURR,CHARGE GL ACCT,CHARGE PROFIT CENTRE,PAYEE,DISB CODE,DISB AMT,DISB CURR,DISB GL ACCT,DISB PROFIT CENTRE,DISB REF
    01/14/2013,BOSSCI, 1 , 9 , 0 ,11981001052312, 55 WITH TEXT ,BILLING, 45 ,#{@ent.broker_reference},CAD, 4000 , 1 ,,,,,,,,

    01/14/2013,BO

    01/16/2013,ADBAIR, 1 , 39009 , 0 ,11981001157739, 22 ,BROKERAGE, 37 ,#{@ent2.broker_reference},CAD, 4000 , 1 ,,,,,,,,
INV
    @k.parse @content

    bi = BrokerInvoice.find_by_invoice_number_and_source_system '39009', 'Fenix'
    bi.should_not be_nil
  end

  it "creates intacct receivables" do
    @ent.update_attributes! entry_number: "11981001052312"
    @content = <<INV
    INVOICE DATE,ACCOUNT#,BRANCH,INVOICE#,SUPP#,REFERENCE,CHARGE CODE,CHARGE DESC,AMOUNT,FILE NUMBER,INV CURR,CHARGE GL ACCT,CHARGE PROFIT CENTRE,PAYEE,DISB CODE,DISB AMT,DISB CURR,DISB GL ACCT,DISB PROFIT CENTRE,DISB REF
    01/14/2013,BOSSCI, 1 , 9 , 0 ,11981001052312, 55 WITH TEXT ,BILLING, 45 ,#{@ent.broker_reference},CAD, 4000 , 1 ,,,,,,,,
    01/14/2013,BOSSCI, 1 , 9 , 0 ,11981001052312, 55 WITH OTHER TEXT ,BILLING, -20,#{@ent.broker_reference},CAD, 4000 , 1 ,,,,,,,,
INV
    
    OpenChain::CustomHandler::Intacct::IntacctClient.should_receive(:delay).and_return OpenChain::CustomHandler::Intacct::IntacctClient
    OpenChain::CustomHandler::Intacct::IntacctClient.should_receive(:async_send_dimension).with 'Broker File', @ent.entry_number, @ent.entry_number

    @k.parse @content

    bi = BrokerInvoice.find_by_invoice_number_and_source_system 9, 'Fenix'

    r = IntacctReceivable.where(company: "vcu", invoice_number: bi.invoice_number).first

    expect(r).not_to be_nil
    expect(r.invoice_date).to eq bi.invoice_date
    expect(r.customer_number).to eq bi.customer_number
    expect(r.currency).to eq bi.currency
    expect(r.receivable_type).to eq "VFC Sales Invoice"

    expect(r.intacct_receivable_lines).to have(2).items

    l = r.intacct_receivable_lines.first
    bl = bi.broker_invoice_lines.first
    expect(l.charge_code).to eq "055"
    expect(l.charge_description).to eq bl.charge_description
    expect(l.amount).to eq bl.charge_amount
    expect(l.line_of_business).to eq "Brokerage"
    expect(l.broker_file).to eq @ent.entry_number
    expect(l.location).to eq "Toronto"

    l = r.intacct_receivable_lines.second
    bl = bi.broker_invoice_lines.second
    expect(l.amount).to eq bl.charge_amount
  end

  it "creates credit receivables" do
    # Just test that we treat credit invoices correctly (.ie inverting the charge lines from negative to positive)
    @content = <<INV
    INVOICE DATE,ACCOUNT#,BRANCH,INVOICE#,SUPP#,REFERENCE,CHARGE CODE,CHARGE DESC,AMOUNT,FILE NUMBER,INV CURR,CHARGE GL ACCT,CHARGE PROFIT CENTRE,PAYEE,DISB CODE,DISB AMT,DISB CURR,DISB GL ACCT,DISB PROFIT CENTRE,DISB REF
    01/14/2013,BOSSCI, 1 , 9 , 0 ,11981001052312, 55 WITH TEXT ,BILLING, -45 ,#{@ent.broker_reference},CAD, 4000 , 1 ,,,,,,,,
    01/14/2013,BOSSCI, 1 , 9 , 0 ,11981001052312, 55 WITH OTHER TEXT ,BILLING, 20 ,#{@ent.broker_reference},CAD, 4000 , 1 ,,,,,,,,
INV

    @k.parse @content

    bi = BrokerInvoice.find_by_invoice_number_and_source_system 9, 'Fenix'

    r = IntacctReceivable.where(company: "vcu", invoice_number: bi.invoice_number).first

    expect(r.receivable_type).to eq "VFC Credit Note"
    l = r.intacct_receivable_lines.first
    bl = bi.broker_invoice_lines.first

    expect(l.amount).to eq (bl.charge_amount * -1)

    l = r.intacct_receivable_lines.second
    bl = bi.broker_invoice_lines.second
    expect(l.amount).to eq (bl.charge_amount * -1)
  end

  it "uses customer xref if present" do
    @content = <<INV
    INVOICE DATE,ACCOUNT#,BRANCH,INVOICE#,SUPP#,REFERENCE,CHARGE CODE,CHARGE DESC,AMOUNT,FILE NUMBER,INV CURR,CHARGE GL ACCT,CHARGE PROFIT CENTRE,PAYEE,DISB CODE,DISB AMT,DISB CURR,DISB GL ACCT,DISB PROFIT CENTRE,DISB REF
    01/14/2013,BOSSCI, 1 , 9 , 0 ,11981001052312, 55 WITH TEXT ,BILLING, 45 ,#{@ent.broker_reference},CAD, 4000 , 1 ,,,,,,,,
INV
    @customer = DataCrossReference.create! key: DataCrossReference.make_compound_key("Fenix", "BOSSCI"), value: "XREF", cross_reference_type: DataCrossReference::INTACCT_CUSTOMER_XREF

    @k.parse @content

    r = IntacctReceivable.where(company: "vcu").first
    expect(r.customer_number).to eq "XREF"
  end

  it "strips trailing U from customer number if billed in USD" do
    @content = <<INV
    INVOICE DATE,ACCOUNT#,BRANCH,INVOICE#,SUPP#,REFERENCE,CHARGE CODE,CHARGE DESC,AMOUNT,FILE NUMBER,INV CURR,CHARGE GL ACCT,CHARGE PROFIT CENTRE,PAYEE,DISB CODE,DISB AMT,DISB CURR,DISB GL ACCT,DISB PROFIT CENTRE,DISB REF
    01/14/2013,BOSSCIU, 1 , 9 , 0 ,11981001052312, 55 WITH TEXT ,BILLING, 45 ,#{@ent.broker_reference},USD, 4000 , 1 ,,,,,,,,
INV
    @k.parse @content
    bi = BrokerInvoice.find_by_invoice_number_and_source_system 9, 'Fenix'
    expect(bi.customer_number).to eq "BOSSCI"
  end

  it "detects charge code 1 and 2 as Duty (D) type codes" do
    @content = <<INV
    INVOICE DATE,ACCOUNT#,BRANCH,INVOICE#,SUPP#,REFERENCE,CHARGE CODE,CHARGE DESC,AMOUNT,FILE NUMBER,INV CURR,CHARGE GL ACCT,CHARGE PROFIT CENTRE,PAYEE,DISB CODE,DISB AMT,DISB CURR,DISB GL ACCT,DISB PROFIT CENTRE,DISB REF
    01/14/2013,BOSSCI, 1 , 9 , 0 ,11981001052312, 1 WITH TEXT ,BILLING, 45 ,#{@ent.broker_reference},CAD, 4000 , 1 ,,,,,,,,
    01/14/2013,BOSSCI, 1 , 9 , 0 ,11981001052312, 2 WITH TEXT ,BILLING, 45 ,#{@ent.broker_reference},CAD, 4000 , 1 ,,,,,,,,
INV

    @k.parse @content
    bi = BrokerInvoice.find_by_invoice_number_and_source_system 9, 'Fenix'
    
    expect(bi.broker_invoice_lines).to have(2).items
    expect(bi.broker_invoice_lines.first.charge_type).to eq "D"
    expect(bi.broker_invoice_lines.second.charge_type).to eq "D"
  end

  it "detects ALS customer numbers" do
    DataCrossReference.create! key: DataCrossReference.make_compound_key("Fenix", "BOSSCI"), value: "POST_XREF", cross_reference_type: DataCrossReference::INTACCT_CUSTOMER_XREF
    DataCrossReference.create! key: "POST_XREF", value: "", cross_reference_type: DataCrossReference::FENIX_ALS_CUSTOMER_NUMBER
    @content = <<INV
    INVOICE DATE,ACCOUNT#,BRANCH,INVOICE#,SUPP#,REFERENCE,CHARGE CODE,CHARGE DESC,AMOUNT,FILE NUMBER,INV CURR,CHARGE GL ACCT,CHARGE PROFIT CENTRE,PAYEE,DISB CODE,DISB AMT,DISB CURR,DISB GL ACCT,DISB PROFIT CENTRE,DISB REF
    01/14/2013,BOSSCI, 1 , 9 , 0 ,11981001052312, 1 WITH TEXT ,BILLING, 45 ,#{@ent.broker_reference},CAD, 4000 , 1 ,,,,,,,,
INV

    @k.parse @content

    r = IntacctReceivable.where(company: "als").first
    expect(r).to_not be_nil
    expect(r.customer_number).to eq "POST_XREF"
    expect(r.receivable_type).to eq "ALS Sales Invoice"
  end

  it "detects ALS customer numbers on credit invoices" do
    DataCrossReference.create! key: DataCrossReference.make_compound_key("Fenix", "BOSSCI"), value: "POST_XREF", cross_reference_type: DataCrossReference::INTACCT_CUSTOMER_XREF
    DataCrossReference.create! key: "POST_XREF", value: "", cross_reference_type: DataCrossReference::FENIX_ALS_CUSTOMER_NUMBER
    @content = <<INV
    INVOICE DATE,ACCOUNT#,BRANCH,INVOICE#,SUPP#,REFERENCE,CHARGE CODE,CHARGE DESC,AMOUNT,FILE NUMBER,INV CURR,CHARGE GL ACCT,CHARGE PROFIT CENTRE,PAYEE,DISB CODE,DISB AMT,DISB CURR,DISB GL ACCT,DISB PROFIT CENTRE,DISB REF
    01/14/2013,BOSSCI, 1 , 9 , 0 ,11981001052312, 1 WITH TEXT ,BILLING, -45 ,#{@ent.broker_reference},CAD, 4000 , 1 ,,,,,,,,
INV

    @k.parse @content

    r = IntacctReceivable.where(company: "als").first
    expect(r).to_not be_nil
    expect(r.receivable_type).to eq "ALS Credit Note"
  end
end
