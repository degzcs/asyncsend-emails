require 'spec_helper'

describe SendEmailMandrill::Users do
  context "send transactional email to all users" do

    it "should be send info letters to one user" do
      diego_tenant = create(:user,email: 'diego.gomez@codescrum.com')

      MandrillOperation.create(service: 'SendEmailMandrill::Users::Service',
                               description: 'send template by email',
                               method_name: 'send_template',
      )

      service = SendEmailMandrill::Users::Service
      response = service.send_template_to('user_id' => diego_tenant.id) #params
      response.first['status'].should include("sent")
    end
  end
end