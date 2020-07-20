describe OpenChain::Report::TicketTrackingReport do
  let!(:us) { Factory(:country, iso_code: "US")}
  let!(:report) { described_class.new }
  let(:now) { ActiveSupport::TimeZone["UTC"].local(2016, 5, 15) }
  let(:tomorrow) { now + 1.day }
  let(:day_after_tomorrow) { tomorrow + 1.day }

  # rubocop:disable Layout/LineLength
  #                          0               1          2          3            4              5               6            7           8           9             10              11               12                  13
  let(:jira_header) { ['Issue Number', 'Issue Type', 'Status', 'Summary', 'Order Number(s)', 'Part Number(s)', 'Description', 'Comments', 'Assignee', 'Reporter', 'Shipment ETA', 'Issue Created', 'Issue Resolved', 'Broker Reference'] }
  let(:jira_result) do
    [['issue num', 'issue type', 'stat', 'summary', 'ord num', 'part num', 'descr', 'issue id 1', 'assignee', 'reporter', 'shipment eta', tomorrow, now, 'brok ref', 'pkey1'],
     ['issue num2', 'issue type2', 'stat2', 'summary2', 'ord num2', 'part num2', 'descr2', 'issue id 2', 'assignee2', 'reporter2', 'shipment eta2', now, now, 'brok ref2', 'pkey2'],
     ['issue num3', 'issue type3', 'stat3', 'summary3', 'ord num3', 'part num3', 'descr3', 'issue id 3', 'assignee3', 'reporter3', 'shipment eta3', day_after_tomorrow, now, 'brok ref3', 'pkey3']]
  end

  #                           0                  1             2              3                4            5         6              7                   8              9                 10                 11               12                       13
  let(:vfi_header) { ["broker_reference", "Entry Number", "PO Numbers", "Part Numbers", "Product Lines", "Vendors", "MIDs", "Countries of Origin", "Master Bills", "House Bills", "Container Numbers", "Release Date", "Link to Jira issue", "Link to Entry"] }
  let(:vfi_result) do
    [["brok ref", "ent num", "po nums", "part nums", "prod lines", "vend names", "mfids", "coo", "mbols", "hbols", "container nums", now, "URL", 1],
     ["brok ref2", "ent num2", "po nums2", "part nums2", "prod lines2", "vend names2", "mfids2", "coo2", "mbols2", "hbols2", "container nums2", now, "URL", 2]]
  end
  #                               0              1           2         3             4              5              6             7           8           9             10             11                12                 13                14              15            16              17             18       19              20                 21              22               23                 24               25                       26
  let (:combined_header) { ['Issue Number', 'Issue Type', 'Status', 'Summary', 'Order Number(s)', 'Part Number(s)', 'Description', 'Comments', 'Assignee', 'Reporter', 'Shipment ETA', 'Issue Created', 'Issue Resolved', 'Broker Reference', "Entry Number", "PO Numbers", "Part Numbers", "Product Lines", "Vendors", "MIDs", "Countries of Origin", "Master Bills", "House Bills", "Container Numbers", "Release Date", "Link to Jira issue", "Link to Entry"] }

  let(:combined_result) do
     [['issue num2', 'issue type2', 'stat2', 'summary2', 'ord num2', 'part num2', 'descr2', 'issue id 2', 'assignee2', 'reporter2', 'shipment eta2', now, now, 'brok ref2', "ent num2", "po nums2", "part nums2", "prod lines2", "vend names2", "mfids2", "coo2", "mbols2", "hbols2", "container nums2", now, 'pkey2', 2],
      ['issue num', 'issue type', 'stat', 'summary', 'ord num', 'part num', 'descr', 'issue id 1', 'assignee', 'reporter', 'shipment eta', tomorrow, now, 'brok ref', "ent num", "po nums", "part nums", "prod lines", "vend names", "mfids", "coo", "mbols", "hbols", "container nums", now, 'pkey1', 1],
      ['issue num3', 'issue type3', 'stat3', 'summary3', 'ord num3', 'part num3', 'descr3', 'issue id 3', 'assignee3', 'reporter3', 'shipment eta3', day_after_tomorrow, now, 'brok ref3', nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, 'pkey3']]
  end

  # rubocop:enable Layout/LineLength

  describe "permission?" do
    let(:user) { instance_double(User) }

    before do
      ms = stub_master_setup
      allow(ms).to receive(:system_code).and_return "www-vfitrack-net"
    end

    context "users who can view entries" do

      it "allows users with access to a ticketing_system_code" do
        expect(user).to receive(:view_entries?).and_return true
        expect(described_class).to receive(:get_project_keys).with(user).and_return ["FOO"]
        expect(described_class.permission?(user)).to eq true
      end

      it "doesn't allow users not belonging to a company with a ticketing_system_code" do
        expect(user).to receive(:view_entries?).and_return true
        expect(described_class).to receive(:get_project_keys).with(user).and_return []
        expect(described_class.permission?(user)).to eq false
      end
    end

    it "doesn't allow users who can't view entries" do
      expect(user).to receive(:view_entries?).and_return false
      allow(described_class).to receive(:get_project_keys).with(user).and_return ["FOO"]
      expect(described_class.permission?(user)).to eq false
    end
  end

  describe "run_report" do
    let(:u) { Factory(:user, time_zone: "Eastern Time (US & Canada)", company: Factory(:company, ticketing_system_code: "CODE")) }

    let(:temp) { nil }

    after { temp&.close }

    it "generates spreadsheet, adjusts for user time zone" do
      stub_master_setup
      adjusted_start = "2016-01-01 05:00:00"
      adjusted_end = "2016-02-01 05:00:00"
      expect_any_instance_of(described_class).to receive(:jira_query).with(["CODE"], adjusted_start, adjusted_end).and_return "jira query"
      expect_any_instance_of(described_class).to receive(:vfi_query).with(["brok ref", "brok ref2", "brok ref3"]).and_return "vfi query"

      expect_any_instance_of(described_class).to receive(:execute_query).with("jira query").and_yield(jira_result).and_return(nil)
      expect_any_instance_of(described_class).to receive(:execute_query).with("vfi query").and_yield(vfi_result).and_return(nil)

      expect_any_instance_of(described_class).to receive(:comments_lambda).and_return(->(_arg1, _arg2) { "comments" })
      temp = described_class.run_report(u, {'start_date' => '2016-01-01', 'end_date' => '2016-02-01', 'project_keys' => ['CODE']})
      wb = XlsxTestReader.new(temp.path).raw_workbook_data
      expect(wb.length).to eq 1

      sheet = wb["Ticket Tracking Report"]
      expect(sheet).not_to be_nil
      expect(sheet.length).to eq 4
      expect(sheet[0]).to eq combined_header
      expect(sheet[1][24].to_s).to eq(now.in_time_zone(u.time_zone).to_s)
      expect(sheet[1][11].to_s).to eq(now.in_time_zone(u.time_zone).to_s)
      expect(sheet[1][12].to_s).to eq(now.in_time_zone(u.time_zone).to_s)
      expect(sheet[1][7]).to eq "comments"
      expect(sheet[1][25]).to eq "Web View"
      expect(sheet[1][26]).to eq "Web View"
    end
  end

  describe "get_project_keys" do
    let(:linked) { Factory(:company, ticketing_system_code: "FOO") }
    let(:co) { Factory(:company, ticketing_system_code: "BAR", linked_companies: [linked]) }
    let(:user) { Factory(:user, company: co)}

    before { Factory(:company, ticketing_system_code: "BAZ") }

    it "returns codes of all companies as well as default list for master user" do
      co.update!(master: true)
      expect(described_class.get_project_keys(user)).to eq ["BAR", "BAZ", "DEMO", "FOO", "IT", "TP"]
    end

    it "returns codes belonging to non-master user's company and linked companies" do
      expect(described_class.get_project_keys(user)).to eq ["BAR", "FOO"]
    end
  end

  describe "validate_ticketing_sys_codes" do
    let(:user) { instance_double(User) }

    it "returns nil if user has access to all listed codes" do
      expect(described_class).to receive(:get_project_keys).with(user).and_return(["FOO", "BAR"])
      expect(report.validate_ticketing_sys_codes(user, ["FOO", "BAR"])).to be_nil
    end

    it "throws exception with names of unauthorized codes if there are any" do
      expect(described_class).to receive(:get_project_keys).with(user).and_return(["FOO", "BAR"])
      expect {report.validate_ticketing_sys_codes(user, ["FOO", "BAZ", "QUUX"])}.to raise_error("User isn't authorized to view project key(s) BAZ, QUUX")
    end
  end

  describe "graft_results" do
    it "combines results of jira and vfi queries, sorting by 'issue created date'" do
      combined = report.graft_results(jira_result, vfi_result)
      expect(combined[0]).to eq(combined_result[0])
      expect(combined[1]).to eq(combined_result[1])
      expect(combined[2]).to eq(combined_result[2])
    end
  end

  describe "vfi_query" do
    let!(:ent) do
      Factory(:entry, entry_number: "ent num", broker_reference: "brok ref", po_numbers: "po nums", part_numbers: "part nums",
                      product_lines: "prod lines", vendor_names: "vend names", mfids: "mfids", origin_country_codes: "coo",
                      master_bills_of_lading: "mbols", house_bills_of_lading: "hbols", container_numbers: "container nums",
                      release_date: now, import_country_id: us.id)
    end

    it "returns expected results" do
      r = ActiveRecord::Base.connection.execute(report.vfi_query(["brok ref"]))
      expect(r.fields).to eq vfi_header
      expect(r.count).to eq 1
      expect(r.first).to eq ["brok ref", "ent num", "po nums", "part nums", "prod lines", "vend names", "mfids", "coo", "mbols", "hbols",
                             "container nums", now, "URL", ent.id]
    end

    it "only includes entries with a listed broker reference" do
      r = ActiveRecord::Base.connection.execute(report.vfi_query(["foo"]))
      expect(r.count).to eq 0
    end

    it "only includes US entries" do
      ent.update!(import_country_id: us.id + 1)
      r = ActiveRecord::Base.connection.execute(report.vfi_query(["brok ref"]))
      expect(r.count).to eq 0
    end
  end
end
