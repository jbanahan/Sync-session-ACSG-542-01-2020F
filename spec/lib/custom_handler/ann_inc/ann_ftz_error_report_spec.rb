describe OpenChain::CustomHandler::AnnInc::AnnFtzErrorReport do
  let(:report) { described_class.new }
  let(:cdefs) { report.cdefs }
  let(:user) { Factory(:user, username: "Nigel Tufnel") }
  let(:approved_date) { Date.new(2019, 3, 15) }
  let(:prod) do
    p = Factory(:product, unique_identifier: "style", last_updated_by: user)
    p.update_custom_value! cdefs[:related_styles], "related styles"
    p
  end
  let(:classi) do
    cl = Factory(:classification, product: prod)
    cl.find_and_set_custom_value(cdefs[:approved_date], approved_date)
    cl.find_and_set_custom_value(cdefs[:manual_flag], true)
    cl.find_and_set_custom_value(cdefs[:classification_type], "class type")
    cl.save!
    cl
  end
  let(:tariff_1) do
    tr = Factory(:tariff_record, classification: classi, hts_1: "123456789", line_number: 1)
    tr.find_and_set_custom_value(cdefs[:percent_of_value], 25)
    tr.find_and_set_custom_value(cdefs[:key_description], "key description")
    tr.save!
    tr
  end
  let(:tariff_2) do
    tr = Factory(:tariff_record, classification: classi, hts_1: "987654321", line_number: 2)
    tr.find_and_set_custom_value(cdefs[:percent_of_value], 75)
    tr.find_and_set_custom_value(cdefs[:key_description], "key description 2")
    tr.save!
    tr
  end
  let(:bvt) { Factory(:business_validation_template, module_type: "Product", system_code: "FTZ") }
  let(:bvre) { Factory(:business_validation_result, business_validation_template: bvt, validatable: prod) }
  let(:bvru) { Factory(:business_validation_rule, business_validation_template: bvt) }
  let(:bvrr) { Factory(:business_validation_rule_result_without_callback, business_validation_rule: bvru, business_validation_result: bvre, state: "Fail", message: "FAIL!!") }
  let(:header) { ["Style", "Related Styles", "Approved Date", "Manual Entry Processing", "Classification Type", "HTS Value",
                  "Percent of Value", "Key Description", "Last User to Alter the Record", "Business Rule Failure Message",
                  "Link to VFI Track"] }

  def load_all
    tariff_1; tariff_2; bvrr
  end

  describe "run_schedulable" do
    before { stub_master_setup }

    it "creates and emails report" do
      load_all

      dist_list = Factory(:mailing_list, system_code: "FTZ list", email_addresses: "tufnel@stonehenge.biz")
      Timecop.freeze(DateTime.new(2019, 3, 15, 6)) { described_class.run_schedulable("distribution_list" => "FTZ list") }
      mail = ActionMailer::Base.deliveries.pop
      expect(mail.to).to eq ["tufnel@stonehenge.biz"]
      expect(mail.subject).to eq "Ann FTZ Error Report 2019-03-15"
      expect(mail.body).to include "The Ann FTZ Error Report for 2019-03-15 is attached."
      expect(mail.attachments.count).to eq 1
      att = mail.attachments.first

      reader = XlsxTestReader.new(StringIO.new(att.read)).raw_workbook_data
      sheet = reader["Rule Failures"]
      expect(sheet[0]).to eq header
      # check boolean conversion
      expect(sheet[1][3]).to eq "true"
    end
  end

  describe "query" do
    before { load_all }

    it "returns expected result" do
      results = ActiveRecord::Base.connection.execute(report.query("FTZ"))
      expect(results.fields).to eq header
      expect(results.count).to eq 2
      res = []
      results.each { |r| res << r }
      expect(res.first).to eq ["style", "related styles", approved_date, 1, "class type", "123456789", 25, "key description", "Nigel Tufnel", "FAIL!!", prod.id]
      expect(res.last).to eq ["style", "related styles", approved_date, 1, "class type", "987654321", 75, "key description 2", "Nigel Tufnel", "FAIL!!", prod.id]
    end

    it "omits Pass results" do
      bvrr.update_attributes! state: "Pass"
      results = ActiveRecord::Base.connection.execute(report.query("FTZ"))
      expect(results.count).to eq 0
    end

    it "omits results from other templates" do
      bvt.update_attributes! system_code: "Foo"
      results = ActiveRecord::Base.connection.execute(report.query("FTZ"))
      expect(results.count).to eq 0
    end

  end

end
