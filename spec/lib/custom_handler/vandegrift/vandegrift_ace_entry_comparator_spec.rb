require 'spec_helper'

describe OpenChain::CustomHandler::Vandegrift::VandegriftAceEntryComparator do

  subject { described_class }
  let(:non_ace_comment) { EntryComment.new body: "Entry Summary queued to send", username: "TESTING", generated_at: "2016-04-09 04:00" }
  let(:ace_comment) { EntryComment.new body: "Ace Certified Entry Summary queued to send", username: "TESTING", generated_at: "2016-04-16 00:00" }
  let(:entry) { Factory(:entry, source_system: "Alliance", broker_reference: "REF", entry_type: "TYPE", fda_transmit_date: "2016-04-17 00:00") }
  let(:snapshot) { entry.create_snapshot user }
  let(:user) {Factory(:user)}

  before :each do
    stub_master_setup_request_host
  end

  describe "compare" do
    
    let (:group) { 
      g = Group.use_system_group("entry_reviewers", name: "Entry Reviewers")
      g.users << user
      g
    }

    context "with non-Ace comment" do

      before :each do
        group
        entry.entry_comments << non_ace_comment
      end

      it "sends an email if non-ace comment is present with no old snapshots" do
        snapshot
        subject.compare nil, nil, nil, nil, nil, snapshot.bucket, snapshot.doc_path, snapshot.version

        expect(ActionMailer::Base.deliveries.length).to eq 1
        m = ActionMailer::Base.deliveries.first
        expect(m.to).to eq [user.email]
        expect(m.subject).to eq "File # REF was transmitted as non-ACE"
        expect(m.body.raw_source).to include "Entry Type: TYPE"
        expect(m.body.raw_source).to include "User: TESTING"
        # Note the timezone adjustment
        expect(m.body.raw_source).to include "Summary Transmit Date: 2016-04-09 00:00"
        expect(m.body.raw_source).to include "FDA Transmit Date: 2016-04-16 20:00"
      end

      it "does not send email if comment made prior to changeover" do
        entry.entry_comments.first.update_attributes! generated_at: "2016-04-09 03:59"
        snapshot

        subject.compare nil, nil, nil, nil, nil, snapshot.bucket, snapshot.doc_path, snapshot.version

        expect(ActionMailer::Base.deliveries.length).to eq 0
      end

      it "does not send email if previous snapshot has non-ace comment in it" do
        snapshot

        # can actually just use the same snapshot here
        subject.compare nil, nil, snapshot.bucket, snapshot.doc_path, snapshot.version, snapshot.bucket, snapshot.doc_path, snapshot.version
        expect(ActionMailer::Base.deliveries.length).to eq 0
      end
    end

    context "with Ace comment" do
      before :each do
        entry.entry_comments << ace_comment
      end

      it "does not send email if snapshot has valid ace comment in it" do
        snapshot
        subject.compare nil, nil, nil, nil, nil, snapshot.bucket, snapshot.doc_path, snapshot.version

        expect(ActionMailer::Base.deliveries.length).to eq 0
      end
    end
  end

  describe "accept" do
    it "accepts kewill snapshots" do
      expect(subject.accept? snapshot).to be_true
    end

    it "doesn't accept non-kewill snapshots" do
      entry.update_attributes! source_system: "Fenix"
      expect(subject.accept? snapshot).to be_false
    end
  end
end