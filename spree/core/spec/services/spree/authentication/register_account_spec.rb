require 'spec_helper'

describe Spree::Authentication::RegisterAccount do
  let(:store) { @default_store }
  let(:provider) { :social_test }

  before do
    Spree.store_authentication_strategies.add(provider, Spree::Authentication::Strategies::EmailPasswordStrategy)
  end

  after do
    Spree.store_authentication_strategies.remove(provider)
  end

  let(:profile) do
    Spree::Authentication::Profile.new(
      provider: provider.to_s, uid: 'subject-1', info: { first_name: 'Ada', last_name: 'Lovelace' }
    )
  end

  subject(:service) { described_class.new(profile: profile, store: store) }

  it 'registers the account through the customer workflow, password-less' do
    expect { @result = service.call(email: 'ada@example.com') }
      .to change(Spree.customer_class, :count).by(1)

    expect(@result).to be_authenticated
    expect(@result.user.email).to eq('ada@example.com')
    expect(@result.user.first_name).to eq('Ada')
    expect(@result.user.last_name).to eq('Lovelace')
    expect(@result.user.password_digest).to be_nil
  end

  # The workflow is what makes social sign-up obey a shop's registration
  # policy; running it is also what records the terms the shopper accepted.
  it 'records the terms consent the workflow would record for a form sign-up' do
    expect { service.call(email: 'ada@example.com', terms_of_service: true) }
      .to change(Spree::ConsentRecord, :count).by(1)
  end

  it 'attaches the identity so the next login resolves' do
    user = service.call(email: 'ada@example.com').user

    expect(Spree::UserIdentity.find_for(provider: provider.to_s, uid: 'subject-1')).to eq(user.identities.first)
  end

  it 'reports a taken address instead of registering a duplicate' do
    create(:user, email: 'ada@example.com')

    expect(service.call(email: 'ada@example.com')).to be_email_taken
    expect(Spree.customer_class.where(email: 'ada@example.com').count).to eq(1)
  end

  it 'reports a registration the workflow refused' do
    result = service.call(email: '')

    expect(result).to be_invalid
    expect(result.record_errors).to be_present
  end

  it 'prefers a name the shopper supplied over the provider claim' do
    result = service.call(email: 'ada@example.com', first_name: 'Augusta')

    expect(result.user.first_name).to eq('Augusta')
  end
end
