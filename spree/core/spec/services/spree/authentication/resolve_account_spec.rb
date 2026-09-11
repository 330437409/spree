require 'spec_helper'

describe Spree::Authentication::ResolveAccount do
  let(:store) { @default_store }
  let(:provider) { :social_test }

  before do
    Spree.store_authentication_strategies.add(provider, Spree::Authentication::Strategies::EmailPasswordStrategy)
  end

  after do
    Spree.store_authentication_strategies.remove(provider)
  end

  def profile(email: nil, email_verified: nil, uid: 'subject-1', info: {})
    Spree::Authentication::Profile.new(
      provider: provider.to_s, uid: uid, email: email, email_verified: email_verified, info: info
    )
  end

  def resolve(user_class: nil, **args)
    described_class.new(profile: profile(**args), store: store, user_class: user_class).call
  end

  it 'requires a store' do
    expect do
      described_class.new(profile: profile(email: 'ada@example.com'), store: nil).call
    end.to raise_error(ArgumentError, /store/)
  end

  context 'when the identity is known' do
    let!(:customer) { create(:user) }
    let!(:identity) do
      create(:user_identity, user: customer, provider: provider.to_s, uid: 'subject-1',
                             access_token: 'old_token')
    end

    it 'signs the account in and refreshes the stored profile' do
      result = described_class.new(
        profile: Spree::Authentication::Profile.new(provider: provider.to_s, uid: 'subject-1',
                                                    info: { first_name: 'Ada' }, tokens: { access_token: 'new_token' }),
        store: store
      ).call

      expect(result).to be_authenticated
      expect(result.user).to eq(customer)
      expect(identity.reload.access_token).to eq('new_token')
      expect(identity.info).to include('first_name' => 'Ada')
    end
  end

  context 'when an account already holds the address the provider verified' do
    let!(:customer) { create(:user, email: 'ada@example.com') }

    it 'adopts that account instead of registering a second one' do
      expect { @result = resolve(email: 'ada@example.com', email_verified: true) }
        .not_to change(Spree.customer_class, :count)

      expect(@result).to be_authenticated
      expect(@result.user).to eq(customer)
      expect(customer.identities.reload.count).to eq(1)
    end

    # The address is only evidence when the provider says it verified it.
    it 'refuses the address when the claim is not verified' do
      expect(resolve(email: 'ada@example.com', email_verified: nil)).to be_email_taken
    end

    it 'refuses the address when the provider explicitly says it is unverified' do
      expect(resolve(email: 'ada@example.com', email_verified: false)).to be_email_taken
    end

    it 'adopts the account when the integration trusts the provider directory' do
      result = described_class.new(
        profile: profile(email: 'ada@example.com', email_verified: nil),
        store: store,
        trust_unverified_email: true
      ).call

      expect(result).to be_authenticated
      expect(result.user).to eq(customer)
    end
  end

  context 'when no account exists and the provider returned an address' do
    it 'registers the account through the customer workflow' do
      expect { @result = resolve(email: 'new@example.com', email_verified: true, info: { first_name: 'Ada' }) }
        .to change(Spree.customer_class, :count).by(1)

      expect(@result).to be_authenticated
      expect(@result.user.email).to eq('new@example.com')
      expect(@result.user.first_name).to eq('Ada')
      expect(@result.user.password_digest).to be_nil
    end
  end

  context 'when the provider returned no address' do
    it 'asks for a registration and creates nothing' do
      expect { @result = resolve(uid: 'subject-2') }.not_to change(Spree.customer_class, :count)

      expect(@result).to be_registration_required
      expect(@result.profile.uid).to eq('subject-2')
    end
  end

  context 'when the user class is never provisioned by a provider' do
    it 'refuses instead of creating staff' do
      expect do
        resolve(email: 'staff@example.com', email_verified: true, user_class: Spree.admin_user_class)
      end.not_to change(Spree.admin_user_class, :count)

      expect(resolve(email: 'staff@example.com', email_verified: true, user_class: Spree.admin_user_class))
        .to be_account_not_provisioned
    end
  end
end
