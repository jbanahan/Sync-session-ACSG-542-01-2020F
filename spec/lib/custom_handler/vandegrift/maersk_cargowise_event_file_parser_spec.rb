describe OpenChain::CustomHandler::Vandegrift::MaerskCargowiseEventFileParser do

  let (:log) { InboundFile.new }
  let (:test_data) { IO.read('spec/fixtures/files/maersk_event.xml') }
  let (:xml_document) {
    doc = Nokogiri::XML test_data
    doc.remove_namespaces!
    doc
  }

  before :each do
    allow(subject).to receive(:inbound_file).and_return log
  end

  def parse_datetime date_str
    @zone ||= ActiveSupport::TimeZone["America/New_York"]
    @zone.parse(date_str)
  end

  describe "process_event" do

    let (:country_us) { FactoryBot(:country, iso_code:"US") }

    it "updates an entry, CCC event" do
      # CCC is the default value in the test XML.
      entry = FactoryBot(:entry, broker_reference:"BQMJ00219066158", source_system:Entry::CARGOWISE_SOURCE_SYSTEM, import_country:country_us)
      entry.entry_comments.build(username:"UniversalEvent", body:"2019-05-07 15:10:52 - DDD - DIFFERENTVAL")
      entry.save!

      expect_any_instance_of(described_class::HoldReleaseSetter).to_not receive(:set_summary_hold_date)
      expect_any_instance_of(described_class::HoldReleaseSetter).to_not receive(:set_summary_hold_release_date)

      expect(subject.process_event entry, xml_document).to eq true

      entry.reload
      expect(entry.entry_filed_date).to eq parse_datetime("2019-05-07T15:10:52")
      expect(entry.first_entry_sent_date).to eq parse_datetime("2019-05-07T15:10:52")
      expect(entry.across_sent_date).to eq parse_datetime("2019-05-07T15:10:52")

      expect(log).to have_identifier :event_type, "CCC"

      expect(log).to have_info_message "Event successfully processed."
      expect(log).to_not have_info_message "Cargowise-sourced entry matching Broker Reference 'BQMJ00219066158' was not found, so a new entry was created."

      expect(entry.entry_comments.length).to eq 2
      comm_exist = entry.entry_comments[0]
      expect(comm_exist.body).to eq "2019-05-07 15:10:52 - DDD - DIFFERENTVAL"
      comm = entry.entry_comments[1]
      expect(comm.body).to eq "2019-05-07 15:10:52 - CCC - SOMEVAL"
      expect(comm.username).to eq "UniversalEvent"
      expect(comm.public_comment).to eq false
      expect(comm.generated_at).to eq parse_datetime("2019-05-07T15:10:52")
    end

    it "updates an entry, CCC event, existing dates" do
      # CCC is the default value in the test XML.
      entry = FactoryBot(:entry, broker_reference:"BQMJ00219066158", source_system:Entry::CARGOWISE_SOURCE_SYSTEM,
                      entry_filed_date:Date.new(2019, 1, 1), first_entry_sent_date:Date.new(2019, 1, 1),
                      across_sent_date:Date.new(2019, 1, 1))
      existing_date = entry.first_entry_sent_date

      entry.entry_comments.build(username:"UniversalEvent", body:"2019-05-07 15:10:52 - CCC - SOMEVAL")
      entry.save!

      expect(subject.process_event entry, xml_document).to eq true

      entry.reload
      # Filed date and ACROSS sent date should have been updated, but the first sent date should have stayed the same.
      expect(entry.entry_filed_date).to eq parse_datetime("2019-05-07T15:10:52")
      expect(entry.first_entry_sent_date).to eq existing_date
      expect(entry.across_sent_date).to eq parse_datetime("2019-05-07T15:10:52")

      expect(log).to have_identifier :event_type, "CCC"

      expect(log).to have_info_message "Event successfully processed."

      # No new comment record should have been created.
      expect(entry.entry_comments.length).to eq 1
      comm = entry.entry_comments[0]
      expect(comm.body).to eq "2019-05-07 15:10:52 - CCC - SOMEVAL"
    end

    it "updates an entry, MSC event, SO - PGA FDA desc" do
      test_data.gsub!(/CCC/, 'MSC')
      test_data.gsub!(/SOMEVAL/, "SO-PGA FDA 33")

      entry = FactoryBot(:entry, broker_reference:"BQMJ00219066158", source_system:Entry::CARGOWISE_SOURCE_SYSTEM, import_country:country_us)

      expect_any_instance_of(described_class::HoldReleaseSetter).to receive(:set_summary_hold_date)
      expect_any_instance_of(described_class::HoldReleaseSetter).to receive(:set_summary_hold_release_date)
      expect_any_instance_of(described_class::HoldReleaseSetter).to_not receive(:set_any_hold_date)
      expect_any_instance_of(described_class::HoldReleaseSetter).to_not receive(:set_any_hold_release_date)

      expect(subject.process_event entry, xml_document).to eq true

      entry.reload
      expect(entry.fda_transmit_date).to eq parse_datetime("2019-05-07T15:10:52")

      expect(log).to have_identifier :event_type, "MSC | SO-PGA FDA 33"

      expect(log).to have_info_message "Event successfully processed."

      expect(entry.entry_comments.length).to eq 1
      comm = entry.entry_comments[0]
      expect(comm.body).to eq "2019-05-07 15:10:52 - MSC - SO-PGA FDA 33"
    end

    it "updates an entry, MSC event, SO - PGA FDA desc, existing date" do
      test_data.gsub!(/CCC/, 'MSC')
      test_data.gsub!(/SOMEVAL/, " SO - PGA FDA")

      entry = FactoryBot(:entry, broker_reference:"BQMJ00219066158", source_system:Entry::CARGOWISE_SOURCE_SYSTEM,
                      fda_transmit_date:Date.new(2019, 1, 1), import_country:country_us)
      existing_date = entry.fda_transmit_date

      expect_any_instance_of(described_class::HoldReleaseSetter).to_not receive(:set_summary_hold_date)
      expect_any_instance_of(described_class::HoldReleaseSetter).to_not receive(:set_summary_hold_release_date)
      expect_any_instance_of(described_class::HoldReleaseSetter).to_not receive(:set_any_hold_date)
      expect_any_instance_of(described_class::HoldReleaseSetter).to_not receive(:set_any_hold_release_date)

      expect(subject.process_event entry, xml_document).to eq false

      entry.reload
      expect(entry.fda_transmit_date).to eq existing_date

      expect(log).to have_identifier :event_type, "MSC |  SO - PGA FDA"

      expect(log).to_not have_info_message "Event successfully processed."

      expect(entry.entry_comments.length).to eq 0
    end

    it "updates an entry, MSC event, SO - PGA FDA 01 desc" do
      test_data.gsub!(/CCC/, 'MSC')
      test_data.gsub!(/SOMEVAL/, "SO -  PGA FDA  01")

      entry = FactoryBot(:entry, broker_reference:"BQMJ00219066158", source_system:Entry::CARGOWISE_SOURCE_SYSTEM, import_country:country_us)

      expect_any_instance_of(described_class::HoldReleaseSetter).to receive(:set_summary_hold_date)
      expect_any_instance_of(described_class::HoldReleaseSetter).to receive(:set_summary_hold_release_date)
      expect_any_instance_of(described_class::HoldReleaseSetter).to_not receive(:set_any_hold_date)
      expect_any_instance_of(described_class::HoldReleaseSetter).to_not receive(:set_any_hold_release_date)

      expect(subject.process_event entry, xml_document).to eq true

      entry.reload
      expect(entry.fda_review_date).to eq parse_datetime("2019-05-07T15:10:52")

      expect(log).to have_identifier :event_type, "MSC | SO -  PGA FDA  01"

      expect(log).to have_info_message "Event successfully processed."

      expect(entry.entry_comments.length).to eq 1
      comm = entry.entry_comments[0]
      expect(comm.body).to eq "2019-05-07 15:10:52 - MSC - SO -  PGA FDA  01"
    end

    it "updates an entry, MSC event, SO - PGA FDA 01 desc, existing dates" do
      test_data.gsub!(/CCC/, 'MSC')
      test_data.gsub!(/SOMEVAL/, "SO- PGA  FDA 01")

      entry = FactoryBot(:entry, broker_reference:"BQMJ00219066158", source_system:Entry::CARGOWISE_SOURCE_SYSTEM,
                      fda_transmit_date:Date.new(2019, 1, 1), fda_review_date:Date.new(2019, 1, 1), import_country:country_us)
      existing_date = entry.fda_review_date

      expect_any_instance_of(described_class::HoldReleaseSetter).to receive(:set_summary_hold_date)
      expect_any_instance_of(described_class::HoldReleaseSetter).to receive(:set_summary_hold_release_date)
      expect_any_instance_of(described_class::HoldReleaseSetter).to_not receive(:set_any_hold_date)
      expect_any_instance_of(described_class::HoldReleaseSetter).to_not receive(:set_any_hold_release_date)

      expect(subject.process_event entry, xml_document).to eq false

      entry.reload
      expect(entry.fda_review_date).to eq existing_date
      expect(entry.fda_transmit_date).to eq existing_date

      expect(log).to have_identifier :event_type, "MSC | SO- PGA  FDA 01"

      expect(log).to_not have_info_message "Event successfully processed."

      expect(entry.entry_comments.length).to eq 0
    end

    it "updates an entry, MSC event, SO - PGA FDA 02 desc" do
      test_data.gsub!(/CCC/, 'MSC')
      test_data.gsub!(/SOMEVAL/, "SO- PGA -FDA 02")

      entry = FactoryBot(:entry, broker_reference:"BQMJ00219066158", source_system:Entry::CARGOWISE_SOURCE_SYSTEM, import_country:country_us)

      expect_any_instance_of(described_class::HoldReleaseSetter).to receive(:set_summary_hold_date)
      expect_any_instance_of(described_class::HoldReleaseSetter).to receive(:set_summary_hold_release_date)
      expect_any_instance_of(described_class::HoldReleaseSetter).to receive(:set_any_hold_date).with(parse_datetime("2019-05-07T15:10:52.977"), :fda_hold_date).and_call_original
      expect_any_instance_of(described_class::HoldReleaseSetter).to_not receive(:set_any_hold_release_date)

      expect(subject.process_event entry, xml_document).to eq true

      entry.reload
      expect(entry.fda_hold_date).to eq parse_datetime("2019-05-07T15:10:52")

      expect(log).to have_identifier :event_type, "MSC | SO- PGA -FDA 02"

      expect(log).to have_info_message "Event successfully processed."

      expect(entry.entry_comments.length).to eq 1
      comm = entry.entry_comments[0]
      expect(comm.body).to eq "2019-05-07 15:10:52 - MSC - SO- PGA -FDA 02"
    end

    # Date should be set, but hold release setter should not be called.  That functionality is for the US only.
    it "updates an entry, MSC event, SO - PGA FDA 02 desc, Canada" do
      test_data.gsub!(/CCC/, 'MSC')
      test_data.gsub!(/SOMEVAL/, "SO- PGA -FDA 02")

      country_ca = FactoryBot(:country, iso_code:"CA")
      entry = FactoryBot(:entry, broker_reference:"BQMJ00219066158", source_system:Entry::CARGOWISE_SOURCE_SYSTEM, import_country:country_ca)

      expect_any_instance_of(described_class::HoldReleaseSetter).to_not receive(:set_summary_hold_date)
      expect_any_instance_of(described_class::HoldReleaseSetter).to_not receive(:set_summary_hold_release_date)
      expect_any_instance_of(described_class::HoldReleaseSetter).to_not receive(:set_any_hold_date)
      expect_any_instance_of(described_class::HoldReleaseSetter).to_not receive(:set_any_hold_release_date)

      expect(subject.process_event entry, xml_document).to eq true

      entry.reload
      expect(entry.fda_hold_date).to eq parse_datetime("2019-05-07T15:10:52")

      expect(log).to have_identifier :event_type, "MSC | SO- PGA -FDA 02"

      expect(log).to have_info_message "Event successfully processed."

      expect(entry.entry_comments.length).to eq 1
      comm = entry.entry_comments[0]
      expect(comm.body).to eq "2019-05-07 15:10:52 - MSC - SO- PGA -FDA 02"
    end

    it "updates an entry, MSC event, SO - PGA FDA 02 desc, existing dates" do
      test_data.gsub!(/CCC/, 'MSC')
      test_data.gsub!(/SOMEVAL/, "SO- PGA FDA  02")

      entry = FactoryBot(:entry, broker_reference:"BQMJ00219066158", source_system:Entry::CARGOWISE_SOURCE_SYSTEM,
                      fda_transmit_date:Date.new(2019, 1, 1), fda_hold_date:Date.new(2019, 1, 1), import_country:country_us)
      existing_date = entry.fda_hold_date

      expect_any_instance_of(described_class::HoldReleaseSetter).to receive(:set_summary_hold_date)
      expect_any_instance_of(described_class::HoldReleaseSetter).to receive(:set_summary_hold_release_date)
      expect_any_instance_of(described_class::HoldReleaseSetter).to_not receive(:set_any_hold_date)
      expect_any_instance_of(described_class::HoldReleaseSetter).to_not receive(:set_any_hold_release_date)

      expect(subject.process_event entry, xml_document).to eq false

      entry.reload
      expect(entry.fda_hold_date).to eq existing_date
      expect(entry.fda_transmit_date).to eq existing_date

      expect(log).to have_identifier :event_type, "MSC | SO- PGA FDA  02"

      expect(log).to_not have_info_message "Event successfully processed."

      expect(entry.entry_comments.length).to eq 0
    end

    it "updates an entry, MSC event, SO - PGA FDA 02 desc, existing dates, out-of-sync hold flag" do
      test_data.gsub!(/CCC/, 'MSC')
      test_data.gsub!(/SOMEVAL/, "SO- PGA FDA  02")

      # On hold flag should be true because FDA hold date is set and FDA hold release date is not.
      entry = FactoryBot(:entry, broker_reference:"BQMJ00219066158", source_system:Entry::CARGOWISE_SOURCE_SYSTEM,
                      fda_transmit_date:Date.new(2019, 1, 1), fda_hold_date:Date.new(2019, 1, 1), import_country:country_us,
                      on_hold:false, fda_hold_release_date:nil)
      existing_date = entry.fda_hold_date

      expect_any_instance_of(described_class::HoldReleaseSetter).to receive(:set_summary_hold_date).and_call_original
      expect_any_instance_of(described_class::HoldReleaseSetter).to receive(:set_summary_hold_release_date).and_call_original
      expect_any_instance_of(described_class::HoldReleaseSetter).to_not receive(:set_any_hold_date)
      expect_any_instance_of(described_class::HoldReleaseSetter).to_not receive(:set_any_hold_release_date)

      expect(subject.process_event entry, xml_document).to eq true

      entry.reload
      expect(entry.fda_hold_date).to eq existing_date
      expect(entry.fda_transmit_date).to eq existing_date
      expect(entry.on_hold?).to eq true

      expect(log).to have_identifier :event_type, "MSC | SO- PGA FDA  02"

      expect(log).to have_info_message "Event successfully processed."

      expect(entry.entry_comments.length).to eq 1
      comm = entry.entry_comments[0]
      expect(comm.body).to eq "2019-05-07 15:10:52 - MSC - SO- PGA FDA  02"
    end

    it "updates an entry, MSC event, SO - PGA FDA 07 desc" do
      test_data.gsub!(/CCC/, 'MSC')
      test_data.gsub!(/SOMEVAL/, "SO -PGA - FDA    07")

      entry = FactoryBot(:entry, broker_reference:"BQMJ00219066158", source_system:Entry::CARGOWISE_SOURCE_SYSTEM,
                      fda_release_date:Date.new(2019, 1, 1), fda_hold_release_date:Date.new(2019, 1, 1), fda_hold_date:Date.new(2017, 7, 7), import_country:country_us)

      expect_any_instance_of(described_class::HoldReleaseSetter).to receive(:set_summary_hold_date)
      expect_any_instance_of(described_class::HoldReleaseSetter).to receive(:set_summary_hold_release_date)
      expect_any_instance_of(described_class::HoldReleaseSetter).to_not receive(:set_any_hold_date)
      expect_any_instance_of(described_class::HoldReleaseSetter).to receive(:set_any_hold_release_date).with(parse_datetime("2019-05-07T15:10:52.977"), :fda_hold_release_date).and_call_original

      expect(subject.process_event entry, xml_document).to eq true

      entry.reload
      expect(entry.fda_release_date).to eq parse_datetime("2019-05-07T15:10:52")
      expect(entry.fda_hold_release_date).to eq parse_datetime("2019-05-07T15:10:52")

      expect(log).to have_identifier :event_type, "MSC | SO -PGA - FDA    07"

      expect(log).to have_info_message "Event successfully processed."

      expect(entry.entry_comments.length).to eq 1
      comm = entry.entry_comments[0]
      expect(comm.body).to eq "2019-05-07 15:10:52 - MSC - SO -PGA - FDA    07"
    end

    # Date should be set, but hold release setter should not be called.
    it "updates an entry, MSC event, SO - PGA FDA 07 desc, Canada" do
      test_data.gsub!(/CCC/, 'MSC')
      test_data.gsub!(/SOMEVAL/, "SO -PGA - FDA    07")

      country_ca = FactoryBot(:country, iso_code:"CA")
      entry = FactoryBot(:entry, broker_reference:"BQMJ00219066158", source_system:Entry::CARGOWISE_SOURCE_SYSTEM,
                      fda_release_date:Date.new(2019, 1, 1), fda_hold_release_date:Date.new(2019, 1, 1), fda_hold_date:Date.new(2017, 7, 7), import_country:country_ca)

      expect_any_instance_of(described_class::HoldReleaseSetter).to_not receive(:set_summary_hold_date)
      expect_any_instance_of(described_class::HoldReleaseSetter).to_not receive(:set_summary_hold_release_date)
      expect_any_instance_of(described_class::HoldReleaseSetter).to_not receive(:set_any_hold_date)
      expect_any_instance_of(described_class::HoldReleaseSetter).to_not receive(:set_any_hold_release_date)

      expect(subject.process_event entry, xml_document).to eq true

      entry.reload
      expect(entry.fda_release_date).to eq parse_datetime("2019-05-07T15:10:52")
      expect(entry.fda_hold_release_date).to eq parse_datetime("2019-05-07T15:10:52")

      expect(log).to have_identifier :event_type, "MSC | SO -PGA - FDA    07"

      expect(log).to have_info_message "Event successfully processed."

      expect(entry.entry_comments.length).to eq 1
      comm = entry.entry_comments[0]
      expect(comm.body).to eq "2019-05-07 15:10:52 - MSC - SO -PGA - FDA    07"
    end

    it "updates an entry, MSC event, SO - PGA NHT 02 desc" do
      test_data.gsub!(/CCC/, 'MSC')
      test_data.gsub!(/SOMEVAL/, "SO - PGA - NHT  02")

      entry = FactoryBot(:entry, broker_reference:"BQMJ00219066158", source_system:Entry::CARGOWISE_SOURCE_SYSTEM, import_country:country_us)

      expect_any_instance_of(described_class::HoldReleaseSetter).to receive(:set_summary_hold_date)
      expect_any_instance_of(described_class::HoldReleaseSetter).to receive(:set_summary_hold_release_date)
      expect_any_instance_of(described_class::HoldReleaseSetter).to receive(:set_any_hold_date).with(parse_datetime("2019-05-07T15:10:52.977"), :nhtsa_hold_date).and_call_original
      expect_any_instance_of(described_class::HoldReleaseSetter).to_not receive(:set_any_hold_release_date)

      expect(subject.process_event entry, xml_document).to eq true

      entry.reload
      expect(entry.nhtsa_hold_date).to eq parse_datetime("2019-05-07T15:10:52")

      expect(log).to have_identifier :event_type, "MSC | SO - PGA - NHT  02"

      expect(log).to have_info_message "Event successfully processed."

      expect(entry.entry_comments.length).to eq 1
      comm = entry.entry_comments[0]
      expect(comm.body).to eq "2019-05-07 15:10:52 - MSC - SO - PGA - NHT  02"
    end

    it "updates an entry, MSC event, SO - PGA NHT 02 desc, existing_date" do
      test_data.gsub!(/CCC/, 'MSC')
      test_data.gsub!(/SOMEVAL/, "SO-PGA NHT 02")

      entry = FactoryBot(:entry, broker_reference:"BQMJ00219066158", source_system:Entry::CARGOWISE_SOURCE_SYSTEM,
                      nhtsa_hold_date:Date.new(2019, 1, 1), import_country:country_us)
      existing_date = entry.nhtsa_hold_date

      expect_any_instance_of(described_class::HoldReleaseSetter).to receive(:set_summary_hold_date)
      expect_any_instance_of(described_class::HoldReleaseSetter).to receive(:set_summary_hold_release_date)
      expect_any_instance_of(described_class::HoldReleaseSetter).to_not receive(:set_any_hold_date)
      expect_any_instance_of(described_class::HoldReleaseSetter).to_not receive(:set_any_hold_release_date)

      expect(subject.process_event entry, xml_document).to eq false

      entry.reload
      expect(entry.nhtsa_hold_date).to eq existing_date

      expect(log).to have_identifier :event_type, "MSC | SO-PGA NHT 02"

      expect(log).to_not have_info_message "Event successfully processed."

      expect(entry.entry_comments.length).to eq 0
    end

    it "updates an entry, MSC event, SO - PGA NHT 07 desc" do
      test_data.gsub!(/CCC/, 'MSC')
      test_data.gsub!(/SOMEVAL/, "SO -  PGA NHT 07")

      entry = FactoryBot(:entry, broker_reference:"BQMJ00219066158", source_system:Entry::CARGOWISE_SOURCE_SYSTEM, nhtsa_hold_date:Date.new(2017, 7, 7), import_country:country_us)

      expect_any_instance_of(described_class::HoldReleaseSetter).to receive(:set_summary_hold_date)
      expect_any_instance_of(described_class::HoldReleaseSetter).to receive(:set_summary_hold_release_date)
      expect_any_instance_of(described_class::HoldReleaseSetter).to_not receive(:set_any_hold_date)
      expect_any_instance_of(described_class::HoldReleaseSetter).to receive(:set_any_hold_release_date).with(parse_datetime("2019-05-07T15:10:52.977"), :nhtsa_hold_release_date).and_call_original

      expect(subject.process_event entry, xml_document).to eq true

      entry.reload
      expect(entry.nhtsa_hold_release_date).to eq parse_datetime("2019-05-07T15:10:52")

      expect(log).to have_identifier :event_type, "MSC | SO -  PGA NHT 07"

      expect(log).to have_info_message "Event successfully processed."

      expect(entry.entry_comments.length).to eq 1
      comm = entry.entry_comments[0]
      expect(comm.body).to eq "2019-05-07 15:10:52 - MSC - SO -  PGA NHT 07"
    end

    it "updates an entry, MSC event, SO - PGA NHT 07 desc, existing_date" do
      test_data.gsub!(/CCC/, 'MSC')
      test_data.gsub!(/SOMEVAL/, "SO- PGA NHT 07")

      entry = FactoryBot(:entry, broker_reference:"BQMJ00219066158", source_system:Entry::CARGOWISE_SOURCE_SYSTEM,
                      nhtsa_hold_release_date:Date.new(2019, 1, 1), import_country:country_us)
      existing_date = entry.nhtsa_hold_release_date

      expect_any_instance_of(described_class::HoldReleaseSetter).to receive(:set_summary_hold_date)
      expect_any_instance_of(described_class::HoldReleaseSetter).to receive(:set_summary_hold_release_date)
      expect_any_instance_of(described_class::HoldReleaseSetter).to_not receive(:set_any_hold_date)
      expect_any_instance_of(described_class::HoldReleaseSetter).to_not receive(:set_any_hold_release_date)

      expect(subject.process_event entry, xml_document).to eq false

      entry.reload
      expect(entry.nhtsa_hold_release_date).to eq existing_date

      expect(log).to have_identifier :event_type, "MSC | SO- PGA NHT 07"

      expect(log).to_not have_info_message "Event successfully processed."

      expect(entry.entry_comments.length).to eq 0
    end

    it "updates an entry, MSC event, SO - PGA NMF 02 desc" do
      test_data.gsub!(/CCC/, 'MSC')
      test_data.gsub!(/SOMEVAL/, "SO -  PGA -NMF  02")

      entry = FactoryBot(:entry, broker_reference:"BQMJ00219066158", source_system:Entry::CARGOWISE_SOURCE_SYSTEM, import_country:country_us)

      expect_any_instance_of(described_class::HoldReleaseSetter).to receive(:set_summary_hold_date)
      expect_any_instance_of(described_class::HoldReleaseSetter).to receive(:set_summary_hold_release_date)
      expect_any_instance_of(described_class::HoldReleaseSetter).to receive(:set_any_hold_date).with(parse_datetime("2019-05-07T15:10:52.977"), :nmfs_hold_date).and_call_original
      expect_any_instance_of(described_class::HoldReleaseSetter).to_not receive(:set_any_hold_release_date)

      expect(subject.process_event entry, xml_document).to eq true

      entry.reload
      expect(entry.nmfs_hold_date).to eq parse_datetime("2019-05-07T15:10:52")

      expect(log).to have_identifier :event_type, "MSC | SO -  PGA -NMF  02"

      expect(log).to have_info_message "Event successfully processed."

      expect(entry.entry_comments.length).to eq 1
      comm = entry.entry_comments[0]
      expect(comm.body).to eq "2019-05-07 15:10:52 - MSC - SO -  PGA -NMF  02"
    end

    it "updates an entry, MSC event, SO - PGA NMF 02 desc, existing_date" do
      test_data.gsub!(/CCC/, 'MSC')
      test_data.gsub!(/SOMEVAL/, "SO - PGA   - NMF 02")

      entry = FactoryBot(:entry, broker_reference:"BQMJ00219066158", source_system:Entry::CARGOWISE_SOURCE_SYSTEM,
                      nmfs_hold_date:Date.new(2019, 1, 1), import_country:country_us)
      existing_date = entry.nmfs_hold_date

      expect_any_instance_of(described_class::HoldReleaseSetter).to receive(:set_summary_hold_date)
      expect_any_instance_of(described_class::HoldReleaseSetter).to receive(:set_summary_hold_release_date)
      expect_any_instance_of(described_class::HoldReleaseSetter).to_not receive(:set_any_hold_date)
      expect_any_instance_of(described_class::HoldReleaseSetter).to_not receive(:set_any_hold_release_date)

      expect(subject.process_event entry, xml_document).to eq false

      entry.reload
      expect(entry.nmfs_hold_date).to eq existing_date

      expect(log).to have_identifier :event_type, "MSC | SO - PGA   - NMF 02"

      expect(log).to_not have_info_message "Event successfully processed."

      expect(entry.entry_comments.length).to eq 0
    end

    it "updates an entry, MSC event, SO - PGA NMF 07 desc" do
      test_data.gsub!(/CCC/, 'MSC')
      test_data.gsub!(/SOMEVAL/, "SO-PGA - NMF 07")

      entry = FactoryBot(:entry, broker_reference:"BQMJ00219066158", source_system:Entry::CARGOWISE_SOURCE_SYSTEM, nmfs_hold_date:Date.new(2017, 7, 7), import_country:country_us)

      expect_any_instance_of(described_class::HoldReleaseSetter).to receive(:set_summary_hold_date)
      expect_any_instance_of(described_class::HoldReleaseSetter).to receive(:set_summary_hold_release_date)
      expect_any_instance_of(described_class::HoldReleaseSetter).to_not receive(:set_any_hold_date)
      expect_any_instance_of(described_class::HoldReleaseSetter).to receive(:set_any_hold_release_date).with(parse_datetime("2019-05-07T15:10:52.977"), :nmfs_hold_release_date).and_call_original

      expect(subject.process_event entry, xml_document).to eq true

      entry.reload
      expect(entry.nmfs_hold_release_date).to eq parse_datetime("2019-05-07T15:10:52")

      expect(log).to have_identifier :event_type, "MSC | SO-PGA - NMF 07"

      expect(log).to have_info_message "Event successfully processed."

      expect(entry.entry_comments.length).to eq 1
      comm = entry.entry_comments[0]
      expect(comm.body).to eq "2019-05-07 15:10:52 - MSC - SO-PGA - NMF 07"
    end

    it "updates an entry, MSC event, SO - PGA NMF 07 desc, existing_date" do
      test_data.gsub!(/CCC/, 'MSC')
      test_data.gsub!(/SOMEVAL/, "SO - PGA NMF 07")

      entry = FactoryBot(:entry, broker_reference:"BQMJ00219066158", source_system:Entry::CARGOWISE_SOURCE_SYSTEM,
                      nmfs_hold_release_date:Date.new(2019, 1, 1), import_country:country_us)
      existing_date = entry.nmfs_hold_release_date

      expect_any_instance_of(described_class::HoldReleaseSetter).to receive(:set_summary_hold_date)
      expect_any_instance_of(described_class::HoldReleaseSetter).to receive(:set_summary_hold_release_date)
      expect_any_instance_of(described_class::HoldReleaseSetter).to_not receive(:set_any_hold_date)
      expect_any_instance_of(described_class::HoldReleaseSetter).to_not receive(:set_any_hold_release_date)

      expect(subject.process_event entry, xml_document).to eq false

      entry.reload
      expect(entry.nmfs_hold_release_date).to eq existing_date

      expect(log).to have_identifier :event_type, "MSC | SO - PGA NMF 07"

      expect(log).to_not have_info_message "Event successfully processed."

      expect(entry.entry_comments.length).to eq 0
    end

    it "updates an entry, MSC event, SO - PGA (?) 02 desc" do
      test_data.gsub!(/CCC/, 'MSC')
      test_data.gsub!(/SOMEVAL/, "SO -  PGA - OGA  02")

      entry = FactoryBot(:entry, broker_reference:"BQMJ00219066158", source_system:Entry::CARGOWISE_SOURCE_SYSTEM, import_country:country_us)

      expect_any_instance_of(described_class::HoldReleaseSetter).to receive(:set_summary_hold_date)
      expect_any_instance_of(described_class::HoldReleaseSetter).to receive(:set_summary_hold_release_date)
      expect_any_instance_of(described_class::HoldReleaseSetter).to receive(:set_any_hold_date).with(parse_datetime("2019-05-07T15:10:52.977"), :other_agency_hold_date).and_call_original
      expect_any_instance_of(described_class::HoldReleaseSetter).to_not receive(:set_any_hold_release_date)

      expect(subject.process_event entry, xml_document).to eq true

      entry.reload
      expect(entry.other_agency_hold_date).to eq parse_datetime("2019-05-07T15:10:52")

      expect(log).to have_identifier :event_type, "MSC | SO -  PGA - OGA  02"

      expect(log).to have_info_message "Event successfully processed."

      expect(entry.entry_comments.length).to eq 1
      comm = entry.entry_comments[0]
      expect(comm.body).to eq "2019-05-07 15:10:52 - MSC - SO -  PGA - OGA  02"
    end

    it "updates an entry, MSC event, SO - PGA (?) 02 desc, existing_date" do
      test_data.gsub!(/CCC/, 'MSC')
      test_data.gsub!(/SOMEVAL/, "SO - PGA OGA 02")

      entry = FactoryBot(:entry, broker_reference:"BQMJ00219066158", source_system:Entry::CARGOWISE_SOURCE_SYSTEM,
                      other_agency_hold_date:Date.new(2019, 1, 1), import_country:country_us)
      existing_date = entry.other_agency_hold_date

      expect_any_instance_of(described_class::HoldReleaseSetter).to receive(:set_summary_hold_date)
      expect_any_instance_of(described_class::HoldReleaseSetter).to receive(:set_summary_hold_release_date)
      expect_any_instance_of(described_class::HoldReleaseSetter).to_not receive(:set_any_hold_date)
      expect_any_instance_of(described_class::HoldReleaseSetter).to_not receive(:set_any_hold_release_date)

      expect(subject.process_event entry, xml_document).to eq false

      entry.reload
      expect(entry.other_agency_hold_date).to eq existing_date

      expect(log).to have_identifier :event_type, "MSC | SO - PGA OGA 02"

      expect(log).to_not have_info_message "Event successfully processed."

      expect(entry.entry_comments.length).to eq 0
    end

    it "updates an entry, MSC event, SO - PGA (?) 07 desc" do
      test_data.gsub!(/CCC/, 'MSC')
      test_data.gsub!(/SOMEVAL/, "SO -  PGA - OGA  07")

      entry = FactoryBot(:entry, broker_reference:"BQMJ00219066158", source_system:Entry::CARGOWISE_SOURCE_SYSTEM, other_agency_hold_date:Date.new(2017, 7, 7), import_country:country_us)

      expect_any_instance_of(described_class::HoldReleaseSetter).to receive(:set_summary_hold_date)
      expect_any_instance_of(described_class::HoldReleaseSetter).to receive(:set_summary_hold_release_date)
      expect_any_instance_of(described_class::HoldReleaseSetter).to_not receive(:set_any_hold_date)
      expect_any_instance_of(described_class::HoldReleaseSetter).to receive(:set_any_hold_release_date).with(parse_datetime("2019-05-07T15:10:52.977"), :other_agency_hold_release_date).and_call_original

      expect(subject.process_event entry, xml_document).to eq true

      entry.reload
      expect(entry.other_agency_hold_release_date).to eq parse_datetime("2019-05-07T15:10:52")

      expect(log).to have_identifier :event_type, "MSC | SO -  PGA - OGA  07"

      expect(log).to have_info_message "Event successfully processed."

      expect(entry.entry_comments.length).to eq 1
      comm = entry.entry_comments[0]
      expect(comm.body).to eq "2019-05-07 15:10:52 - MSC - SO -  PGA - OGA  07"
    end

    it "updates an entry, MSC event, SO - PGA (?) 07 desc, existing_date" do
      test_data.gsub!(/CCC/, 'MSC')
      test_data.gsub!(/SOMEVAL/, "SO - PGA - OGA 07")

      entry = FactoryBot(:entry, broker_reference:"BQMJ00219066158", source_system:Entry::CARGOWISE_SOURCE_SYSTEM,
                      other_agency_hold_release_date:Date.new(2019, 1, 1), import_country:country_us)
      existing_date = entry.other_agency_hold_release_date

      expect_any_instance_of(described_class::HoldReleaseSetter).to receive(:set_summary_hold_date)
      expect_any_instance_of(described_class::HoldReleaseSetter).to receive(:set_summary_hold_release_date)
      expect_any_instance_of(described_class::HoldReleaseSetter).to_not receive(:set_any_hold_date)
      expect_any_instance_of(described_class::HoldReleaseSetter).to_not receive(:set_any_hold_release_date)

      expect(subject.process_event entry, xml_document).to eq false

      entry.reload
      expect(entry.other_agency_hold_release_date).to eq existing_date

      expect(log).to have_identifier :event_type, "MSC | SO - PGA - OGA 07"

      expect(log).to_not have_info_message "Event successfully processed."

      expect(entry.entry_comments.length).to eq 0
    end

    it "updates an entry, MSC event, unexpected desc" do
      test_data.gsub!(/CCC/, 'MSC')
      test_data.gsub!(/SOMEVAL/, "SO - RAVEN")

      entry = FactoryBot(:entry, broker_reference:"BQMJ00219066158", source_system:Entry::CARGOWISE_SOURCE_SYSTEM, import_country:country_us)

      expect_any_instance_of(described_class::HoldReleaseSetter).to_not receive(:set_summary_hold_date)
      expect_any_instance_of(described_class::HoldReleaseSetter).to_not receive(:set_summary_hold_release_date)
      expect_any_instance_of(described_class::HoldReleaseSetter).to_not receive(:set_any_hold_date)
      expect_any_instance_of(described_class::HoldReleaseSetter).to_not receive(:set_any_hold_release_date)

      expect(subject.process_event entry, xml_document).to eq false

      entry.reload

      expect(log).to have_identifier :event_type, "MSC | SO - RAVEN"

      expect(log).to_not have_info_message "Event successfully processed."

      expect(entry.entry_comments.length).to eq 0
    end

    it "updates an entry, CLR event" do
      test_data.gsub!(/CCC/, 'CLR')

      entry = FactoryBot(:entry, broker_reference:"BQMJ00219066158", source_system:Entry::CARGOWISE_SOURCE_SYSTEM, import_country:country_us)

      expect_any_instance_of(described_class::HoldReleaseSetter).to_not receive(:set_summary_hold_date)
      expect_any_instance_of(described_class::HoldReleaseSetter).to_not receive(:set_summary_hold_release_date)

      expect(subject.process_event entry, xml_document).to eq true

      entry.reload
      expect(entry.first_release_received_date).to eq parse_datetime("2019-05-07T15:10:52")
      expect(entry.pars_ack_date).to eq parse_datetime("2019-05-07T15:10:52")
      expect(entry.across_declaration_accepted).to eq parse_datetime("2019-05-07T15:10:52")
      expect(entry.first_7501_print).to eq parse_datetime("2019-05-07T15:10:52")

      expect(log).to have_identifier :event_type, "CLR"

      expect(log).to have_info_message "Event successfully processed."

      expect(entry.entry_comments.length).to eq 1
      comm = entry.entry_comments[0]
      expect(comm.body).to eq "2019-05-07 15:10:52 - CLR - SOMEVAL"
    end

    it "updates an entry, CLR event, existing dates (older)" do
      test_data.gsub!(/CCC/, 'CLR')

      # These dates occur prior to the date in the XML.  The XML date should be ignored.
      entry = FactoryBot(:entry, broker_reference:"BQMJ00219066158", source_system:Entry::CARGOWISE_SOURCE_SYSTEM,
                      first_release_received_date:Date.new(2019, 1, 1), pars_ack_date:Date.new(2019, 1, 1),
                      across_declaration_accepted:Date.new(2019, 1, 1), first_7501_print:Date.new(2019, 1, 1))
      existing_date = entry.first_release_received_date
      expect(subject.process_event entry, xml_document).to eq false

      entry.reload
      expect(entry.first_release_received_date).to eq existing_date
      expect(entry.pars_ack_date).to eq existing_date
      expect(entry.across_declaration_accepted).to eq existing_date
      expect(entry.first_7501_print).to eq existing_date

      expect(log).to have_identifier :event_type, "CLR"

      expect(log).to_not have_info_message "Event successfully processed."

      expect(entry.entry_comments.length).to eq 0
    end

    it "updates an entry, CLR event, existing dates (newer)" do
      test_data.gsub!(/CCC/, 'CLR')

      # These dates occur more recently than the date in the XML.  It should replace them.
      entry = FactoryBot(:entry, broker_reference:"BQMJ00219066158", source_system:Entry::CARGOWISE_SOURCE_SYSTEM,
                      first_release_received_date:Date.new(2020, 1, 1), pars_ack_date:Date.new(2020, 1, 1),
                      across_declaration_accepted:Date.new(2020, 1, 1), first_7501_print:Date.new(2020, 1, 1))
      expect(subject.process_event entry, xml_document).to eq true

      entry.reload
      expect(entry.first_release_received_date).to eq parse_datetime("2019-05-07T15:10:52")
      expect(entry.pars_ack_date).to eq parse_datetime("2019-05-07T15:10:52")
      expect(entry.across_declaration_accepted).to eq parse_datetime("2019-05-07T15:10:52")
      expect(entry.first_7501_print).to eq parse_datetime("2019-05-07T15:10:52")

      expect(log).to have_identifier :event_type, "CLR"

      expect(log).to have_info_message "Event successfully processed."

      expect(entry.entry_comments.length).to eq 1
      comm = entry.entry_comments[0]
      expect(comm.body).to eq "2019-05-07 15:10:52 - CLR - SOMEVAL"
    end

    it "updates an entry, DIM event" do
      test_data.gsub!(/CCC/, 'DIM')

      entry = FactoryBot(:entry, broker_reference:"BQMJ00219066158", source_system:Entry::CARGOWISE_SOURCE_SYSTEM,
                      edi_received_date:Date.new(2019, 1, 1))
      expect(subject.process_event entry, xml_document).to eq true

      entry.reload
      expect(entry.edi_received_date).to eq parse_datetime("2019-05-07T15:10:52").to_date

      expect(log).to have_identifier :event_type, "DIM"

      expect(log).to have_info_message "Event successfully processed."

      expect(entry.entry_comments.length).to eq 1
      comm = entry.entry_comments[0]
      expect(comm.body).to eq "2019-05-07 15:10:52 - DIM - SOMEVAL"
    end

    it "updates an entry, JOP event" do
      test_data.gsub!(/CCC/, 'JOP')

      entry = FactoryBot(:entry, broker_reference:"BQMJ00219066158", source_system:Entry::CARGOWISE_SOURCE_SYSTEM,
                      file_logged_date:Date.new(2019, 1, 1))
      expect(subject.process_event entry, xml_document).to eq true

      entry.reload
      expect(entry.file_logged_date).to eq parse_datetime("2019-05-07T15:10:52")

      expect(log).to have_identifier :event_type, "JOP"

      expect(log).to have_info_message "Event successfully processed."

      expect(entry.entry_comments.length).to eq 1
      comm = entry.entry_comments[0]
      expect(comm.body).to eq "2019-05-07 15:10:52 - JOP - SOMEVAL"
    end

    it "updates an entry, DDV event" do
      test_data.gsub!(/CCC/, 'DDV')

      entry = FactoryBot(:entry, broker_reference:"BQMJ00219066158", source_system:Entry::CARGOWISE_SOURCE_SYSTEM,
                      last_7501_print:Date.new(2019, 1, 1))
      expect(subject.process_event entry, xml_document).to eq true

      entry.reload
      expect(entry.last_7501_print).to eq parse_datetime("2019-05-07T15:10:52")
      expect(entry.first_do_issued_date).to be_nil

      expect(log).to have_identifier :event_type, "DDV"

      expect(log).to have_info_message "Event successfully processed."

      expect(entry.entry_comments.length).to eq 1
      comm = entry.entry_comments[0]
      expect(comm.body).to eq "2019-05-07 15:10:52 - DDV - SOMEVAL"
    end

    it "updates an entry, DDV event, Delivery Order desc" do
      test_data.gsub!(/CCC/, 'DDV')
      test_data.gsub!(/SOMEVAL/, "AAA Delivery Order BBB")

      entry = FactoryBot(:entry, broker_reference:"BQMJ00219066158", source_system:Entry::CARGOWISE_SOURCE_SYSTEM,
                      last_7501_print:Date.new(2019, 1, 1))
      expect(subject.process_event entry, xml_document).to eq true

      entry.reload
      expect(entry.last_7501_print).to eq parse_datetime("2019-05-07T15:10:52")
      expect(entry.first_do_issued_date).to eq parse_datetime("2019-05-07T15:10:52")

      expect(log).to have_identifier :event_type, "DDV"

      expect(log).to have_info_message "Event successfully processed."

      expect(entry.entry_comments.length).to eq 1
      comm = entry.entry_comments[0]
      expect(comm.body).to eq "2019-05-07 15:10:52 - DDV - AAA Delivery Order BBB"
    end

    it "updates an entry, CRP event" do
      test_data.gsub!(/CCC/, 'CRP')

      entry = FactoryBot(:entry, broker_reference:"BQMJ00219066158", source_system:Entry::CARGOWISE_SOURCE_SYSTEM,
                      cadex_accept_date:Date.new(2019, 1, 1), k84_receive_date:Date.new(2019, 1, 1),
                      b3_print_date:Date.new(2019, 1, 1))
      expect(subject.process_event entry, xml_document).to eq true

      entry.reload
      expect(entry.cadex_accept_date).to eq parse_datetime("2019-05-07T15:10:52")
      expect(entry.k84_receive_date).to eq parse_datetime("2019-05-07T15:10:52").to_date
      expect(entry.b3_print_date).to eq parse_datetime("2019-05-08T15:10:52").to_date

      expect(log).to have_identifier :event_type, "CRP"

      expect(log).to have_info_message "Event successfully processed."

      expect(entry.entry_comments.length).to eq 1
      comm = entry.entry_comments[0]
      expect(comm.body).to eq "2019-05-07 15:10:52 - CRP - SOMEVAL"
    end

    it "updates an entry, CES event, EXM description" do
      test_data.gsub!(/CCC/, 'CES')
      test_data.gsub!(/SOMEVAL/, "DeusEXMachina")

      entry = FactoryBot(:entry, broker_reference:"BQMJ00219066158", source_system:Entry::CARGOWISE_SOURCE_SYSTEM)
      expect(subject.process_event entry, xml_document).to eq true

      entry.reload
      expect(entry.exam_ordered_date).to eq parse_datetime("2019-05-07T15:10:52")

      expect(log).to have_identifier :event_type, "CES | DeusEXMachina"

      expect(log).to have_info_message "Event successfully processed."

      expect(entry.entry_comments.length).to eq 1
      comm = entry.entry_comments[0]
      expect(comm.body).to eq "2019-05-07 15:10:52 - CES - DeusEXMachina"
    end

    it "updates an entry, CES event, EXM description, existing date" do
      test_data.gsub!(/CCC/, 'CES')
      test_data.gsub!(/SOMEVAL/, "DeusEXMachina")

      entry = FactoryBot(:entry, broker_reference:"BQMJ00219066158", source_system:Entry::CARGOWISE_SOURCE_SYSTEM,
                      exam_ordered_date:Date.new(2019, 1, 1))
      existing_date = entry.exam_ordered_date
      expect(subject.process_event entry, xml_document).to eq false

      entry.reload
      expect(entry.exam_ordered_date).to eq existing_date

      expect(log).to have_identifier :event_type, "CES | DeusEXMachina"

      expect(log).to_not have_info_message "Event successfully processed."

      expect(entry.entry_comments.length).to eq 0
    end

    it "updates an entry, CES event, WTA description" do
      test_data.gsub!(/CCC/, 'CES')
      test_data.gsub!(/SOMEVAL/, "WTA")

      entry = FactoryBot(:entry, broker_reference:"BQMJ00219066158", source_system:Entry::CARGOWISE_SOURCE_SYSTEM)
      expect(subject.process_event entry, xml_document).to eq true

      entry.reload
      expect(entry.pars_ack_date).to eq parse_datetime("2019-05-07T15:10:52")
      expect(entry.across_declaration_accepted).to eq parse_datetime("2019-05-07T15:10:52")

      expect(log).to have_identifier :event_type, "CES | WTA"

      expect(log).to have_info_message "Event successfully processed."

      expect(entry.entry_comments.length).to eq 1
      comm = entry.entry_comments[0]
      expect(comm.body).to eq "2019-05-07 15:10:52 - CES - WTA"
    end

    it "updates an entry, CES event, WTA description, existing date" do
      test_data.gsub!(/CCC/, 'CES')
      test_data.gsub!(/SOMEVAL/, "WTA")

      entry = FactoryBot(:entry, broker_reference:"BQMJ00219066158", source_system:Entry::CARGOWISE_SOURCE_SYSTEM,
                      pars_ack_date:Date.new(2019, 1, 1), across_declaration_accepted:Date.new(2019, 1, 1))
      existing_date = entry.pars_ack_date
      expect(subject.process_event entry, xml_document).to eq false

      entry.reload
      expect(entry.pars_ack_date).to eq existing_date
      expect(entry.across_declaration_accepted).to eq existing_date

      expect(log).to have_identifier :event_type, "CES | WTA"

      expect(log).to_not have_info_message "Event successfully processed."

      expect(entry.entry_comments.length).to eq 0
    end

    it "updates an entry, CES event, unknown desc" do
      test_data.gsub!(/CCC/, 'CES')
      test_data.gsub!(/SOMEVAL/, "AAAAAA")

      entry = FactoryBot(:entry, broker_reference:"BQMJ00219066158", source_system:Entry::CARGOWISE_SOURCE_SYSTEM)
      expect(subject.process_event entry, xml_document).to eq false

      expect(log).to have_identifier :event_type, "CES | AAAAAA"

      expect(log).to_not have_info_message "Event successfully processed."

      expect(entry.entry_comments.length).to eq 0
    end

    it "updates an entry, MRJ event, IID REJECTED description" do
      test_data.gsub!(/CCC/, 'MRJ')
      test_data.gsub!(/SOMEVAL/, "IID REJECTED")

      entry = FactoryBot(:entry, broker_reference:"BQMJ00219066158", source_system:Entry::CARGOWISE_SOURCE_SYSTEM,
                      pars_reject_date:Date.new(2019, 1, 1))
      expect(subject.process_event entry, xml_document).to eq true

      entry.reload
      expect(entry.pars_reject_date).to eq parse_datetime("2019-05-07T15:10:52")

      expect(log).to have_identifier :event_type, "MRJ | IID REJECTED"

      expect(log).to have_info_message "Event successfully processed."

      expect(entry.entry_comments.length).to eq 1
      comm = entry.entry_comments[0]
      expect(comm.body).to eq "2019-05-07 15:10:52 - MRJ - IID REJECTED"
    end

    it "updates an entry, MRJ event, unknown desc" do
      test_data.gsub!(/CCC/, 'MRJ')
      test_data.gsub!(/SOMEVAL/, "AAAAAA")

      entry = FactoryBot(:entry, broker_reference:"BQMJ00219066158", source_system:Entry::CARGOWISE_SOURCE_SYSTEM)
      expect(subject.process_event entry, xml_document).to eq false

      expect(log).to have_identifier :event_type, "MRJ | AAAAAA"

      expect(log).to_not have_info_message "Event successfully processed."

      expect(entry.entry_comments.length).to eq 0
    end

    it "rejects when event type is missing" do
      test_data.gsub!(/EventType/, 'EventTerp')

      entry = FactoryBot(:entry, broker_reference:"BQMJ00219066158", source_system:Entry::CARGOWISE_SOURCE_SYSTEM)

      expect(subject.process_event entry, xml_document).to eq false

      expect(log).to_not have_info_message "Event successfully processed."
      expect(log).to have_reject_message "Event Type is required."
    end

    it "warns when event type is unknown" do
      test_data.gsub!(/CCC/, 'BLEH')

      entry = FactoryBot(:entry, broker_reference:"BQMJ00219066158", source_system:Entry::CARGOWISE_SOURCE_SYSTEM)

      expect(subject.process_event entry, xml_document).to eq false

      expect(log).to_not have_info_message "Event successfully processed."
      expect(log).to have_warning_message "Event Type is not mapped and was ignored: BLEH."
    end

    it "clears date when event time not provided" do
      # CCC is the default value in the test XML.

      test_data.gsub!(/EventTime/, 'EventTim')

      entry = FactoryBot(:entry, broker_reference:"BQMJ00219066158", source_system:Entry::CARGOWISE_SOURCE_SYSTEM,
                      entry_filed_date:Date.new(2019, 1, 1))

      expect(subject.process_event entry, xml_document).to eq true

      entry.reload
      expect(entry.entry_filed_date).to be_nil

      expect(log).to have_info_message "Event successfully processed."

      expect(entry.entry_comments.length).to eq 1
      comm = entry.entry_comments[0]
      expect(comm.body).to eq "(no date) - CCC - SOMEVAL"
      expect(comm.generated_at).to eq nil
    end

    it "skips any DDA event types" do
      # DDA events are sent for Documents (.ie attachments / images)
      test_data.gsub!(/CCC/, 'DDA')

      # Because nothing from the entry should be accessed for DDA events, we can just send nil rather than an actual entry
      expect(subject.process_event nil, xml_document).to eq false

      # The log should still show a DDA event
      expect(log).to have_identifier :event_type, "DDA"
    end
  end

  describe "parse" do

    it "parses xml, creates entry, processes event and processes documents and snapshots" do
      expect(subject).to receive(:process_event).with(instance_of(Entry), instance_of(xml_document.class)).and_return true
      expect(subject).to receive(:process_documents).with(instance_of(Entry), instance_of(xml_document.class)).and_return true

      expect_any_instance_of(Entry).to receive(:create_snapshot).with(User.integration, nil, "file.xml")
      expect_any_instance_of(Entry).to receive(:broadcast_event).with(:save)

      subject.parse xml_document, key: "file.xml"
      entry = Entry.where(broker_reference:"BQMJ00219066158", source_system:Entry::CARGOWISE_SOURCE_SYSTEM).first
      expect(entry).not_to be_nil

      expect(log).to have_info_message("Cargowise-sourced entry matching Broker Reference 'BQMJ00219066158' was not found, so a new entry was created.")
    end

    it "rejects when broker reference is missing" do
      test_data.gsub!(/CustomsDeclaration/, 'CustomDucklaration')
      subject.parse xml_document
      expect(log).to have_reject_message "Broker Reference (Job Number) is required."
      expect(Entry.count).to eq 0
    end

    it "handles UniversalInterchange as root element" do
      test_data.prepend "<UniversalInterchange><Body>"
      test_data << "</Body></UniversalInterchange>"

      expect(subject).to receive(:process_event).with(instance_of(Entry), instance_of(Nokogiri::XML::Element)).and_return true
      expect(subject).to receive(:process_documents).with(instance_of(Entry), instance_of(Nokogiri::XML::Element)).and_return true

      expect_any_instance_of(Entry).to receive(:create_snapshot).with(User.integration, nil, "file.xml")
      expect_any_instance_of(Entry).to receive(:broadcast_event).with(:save)

      entry = FactoryBot(:entry, broker_reference:"BQMJ00219066158", source_system:Entry::CARGOWISE_SOURCE_SYSTEM)
      subject.parse xml_document, key: "file.xml"
    end
  end

  describe "process_documents" do

    let (:test_data) { IO.read ('spec/fixtures/files/maersk_event_document.xml') }
    let! (:entry) { FactoryBot(:entry, broker_reference:"BQMJ00219066158", source_system:Entry::CARGOWISE_SOURCE_SYSTEM) }

    it "extracts document data from event xml" do
      subject.process_documents entry, xml_document

      entry.reload

      expect(entry.attachments.length).to eq 1
      attachment = entry.attachments.first
      # Note the added hyphens and colons changed to - (this ensures the filename is sanitized)
      expect(attachment.attached_file_name).to eq "BQMJ00415005747-16-01-2016 11-10-43 AM.pdf"
      expect(attachment.attached_content_type).to eq "application/pdf"
      expect(attachment.checksum).to eq "7e24c0c2332de06c49e233791c09ac4a80f3f11045ada96c0ed56d1b3a60fb88"
      expect(attachment.is_private).to eq false
      expect(attachment.source_system_timestamp).to eq ActiveSupport::TimeZone["UTC"].parse("2016-01-16T16:12")
      expect(attachment.attachment_type).to eq "7501"

      expect(log).to have_identifier :attachment_name, "BQMJ00415005747-16-01-2016 11-10-43 AM.pdf"
      expect(log).to have_info_message "Attached document BQMJ00415005747-16-01-2016 11-10-43 AM.pdf."
    end

    it "does not add document if entry already contains existing document with same checksum, name, and type" do
      entry.attachments.create! checksum: "7e24c0c2332de06c49e233791c09ac4a80f3f11045ada96c0ed56d1b3a60fb88", attached_file_name: "BQMJ00415005747-16-01-2016 11-10-43 AM.pdf", attachment_type: "7501"

      subject.process_documents entry, xml_document

      entry.reload
      # Just ensure something like is_private is null, since that value will not be set if the document is already attached
      expect(entry.attachments.first.is_private).to be_nil

      expect(log).to have_identifier :attachment_name, "BQMJ00415005747-16-01-2016 11-10-43 AM.pdf"
      expect(log).to have_info_message "Document 'BQMJ00415005747-16-01-2016 11-10-43 AM.pdf' is already attached to this entry."
    end

    it "handles origin documents" do
      # Origin Documents are special cases of documents that are loaded directly into Cargowise by the user.
      # They're essentially all the shipment docs that the user has zipped together into a single file.
      # The data for them comes over a little different than system generated documents in Cargowise (like 7501s, etc)
      test_data.gsub! "DFD-7501-BQMJ00415005747-16/01/2016 11:10:43 AM.pdf", "some-file.pdf"
      test_data.gsub! "<Code>EPR</Code>", "<Code>ORG</Code>"

      subject.process_documents entry, xml_document
      expect(entry.attachments.length).to eq 1
      attachment = entry.attachments.first
      expect(attachment.attached_file_name).to eq "some-file.pdf"
      expect(attachment.attachment_type).to eq "Origin Document Pack"
    end

    context "with replacement document types" do
      let! (:cross_reference) { DataCrossReference.create! cross_reference_type: DataCrossReference::CARGOWISE_SINGLE_DOCUMENT_CODE, key: "7501"}

      it "replaces exising document types for types in the cross reference" do
        entry.attachments.create! checksum: "another document", attached_file_name: "another_file.pdf", attachment_type: "7501"

        subject.process_documents entry, xml_document
        entry.reload
        expect(entry.attachments.length).to eq 1
        attachment = entry.attachments.first
        expect(attachment.attached_file_name).to eq "BQMJ00415005747-16-01-2016 11-10-43 AM.pdf"
      end
    end

    context "without replacement document type" do
      it "adds a second document with the same document type" do
        entry.attachments.create! checksum: "another document", attached_file_name: "another_file.pdf", attachment_type: "INV"

        subject.process_documents entry, xml_document
        entry.reload
        expect(entry.attachments.length).to eq 2
        attachment = entry.attachments.first
        expect(attachment.attached_file_name).to eq "another_file.pdf"

        attachment = entry.attachments.second
        expect(attachment.attached_file_name).to eq "BQMJ00415005747-16-01-2016 11-10-43 AM.pdf"
      end
    end
  end

  describe "document_data" do
    # This is a little weird...the reason I'm testing a private method is because I don't really have any way
    # to verify from the actual entry / attachment data if the data being extracted is actually be transformed
    # from Base64 encoded data correctly...that's why I'm specifically testing the document_data method
    let (:attached_document_element) { xml_document.xpath("/UniversalEvent/Event/AttachedDocumentCollection/AttachedDocument").first }
    let (:test_data) { IO.read ('spec/fixtures/files/maersk_event_document.xml') }

    it "decodes the document data" do
      # The first bit of a PDF file (which is what's embedded in the file) should include the PDF version
      # So just look for that string...if found, it means the Base64 data was decoded properly
      expect(subject.send(:document_data, attached_document_element)).to include "PDF-1.7"
    end

    it "returns nil if image data isn't found" do
      test_data.gsub!("<ImageData>", "<NotImageData>")
      test_data.gsub!("</ImageData>", "</NotImageData>")

      expect(subject.send(:document_data, attached_document_element)).to be_nil
    end
  end

  describe "parse_file" do
    subject { described_class }

    it "processes events and documents" do
      expect_any_instance_of(subject).to receive(:process_event).with(instance_of(Entry), instance_of(Nokogiri::XML::Document)).and_return true
      expect_any_instance_of(subject).to receive(:process_documents).with(instance_of(Entry), instance_of(Nokogiri::XML::Document)).and_return true

      subject.parse_file test_data, log, {key: "s3_path"}

      e = Entry.where(broker_reference: "BQMJ00219066158", source_system: "Cargowise").first
      expect(e).not_to be_nil
      expect(e.entity_snapshots.length).to eq 1
      s = e.entity_snapshots.last
      expect(s.user).to eq User.integration
      expect(s.context).to eq "s3_path"

      expect(log).to have_identifier(:broker_reference, "BQMJ00219066158", e)
    end

    it "finds broker reference from document filename if not found from DataSource" do
      test_data.clear
      test_data << IO.read('spec/fixtures/files/maersk_event_document.xml')
      # Switch the event type to come from Accounting Invoice, this will force the JobNumber to have to be
      # retrieved from the document's file name
      test_data.gsub!("<Type>CustomsDeclaration</Type>", "<Type>AccountingInvoice</Type>")

      expect_any_instance_of(subject).to receive(:process_event).with(instance_of(Entry), instance_of(Nokogiri::XML::Document)).and_return true
      expect_any_instance_of(subject).to receive(:process_documents).with(instance_of(Entry), instance_of(Nokogiri::XML::Document)).and_return true

      subject.parse_file test_data, log, {key: "s3_path"}

      e = Entry.where(broker_reference: "BQMJ00415005747", source_system: "Cargowise").first
      expect(e).not_to be_nil
      expect(e.entity_snapshots.length).to eq 1
      s = e.entity_snapshots.last
      expect(s.user).to eq User.integration
      expect(s.context).to eq "s3_path"

      expect(log).to have_identifier(:broker_reference, "BQMJ00415005747", e)
    end
  end
end