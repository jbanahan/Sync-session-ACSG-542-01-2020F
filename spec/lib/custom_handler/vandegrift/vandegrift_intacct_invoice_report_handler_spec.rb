describe OpenChain::CustomHandler::Vandegrift::VandegriftIntacctInvoiceReportHandler do
  let!(:ms) do
    ms = stub_master_setup
    allow(MasterSetup).to receive(:get).and_return ms
    ms
  end
  let(:cf) { instance_double(CustomFile) }
  let(:handler) { described_class.new(cf) }

  describe "valid_file?" do
    it "returns true for Excel files" do
      expect(described_class.valid_file? "foo.xls").to eq true
      expect(described_class.valid_file? "foo.Xls").to eq true
      expect(described_class.valid_file? "foo.xlsx").to eq true
      expect(described_class.valid_file? "foo.xLsx").to eq true
    end

    it "returns false for non-Excel files" do
      expect(described_class.valid_file? "foo.csv").to eq false
      expect(described_class.valid_file? "foo.txt").to eq false
    end
  end

  describe "can_view?" do
    it "returns true for master users" do
      u = Factory(:master_user)
      expect(ms).to receive(:custom_feature?).with('Intacct Invoice Report Upload').and_return true
      expect(described_class.can_view? u).to eq true
    end

    it "returns false for non-master users" do
      u = Factory(:user)
      expect(ms).to receive(:custom_feature?).with('Intacct Invoice Report Upload').and_return true
      expect(described_class.can_view? u).to eq false
    end

    it "returns false if feature not enabled" do
      u = Factory(:master_user)
      expect(ms).to receive(:custom_feature?).with('Intacct Invoice Report Upload').and_return false
      expect(described_class.can_view? u).to eq false
    end
  end

  describe "get_urls" do
    it "associates a list of invoice numbers with entry URLs, returning nil for those that aren't found" do
      bi1 = Factory(:broker_invoice, entry: Factory(:entry), invoice_number: "1234")
      bi2 = Factory(:broker_invoice, entry: Factory(:entry), invoice_number: "5678")
      expect(handler.get_urls(["1234", "5678", "9012"])).to eq({"1234" => bi1.entry.excel_url, 
                                                                "5678" => bi2.entry.excel_url,
                                                                "9012" => nil})
    end
  end
  
  describe "send_success_email" do
    it "sends email with attachment and list of missing invoices if there were no errors" do
      Tempfile.open(["s3_content", ".txt"]) do |t|
        t.binmode
        t << "Content of a tempfile"
        Attachment.add_original_filename_method t, "foo.xlsx"
        t.rewind

        handler.send_success_email "tufnel@stonehenge.biz", t, ["inv1<", "inv2"] #test escaping
        m = OpenMailer.deliveries.pop
        expect(m.to.first).to eq "tufnel@stonehenge.biz"
        expect(m.subject).to eq "[VFI Track] Intacct Invoice Report Upload completed successfully"
        expect(m.body.raw_source).to include "The updated Intacct Invoice Report foo.xlsx is attached.<br>The following invoices could not be found: inv1&lt;, inv2"
        expect(m.attachments.size).to eq 1
      end
    end
  end

  describe "send_failure_email" do
    it "sends email with error messages if exceptions were thrown" do
      handler.send_failure_email "tufnel@stonehenge.biz", "ERROR"
      m = OpenMailer.deliveries.pop
      expect(m.to.first).to eq "tufnel@stonehenge.biz"
      expect(m.subject).to eq "[VFI Track] Intacct Invoice Report Upload completed with errors"
      expect(m.body.raw_source).to include "The Intacct Invoice Report could not be updated due to the following error: ERROR"
      expect(m.attachments.size).to eq 0
    end
  end

  describe "send_xl" do
    it "downloads and emails updated XLSX file" do
      temp = instance_double "TempFile"
      u = Factory(:user, email: "tufnel@stonehenge.biz")
      expect(cf).to receive(:attached_file_name).and_return "foo.xlsx"
      expect(OpenChain::S3).to receive(:download_to_tempfile).with("chainio-temp", "test-uuid/intacct_invoice_report/foo.xlsx").and_yield temp
      expect(handler).to receive(:send_success_email).with "tufnel@stonehenge.biz", temp, ["k3"]
      handler.send_xl u, {"k1" => "foo", "k2" => "bar", "k3" => nil}, "foo.xls"
    end
  end
  
  context "XlClient" do
    let(:xl_client) { instance_double "XlClient" }

    describe "process" do
      let(:u) { Factory(:user, email: "tufnel@stonehenge.biz") }
      
      it "adds URLs to file, saves it to S3, and emails it" do
        urls = instance_double "Hash"
        expect(cf).to receive :path
        expect(cf).to receive(:attached_file_name).twice.and_return "foo.xlsx"
        expect_any_instance_of(OpenChain::XLClient).to receive(:all_row_values).with(starting_row_number: 7).and_yield([nil,nil,"123A"]).and_yield([nil,nil,"hi there"])
        expect(handler).to receive(:get_urls).with(["123A"]).and_return urls
        expect(handler).to receive(:write_xl).with(instance_of(OpenChain::XLClient), urls)
        expect_any_instance_of(OpenChain::XLClient).to receive(:save).with "test-uuid/intacct_invoice_report/foo.xlsx", {bucket: "chainio-temp"}
        expect(handler).to receive(:send_xl).with u, urls, "foo.xlsx"

        handler.process u
      end

      it "sends email if an exception is thrown" do
        expect(cf).to receive :path
        expect_any_instance_of(OpenChain::XLClient).to receive(:all_row_values).and_raise "ERROR!"
        expect(handler).to receive(:send_failure_email).with "tufnel@stonehenge.biz", "ERROR!"
        handler.process u
      end
    end

    describe "write_xl" do
      it "writes the column header and adds links from URL hash" do
        r = [nil,nil,"inv_num"]
        r2 = [nil,nil,"inv_num_2"]
        r3 = [nil,nil,"inv_num_3"] # this one doesn't get written since it's missing from the hash
        expect(xl_client).to receive(:set_cell).with 0, 6, 16, "VFI Track Entry Link"
        expect(xl_client).to receive(:all_row_values).with(starting_row_number: 7).and_yield(r).and_yield(r2).and_yield(r3)
        expect(xl_client).to receive(:set_cell).with 0, 7, 16, "Web Link", "http://entry_link"
        expect(xl_client).to receive(:set_cell).with 0, 8, 16, "Web Link", "http://entry_link_2"
        handler.write_xl xl_client, {"inv_num" => "http://entry_link", "inv_num_2" => "http://entry_link_2"}
      end
    end

  end

end
