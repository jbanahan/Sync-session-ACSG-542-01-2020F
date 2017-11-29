describe DailyStatement do

  describe "search_where" do
    let (:master_user) { Factory(:master_user) }
    let! (:statement) { described_class.create! statement_number: "STATEMENT" }

    context "with user than can view statements" do
      before :each do
        expect_any_instance_of(User).to receive(:view_statements?).and_return true
      end

      it"allows master company to view all statements" do
        expect(described_class.where(described_class.search_where(master_user)).all).to include statement
      end

      it "allows importer users to view statements linked to their account" do 
        user = Factory(:user, company: Factory(:importer))
        statement.update_attributes! importer_id: user.company.id

        expect(described_class.where(described_class.search_where(master_user)).all).to include statement
      end

      it "allows users linked to the statements importer to see it" do
        user = Factory(:user)
        importer = Factory(:importer)
        statement.update_attributes! importer_id: importer.id
        user.company.linked_companies << importer

        expect(described_class.where(described_class.search_where(master_user)).all).to include statement
      end

      it "does not allow users not linked to importer to see it" do
        user = Factory(:user)
        importer = Factory(:importer)
        statement.update_attributes! importer_id: importer.id

        expect(described_class.where(described_class.search_where(master_user)).all).to include statement
      end
    end
    
    it "does not allow users that cannot view statements to see any" do
      expect_any_instance_of(User).to receive(:view_statements?).and_return false
      expect(described_class.where(described_class.search_where(master_user)).all).to eq []
    end
  end

  describe "can_view?" do
    let! (:statement) { described_class.create! statement_number: "STATEMENT" }

    context "with user that can view statements" do
      before :each do
        expect_any_instance_of(User).to receive(:view_statements?).and_return true
      end

      it "allows master company to view all statements" do
        expect(statement.can_view? Factory(:master_user)).to eq true
      end

      it "does not allow non-master users to see statements without an importer" do
        expect(statement.can_view? Factory(:user)).to eq false
      end

      it "allows importer users to view statements linked to their account" do 
        user = Factory(:user, company: Factory(:importer))
        statement.update_attributes! importer_id: user.company.id

        expect(statement.can_view? user).to eq true
      end

      it "allows users linked to the statements importer to see it" do
        user = Factory(:user)
        importer = Factory(:importer)
        statement.update_attributes! importer_id: importer.id
        user.company.linked_companies << importer

        expect(statement.can_view? user).to eq true
      end

      it "does not allow users not linked to importer to see it" do
        user = Factory(:user)
        importer = Factory(:importer)
        statement.update_attributes! importer_id: importer.id

        expect(statement.can_view? user).to eq false
      end
    end

    it "does not let users without statement view permission to view statements" do 
      user = User.new
      expect(user).to receive(:view_statements?).and_return false
      expect(statement.can_view? user).to eq false
    end    
  end

  describe "final_statement?" do
    it "identifies final statements" do
      expect(described_class.new(status: "F").final_statement?).to eq true
    end

    it "identifies non-final statements" do
      expect(described_class.new(status: "").final_statement?).to eq false
    end
  end

  describe "pay_type_description" do
    [[1, "Direct Payment"], [2, "Broker Daily Statement"], [3, "Importer Daily Statement"], [6, "Broker Monthly Statement"], [7, "Importer Monthly Statement"], [nil, ""]].each do |vals|
      it "identifies #{vals[1]}" do
        expect(described_class.new(pay_type: vals[0]).pay_type_description).to eq vals[1]
      end
    end
  end

  describe "status_description" do
    [["f", "Final"], ["P", "Preliminary"], [nil, ""]].each do |vals|
      it "identifies #{vals[1]}" do 
        expect(described_class.new(status: vals[0]).status_description).to eq vals[1]
      end
    end
  end
end