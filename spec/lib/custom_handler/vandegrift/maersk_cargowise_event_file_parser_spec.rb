describe OpenChain::CustomHandler::Vandegrift::MaerskCargowiseEventFileParser do

  describe "parse" do
    let (:log) { InboundFile.new }
    let (:test_data) { IO.read('spec/fixtures/files/maersk_event.xml') }

    before :each do
      allow(subject).to receive(:inbound_file).and_return log
    end

    def parse_datetime date_str
      @zone ||= ActiveSupport::TimeZone["America/New_York"]
      @zone.parse(date_str)
    end
    
    def make_document xml_str
      doc = Nokogiri::XML xml_str
      doc.remove_namespaces!
      doc
    end

    it "updates an entry, CCC event" do
      # CCC is the default value in the test XML.

      entry = Factory(:entry, broker_reference:"BQMJ00219066158", source_system:Entry::CARGOWISE_SOURCE_SYSTEM)
      entry.entry_comments.build(username:"UniversalEvent", body:"2019-05-07 15:10:52 - DDD - DIFFERENTVAL")
      entry.save!

      expect_any_instance_of(Entry).to receive(:create_snapshot).with(User.integration, nil, "this_key")
      expect_any_instance_of(Entry).to receive(:broadcast_event).with(:save)
      subject.parse make_document(test_data), { :key=>"this_key"}

      entry.reload
      expect(entry.entry_filed_date).to eq parse_datetime("2019-05-07T15:10:52")
      expect(entry.first_entry_sent_date).to eq parse_datetime("2019-05-07T15:10:52")
      expect(entry.across_sent_date).to eq parse_datetime("2019-05-07T15:10:52")

      expect(log).to have_identifier :broker_reference, "BQMJ00219066158", Entry, entry.id
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

      entry = Factory(:entry, broker_reference:"BQMJ00219066158", source_system:Entry::CARGOWISE_SOURCE_SYSTEM,
                      entry_filed_date:Date.new(2019,1,1), first_entry_sent_date:Date.new(2019,1,1),
                      across_sent_date:Date.new(2019,1,1))
      existing_date = entry.first_entry_sent_date

      entry.entry_comments.build(username:"UniversalEvent", body:"2019-05-07 15:10:52 - CCC - SOMEVAL")
      entry.save!

      expect_any_instance_of(Entry).to receive(:create_snapshot).with(User.integration, nil, "this_key")
      expect_any_instance_of(Entry).to receive(:broadcast_event).with(:save)
      subject.parse make_document(test_data), { :key=>"this_key"}

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
      test_data.gsub!(/CCC/,'MSC')
      test_data.gsub!(/SOMEVAL/, "SO-PGA FDA 33")

      entry = Factory(:entry, broker_reference:"BQMJ00219066158", source_system:Entry::CARGOWISE_SOURCE_SYSTEM)

      expect_any_instance_of(Entry).to receive(:create_snapshot).with(User.integration, nil, "this_key")
      expect_any_instance_of(Entry).to receive(:broadcast_event).with(:save)
      subject.parse make_document(test_data), { :key=>"this_key"}

      entry.reload
      expect(entry.fda_transmit_date).to eq parse_datetime("2019-05-07T15:10:52")

      expect(log).to have_identifier :event_type, "MSC | SO-PGA FDA 33"

      expect(log).to have_info_message "Event successfully processed."

      expect(entry.entry_comments.length).to eq 1
      comm = entry.entry_comments[0]
      expect(comm.body).to eq "2019-05-07 15:10:52 - MSC - SO-PGA FDA 33"
    end

    it "updates an entry, MSC event, SO - PGA FDA desc, existing date" do
      test_data.gsub!(/CCC/,'MSC')
      test_data.gsub!(/SOMEVAL/, " SO - PGA FDA")

      entry = Factory(:entry, broker_reference:"BQMJ00219066158", source_system:Entry::CARGOWISE_SOURCE_SYSTEM,
                      fda_transmit_date:Date.new(2019,1,1))
      existing_date = entry.fda_transmit_date

      expect_any_instance_of(Entry).to_not receive(:create_snapshot).with(User.integration, nil, "this_key")
      expect_any_instance_of(Entry).to_not receive(:broadcast_event).with(:save)
      subject.parse make_document(test_data), { :key=>"this_key"}

      entry.reload
      expect(entry.fda_transmit_date).to eq existing_date

      expect(log).to have_identifier :event_type, "MSC |  SO - PGA FDA"

      expect(log).to_not have_info_message "Event successfully processed."
      expect(log).to have_info_message "No changes made."

      expect(entry.entry_comments.length).to eq 0
    end

    it "updates an entry, MSC event, SO - PGA FDA 01 desc" do
      test_data.gsub!(/CCC/,'MSC')
      test_data.gsub!(/SOMEVAL/, "SO -  PGA FDA  01")

      entry = Factory(:entry, broker_reference:"BQMJ00219066158", source_system:Entry::CARGOWISE_SOURCE_SYSTEM)

      expect_any_instance_of(Entry).to receive(:create_snapshot).with(User.integration, nil, "this_key")
      expect_any_instance_of(Entry).to receive(:broadcast_event).with(:save)
      subject.parse make_document(test_data), { :key=>"this_key"}

      entry.reload
      expect(entry.fda_review_date).to eq parse_datetime("2019-05-07T15:10:52")

      expect(log).to have_identifier :event_type, "MSC | SO -  PGA FDA  01"

      expect(log).to have_info_message "Event successfully processed."

      expect(entry.entry_comments.length).to eq 1
      comm = entry.entry_comments[0]
      expect(comm.body).to eq "2019-05-07 15:10:52 - MSC - SO -  PGA FDA  01"
    end

    it "updates an entry, MSC event, SO - PGA FDA 01 desc, existing dates" do
      test_data.gsub!(/CCC/,'MSC')
      test_data.gsub!(/SOMEVAL/, "SO- PGA  FDA 01")

      entry = Factory(:entry, broker_reference:"BQMJ00219066158", source_system:Entry::CARGOWISE_SOURCE_SYSTEM,
                      fda_transmit_date:Date.new(2019,1,1), fda_review_date:Date.new(2019,1,1))
      existing_date = entry.fda_review_date

      expect_any_instance_of(Entry).to_not receive(:create_snapshot).with(User.integration, nil, "this_key")
      expect_any_instance_of(Entry).to_not receive(:broadcast_event).with(:save)
      subject.parse make_document(test_data), { :key=>"this_key"}

      entry.reload
      expect(entry.fda_review_date).to eq existing_date
      expect(entry.fda_transmit_date).to eq existing_date

      expect(log).to have_identifier :event_type, "MSC | SO- PGA  FDA 01"

      expect(log).to_not have_info_message "Event successfully processed."
      expect(log).to have_info_message "No changes made."

      expect(entry.entry_comments.length).to eq 0
    end

    it "updates an entry, MSC event, SO - PGA FDA 02 desc" do
      test_data.gsub!(/CCC/,'MSC')
      test_data.gsub!(/SOMEVAL/, "SO- PGA -FDA 02")

      entry = Factory(:entry, broker_reference:"BQMJ00219066158", source_system:Entry::CARGOWISE_SOURCE_SYSTEM)

      expect_any_instance_of(Entry).to receive(:create_snapshot).with(User.integration, nil, "this_key")
      expect_any_instance_of(Entry).to receive(:broadcast_event).with(:save)
      subject.parse make_document(test_data), { :key=>"this_key"}

      entry.reload
      expect(entry.fda_hold_date).to eq parse_datetime("2019-05-07T15:10:52")

      expect(log).to have_identifier :event_type, "MSC | SO- PGA -FDA 02"

      expect(log).to have_info_message "Event successfully processed."

      expect(entry.entry_comments.length).to eq 1
      comm = entry.entry_comments[0]
      expect(comm.body).to eq "2019-05-07 15:10:52 - MSC - SO- PGA -FDA 02"
    end

    it "updates an entry, MSC event, SO - PGA FDA 02 desc, existing dates" do
      test_data.gsub!(/CCC/,'MSC')
      test_data.gsub!(/SOMEVAL/, "SO- PGA FDA  02")

      entry = Factory(:entry, broker_reference:"BQMJ00219066158", source_system:Entry::CARGOWISE_SOURCE_SYSTEM,
                      fda_transmit_date:Date.new(2019,1,1), fda_hold_date:Date.new(2019,1,1))
      existing_date = entry.fda_hold_date

      expect_any_instance_of(Entry).to_not receive(:create_snapshot).with(User.integration, nil, "this_key")
      expect_any_instance_of(Entry).to_not receive(:broadcast_event).with(:save)
      subject.parse make_document(test_data), { :key=>"this_key"}

      entry.reload
      expect(entry.fda_hold_date).to eq existing_date
      expect(entry.fda_transmit_date).to eq existing_date

      expect(log).to have_identifier :event_type, "MSC | SO- PGA FDA  02"

      expect(log).to_not have_info_message "Event successfully processed."
      expect(log).to have_info_message "No changes made."

      expect(entry.entry_comments.length).to eq 0
    end

    it "updates an entry, MSC event, SO - PGA FDA 07 desc" do
      test_data.gsub!(/CCC/,'MSC')
      test_data.gsub!(/SOMEVAL/, "SO -PGA - FDA    07")

      entry = Factory(:entry, broker_reference:"BQMJ00219066158", source_system:Entry::CARGOWISE_SOURCE_SYSTEM,
                      fda_release_date:Date.new(2019,1,1), fda_hold_release_date:Date.new(2019,1,1))

      expect_any_instance_of(Entry).to receive(:create_snapshot).with(User.integration, nil, "this_key")
      expect_any_instance_of(Entry).to receive(:broadcast_event).with(:save)
      subject.parse make_document(test_data), { :key=>"this_key"}

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
      test_data.gsub!(/CCC/,'MSC')
      test_data.gsub!(/SOMEVAL/, "SO - PGA - NHT  02")

      entry = Factory(:entry, broker_reference:"BQMJ00219066158", source_system:Entry::CARGOWISE_SOURCE_SYSTEM)

      expect_any_instance_of(Entry).to receive(:create_snapshot).with(User.integration, nil, "this_key")
      expect_any_instance_of(Entry).to receive(:broadcast_event).with(:save)
      subject.parse make_document(test_data), { :key=>"this_key"}

      entry.reload
      expect(entry.nhtsa_hold_date).to eq parse_datetime("2019-05-07T15:10:52")

      expect(log).to have_identifier :event_type, "MSC | SO - PGA - NHT  02"

      expect(log).to have_info_message "Event successfully processed."

      expect(entry.entry_comments.length).to eq 1
      comm = entry.entry_comments[0]
      expect(comm.body).to eq "2019-05-07 15:10:52 - MSC - SO - PGA - NHT  02"
    end

    it "updates an entry, MSC event, SO - PGA NHT 02 desc, existing_date" do
      test_data.gsub!(/CCC/,'MSC')
      test_data.gsub!(/SOMEVAL/, "SO-PGA NHT 02")

      entry = Factory(:entry, broker_reference:"BQMJ00219066158", source_system:Entry::CARGOWISE_SOURCE_SYSTEM,
                      nhtsa_hold_date:Date.new(2019,1,1))
      existing_date = entry.nhtsa_hold_date

      expect_any_instance_of(Entry).to_not receive(:create_snapshot).with(User.integration, nil, "this_key")
      expect_any_instance_of(Entry).to_not receive(:broadcast_event).with(:save)
      subject.parse make_document(test_data), { :key=>"this_key"}

      entry.reload
      expect(entry.nhtsa_hold_date).to eq existing_date

      expect(log).to have_identifier :event_type, "MSC | SO-PGA NHT 02"

      expect(log).to_not have_info_message "Event successfully processed."
      expect(log).to have_info_message "No changes made."

      expect(entry.entry_comments.length).to eq 0
    end

    it "updates an entry, MSC event, SO - PGA NHT 07 desc" do
      test_data.gsub!(/CCC/,'MSC')
      test_data.gsub!(/SOMEVAL/, "SO -  PGA NHT 07")

      entry = Factory(:entry, broker_reference:"BQMJ00219066158", source_system:Entry::CARGOWISE_SOURCE_SYSTEM)

      expect_any_instance_of(Entry).to receive(:create_snapshot).with(User.integration, nil, "this_key")
      expect_any_instance_of(Entry).to receive(:broadcast_event).with(:save)
      subject.parse make_document(test_data), { :key=>"this_key"}

      entry.reload
      expect(entry.nhtsa_hold_release_date).to eq parse_datetime("2019-05-07T15:10:52")

      expect(log).to have_identifier :event_type, "MSC | SO -  PGA NHT 07"

      expect(log).to have_info_message "Event successfully processed."

      expect(entry.entry_comments.length).to eq 1
      comm = entry.entry_comments[0]
      expect(comm.body).to eq "2019-05-07 15:10:52 - MSC - SO -  PGA NHT 07"
    end

    it "updates an entry, MSC event, SO - PGA NHT 07 desc, existing_date" do
      test_data.gsub!(/CCC/,'MSC')
      test_data.gsub!(/SOMEVAL/, "SO- PGA NHT 07")

      entry = Factory(:entry, broker_reference:"BQMJ00219066158", source_system:Entry::CARGOWISE_SOURCE_SYSTEM,
                      nhtsa_hold_release_date:Date.new(2019,1,1))
      existing_date = entry.nhtsa_hold_release_date

      expect_any_instance_of(Entry).to_not receive(:create_snapshot).with(User.integration, nil, "this_key")
      expect_any_instance_of(Entry).to_not receive(:broadcast_event).with(:save)
      subject.parse make_document(test_data), { :key=>"this_key"}

      entry.reload
      expect(entry.nhtsa_hold_release_date).to eq existing_date

      expect(log).to have_identifier :event_type, "MSC | SO- PGA NHT 07"

      expect(log).to_not have_info_message "Event successfully processed."
      expect(log).to have_info_message "No changes made."

      expect(entry.entry_comments.length).to eq 0
    end

    it "updates an entry, MSC event, SO - PGA NMF 02 desc" do
      test_data.gsub!(/CCC/,'MSC')
      test_data.gsub!(/SOMEVAL/, "SO -  PGA -NMF  02")

      entry = Factory(:entry, broker_reference:"BQMJ00219066158", source_system:Entry::CARGOWISE_SOURCE_SYSTEM)

      expect_any_instance_of(Entry).to receive(:create_snapshot).with(User.integration, nil, "this_key")
      expect_any_instance_of(Entry).to receive(:broadcast_event).with(:save)
      subject.parse make_document(test_data), { :key=>"this_key"}

      entry.reload
      expect(entry.nmfs_hold_date).to eq parse_datetime("2019-05-07T15:10:52")

      expect(log).to have_identifier :event_type, "MSC | SO -  PGA -NMF  02"

      expect(log).to have_info_message "Event successfully processed."

      expect(entry.entry_comments.length).to eq 1
      comm = entry.entry_comments[0]
      expect(comm.body).to eq "2019-05-07 15:10:52 - MSC - SO -  PGA -NMF  02"
    end

    it "updates an entry, MSC event, SO - PGA NMF 02 desc, existing_date" do
      test_data.gsub!(/CCC/,'MSC')
      test_data.gsub!(/SOMEVAL/, "SO - PGA   - NMF 02")

      entry = Factory(:entry, broker_reference:"BQMJ00219066158", source_system:Entry::CARGOWISE_SOURCE_SYSTEM,
                      nmfs_hold_date:Date.new(2019,1,1))
      existing_date = entry.nmfs_hold_date

      expect_any_instance_of(Entry).to_not receive(:create_snapshot).with(User.integration, nil, "this_key")
      expect_any_instance_of(Entry).to_not receive(:broadcast_event).with(:save)
      subject.parse make_document(test_data), { :key=>"this_key"}

      entry.reload
      expect(entry.nmfs_hold_date).to eq existing_date

      expect(log).to have_identifier :event_type, "MSC | SO - PGA   - NMF 02"

      expect(log).to_not have_info_message "Event successfully processed."
      expect(log).to have_info_message "No changes made."

      expect(entry.entry_comments.length).to eq 0
    end

    it "updates an entry, MSC event, SO - PGA NMF 07 desc" do
      test_data.gsub!(/CCC/,'MSC')
      test_data.gsub!(/SOMEVAL/, "SO-PGA - NMF 07")

      entry = Factory(:entry, broker_reference:"BQMJ00219066158", source_system:Entry::CARGOWISE_SOURCE_SYSTEM)

      expect_any_instance_of(Entry).to receive(:create_snapshot).with(User.integration, nil, "this_key")
      expect_any_instance_of(Entry).to receive(:broadcast_event).with(:save)
      subject.parse make_document(test_data), { :key=>"this_key"}

      entry.reload
      expect(entry.nmfs_hold_release_date).to eq parse_datetime("2019-05-07T15:10:52")

      expect(log).to have_identifier :event_type, "MSC | SO-PGA - NMF 07"

      expect(log).to have_info_message "Event successfully processed."

      expect(entry.entry_comments.length).to eq 1
      comm = entry.entry_comments[0]
      expect(comm.body).to eq "2019-05-07 15:10:52 - MSC - SO-PGA - NMF 07"
    end

    it "updates an entry, MSC event, SO - PGA NMF 07 desc, existing_date" do
      test_data.gsub!(/CCC/,'MSC')
      test_data.gsub!(/SOMEVAL/, "SO - PGA NMF 07")

      entry = Factory(:entry, broker_reference:"BQMJ00219066158", source_system:Entry::CARGOWISE_SOURCE_SYSTEM,
                      nmfs_hold_release_date:Date.new(2019,1,1))
      existing_date = entry.nmfs_hold_release_date

      expect_any_instance_of(Entry).to_not receive(:create_snapshot).with(User.integration, nil, "this_key")
      expect_any_instance_of(Entry).to_not receive(:broadcast_event).with(:save)
      subject.parse make_document(test_data), { :key=>"this_key"}

      entry.reload
      expect(entry.nmfs_hold_release_date).to eq existing_date

      expect(log).to have_identifier :event_type, "MSC | SO - PGA NMF 07"

      expect(log).to_not have_info_message "Event successfully processed."
      expect(log).to have_info_message "No changes made."

      expect(entry.entry_comments.length).to eq 0
    end

    it "updates an entry, MSC event, SO - PGA (?) 02 desc" do
      test_data.gsub!(/CCC/,'MSC')
      test_data.gsub!(/SOMEVAL/, "SO -  PGA - OGA  02")

      entry = Factory(:entry, broker_reference:"BQMJ00219066158", source_system:Entry::CARGOWISE_SOURCE_SYSTEM)

      expect_any_instance_of(Entry).to receive(:create_snapshot).with(User.integration, nil, "this_key")
      expect_any_instance_of(Entry).to receive(:broadcast_event).with(:save)
      subject.parse make_document(test_data), { :key=>"this_key"}

      entry.reload
      expect(entry.other_agency_hold_date).to eq parse_datetime("2019-05-07T15:10:52")

      expect(log).to have_identifier :event_type, "MSC | SO -  PGA - OGA  02"

      expect(log).to have_info_message "Event successfully processed."

      expect(entry.entry_comments.length).to eq 1
      comm = entry.entry_comments[0]
      expect(comm.body).to eq "2019-05-07 15:10:52 - MSC - SO -  PGA - OGA  02"
    end

    it "updates an entry, MSC event, SO - PGA (?) 02 desc, existing_date" do
      test_data.gsub!(/CCC/,'MSC')
      test_data.gsub!(/SOMEVAL/, "SO - PGA OGA 02")

      entry = Factory(:entry, broker_reference:"BQMJ00219066158", source_system:Entry::CARGOWISE_SOURCE_SYSTEM,
                      other_agency_hold_date:Date.new(2019,1,1))
      existing_date = entry.other_agency_hold_date

      expect_any_instance_of(Entry).to_not receive(:create_snapshot).with(User.integration, nil, "this_key")
      expect_any_instance_of(Entry).to_not receive(:broadcast_event).with(:save)
      subject.parse make_document(test_data), { :key=>"this_key"}

      entry.reload
      expect(entry.other_agency_hold_date).to eq existing_date

      expect(log).to have_identifier :event_type, "MSC | SO - PGA OGA 02"

      expect(log).to_not have_info_message "Event successfully processed."
      expect(log).to have_info_message "No changes made."

      expect(entry.entry_comments.length).to eq 0
    end

    it "updates an entry, MSC event, SO - PGA (?) 07 desc" do
      test_data.gsub!(/CCC/,'MSC')
      test_data.gsub!(/SOMEVAL/, "SO -  PGA - OGA  07")

      entry = Factory(:entry, broker_reference:"BQMJ00219066158", source_system:Entry::CARGOWISE_SOURCE_SYSTEM)

      expect_any_instance_of(Entry).to receive(:create_snapshot).with(User.integration, nil, "this_key")
      expect_any_instance_of(Entry).to receive(:broadcast_event).with(:save)
      subject.parse make_document(test_data), { :key=>"this_key"}

      entry.reload
      expect(entry.other_agency_hold_release_date).to eq parse_datetime("2019-05-07T15:10:52")

      expect(log).to have_identifier :event_type, "MSC | SO -  PGA - OGA  07"

      expect(log).to have_info_message "Event successfully processed."

      expect(entry.entry_comments.length).to eq 1
      comm = entry.entry_comments[0]
      expect(comm.body).to eq "2019-05-07 15:10:52 - MSC - SO -  PGA - OGA  07"
    end

    it "updates an entry, MSC event, SO - PGA (?) 07 desc, existing_date" do
      test_data.gsub!(/CCC/,'MSC')
      test_data.gsub!(/SOMEVAL/, "SO - PGA - OGA 07")

      entry = Factory(:entry, broker_reference:"BQMJ00219066158", source_system:Entry::CARGOWISE_SOURCE_SYSTEM,
                      other_agency_hold_release_date:Date.new(2019,1,1))
      existing_date = entry.other_agency_hold_release_date

      expect_any_instance_of(Entry).to_not receive(:create_snapshot).with(User.integration, nil, "this_key")
      expect_any_instance_of(Entry).to_not receive(:broadcast_event).with(:save)
      subject.parse make_document(test_data), { :key=>"this_key"}

      entry.reload
      expect(entry.other_agency_hold_release_date).to eq existing_date

      expect(log).to have_identifier :event_type, "MSC | SO - PGA - OGA 07"

      expect(log).to_not have_info_message "Event successfully processed."
      expect(log).to have_info_message "No changes made."

      expect(entry.entry_comments.length).to eq 0
    end

    it "updates an entry, MSC event, unexpected desc" do
      test_data.gsub!(/CCC/,'MSC')
      test_data.gsub!(/SOMEVAL/, "SO - RAVEN")

      entry = Factory(:entry, broker_reference:"BQMJ00219066158", source_system:Entry::CARGOWISE_SOURCE_SYSTEM)

      expect_any_instance_of(Entry).to_not receive(:create_snapshot).with(User.integration, nil, "this_key")
      expect_any_instance_of(Entry).to_not receive(:broadcast_event).with(:save)
      subject.parse make_document(test_data), { :key=>"this_key"}

      entry.reload

      expect(log).to have_identifier :event_type, "MSC | SO - RAVEN"

      expect(log).to_not have_info_message "Event successfully processed."
      expect(log).to have_info_message "No changes made."

      expect(entry.entry_comments.length).to eq 0
    end

    it "updates an entry, CLR event" do
      test_data.gsub!(/CCC/,'CLR')

      entry = Factory(:entry, broker_reference:"BQMJ00219066158", source_system:Entry::CARGOWISE_SOURCE_SYSTEM)

      expect_any_instance_of(Entry).to receive(:create_snapshot).with(User.integration, nil, "this_key")
      expect_any_instance_of(Entry).to receive(:broadcast_event).with(:save)
      subject.parse make_document(test_data), { :key=>"this_key"}

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
      test_data.gsub!(/CCC/,'CLR')

      # These dates occur prior to the date in the XML.  The XML date should be ignored.
      entry = Factory(:entry, broker_reference:"BQMJ00219066158", source_system:Entry::CARGOWISE_SOURCE_SYSTEM,
                      first_release_received_date:Date.new(2019,1,1), pars_ack_date:Date.new(2019,1,1),
                      across_declaration_accepted:Date.new(2019,1,1), first_7501_print:Date.new(2019,1,1))
      existing_date = entry.first_release_received_date

      expect_any_instance_of(Entry).to_not receive(:create_snapshot).with(User.integration, nil, "this_key")
      expect_any_instance_of(Entry).to_not receive(:broadcast_event).with(:save)
      subject.parse make_document(test_data), { :key=>"this_key"}

      entry.reload
      expect(entry.first_release_received_date).to eq existing_date
      expect(entry.pars_ack_date).to eq existing_date
      expect(entry.across_declaration_accepted).to eq existing_date
      expect(entry.first_7501_print).to eq existing_date

      expect(log).to have_identifier :event_type, "CLR"

      expect(log).to_not have_info_message "Event successfully processed."
      expect(log).to have_info_message "No changes made."

      expect(entry.entry_comments.length).to eq 0
    end

    it "updates an entry, CLR event, existing dates (newer)" do
      test_data.gsub!(/CCC/,'CLR')

      # These dates occur more recently than the date in the XML.  It should replace them.
      entry = Factory(:entry, broker_reference:"BQMJ00219066158", source_system:Entry::CARGOWISE_SOURCE_SYSTEM,
                      first_release_received_date:Date.new(2020,1,1), pars_ack_date:Date.new(2020,1,1),
                      across_declaration_accepted:Date.new(2020,1,1), first_7501_print:Date.new(2020,1,1))

      expect_any_instance_of(Entry).to receive(:create_snapshot).with(User.integration, nil, "this_key")
      expect_any_instance_of(Entry).to receive(:broadcast_event).with(:save)
      subject.parse make_document(test_data), { :key=>"this_key"}

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
      test_data.gsub!(/CCC/,'DIM')

      entry = Factory(:entry, broker_reference:"BQMJ00219066158", source_system:Entry::CARGOWISE_SOURCE_SYSTEM,
                      edi_received_date:Date.new(2019,1,1))

      expect_any_instance_of(Entry).to receive(:create_snapshot).with(User.integration, nil, "this_key")
      expect_any_instance_of(Entry).to receive(:broadcast_event).with(:save)
      subject.parse make_document(test_data), { :key=>"this_key"}

      entry.reload
      expect(entry.edi_received_date).to eq parse_datetime("2019-05-07T15:10:52").to_date

      expect(log).to have_identifier :event_type, "DIM"

      expect(log).to have_info_message "Event successfully processed."

      expect(entry.entry_comments.length).to eq 1
      comm = entry.entry_comments[0]
      expect(comm.body).to eq "2019-05-07 15:10:52 - DIM - SOMEVAL"
    end

    it "updates an entry, JOP event" do
      test_data.gsub!(/CCC/,'JOP')

      entry = Factory(:entry, broker_reference:"BQMJ00219066158", source_system:Entry::CARGOWISE_SOURCE_SYSTEM,
                      file_logged_date:Date.new(2019,1,1))

      expect_any_instance_of(Entry).to receive(:create_snapshot).with(User.integration, nil, "this_key")
      expect_any_instance_of(Entry).to receive(:broadcast_event).with(:save)
      subject.parse make_document(test_data), { :key=>"this_key"}

      entry.reload
      expect(entry.file_logged_date).to eq parse_datetime("2019-05-07T15:10:52")

      expect(log).to have_identifier :event_type, "JOP"

      expect(log).to have_info_message "Event successfully processed."

      expect(entry.entry_comments.length).to eq 1
      comm = entry.entry_comments[0]
      expect(comm.body).to eq "2019-05-07 15:10:52 - JOP - SOMEVAL"
    end

    it "updates an entry, DDV event" do
      test_data.gsub!(/CCC/,'DDV')

      entry = Factory(:entry, broker_reference:"BQMJ00219066158", source_system:Entry::CARGOWISE_SOURCE_SYSTEM,
                      last_7501_print:Date.new(2019,1,1))

      expect_any_instance_of(Entry).to receive(:create_snapshot).with(User.integration, nil, "this_key")
      expect_any_instance_of(Entry).to receive(:broadcast_event).with(:save)
      subject.parse make_document(test_data), { :key=>"this_key"}

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
      test_data.gsub!(/CCC/,'DDV')
      test_data.gsub!(/SOMEVAL/, "AAA Delivery Order BBB")

      entry = Factory(:entry, broker_reference:"BQMJ00219066158", source_system:Entry::CARGOWISE_SOURCE_SYSTEM,
                      last_7501_print:Date.new(2019,1,1))

      expect_any_instance_of(Entry).to receive(:create_snapshot).with(User.integration, nil, "this_key")
      expect_any_instance_of(Entry).to receive(:broadcast_event).with(:save)
      subject.parse make_document(test_data), { :key=>"this_key"}

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
      test_data.gsub!(/CCC/,'CRP')

      entry = Factory(:entry, broker_reference:"BQMJ00219066158", source_system:Entry::CARGOWISE_SOURCE_SYSTEM,
                      cadex_accept_date:Date.new(2019,1,1), k84_receive_date:Date.new(2019,1,1),
                      b3_print_date:Date.new(2019,1,1))

      expect_any_instance_of(Entry).to receive(:create_snapshot).with(User.integration, nil, "this_key")
      expect_any_instance_of(Entry).to receive(:broadcast_event).with(:save)
      subject.parse make_document(test_data), { :key=>"this_key"}

      entry.reload
      expect(entry.cadex_accept_date).to eq parse_datetime("2019-05-07T15:10:52")
      expect(entry.k84_receive_date).to eq parse_datetime("2019-05-08T15:10:52").to_date
      expect(entry.b3_print_date).to eq parse_datetime("2019-05-08T15:10:52").to_date

      expect(log).to have_identifier :event_type, "CRP"

      expect(log).to have_info_message "Event successfully processed."

      expect(entry.entry_comments.length).to eq 1
      comm = entry.entry_comments[0]
      expect(comm.body).to eq "2019-05-07 15:10:52 - CRP - SOMEVAL"
    end

    it "updates an entry, CES event, EXM description" do
      test_data.gsub!(/CCC/,'CES')
      test_data.gsub!(/SOMEVAL/, "DeusEXMachina")

      entry = Factory(:entry, broker_reference:"BQMJ00219066158", source_system:Entry::CARGOWISE_SOURCE_SYSTEM)

      expect_any_instance_of(Entry).to receive(:create_snapshot).with(User.integration, nil, "this_key")
      expect_any_instance_of(Entry).to receive(:broadcast_event).with(:save)
      subject.parse make_document(test_data), { :key=>"this_key"}

      entry.reload
      expect(entry.exam_ordered_date).to eq parse_datetime("2019-05-07T15:10:52")

      expect(log).to have_identifier :event_type, "CES | DeusEXMachina"

      expect(log).to have_info_message "Event successfully processed."

      expect(entry.entry_comments.length).to eq 1
      comm = entry.entry_comments[0]
      expect(comm.body).to eq "2019-05-07 15:10:52 - CES - DeusEXMachina"
    end

    it "updates an entry, CES event, EXM description, existing date" do
      test_data.gsub!(/CCC/,'CES')
      test_data.gsub!(/SOMEVAL/, "DeusEXMachina")

      entry = Factory(:entry, broker_reference:"BQMJ00219066158", source_system:Entry::CARGOWISE_SOURCE_SYSTEM,
                      exam_ordered_date:Date.new(2019,1,1))
      existing_date = entry.exam_ordered_date

      expect_any_instance_of(Entry).to_not receive(:create_snapshot).with(User.integration, nil, "this_key")
      expect_any_instance_of(Entry).to_not receive(:broadcast_event).with(:save)
      subject.parse make_document(test_data), { :key=>"this_key"}

      entry.reload
      expect(entry.exam_ordered_date).to eq existing_date

      expect(log).to have_identifier :event_type, "CES | DeusEXMachina"

      expect(log).to_not have_info_message "Event successfully processed."
      expect(log).to have_info_message "No changes made."

      expect(entry.entry_comments.length).to eq 0
    end

    it "updates an entry, CES event, WTA description" do
      test_data.gsub!(/CCC/,'CES')
      test_data.gsub!(/SOMEVAL/, "WTA")

      entry = Factory(:entry, broker_reference:"BQMJ00219066158", source_system:Entry::CARGOWISE_SOURCE_SYSTEM)

      expect_any_instance_of(Entry).to receive(:create_snapshot).with(User.integration, nil, "this_key")
      expect_any_instance_of(Entry).to receive(:broadcast_event).with(:save)
      subject.parse make_document(test_data), { :key=>"this_key"}

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
      test_data.gsub!(/CCC/,'CES')
      test_data.gsub!(/SOMEVAL/, "WTA")

      entry = Factory(:entry, broker_reference:"BQMJ00219066158", source_system:Entry::CARGOWISE_SOURCE_SYSTEM,
                      pars_ack_date:Date.new(2019,1,1), across_declaration_accepted:Date.new(2019,1,1))
      existing_date = entry.pars_ack_date

      expect_any_instance_of(Entry).to_not receive(:create_snapshot).with(User.integration, nil, "this_key")
      expect_any_instance_of(Entry).to_not receive(:broadcast_event).with(:save)
      subject.parse make_document(test_data), { :key=>"this_key"}

      entry.reload
      expect(entry.pars_ack_date).to eq existing_date
      expect(entry.across_declaration_accepted).to eq existing_date

      expect(log).to have_identifier :event_type, "CES | WTA"

      expect(log).to_not have_info_message "Event successfully processed."
      expect(log).to have_info_message "No changes made."

      expect(entry.entry_comments.length).to eq 0
    end

    it "updates an entry, CES event, unknown desc" do
      test_data.gsub!(/CCC/,'CES')
      test_data.gsub!(/SOMEVAL/, "AAAAAA")

      entry = Factory(:entry, broker_reference:"BQMJ00219066158", source_system:Entry::CARGOWISE_SOURCE_SYSTEM)

      expect_any_instance_of(Entry).to_not receive(:create_snapshot).with(User.integration, nil, "this_key")
      expect_any_instance_of(Entry).to_not receive(:broadcast_event).with(:save)
      subject.parse make_document(test_data), { :key=>"this_key"}

      expect(log).to have_identifier :event_type, "CES | AAAAAA"

      expect(log).to_not have_info_message "Event successfully processed."
      expect(log).to have_info_message "No changes made."

      expect(entry.entry_comments.length).to eq 0
    end

    it "updates an entry, MRJ event, IID REJECTED description" do
      test_data.gsub!(/CCC/,'MRJ')
      test_data.gsub!(/SOMEVAL/, "IID REJECTED")

      entry = Factory(:entry, broker_reference:"BQMJ00219066158", source_system:Entry::CARGOWISE_SOURCE_SYSTEM,
                      pars_reject_date:Date.new(2019,1,1))

      expect_any_instance_of(Entry).to receive(:create_snapshot).with(User.integration, nil, "this_key")
      expect_any_instance_of(Entry).to receive(:broadcast_event).with(:save)
      subject.parse make_document(test_data), { :key=>"this_key"}

      entry.reload
      expect(entry.pars_reject_date).to eq parse_datetime("2019-05-07T15:10:52")

      expect(log).to have_identifier :event_type, "MRJ | IID REJECTED"

      expect(log).to have_info_message "Event successfully processed."

      expect(entry.entry_comments.length).to eq 1
      comm = entry.entry_comments[0]
      expect(comm.body).to eq "2019-05-07 15:10:52 - MRJ - IID REJECTED"
    end

    it "updates an entry, MRJ event, unknown desc" do
      test_data.gsub!(/CCC/,'MRJ')
      test_data.gsub!(/SOMEVAL/, "AAAAAA")

      entry = Factory(:entry, broker_reference:"BQMJ00219066158", source_system:Entry::CARGOWISE_SOURCE_SYSTEM)

      expect_any_instance_of(Entry).to_not receive(:create_snapshot).with(User.integration, nil, "this_key")
      expect_any_instance_of(Entry).to_not receive(:broadcast_event).with(:save)
      subject.parse make_document(test_data), { :key=>"this_key"}

      expect(log).to have_identifier :event_type, "MRJ | AAAAAA"

      expect(log).to_not have_info_message "Event successfully processed."
      expect(log).to have_info_message "No changes made."

      expect(entry.entry_comments.length).to eq 0
    end

    it "creates new entry when entry not found" do
      expect_any_instance_of(Entry).to receive(:create_snapshot).with(User.integration, nil, "this_key")
      expect_any_instance_of(Entry).to receive(:broadcast_event).with(:save)
      subject.parse make_document(test_data), { :key=>"this_key"}

      expect(Entry.where(broker_reference:"BQMJ00219066158", source_system:Entry::CARGOWISE_SOURCE_SYSTEM).first).to_not be_nil

      expect(log).to have_info_message "Cargowise-sourced entry matching Broker Reference 'BQMJ00219066158' was not found, so a new entry was created."
      expect(log).to have_info_message "Event successfully processed."
    end

    it "rejects when broker reference is missing" do
      test_data.gsub!(/CustomsDeclaration/,'CustomDucklaration')

      expect_any_instance_of(Entry).to_not receive(:create_snapshot)
      expect_any_instance_of(Entry).to_not receive(:broadcast_event)
      subject.parse make_document(test_data)

      expect(log).to_not have_info_message "Event successfully processed."
      expect(log).to have_reject_message "Broker Reference (Job Number) is required."
    end

    it "rejects when event type is missing" do
      test_data.gsub!(/EventType/,'EventTerp')

      entry = Factory(:entry, broker_reference:"BQMJ00219066158", source_system:Entry::CARGOWISE_SOURCE_SYSTEM)

      subject.parse make_document(test_data)

      expect(log).to_not have_info_message "Event successfully processed."
      expect(log).to have_reject_message "Event Type is required."
    end

    it "warns when event type is unknown" do
      test_data.gsub!(/CCC/,'BLEH')

      entry = Factory(:entry, broker_reference:"BQMJ00219066158", source_system:Entry::CARGOWISE_SOURCE_SYSTEM)

      subject.parse make_document(test_data)

      expect(log).to_not have_info_message "Event successfully processed."
      expect(log).to have_warning_message "Event Type is not mapped and was ignored: BLEH."
    end

    it "clears date when event time not provided" do
      # CCC is the default value in the test XML.

      test_data.gsub!(/EventTime/,'EventTim')

      entry = Factory(:entry, broker_reference:"BQMJ00219066158", source_system:Entry::CARGOWISE_SOURCE_SYSTEM,
                      entry_filed_date:Date.new(2019,1,1))

      subject.parse make_document(test_data)

      entry.reload
      expect(entry.entry_filed_date).to be_nil

      expect(log).to have_info_message "Event successfully processed."

      expect(entry.entry_comments.length).to eq 1
      comm = entry.entry_comments[0]
      expect(comm.body).to eq "(no date) - CCC - SOMEVAL"
      expect(comm.generated_at).to eq nil
    end

    it "handles UniversalInterchange as root element" do
      entry = Factory(:entry, broker_reference:"BQMJ00219066158", source_system:Entry::CARGOWISE_SOURCE_SYSTEM)

      expect_any_instance_of(Entry).to receive(:create_snapshot).with(User.integration, nil, "this_key")
      expect_any_instance_of(Entry).to receive(:broadcast_event).with(:save)
      subject.parse make_document("<UniversalInterchange><Body>#{test_data}</Body></UniversalInterchange>"), { :key=>"this_key"}

      entry.reload
      expect(entry.entry_filed_date).to eq parse_datetime("2019-05-07T15:10:52")

      expect(log).to have_info_message "Event successfully processed."
    end
  end

end