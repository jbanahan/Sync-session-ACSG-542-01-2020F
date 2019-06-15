describe ComparepdfController do

  describe "compare" do
    let (:secure_url) { "http://my.secure.url"}
    let (:att1) { double(:attachment, secure_url: secure_url, attached_file_name: "file1.pdf") }
    let (:att2) { double(:attachment, secure_url: secure_url, attached_file_name: "file2.pdf") }
    let (:att3) { double(:attachment, secure_url: secure_url, attached_file_name: "file3.csv") }
    let! (:user) { u = Factory(:user); sign_in_as(u); u }

    it "provides s3 inline urls for viewing" do
      expect(Attachment).to receive(:find).with("1").and_return att1
      expect(Attachment).to receive(:find).with("2").and_return att2
      expect(att1).to receive(:can_view?).with(user).and_return true
      expect(att2).to receive(:can_view?).with(user).and_return true
      expect(att1).to receive(:is_pdf?).and_return true
      expect(att2).to receive(:is_pdf?).and_return true

      get :compare, file1: 1, file2: 2
      expect(response).to be_success
    end

    it "redirects if user can't view one of the files" do
      expect(Attachment).to receive(:find).with("1").and_return att1
      expect(Attachment).to receive(:find).with("2").and_return att2
      expect(att1).to receive(:can_view?).with(user).and_return true
      expect(att2).to receive(:can_view?).with(user).and_return false
      expect(att1).to receive(:is_pdf?).and_return true
      expect(att2).to receive(:is_pdf?).and_return true

      get :compare, file1: 1, file2: 2
      expect(response).to redirect_to root_path
      expect(flash[:errors]).to include "You do not have permission to view one or both documents."
    end

    it "redirects if one of the files is not a pdf" do
      expect(Attachment).to receive(:find).with("1").and_return att1
      expect(Attachment).to receive(:find).with("3").and_return att3

      expect(att1).to receive(:can_view?).with(user).and_return true
      expect(att3).to receive(:can_view?).with(user).and_return true

      expect(att1).to receive(:is_pdf?).and_return true
      expect(att3).to receive(:is_pdf?).and_return false

      get :compare, file1: 1, file2: 3
      expect(response).to redirect_to root_path
      expect(flash[:errors]).to include "One or both documents is not a PDF."
    end

    it "redirects if one of the files is not provided" do
      get :compare, file1: 1, file2: ""
      expect(response).to redirect_to root_path
      expect(flash[:errors]).to include "Two files must be provided."
    end
  end

end
