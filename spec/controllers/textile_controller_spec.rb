describe TextileController do
  describe "preview" do
    it "should send back formatted html without authentication" do
      get :preview, {"c"=>"h1. hello world\n\necho"}
      expect(response).to be_success
      expect(response.body).to eq("<h1>hello world</h1>\n<p>echo</p>")
    end
  end
end
