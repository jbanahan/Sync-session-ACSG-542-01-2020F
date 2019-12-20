describe OpenChain::Report::BouncedEmailReport do
  
  describe "run_schedulable" do
    it 'sends the report' do
      Timecop.freeze(Time.zone.parse("2019-12-20 01:00")) do
        described_class.run_schedulable 'email_to' => 'test@test.com'

        mail = ActionMailer::Base.deliveries.pop
        expect(mail.to).to eq ['test@test.com']
        # It should be 12/18 because we're taking the current time in current timezone (UTC) and translating it to
        # US Eastern time (which rolls the date back to 12/19).  Then the report it self is over the previous
        # day (12/18).
        expect(mail.subject).to eq "Bounced Email Report for 2019-12-18"
        expect(mail.body).to include "Attached is the bounced email report for 2019-12-18"
      end
    end
  end

  describe "get_yesterday_in_timezone" do
    it 'returns the expected dates' do
      Timecop.freeze(Time.zone.parse("03/10/2018 09:00 -0400")) do
        Time.use_zone("America/New_York") do
          expected_beginning = Time.zone.now.yesterday.beginning_of_day.in_time_zone("UTC")
          expected_ending = Time.zone.now.yesterday.end_of_day.in_time_zone("UTC")

          beginning, ending = subject.get_yesterday_in_timezone("America/New_York")
          expect(beginning).to eql(expected_beginning)
          expect(ending).to eql(expected_ending)
        end
      end
    end
  end

  describe "get_bounced_emails_for_dates" do
    describe 'beginning date' do
      it 'retrieves emails after the beginning date' do
        Timecop.freeze(Time.zone.now) do
          beginning, ending = subject.get_yesterday_in_timezone("America/New_York")
          zero_hour_email = Factory(:sent_email, email_date: beginning, delivery_error: 'it dun goofed')
          after_beginning_email = Factory(:sent_email, email_date: beginning + 1.hour, delivery_error: 'really goofed')

          expect(subject.get_bounced_emails_for_dates(beginning, ending)).to include(zero_hour_email)
          expect(subject.get_bounced_emails_for_dates(beginning, ending)).to include(after_beginning_email)
        end
      end
    end

    describe 'ending date' do
      it 'retrieves emails before the ending date' do
        beginning, ending = subject.get_yesterday_in_timezone("America/New_York")
        zero_hour_email = Factory(:sent_email, email_date: ending, delivery_error: 'it dun goofed')
        after_beginning_email = Factory(:sent_email, email_date: ending - 1.hour, delivery_error: 'really goofed')

        expect(subject.get_bounced_emails_for_dates(beginning, ending)).to include(zero_hour_email)
        expect(subject.get_bounced_emails_for_dates(beginning, ending)).to include(after_beginning_email)
      end
    end

    it 'does not include emails before the beginning or after the ending date' do
      beginning, ending = subject.get_yesterday_in_timezone("America/New_York")
      before_beginning = Factory(:sent_email, email_date: beginning - 1.hour, delivery_error: 'it dun goofed')
      after_ending_email = Factory(:sent_email, email_date: ending + 1.hour, delivery_error: 'really goofed')

      expect(subject.get_bounced_emails_for_dates(beginning, ending)).to_not include(before_beginning)
      expect(subject.get_bounced_emails_for_dates(beginning, ending)).to_not include(after_ending_email)
    end

    it 'does not include emails without errors' do
      beginning, ending = subject.get_yesterday_in_timezone("America/New_York")
      bad_email = Factory(:sent_email, email_date: ending, delivery_error: 'it dun goofed')
      good_email = Factory(:sent_email, email_date: ending - 1.hour)

      expect(subject.get_bounced_emails_for_dates(beginning, ending)).to include(bad_email)
      expect(subject.get_bounced_emails_for_dates(beginning, ending)).to_not include(good_email)
    end
  end
end