require 'spec_helper'

describe SecurityFiling do
  context "validations" do
    it "should fail on non-unique host_system_file_number for same host_system" do
      SecurityFiling.create!(:host_system=>'ABC',:host_system_file_number=>"DEF")
      should_fail = SecurityFiling.new(:host_system=>'ABC',:host_system_file_number=>"DEF")
      expect(should_fail.save).to be_falsey
      expect(should_fail.errors[:host_system_file_number].size).to eq(1)
    end
    it "should pass on repeated host_system_file_number for diffferent host_systems" do
      SecurityFiling.create!(:host_system=>'ABC',:host_system_file_number=>"DEF")
      expect(SecurityFiling.new(:host_system=>'XYX',:host_system_file_number=>'DEF').save).to be_truthy
    end
    it "should pass on nil host_system_file_number for same host system" do
      SecurityFiling.create!(:host_system=>'ABC')
      expect(SecurityFiling.new(:host_system=>'ABC').save).to be_truthy
    end
  end
  context "security" do
    describe "search secure" do
      before :each do
        @sf = Factory(:security_filing)
        @sf2 = Factory(:security_filing)
        @sf3 = Factory(:security_filing)
      end
      it "should limit importers to their own items" do
        r = SecurityFiling.search_secure(Factory(:importer_user,:company=>@sf.importer),SecurityFiling)
        expect(r.to_a).to eq([@sf])
      end
      it "should show linked importers" do
        @sf.importer.linked_companies << @sf2.importer
        r = SecurityFiling.search_secure(Factory(:importer_user,:company=>@sf.importer),SecurityFiling)
        expect(r.to_a).to eq([@sf,@sf2])
      end
      it "should allow all for master" do
        r = SecurityFiling.search_secure(Factory(:master_user),SecurityFiling)
        expect(r.to_a).to eq([@sf,@sf2,@sf3])
      end
    end
  end
  context "permission" do
    describe "can edit / comment / attach" do
      it "should allow if master company" do
        allow_any_instance_of(User).to receive(:edit_security_filings?).and_return(true)
        allow_any_instance_of(User).to receive(:comment_security_filings?).and_return(true)
        allow_any_instance_of(User).to receive(:attach_security_filings?).and_return(true)
        u = Factory(:master_user)
        sf = Factory(:security_filing)
        expect(sf.can_edit?(u)).to be_truthy
        expect(sf.can_attach?(u)).to be_truthy
        expect(sf.can_comment?(u)).to be_truthy
      end
      it "should not allow if not master company" do
        allow_any_instance_of(User).to receive(:edit_security_filings?).and_return(true)
        allow_any_instance_of(User).to receive(:comment_security_filings?).and_return(true)
        allow_any_instance_of(User).to receive(:attach_security_filings?).and_return(true)
        u = Factory(:importer_user)
        sf = Factory(:security_filing,:importer=>u.company)
        expect(sf.can_edit?(u)).to be_falsey
        expect(sf.can_attach?(u)).to be_falsey
        expect(sf.can_comment?(u)).to be_falsey
      end
    end
    describe "can_view?" do
      context "user permission good" do
        before :each do
          allow_any_instance_of(User).to receive(:view_security_filings?).and_return(true)
        end
        it "should allow if master company" do
          expect(Factory(:security_filing).can_view?(Factory(:master_user))).to be_truthy
        end
        it "should allow if importer = current user" do
          sf = Factory(:security_filing)
          expect(sf.can_view?(Factory(:user,:company=>sf.importer))).to be_truthy
        end
        it "should allow if importer linked to current_user company" do
          u = Factory(:importer_user)
          sf = Factory(:security_filing)
          u.company.linked_companies << sf.importer
          expect(sf.can_view?(u)).to be_truthy
        end
        it "should not allow if not master & importer!=current user" do
          u = Factory(:importer_user)
          sf = Factory(:security_filing)
          expect(sf.can_view?(u)).to be_falsey
        end
      end
      it "should not allow if user cannot view security filings" do
        u = Factory(:master_user)
        allow(u).to receive(:view_security_filings?).and_return(false)
        expect(SecurityFiling.new.can_view?(u)).to be_falsey
      end
    end
  end

  describe "matched?" do
    it "recognizes matched status code" do
      expect(SecurityFiling.new(status_code: "ACCMATCH").matched?).to eq true
    end

    context "with unmatched statuses" do
      ["ACCNOMATCH", "DEL_ACCEPT", "REPLACE", "ACCEPTED", "ACCWARNING", "DELETED", ""].each do |status|
        it "recongizes #{status} as unmatched" do
          expect(SecurityFiling.new(status_code: status).matched?).to eq false
        end
      end
    end
  end
end
