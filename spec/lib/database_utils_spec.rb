describe OpenChain::DatabaseUtils do 

  subject { described_class }

  describe "deadlock_error?" do
    let (:deadlock) { Mysql2::Error.new "deadlock found when trying to get lock" }
    let (:lock_wait) { Mysql2::Error.new "lock wait timeout exceeded"}

    it "identifies Mysql2 deadlock error" do
      expect(subject.deadlock_error? deadlock).to eq true
    end

    it "identifies Mysql2 lock wait error" do
      expect(subject.deadlock_error? lock_wait).to eq true
    end

    it "returns false for other error types" do
      expect(subject.deadlock_error? StandardError.new("test")).to eq false
    end
  end
end