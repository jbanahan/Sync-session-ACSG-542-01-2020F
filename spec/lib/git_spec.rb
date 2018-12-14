describe OpenChain::Git do
  subject { described_class }

  describe "current_tag_name" do
    let (:tag_status) {"HEAD detached at test_tag_name\nnothing to commit, working directory clean\n"}
    let (:branch_status) {"On branch master\nYour branch is up-to-date with 'origin/master'.\nnothing to commit, working directory clean\n"}
    let (:rebase_status) { "rebase in progress; onto db7db3b\nYou are currently rebasing branch 'branchname' on 'db7db3b'." }
    let (:process_status_success) { 
      stat = double("Process")
      expect(stat).to receive(:success?).and_return true
      stat
    }
    let (:process_status_error) { 
      stat = double("Process")
      expect(stat).to receive(:success?).and_return false
      stat
    }

    it "parses output of `git status` to determine currently checked out tag name" do
      expect(Open3).to receive(:capture3).with("git status").and_return [tag_status, "", process_status_success]
      expect(subject.current_tag_name).to eq "test_tag_name"
    end

    it "raises an error if `git status` process fails" do
      expect(Open3).to receive(:capture3).with("git status").and_return [tag_status, "There was an error.", process_status_error]

      expect { subject.current_tag_name}.to raise_error "Failed to return tag name: There was an error."
    end

    it "allows for using branch name if specified" do
      expect(Open3).to receive(:capture3).with("git status").and_return [branch_status, "", process_status_success]
      expect(subject.current_tag_name allow_branch_name: true).to eq "master"
    end

    it "does not allow for using branch name unless specified" do
      expect(Open3).to receive(:capture3).with("git status").and_return [branch_status, "", process_status_success]
      expect{ subject.current_tag_name allow_branch_name: false }.to raise_error "Failed to discover current git tag name."
    end

    it "errors if no tag name found in git output" do
      expect(Open3).to receive(:capture3).with("git status").and_return ["", "", process_status_success]
      expect{ subject.current_tag_name }.to raise_error "Failed to discover current git tag name."
    end

    it "does not error if not in production when on a rebase branch" do
      expect(subject).to receive(:production?).and_return false
      expect(Open3).to receive(:capture3).with("git status").and_return [rebase_status, "", process_status_success]

      expect(subject.current_tag_name).to eq "rebase"
    end

    it "errors in production while rebasing" do
      expect(subject).to receive(:production?).and_return true
      expect(Open3).to receive(:capture3).with("git status").and_return [rebase_status, "", process_status_success]

      expect{ subject.current_tag_name }.to raise_error "Failed to discover current git tag name."
    end
  end
end