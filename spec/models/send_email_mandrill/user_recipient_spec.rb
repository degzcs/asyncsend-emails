require 'spec_helper'

describe 'SendEmailMandrill::Users::Recipient' do

  context "build user recipients" do
    it "given ONE user recipient setup the params called TO and the MERGE_VARS" do
      user_with_emails = create(:user, email: 'user_test1@example.com')

      recipient = SendEmailMandrill::Users::Recipient.wrap(user_with_emails)
      recipient.to[:email].should include("user_test1@example.com")
      recipient.to[:name].should_not be_empty
      recipient.merge_vars[:rcpt].should include("user_test1@example.com")
      recipient.merge_vars[:vars].each do |var|
        var.values_at(:content).should_not be_empty
      end
    end
  end
end
