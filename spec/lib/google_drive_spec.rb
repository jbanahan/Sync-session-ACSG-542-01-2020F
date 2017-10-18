require 'spec_helper'
require 'socket'

# This set of specs takes quite a while to complete (25 seconds or so) as there are a number of HTTP 
# requests that are sent to the Google Drive API, each one from .5 to 1 second in length.
describe OpenChain::GoogleDrive do

  # For speed reasons, a lot of these methods use files that are known to exist in the integration-dev drive account
  let (:existing_drive_folder) { "Rspec Test/" }
  let (:existing_drive_file) { "Rspec Test/file.txt" }
  let (:existing_drive_file_id) { "0B92M--X0uMKPLWNNNDZZUnFGekk" }
  let (:existing_drive_folder_id) { "0B92M--X0uMKPS2oza2NmOWFMeTQ" }
  let (:existing_drive_folder_parent_id) { "0AN2M--X0uMKPUk9PVA" }
  let (:existing_team_drive_folder) { "Team Drives/VFI Track Testing/Rspec Test/" }
  let (:existing_team_drive_file) { "Team Drives/VFI Track Testing/Rspec Test/file.txt" }
  let (:existing_team_drive_file_id) { "0B92M--X0uMKPbzRwQktFenpPUWc" }
  let (:existing_team_drive_folder_id) { "0B92M--X0uMKPSEwwRHlDWTJqQlk" }
  let (:existing_team_drive_folder_parent_id) { "0AFnKW8YWdmjaUk9PVA" }
  let (:existing_team_drive_id) { "0AFnKW8YWdmjaUk9PVA" }

  before :all do
    @test_folder = "spec-" + Random.rand(1000000).to_s + "-" + Socket.gethostname
  end

  subject { described_class }

  def delete_file_ids ids
    ids.each do |id|
      retry_expect(retry_count: 5, retry_wait: 0.5, additional_rescue_from: [StandardError]) {
        OpenChain::GoogleDrive.delete_by_id id
        expect(OpenChain::GoogleDrive.find_file_by_id(id)).to be_nil
      } rescue Google::Apis::ClientError
    end
  end

  def delete_folder_ids ids
    ids.each do |id|
      retry_expect(retry_count: 5, retry_wait: 0.5, additional_rescue_from: [StandardError]) {
        OpenChain::GoogleDrive.delete_by_id id
        expect(OpenChain::GoogleDrive.find_folder_by_id(id)).to be_nil
      } rescue Google::Apis::ClientError
    end
  end

  describe "download_to_tempfile" do

    let (:contents) { "This is the file contents.\r\nContents.\r\n"}

    context "standard drive" do
      let (:path) {  existing_drive_folder + "file.txt"}

      it "downloads data to a tempfile with a block" do
        retry_expect(additional_rescue_from: [StandardError]) {
          tempfile_contents = nil
          tempfile = nil
          subject.download_to_tempfile(path) do |f| 
            tempfile = f
            tempfile_contents = f.read 
          end
          expect(tempfile_contents).to eq contents
          expect(tempfile.closed?).to eq true
        }
      end

      it "returns a tempfile if no block given" do
        retry_expect(additional_rescue_from: [StandardError]) {
          tempfile = nil
          begin
            tempfile = subject.download_to_tempfile(path)
            expect(tempfile.read).to eq contents
          ensure
            tempfile.close! unless tempfile.nil? || tempfile.closed?
          end
        }
      end

      context "team drive" do
        let (:path) { existing_team_drive_folder + "file.txt" }

        it "downloads data to a tempfile with a block" do
          retry_expect(additional_rescue_from: [StandardError]) {
            tempfile_contents = nil
            tempfile = nil
            subject.download_to_tempfile(path) do |f| 
              tempfile = f
              tempfile_contents = f.read 
            end
            expect(tempfile_contents).to eq contents
            expect(tempfile.closed?).to eq true
          }
        end
      end
    end
  end

  describe "upload_file" do
    let (:local_file_path) { "spec/fixtures/files/attorney.png" }
    let (:file_ids) { [] }
    let (:folder_ids) { [] }

    after :each do 
      delete_folder_ids(folder_ids)
      delete_file_ids(file_ids)
    end

    context "using standard drive" do
      let (:remote_path) { existing_drive_folder + "#{Time.zone.now}-saul.png" }

      it "uploads a file to an existing folder using a file path" do
        file = subject.upload_file remote_path, local_file_path
        expect(file[:id]).not_to be_nil
        file_ids << file[:id]
        expect(file[:name]).to eq File.basename(remote_path)
        expect(file[:size]).to eq 85867
        expect(file[:parents]).to eq [existing_drive_folder_id]
        expect(file[:created_time]).not_to be_nil
        expect(file[:modified_time]).not_to be_nil
        expect(file[:team_drive_id]).to be_nil
      end

      it "uploads a file to an existing folder using an IO object" do
        File.open(local_file_path, "rb") do |f|
          file = subject.upload_file remote_path, f
          expect(file[:id]).not_to be_nil
          file_ids << file[:id]
          expect(file[:name]).to eq File.basename(remote_path)
          expect(file[:size]).to eq 85867
          expect(file[:parents]).to eq [existing_drive_folder_id]
          expect(file[:created_time]).not_to be_nil
          expect(file[:modified_time]).not_to be_nil
          expect(file[:team_drive_id]).to be_nil
        end
      end

      it "creates new folders on drive if required" do
        path = existing_drive_folder + "/New Folder/#{File.basename(remote_path)}"
        file = subject.upload_file path, local_file_path
        expect(file[:id]).not_to be_nil
        file_ids << file[:id]
        folder_ids << file[:parents].first
      end
    end

    context "using team drive" do
      let (:remote_path) { existing_team_drive_folder + "#{Time.zone.now}-saul.png" }

      it "uploads a file to an existing folder using a file path" do
        file = subject.upload_file remote_path, local_file_path
        expect(file[:id]).not_to be_nil
        file_ids << file[:id]
        expect(file[:name]).to eq File.basename(remote_path)
        expect(file[:size]).to eq 85867
        expect(file[:parents]).to eq [existing_team_drive_folder_id]
        expect(file[:created_time]).not_to be_nil
        expect(file[:modified_time]).not_to be_nil
        expect(file[:team_drive_id]).to eq existing_team_drive_id
      end

      it "creates new folders on drive if required" do
        path = existing_team_drive_folder + "/New Folder/#{File.basename(remote_path)}"
        file = subject.upload_file path, local_file_path
        expect(file[:id]).not_to be_nil
        file_ids << file[:id]
        folder_ids << file[:parents].first
      end
    end
  end

  describe "delete_file" do
    
    let (:uploaded_file) {
      io = StringIO.new
      subject.upload_file remote_path, io
    }

    context "using standard drive" do
      let (:remote_path) { existing_drive_folder + "#{Time.zone.now}-test.txt" }

      it "deletes a file" do
        # The upload takes a few seconds to propigate on drive, so try this a couple times
        retry_expect(retry_count: 5, additional_rescue_from: [StandardError]) {
          expect(subject.delete_file remote_path).to be_nil
          expect(subject.find_file_by_id uploaded_file[:id]).to be_nil
        }
      end
    end

    context "using team drive" do
      let (:remote_path) { existing_team_drive_folder + "#{Time.zone.now}-test.txt" }

      it "deletes a file" do
        # The upload takes a few seconds to propigate on drive, so try this a couple times
        retry_expect(retry_count: 5, additional_rescue_from: [StandardError]) {
          expect(subject.delete_file remote_path).to be_nil
          expect(subject.find_file_by_id uploaded_file[:id]).to be_nil
        }
      end
    end
  end

  describe "delete_folder" do
    let (:uploaded_file) {
      io = StringIO.new
      subject.upload_file remote_path, io
    }

    context "using standard drive" do
      let (:remote_path) { existing_drive_folder + "#{Time.zone.now}-folder/test.txt" }

      it "deletes a folder" do
        # The upload takes a few seconds to propigate on drive, so try this a couple times
        retry_expect(retry_count: 5, additional_rescue_from: [StandardError]) {
          folder = Pathname.new(remote_path).split.first.to_s
          expect(subject.delete_folder folder).to be_nil
          expect(subject.find_folder_by_id uploaded_file[:parents].first).to be_nil
        }
      end
    end

    context "using team drive" do
      let (:remote_path) { existing_team_drive_folder + "#{Time.zone.now}-folder/test.txt" }

      it "deletes a file" do
        # The upload takes a few seconds to propigate on drive, so try this a couple times
        retry_expect(retry_count: 5, additional_rescue_from: [StandardError]) {
          folder = Pathname.new(remote_path).split.first.to_s
          expect(subject.delete_folder folder).to be_nil
          expect(subject.find_folder_by_id uploaded_file[:parents].first).to be_nil
        }
      end
    end
  end

  describe "find_folder" do
    context "using standard drive" do
      it "finds a folder" do
        folder = subject.find_folder existing_drive_folder
        expect(folder).not_to be_nil
        expect(folder[:id]).to eq existing_drive_folder_id
        expect(folder[:name]).to eq "Rspec Test"
        expect(folder[:created_time]).not_to be_nil
        expect(folder[:modified_time]).not_to be_nil
        expect(folder[:parents]).to eq [existing_drive_folder_parent_id]
        expect(folder[:team_drive_id]).to be_nil
      end
    end

    context "using team drive" do
      it "finds a folder" do
        folder = subject.find_folder existing_team_drive_folder
        expect(folder).not_to be_nil
        expect(folder[:id]).to eq existing_team_drive_folder_id
        expect(folder[:name]).to eq "Rspec Test"
        expect(folder[:created_time]).not_to be_nil
        expect(folder[:modified_time]).not_to be_nil
        expect(folder[:parents]).to eq [existing_team_drive_folder_parent_id]
        expect(folder[:team_drive_id]).to eq existing_team_drive_id
      end
    end
  end

  describe "find_file" do
    context "using standard drive" do
      it "finds a file" do
        file = subject.find_file existing_drive_file
        expect(file).not_to be_nil
        expect(file[:id]).to eq existing_drive_file_id
        expect(file[:name]).to eq "file.txt"
        expect(file[:size]).to eq 39
        expect(file[:created_time]).not_to be_nil
        expect(file[:modified_time]).not_to be_nil
        expect(file[:parents]).to eq [existing_drive_folder_id]
        expect(file[:team_drive_id]).to be_nil
      end
    end

    context "using team drive" do
      it "finds a file" do
        file = subject.find_file existing_team_drive_file
        expect(file).not_to be_nil
        expect(file[:id]).to eq existing_team_drive_file_id
        expect(file[:name]).to eq "file.txt"
        expect(file[:size]).to eq 39
        expect(file[:created_time]).not_to be_nil
        expect(file[:modified_time]).not_to be_nil
        expect(file[:parents]).to eq [existing_team_drive_folder_id]
        expect(file[:team_drive_id]).to eq existing_team_drive_id
      end
    end
  end

  describe "delete_by_id" do
    let (:folder_ids) { [] }
    let (:uploaded_file) {
      io = StringIO.new
      file = subject.upload_file remote_path, io
      folder_ids << file[:parents].first
      file
    }

    after :each do 
      delete_folder_ids(folder_ids)
    end

    context "using standard drive" do
      let (:remote_path) { existing_drive_folder + "#{Time.zone.now}-folder/test.txt" }

      it "deletes a file" do
        # The upload takes a few seconds to propigate on drive, so try this a couple times
        retry_expect(retry_count: 5, additional_rescue_from: [StandardError]) {
          expect(subject.delete_by_id uploaded_file[:id]).to be_nil
          expect(subject.find_file_by_id uploaded_file[:id]).to be_nil
        }
      end

      it "deletes a folder" do
        # The upload takes a few seconds to propigate on drive, so try this a couple times
        retry_expect(retry_count: 10, additional_rescue_from: [StandardError]) {
          expect(subject.delete_by_id uploaded_file[:parents].first).to be_nil
          expect(subject.find_folder_by_id uploaded_file[:parents].first).to be_nil
        }
      end
    end

    context "using team drive" do
      let (:remote_path) { existing_team_drive_folder + "#{Time.zone.now}-folder/test.txt" }

      it "deletes a file" do
        # The upload takes a few seconds to propigate on drive, so try this a couple times
        retry_expect(retry_count: 5, additional_rescue_from: [StandardError]) {
          expect(subject.delete_by_id uploaded_file[:id]).to be_nil
          expect(subject.find_file_by_id uploaded_file[:id]).to be_nil
          # According to the V3 api docs, if a folder is deleted, any children are also deleted...so there's no point in also checking that the file
          # has been removed.  Also, it can take several minutes for the children to be removed on google's end.
        }
      end

      it "deletes a folder" do
        # The upload takes a few seconds to propigate on drive, so try this a couple times
        retry_expect(retry_count: 10, additional_rescue_from: [StandardError]) {
          expect(subject.delete_by_id uploaded_file[:parents].first).to be_nil
          expect(subject.find_folder_by_id uploaded_file[:parents].first).to be_nil
          # According to the V3 api docs, if a folder is deleted, any children are also deleted...so there's no point in also checking that the file
          # has been removed.  Also, it can take several minutes for the children to be removed on google's end.
        }
      end
    end
  end

  describe "find_file_by_id" do
    context "using standard drive" do
      it "finds a file" do
        file = subject.find_file_by_id existing_drive_file_id
        expect(file).not_to be_nil
        expect(file[:id]).to eq existing_drive_file_id
        expect(file[:name]).to eq "file.txt"
        expect(file[:size]).to eq 39
        expect(file[:created_time]).not_to be_nil
        expect(file[:modified_time]).not_to be_nil
        expect(file[:parents]).to eq [existing_drive_folder_id]
        expect(file[:team_drive_id]).to be_nil
      end
    end

    context "using team drive" do
      it "finds a file" do
        file = subject.find_file_by_id existing_team_drive_file_id
        expect(file).not_to be_nil
        expect(file[:id]).to eq existing_team_drive_file_id
        expect(file[:name]).to eq "file.txt"
        expect(file[:size]).to eq 39
        expect(file[:created_time]).not_to be_nil
        expect(file[:modified_time]).not_to be_nil
        expect(file[:parents]).to eq [existing_team_drive_folder_id]
        expect(file[:team_drive_id]).to eq existing_team_drive_id
      end
    end
  end

  describe "find_folder_by_id" do
    context "using standard drive" do
      it "finds a folder" do
        folder = subject.find_folder_by_id existing_drive_folder_id
        expect(folder).not_to be_nil
        expect(folder[:id]).to eq existing_drive_folder_id
        expect(folder[:name]).to eq "Rspec Test"
        expect(folder[:created_time]).not_to be_nil
        expect(folder[:modified_time]).not_to be_nil
        expect(folder[:parents]).to eq [existing_drive_folder_parent_id]
        expect(folder[:team_drive_id]).to be_nil
      end
    end

    context "using team drive" do
      it "finds a folder" do
        folder = subject.find_folder_by_id existing_team_drive_folder_id
        expect(folder).not_to be_nil
        expect(folder[:id]).to eq existing_team_drive_folder_id
        expect(folder[:name]).to eq "Rspec Test"
        expect(folder[:created_time]).not_to be_nil
        expect(folder[:modified_time]).not_to be_nil
        expect(folder[:parents]).to eq [existing_team_drive_folder_parent_id]
        expect(folder[:team_drive_id]).to eq existing_team_drive_id
      end
    end
  end
end