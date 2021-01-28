describe HomeController do

  before :each do
    @user = create(:master_user, :email=>'a@example.com')
    sign_in_as @user
  end

  describe "index" do

    it "redirects to dashboard widgets by default" do
      get :index
      expect(response).to be_redirect
      expect(response).to redirect_to dashboard_widgets_path
    end

    it "redirects to user's homepage when set" do
      @user.update_attributes! homepage: "/testing#123"
      get :index
      expect(response).to be_redirect
      expect(response).to redirect_to "/testing#123"
    end

    it "should identify IE 9 as modern" do
      # Supposedly you should be able to overload request headers directly in the get call..
      # That wasn't working..hence the direct user agent setting (which does work)
      @request.user_agent = "Mozilla/5.0 (Windows; U; MSIE 9.0; WIndows NT 9.0; en-US)"
      get :index
      expect(flash[:notices]).to be nil
    end

    it "should identify IE 10 as modern" do
      @request.user_agent = "Mozilla/5.0 (compatible; MSIE 10.0; Windows NT 6.1; WOW64; Trident/6.0)"
      get :index
      expect(flash[:notices]).to be nil
    end

    it "should identify Internet Explorer < 9 and add notice" do
      @request.user_agent = "Mozilla/5.0 (compatible; MSIE 8.0; Windows NT 6.1; Trident/4.0; GTB7.4; InfoPath.2; SV1; .NET CLR 3.3.69573; WOW64; en-US)"
      get :index
      expect(flash[:notices]).to eq(["Because you are using an older version of Internet Explorer, the search/report screens will have reduced functionality, showing only 10 search results per page.  Please consider upgrading or using the Chrome browser instead."])
    end

    it "should identify Chrome" do
      @request.user_agent = "Mozilla/5.0 (Windows NT 6.1) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/28.0.1468.0 Safari/537.36"
      get :index
      expect(flash[:notices]).to be nil
    end

    it "should identify Firefox" do
      @request.user_agent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10.8; rv:24.0) Gecko/20100101 Firefox/24.0"
      get :index
      expect(flash[:notices]).to be nil
    end
  end
end