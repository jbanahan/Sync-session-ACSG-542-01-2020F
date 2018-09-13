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
    expect(b.last_file_bucket).to eq('bucket')
    expect(b.last_file_path).to eq('key')
  end
  it "should write invoice" do
    # There's two invoices in the spec csv file, account for that
    expect(Lock).to receive(:acquire).with("BrokerInvoice-01-0000009").and_yield
    expect(Lock).to receive(:acquire).with("BrokerInvoice-01-0039009").and_yield
    expect(Lock).to receive(:with_lock_retry).twice.with(instance_of(BrokerInvoice)).and_yield
    expect(Lock).to receive(:with_lock_retry).twice.with(instance_of(IntacctReceivable)).and_yield

    @k.parse @content
    expect(BrokerInvoice.count).to eq(2)
    bi = BrokerInvoice.find_by_broker_reference_and_source_system '280952', 'Fenix'
    expect(bi.invoice_total).to eq(4574.83) #does not include GST (code 2)
    expect(bi.suffix).to be_blank
    expect(bi.currency).to eq('CAD')
    bi.invoice_date = Date.new(2013,1,14)
    expect(bi.invoice_number).to eq('01-0000009')
    expect(bi.customer_number).to eq("BOSSCI")
  end
  it "should write details" do
    @k.parse @content
    bi = BrokerInvoice.find_by_broker_reference_and_source_system '280952', 'Fenix'
    expect(bi.broker_invoice_lines.size).to eq(3)

    billing = bi.broker_invoice_lines.find_by_charge_code '55' #should truncate the text if the invoice charge code starts with a number and a space
    expect(billing.charge_description).to eq('BILLING')
    expect(billing.charge_amount).to eq(45)
    expect(billing.charge_type).to eq('R')

    hst = bi.broker_invoice_lines.find_by_charge_code '255'
    expect(hst.charge_description).to eq('HST (ON)')
    expect(hst.charge_amount).to eq(5.85)
    expect(hst.charge_type).to eq('R')

    gst = bi.broker_invoice_lines.find_by_charge_code '21'
    expect(gst.charge_description).to eq('GST ON IMPORTS')
    expect(gst.charge_amount).to eq(4523.98)
    expect(gst.charge_type).to eq('D')
  end
  it "should replace invoice" do
    #going to process, then delete a line, then reprocess and line should come back
    @k.parse @content
    bi = BrokerInvoice.find_by_broker_reference_and_source_system '280952', 'Fenix'
    bi.broker_invoice_lines.first.destroy
    bi.update_attributes(:invoice_total=>2)

    @k.parse @content
    bi.reload
    expect(bi.broker_invoice_lines.size).to eq(3)
    expect(bi.invoice_total).to eq(4574.83)
  end
  it "should match to entry" do
    @k.parse @content
    bi = BrokerInvoice.find_by_broker_reference_and_source_system @ent.broker_reference, 'Fenix'
    expect(bi.entry).to eq(@ent)
    expect(bi.entry.broker_invoice_total).to eq(bi.invoice_total)
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
    expect(@ent.broker_invoices.size).to eq(2)
    expect(@ent.broker_invoice_total).to eq(@ent.broker_invoices.inject(BigDecimal.new("0.0")){|sum, inv| sum += inv.invoice_total})
  end

  it "invoice total should not include codes 20 or 21" do
    @k.parse @content
    expect(BrokerInvoice.find_by_broker_reference('280952').invoice_total).to eq(4574.83)
    expect(BrokerInvoice.find_by_broker_reference('281350').invoice_total.to_f).to eq(595.68)
  end

  it "should handle a minimal amount of information" do
    @k.parse "INVOICE DATE,ACCOUNT#,BRANCH,INVOICE#,SUPP#,REFERENCE,CHARGE CODE,CHARGE DESC,AMOUNT,FILE NUMBER,INV CURR,CHARGE GL ACCT,CHARGE PROFIT CENTRE,PAYEE,DISB CODE,DISB AMT,DISB CURR,DISB GL ACCT,DISB PROFIT CENTRE,DISB REF\n" +
              "04/27/2013,, 1 , INV# , ,,22 BROKERAGE,BROKERAGE, 55 ,#{@ent.broker_reference},  , 1 ,,,,,,,,"
    bi = BrokerInvoice.find_by_invoice_number_and_source_system '01-000INV#', 'Fenix'
    expect(bi.broker_reference).to eq(@ent.broker_reference)
  end

  it "should handle errors for each invoice individually" do
    expect {
      @k.parse "INVOICE DATE,ACCOUNT#,BRANCH,INVOICE#,SUPP#,REFERENCE,CHARGE CODE,CHARGE DESC,AMOUNT,FILE NUMBER,INV CURR,CHARGE GL ACCT,CHARGE PROFIT CENTRE,PAYEE,DISB CODE,DISB AMT,DISB CURR,DISB GL ACCT,DISB PROFIT CENTRE,DISB REF\n" +
      # This line fails due to missing invoice date
      ",, 1 , INV#2 , ,,22 BROKERAGE,BROKERAGE, 55 ,REF#,,  , 1 ,,,,,,,,\n" +
      "04/27/2013,, 1 , INV# , ,,22 BROKERAGE,BROKERAGE, 55 ,#{@ent.broker_reference},,  , 1 ,,,,,,,,\n", {:key => "path/to/file"}
    }.to change(ErrorLogEntry,:count).by(1)
    bi = BrokerInvoice.find_by_invoice_number_and_source_system '01-00INV#2', 'Fenix'
    expect(bi).not_to be_nil
  end

  it "should raise an error if the broker reference is missing" do
    expect {
      @k.parse "INVOICE DATE,ACCOUNT#,BRANCH,INVOICE#,SUPP#,REFERENCE,CHARGE CODE,CHARGE DESC,AMOUNT,FILE NUMBER,INV CURR,CHARGE GL ACCT,CHARGE PROFIT CENTRE,PAYEE,DISB CODE,DISB AMT,DISB CURR,DISB GL ACCT,DISB PROFIT CENTRE,DISB REF\n" +
      # This line fails due to missing broker reference
      "04/27/2013,, 1 , INV#2 , ,,22 BROKERAGE,BROKERAGE, 55 ,,,  , 1 ,,,,,,,,"
    }.to change(ErrorLogEntry,:count).by(1)
    bi = BrokerInvoice.find_by_invoice_number_and_source_system '01-00INV#2', 'Fenix'
    expect(bi).to be_nil
  end

  it "should skip lines that are missing invoice numbers" do
    @content = <<INV
    INVOICE DATE,ACCOUNT#,BRANCH,INVOICE#,SUPP#,REFERENCE,CHARGE CODE,CHARGE DESC,AMOUNT,FILE NUMBER,INV CURR,CHARGE GL ACCT,CHARGE PROFIT CENTRE,PAYEE,DISB CODE,DISB AMT,DISB CURR,DISB GL ACCT,DISB PROFIT CENTRE,DISB REF
    01/14/2013,BOSSCI, 1 , 9 , 0 ,11981001052312, 55 WITH TEXT ,BILLING, 45 ,#{@ent.broker_reference},CAD, 4000 , 1 ,,,,,,,,

    01/14/2013,BO

    01/16/2013,ADBAIR, 1 , 39009 , 0 ,11981001157739, 22 ,BROKERAGE, 37 ,#{@ent2.broker_reference},CAD, 4000 , 1 ,,,,,,,,
INV
    @k.parse @content

    bi = BrokerInvoice.find_by_invoice_number_and_source_system '01-0039009', 'Fenix'
    expect(bi).not_to be_nil
  end

  it "uses suffix in invoice number if value in column 4 is not 0" do
    @content = <<INV
    INVOICE DATE,ACCOUNT#,BRANCH,INVOICE#,SUPP#,REFERENCE,CHARGE CODE,CHARGE DESC,AMOUNT,FILE NUMBER,INV CURR,CHARGE GL ACCT,CHARGE PROFIT CENTRE,PAYEE,DISB CODE,DISB AMT,DISB CURR,DISB GL ACCT,DISB PROFIT CENTRE,DISB REF
    01/14/2013,BOSSCI, 1 , 9 , 1 ,11981001052312, 55 WITH TEXT ,BILLING, 45 ,#{@ent.broker_reference},CAD, 4000 , 1 ,,,,,,,,
INV
    @k.parse @content
    bi = BrokerInvoice.find_by_invoice_number_and_source_system "01-0000009-01", 'Fenix'
    expect(bi).to_not be_nil
  end

  it "does not create receivables for GENERIC customer" do
    @ent.update_attributes! entry_number: "11981001052312"
    @content = <<INV
    INVOICE DATE,ACCOUNT#,BRANCH,INVOICE#,SUPP#,REFERENCE,CHARGE CODE,CHARGE DESC,AMOUNT,FILE NUMBER,INV CURR,CHARGE GL ACCT,CHARGE PROFIT CENTRE,PAYEE,DISB CODE,DISB AMT,DISB CURR,DISB GL ACCT,DISB PROFIT CENTRE,DISB REF
    01/14/2013,GENERIC, 1 , 9 , 0 ,11981001052312, 55 WITH TEXT ,BILLING, 45 ,#{@ent.broker_reference},CAD, 4000 , 1 ,,,,,,,,
    01/14/2013,GENERIC, 1 , 9 , 0 ,11981001052312, 55 WITH OTHER TEXT ,BILLING, -20,#{@ent.broker_reference},CAD, 4000 , 1 ,,,,,,,,
INV
    @k.parse @content
    expect(IntacctReceivable.count).to eq 0
  end

  it "creates intacct receivables" do
    @ent.update_attributes! entry_number: "11981001052312"
    @content = <<INV
    INVOICE DATE,ACCOUNT#,BRANCH,INVOICE#,SUPP#,REFERENCE,CHARGE CODE,CHARGE DESC,AMOUNT,FILE NUMBER,INV CURR,CHARGE GL ACCT,CHARGE PROFIT CENTRE,PAYEE,DISB CODE,DISB AMT,DISB CURR,DISB GL ACCT,DISB PROFIT CENTRE,DISB REF
    01/14/2013,BOSSCI, 1 , 9 , 0 ,11981001052312, 55 WITH TEXT ,BILLING, 45 ,#{@ent.broker_reference},CAD, 4000 , 1 ,,,,,,,,
    01/14/2013,BOSSCI, 1 , 9 , 0 ,11981001052312, 55 WITH OTHER TEXT ,BILLING, -20,#{@ent.broker_reference},CAD, 4000 , 1 ,,,,,,,,
INV

    expect(OpenChain::CustomHandler::Intacct::IntacctClient).to receive(:delay).and_return OpenChain::CustomHandler::Intacct::IntacctClient
    expect(OpenChain::CustomHandler::Intacct::IntacctClient).to receive(:async_send_dimension).with 'Broker File', @ent.entry_number, @ent.entry_number

    @k.parse @content

    bi = BrokerInvoice.find_by_invoice_number_and_source_system "01-0000009", 'Fenix'

    r = IntacctReceivable.where(company: "vcu", invoice_number: bi.invoice_number).first

    expect(r).not_to be_nil
    expect(r.invoice_date).to eq bi.invoice_date
    expect(r.customer_number).to eq bi.customer_number
    expect(r.currency).to eq bi.currency
    expect(r.receivable_type).to eq "VFC Sales Invoice"

    expect(r.intacct_receivable_lines.size).to eq(2)

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

    bi = BrokerInvoice.find_by_invoice_number_and_source_system "01-0000009", 'Fenix'

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
    bi = BrokerInvoice.find_by_invoice_number_and_source_system "01-0000009", 'Fenix'
    expect(bi.customer_number).to eq "BOSSCI"
  end

  it "detects charge code 1 and 2 as Duty (D) type codes" do
    @content = <<INV
    INVOICE DATE,ACCOUNT#,BRANCH,INVOICE#,SUPP#,REFERENCE,CHARGE CODE,CHARGE DESC,AMOUNT,FILE NUMBER,INV CURR,CHARGE GL ACCT,CHARGE PROFIT CENTRE,PAYEE,DISB CODE,DISB AMT,DISB CURR,DISB GL ACCT,DISB PROFIT CENTRE,DISB REF
    01/14/2013,BOSSCI, 1 , 9 , 0 ,11981001052312, 1 WITH TEXT ,BILLING, 45 ,#{@ent.broker_reference},CAD, 4000 , 1 ,,,,,,,,
    01/14/2013,BOSSCI, 1 , 9 , 0 ,11981001052312, 2 WITH TEXT ,BILLING, 45 ,#{@ent.broker_reference},CAD, 4000 , 1 ,,,,,,,,
INV

    @k.parse @content
    bi = BrokerInvoice.find_by_invoice_number_and_source_system "01-0000009", 'Fenix'

    expect(bi.broker_invoice_lines.size).to eq(2)
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
    expect(r.intacct_receivable_lines.first.location).to eq "TOR"
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

  it "updates ALS receivable" do
    inv = IntacctReceivable.create! company: "als", invoice_number: "01-0000009"
    inv.intacct_receivable_lines.create! charge_code: "ABC"

    DataCrossReference.create! key: "BOSSCI", value: "", cross_reference_type: DataCrossReference::FENIX_ALS_CUSTOMER_NUMBER

    @content = <<INV
    INVOICE DATE,ACCOUNT#,BRANCH,INVOICE#,SUPP#,REFERENCE,CHARGE CODE,CHARGE DESC,AMOUNT,FILE NUMBER,INV CURR,CHARGE GL ACCT,CHARGE PROFIT CENTRE,PAYEE,DISB CODE,DISB AMT,DISB CURR,DISB GL ACCT,DISB PROFIT CENTRE,DISB REF
    01/14/2013,BOSSCI, 1 , 9 , 0 ,11981001052312, 1 WITH TEXT ,BILLING, 45 ,#{@ent.broker_reference},CAD, 4000 , 1 ,,,,,,,,
INV
    @k.parse @content
    inv.reload

    expect(inv.customer_number).to eq "BOSSCI"
    expect(inv.intacct_receivable_lines.first.charge_code).to eq "001"
  end

  it "assigns fiscal month to broker invoice" do
    imp = Factory(:company, fiscal_reference: "ent_release_date")
    @ent.update_attributes(importer: imp, release_date: "20130105")
    fm = Factory(:fiscal_month, company: imp, year: 2013, month_number: 1, start_date: Date.new(2013,1,1), end_date: Date.new(2015,1,31))
    @k.parse @content

    brok_inv = @ent.broker_invoices.first
    expect(brok_inv.fiscal_date).to eq fm.start_date
    expect(brok_inv.fiscal_month).to eq 1
    expect(brok_inv.fiscal_year).to eq 2013
  end
end
