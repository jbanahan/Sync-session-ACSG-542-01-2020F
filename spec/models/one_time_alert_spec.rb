describe OneTimeAlert do
  let(:ent) { create(:entry, broker_reference: "BROKREF_ABC") }
  let(:ota) do
    create(:one_time_alert, user: create(:user, email: "sthubbins@hellhole.co.uk"), email_addresses: "tufnel@stonehenge.biz",
                             email_subject: "alert", email_body: "Watch out!", module_type: "Entry", blind_copy_me: true,
                             search_criterions: [create(:search_criterion, model_field_uid: "ent_gross_weight", value: 5),
                                                           create(:search_criterion, model_field_uid: "ent_vessel", value: "HMS Pinafore")])
  end

  context "permissions" do
    let(:user) { create(:user) }

    describe "can_edit?" do
      it "allows alert's creator" do
        ota.update! user: user
        expect(ota.can_edit?(user)).to eq true
      end

      it "allows admin users" do
        user.admin = true; user.save!
        expect(ota.can_edit?(user)). to eq true
      end

      it "block anyone else" do
        expect(ota.can_edit?(create(:user))).to eq false
      end
    end

    describe "can_view?" do
      it "allows alert's creator" do
        ota.update! user: user
        expect(ota.can_view?(user)).to eq true
      end

      it "allows admin users" do
        user.admin = true; user.save!
        expect(ota.can_view?(user)). to eq true
      end

      it "block anyone else" do
        expect(ota.can_view?(create(:user))).to eq false
      end
    end
  end

  describe "test?" do
    it "returns true if object matches all of the criterions" do
      ent.update! gross_weight: 5, vessel: "HMS Pinafore"
      expect(ota.test?(ent)).to eq true
    end

    it "returns false otherwise" do
      ent.update! gross_weight: 5, vessel: "HMS Bounty"
      expect(ota.test?(ent)).to eq false
    end
  end

  describe "trigger" do
    it "creates a sync_record, sends email, and creates log entry" do
      now = DateTime.new(2018, 3, 15)
      expect(ota).to receive(:send_email).with(ent)
      Timecop.freeze(now) { ota.trigger ent }

      sr = ent.sync_records.first
      expect(sr.trading_partner).to eq "one_time_alert"
      expect(sr.sent_at).to eq now
      expect(sr.confirmed_at).to eq(now + 1.minute)
      expect(sr.fingerprint).to eq ota.id.to_s

      log = ota.log_entries.first
      expect(log.alertable).to eq ent
      expect(log.logged_at).to eq now
      expect(log.reference_fields).to eq "Gross Weight 5, Vessel/Airline HMS Pinafore"
    end
  end

  describe "recipients_and_mailing_lists" do
    let(:ml) { create(:mailing_list, email_addresses: "sthubbins@hellhole.co.uk, smalls@sharksandwich.net")}

    it "returns addresses in mailing list" do
      ota.update(email_addresses: nil, mailing_list: ml)
      expect(ota.recipients_and_mailing_lists).to eq "sthubbins@hellhole.co.uk, smalls@sharksandwich.net"
    end

    it "returns addresses in email_addresses" do
      expect(ota.recipients_and_mailing_lists).to eq "tufnel@stonehenge.biz"
    end

    it "returns addresses from both sources, if present" do
      ota.update(mailing_list: ml)
      expect(ota.recipients_and_mailing_lists).to eq "tufnel@stonehenge.biz, sthubbins@hellhole.co.uk, smalls@sharksandwich.net"
    end
  end

  describe "send_email" do
    before { ent.update! gross_weight: 5, vessel: "HMS Pinafore" }

    it "generates standard email with object argument" do
      ota.send_email ent
      mail = ActionMailer::Base.deliveries.pop
      expect(mail.to).to eq ["tufnel@stonehenge.biz"]
      expect(mail.bcc).to eq ["sthubbins@hellhole.co.uk"]
      expect(mail.subject).to eq "alert"
      expect(mail.body).to include "Entry - Broker Reference BROKREF_ABC: Gross Weight 5, Vessel/Airline HMS Pinafore"
      expect(mail.body).to include "Watch out!"
      expect(mail.body).not_to include "THIS IS A TEST EMAIL ONLY AND NOT A NOTIFICATION"
    end

    it "generates test email with nil argument" do
      ota.send_email nil
      mail = ActionMailer::Base.deliveries.pop
      expect(mail.to).to eq ["tufnel@stonehenge.biz"]
      expect(mail.bcc).to eq ["sthubbins@hellhole.co.uk"]
      expect(mail.subject).to eq "alert"
      expect(mail.body).to include "Entry - Broker Reference <identifier>: Gross Weight 5, Vessel/Airline HMS Pinafore"
      expect(mail.body).to include "Watch out!"
      expect(mail.body).to include "THIS IS A TEST EMAIL ONLY AND NOT A NOTIFICATION"
    end
  end
end
