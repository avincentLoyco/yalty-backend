require "rails_helper"

RSpec.describe API::V1::ServiceOffersController, type: :controller do
  include_context "shared_context_headers"

  before do
    ENV["YALTY_SERVICE_EMAIL"] = "yalty@service.com"
    allow(ServiceRequestMailer).to receive(:book_request).and_call_original
    allow(ServiceRequestMailer).to receive(:quote_request).and_call_original
  end

  let(:params) do
    {
      "data": {
        "employee-administration": {
          "payroll-outsourcing": {
            "toggle": true,
            "num-of-employees": 3,
            "from-when": "2017-02-01",
            "meta": {
              "recurring": 150,
              "onetime": 67.5,
            },
          },
          "hr-administration": {
            "toggle": true,
            "meta": {
              "recurring": 51,
              "onetime": 0,
            },
          },
          "sickness-accident-mgmt": {
            "toggle": true,
            "meta": {
              "recurring": 27,
              "onetime": 0,
            },
          },
        },
        "enterprise-administration": {
          "accounting": {
            "toggle": true,
            "num-of-accounting-pieces": "301-500 p/year",
            "num-of-intermediate-closing": 3,
            "meta": {
              "recurring": 912.5,
              "onetime": 1500,
            },
          },
          "taxation": {
            "toggle": true,
            "handle-tax-declaration": true,
            "hours-of-consulting": 2,
            "meta": {
              "recurring": 80,
              "onetime": 400,
            },
          },
          "enterprise-creation": {
            "toggle": true,
            "juridic-form": "SARL",
            "meta": {
              "recurring": 0,
              "onetime": 3000,
            },
          },
          "hr-consulting": {
            "toggle": true,
            "num-of-hours": 2,
            "meta": {
              "recurring": 0,
              "onetime": 400,
            },
          },
        },
        "marketing-communication": {
          "website-creation": {
            "toggle": true,
            "num-of-pages": 2,
            "photo-shooting": true,
            "meta": {
              "recurring": 0,
              "onetime": 2800,
            },
          },
          "social-networks": {
            "toggle": true,
            "network-list": [
              "Twitter",
              "LinkedIn",
            ],
            "animate": true,
            "meta": {
              "recurring": 500,
              "onetime": 700,
            },
          },
          "creative-content-creation": {
            "toggle": true,
            "num-of-logos": 1,
            "num-of-material-packages": 1,
            "num-of-photo-shooting": 0,
            "meta": {
              "recurring": 0,
              "onetime": 3000,
            },
          },
          "marketing-campaign": {
            "toggle": true,
            "num-of-email-campaigns": 1,
            "num-of-social-network-campaigns": 3,
            "meta": {
              "recurring": 0,
              "onetime": 3200,
            },
          },
          "promotional-movie": {
            "toggle": true,
            "minutes-of-promotional-video": 2,
            "minutes-of-video-reportage": 2,
            "num-of-voiceover-packages": 3,
            "meta": {
              "recurring": 0,
              "onetime": 13050,
            },
          },
        },
        "it": {
          "it-consulting": {
            "toggle": true,
            "num-of-hours": 3,
            "meta": {
              "recurring": 0,
              "onetime": 600,
            },
          },
        },
        "logistics": {
          "logistics-support": {
            "toggle": true,
            "num-of-hours": 1,
            "meta": {
              "recurring": 0,
              "onetime": 150,
            },
          },
        },
      },
      "meta": {
        "action": service_action,
        "costs": {
          "recurring": 1720.5,
          "onetime": 28867.5,
        },
      },
    }.with_indifferent_access
  end

  describe "POST #create" do
    subject { post :create, params }

    context "with book-now action" do
      let(:service_action) { "book-now" }

      it { is_expected.to have_http_status(204) }
      it { expect { subject }.to change(ActionMailer::Base.deliveries, :count) }
      it "calls ServiceRequestMailer" do
        subject
        expect(ServiceRequestMailer)
          .to have_received(:book_request)
          .with(Account.current, Account::User.current, anything)
      end
    end

    context "with send-quote action" do
      let(:service_action) { "send-quote" }

      it { is_expected.to have_http_status(204) }
      it { expect { subject }.to change(ActionMailer::Base.deliveries, :count) }
      it "calls ServiceRequestMailer" do
        subject
        expect(ServiceRequestMailer)
          .to have_received(:quote_request)
          .with(Account.current, Account::User.current, anything)
      end
    end
  end
end
