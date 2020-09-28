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
            }
        ]
    }'
  end

  describe 'run_schedulable' do

    subject { described_class }

    it "implements SchedulableJob interface" do
      expect(subject).to receive(:delay).and_return subject
      expect(subject).to receive(:update_news)

      described_class.run_schedulable
    end
  end

  describe 'update_news' do

    subject { described_class }

    let (:http_client) do
      http = instance_double(OpenChain::HttpClient)
      expect(subject).to receive(:http_client).and_return http
      http
    end

    it "gets the results from the Vandegrift news site in JSON and upload to S3" do
      expect(http_client).to receive(:get).with('https://www.vandegriftinc.com/news?format=json').and_return news_response
      expect(OpenChain::S3).to receive(:upload_data).with('vandegrift-news', 'latest_news.json', news_response)

      subject.update_news
    end
  end
end
