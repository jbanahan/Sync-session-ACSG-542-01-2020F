describe OpenChain::GetNewsFeed do

  let (:news_response) do
    '{
        "calendarView": false,
        "collection": {
            "fullUrl": "/news",
            "id": "5a31dc5a9140b73f73e58370",
            "navigationTitle": "News",
            "title": "News",
            "typeLabel": "blog",
            "typeName": "blog",
            "updatedOn": 1594664570273,
            "urlId": "news",
            "websiteId": "59da89f28419c28f51bedd83"
        },
        "empty": false,
        "emptyFolder": false,
        "items": [
            {
                "addedOn": 1594664544732,
                "assetUrl": "https://static1.squarespace.com/static/59da89f28419c28f51bedd83/5a31dc5a9140b73f73e58370/5f0ca67a2a34c20dba1918f3/1594664596952/",
                "author": {
                    "displayName": "Katie Thunig",
                    "firstName": "Katie",
                    "id": "5a81a585c6deb0cb52aefa9b",
                    "lastName": "Thunig"
                },
                "authorId": "5a81a585c6deb0cb52aefa9b",
                "body": "<div>Some news.</div>",
                "categories": [],
                "collectionId": "5a31dc5a9140b73f73e58370",
                "commentCount": 0,
                "commentState": 2,
                "contentType": "text/html",
                "customContent": null,
                "excerpt": "",
                "fullUrl": "/news/2020/7/13/ustr-extends-exclusions-from-list-1-and-issues-more-for-list-4",
                "id": "5f0ca67a2a34c20dba1918f3",
                "items": [],
                "likeCount": 0,
                "location": {
                    "mapLat": 40.7207559,
                    "mapLng": -74.0007613,
                    "mapZoom": 12.0,
                    "markerLat": 40.7207559,
                    "markerLng": -74.0007613
                },
                "mediaFocalPoint": {
                    "source": 3,
                    "x": 0.5,
                    "y": 0.5
                },
                "passthrough": false,
                "pendingPushedServices": {},
                "publicCommentCount": 0,
                "publishOn": 1594664544732,
                "pushedServices": {},
                "recordType": 1,
                "recordTypeLabel": "text",
                "sourceUrl": "",
                "starred": false,
                "tags": [],
                "title": "USTR Extends Exclusions from List 1 and Issues More for List 4 ",
                "unsaved": false,
                "updatedOn": 1594664596952,
                "urlId": "2020/7/13/ustr-extends-exclusions-from-list-1-and-issues-more-for-list-4",
                "workflowState": 1
            },
            {
                "addedOn": 1593528295716,
                "assetUrl": "https://static1.squarespace.com/static/59da89f28419c28f51bedd83/5a31dc5a9140b73f73e58370/5efb4ffe2ae1ca7833fa844c/1593528334501/",
                "author": {
                    "displayName": "Katie Thunig",
                    "firstName": "Katie",
                    "id": "5a81a585c6deb0cb52aefa9b",
                    "lastName": "Thunig"
                },
                "authorId": "5a81a585c6deb0cb52aefa9b",
                "body": "<div>Some other news.</div>",
                "categories": [],
                "collectionId": "5a31dc5a9140b73f73e58370",
                "commentCount": 0,
                "commentState": 2,
                "contentType": "text/html",
                "customContent": null,
                "excerpt": "",
                "fullUrl": "/news/2020/6/30/ustr-seeks-comments-for-list-4a-exclusions",
                "id": "5efb4ffe2ae1ca7833fa844c",
                "items": [],
                "likeCount": 0,
                "location": {
                    "mapLat": 40.7207559,
                    "mapLng": -74.0007613,
                    "mapZoom": 12.0,
                    "markerLat": 40.7207559,
                    "markerLng": -74.0007613
                },
                "mediaFocalPoint": {
                    "source": 3,
                    "x": 0.5,
                    "y": 0.5
                },
                "passthrough": false,
                "pendingPushedServices": {},
                "publicCommentCount": 0,
                "publishOn": 1593528295716,
                "pushedServices": {},
                "recordType": 1,
                "recordTypeLabel": "text",
                "sourceUrl": "",
                "starred": false,
                "tags": [],
                "title": "USTR Seeks Comments for List 4A Exclusions",
                "unsaved": false,
                "updatedOn": 1593528334501,
                "urlId": "2020/6/30/ustr-seeks-comments-for-list-4a-exclusions",
                "workflowState": 1
            }
        ]
    }'.to_json
  end

  describe 'run_schedulable' do
    it "implements SchedulableJob interface" do
      allow(described_class).to receive(:delay).and_return described_class
      expect(described_class).to receive(:update_news)

      described_class.run_schedulable
    end
  end

  describe 'update_news' do
    before do
      allow(RestClient).to receive(:get).with('https://www.vandegriftinc.com/news?format=json').and_return news_response
    end

    it "gets the results from the Vandegrift news site in JSON" do
      expect(RestClient).to receive(:get).with('https://www.vandegriftinc.com/news?format=json').and_return news_response
      described_class.update_news
    end

    it "stores the data in s3" do
      expect(OpenChain::S3).to receive(:upload_data).with('vandegrift-news', 'latest_news.json', news_response).and_return nil
      described_class.update_news
    end
  end
end
