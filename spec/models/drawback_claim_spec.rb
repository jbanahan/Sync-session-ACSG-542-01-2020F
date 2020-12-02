describe DrawbackClaim do
  context "callbacks" do
    before :each do
      @imp = create(:company, :importer=>true)
    end
    it "should set total claim amount" do
      expect(DrawbackClaim.
        create!(:importer=>@imp, :name=>'x', :hmf_claimed=>1, :duty_claimed=>2, :mpf_claimed=>3, :bill_amount=>1).
        total_claim_amount).to eq(6)
    end
    it "should set net claim amount" do
      expect(DrawbackClaim.
        create!(:importer=>@imp, :name=>'y', :hmf_claimed=>1, :duty_claimed=>2, :mpf_claimed=>3, :bill_amount=>1).
        net_claim_amount).to eq(5)
    end
    it "should set claim totals when bill_amount is nil" do
      d = DrawbackClaim.create!(:importer=>@imp, :name=>'y', :hmf_claimed=>1, :duty_claimed=>2, :mpf_claimed=>3)
      expect(d.total_claim_amount).to eq(6)
      expect(d.net_claim_amount).to eq(6)
    end
    it "should set claim totals when hmf is nil" do
      d = DrawbackClaim.create!(:importer=>@imp, :name=>'y', :bill_amount=>1, :duty_claimed=>2, :mpf_claimed=>3)
      expect(d.total_claim_amount).to eq(5)
      expect(d.net_claim_amount).to eq(4)
    end
  end
  context "validations" do
    it "should require importer_id" do
      d = DrawbackClaim.new(:name=>'x')
      expect(d.save).to be_falsey
      expect(d.errors[:importer_id].size).to eq(1)
    end
    it "should require name" do
      d = DrawbackClaim.new(:importer_id=>create(:company, :drawback=>true).id)
      expect(d.save).to be_falsey
      expect(d.errors[:name].size).to eq(1)
    end
  end
  describe "can_attach?" do
    before :each do
      @dbc = create(:drawback_claim)
      @u = create(:user)
    end
    it "should be true if can_edit? is true" do
      allow_any_instance_of(DrawbackClaim).to receive(:can_edit?).and_return true
      expect(@dbc.can_attach?(@u)).to eq(true)
    end
    it "should be false if can_edit? is false" do
      allow_any_instance_of(DrawbackClaim).to receive(:can_edit?).and_return false
      expect(@dbc.can_attach?(@u)).to eq(false)
    end
  end
  describe "percent_pieces_claimed" do
    it "should calculate claim percentage by export pieces" do
      expect(DrawbackClaim.new(:total_pieces_exported=>9, :total_pieces_claimed=>3).percent_pieces_claimed).to eq(0.333)
    end
    it "should return 0 if exported pieces is nil" do
      expect(DrawbackClaim.new(:total_pieces_exported=>nil, :total_pieces_claimed=>3).percent_pieces_claimed).to eq(0)
    end
    it "should return 0 if exported pieces is 0" do
      expect(DrawbackClaim.new(:total_pieces_exported=>0, :total_pieces_claimed=>3).percent_pieces_claimed).to eq(0)
    end
    it "should return 0 if claimed pieces is nil" do
      expect(DrawbackClaim.new(:total_pieces_exported=>5, :total_pieces_claimed=>nil).percent_pieces_claimed).to eq(0)
    end
    it "should round down" do
      expect(DrawbackClaim.new(:total_pieces_exported=>100000, :total_pieces_claimed=>99999).percent_pieces_claimed).to eq(0.999)
    end
  end
  describe "percent_money_claimed" do
    it "should calculate percentage by net claim amount vs planned" do
      expect(DrawbackClaim.new(:planned_claim_amount=>9, :net_claim_amount=>3).percent_money_claimed).to eq(0.333)
    end
    it "should return 0 if planned amount is nil" do
      expect(DrawbackClaim.new(:planned_claim_amount=>nil, :net_claim_amount=>3).percent_money_claimed).to eq(0)
    end
    it "should return 0 if planned amount is 0" do
      expect(DrawbackClaim.new(:planned_claim_amount=>0, :net_claim_amount=>3).percent_money_claimed).to eq(0)
    end
    it "should return 0 if net claimed is nil" do
      expect(DrawbackClaim.new(:planned_claim_amount=>0, :net_claim_amount=>nil).percent_money_claimed).to eq(0)
    end
  end
  describe "viewable" do
    let! (:master_setup) {
      ms = stub_master_setup
      allow(ms).to receive(:drawback_enabled?).and_return true
      ms
    }

    let! (:base_claim) {create(:drawback_claim)}

    it "should not limit master user with permission" do
      d = create(:drawback_claim)
      u = create(:master_user, :drawback_view=>true)
      expect(DrawbackClaim.viewable(u).to_a).to eq([base_claim, d])
    end
    it "should return nothing if user does not have permission" do
      u = create(:master_user, :drawback_view=>false)
      expect(DrawbackClaim.viewable(u)).to be_empty
    end
    it "should return claims for current company" do
      d = create(:drawback_claim)
      d2 = create(:drawback_claim)
      u = create(:drawback_user, :company=>d.importer)
      expect(DrawbackClaim.viewable(u).to_a).to eq([d])
    end
    it "should return claims for linked company" do
      d = create(:drawback_claim)
      d2 = create(:drawback_claim)
      u = create(:drawback_user, :company=>d.importer)
      u.company.linked_companies << d2.importer
      expect(DrawbackClaim.viewable(u).to_a).to eq([d, d2])
    end
  end

  describe "can_view?" do
    before :each do
      @d = create(:drawback_claim)
    end
    context "with_permission" do
      before :each do
        allow_any_instance_of(User).to receive(:view_drawback?).and_return(true)
      end
      it "should allow user with permission and master company to view" do
        u = create(:master_user)
        expect(@d.can_view?(u)).to be_truthy
      end
      it "should allow user with permission and same company to view" do
        u = create(:user, :company=>@d.importer)
        expect(@d.can_view?(u)).to be_truthy
      end
      it "should allow user with permission and linked company to view" do
        u = create(:user)
        u.company.linked_companies << @d.importer
        expect(@d.can_view?(u)).to be_truthy
      end
      it "should not allow user from different company to view" do
        u = create(:user)
        expect(@d.can_view?(u)).to be_falsey
      end
    end
    it "should now allow user without permission to view" do
      u = create(:master_user)
      allow(u).to receive(:view_drawback?).and_return(false)
      expect(@d.can_view?(u)).to be_falsey
    end
  end

  describe "can_comment?" do
    before :each do
      @d = create(:drawback_claim)
      @u = create(:user)
    end

    it "should allow user with permissions to comment" do
      allow(@d).to receive(:can_view?).with(@u).and_return true
      expect(@d.can_comment?(@u)).to be_truthy
    end

    it "should not allow user without permission to view this drawback to comment" do
      allow(@d).to receive(:can_view?).with(@u).and_return false
      expect(@d.can_comment?(@u)).to be_falsey
    end
  end

  describe "can_edit" do
    before :each do
      @d = create(:drawback_claim)
    end
    it "should now allow user without permission to edit" do
      u = create(:master_user)
      allow(u).to receive(:edit_drawback?).and_return(false)
      expect(@d.can_edit?(u)).to be_falsey
    end
    context "with permission" do
      before :each do
        allow_any_instance_of(User).to receive(:edit_drawback?).and_return(true)
      end
      it "should allow user with permission and master company to edit" do
        u = create(:master_user)
        expect(@d.can_edit?(u)).to be_truthy
      end
      it "should allow user with permission and same company to edit" do
        u = create(:user, :company=>@d.importer)
        expect(@d.can_edit?(u)).to be_truthy
      end
      it "should allow user with permission and linked company to edit" do
        u = create(:user)
        u.company.linked_companies << @d.importer
        expect(@d.can_edit?(u)).to be_truthy
      end
      it "should not allow user from different company to edit" do
        u = create(:user)
        expect(@d.can_edit?(u)).to be_falsey
      end
    end
  end

  describe "exports_not_in_import" do
    before :each do
      @c = create(:drawback_claim)
      @month_ago = DutyCalcExportFileLine.create!(:importer_id=>@c.importer_id, :part_number=>'ABC', :export_date=>1.month.ago)
      @year_ago = DutyCalcExportFileLine.create!(:importer_id=>@c.importer_id, :part_number=>'DEF', :export_date=>1.year.ago)
    end
    it "should return all lines if export dates are empty" do
      expect(@c.exports_not_in_import.to_a).to eq([@month_ago, @year_ago])
    end
    it "should use export dates" do
      @c.exports_start_date = 3.months.ago
      expect(@c.exports_not_in_import.to_a).to eq([@month_ago])
      @c.exports_start_date = nil
      @c.exports_end_date = 3.months.ago
      expect(@c.exports_not_in_import.to_a).to eq([@year_ago])
    end
    it "should not return lines for different importer than claim" do
      @c.importer_id= create(:company).id
      expect(@c.exports_not_in_import).to be_empty
    end
    it "should not return lines that match imports" do
      p = create(:product, :unique_identifier=>@month_ago.part_number)
      DrawbackImportLine.create!(:product_id=>p.id, :part_number=>p.unique_identifier, :import_date=>2.months.ago, :importer_id=>@c.importer_id)
      expect(@c.exports_not_in_import.to_a).to eq([@year_ago])
    end
  end
end
