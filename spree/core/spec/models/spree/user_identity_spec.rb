require 'spec_helper'

describe Spree::UserIdentity, type: :model do
  let(:store) { @default_store }
  let(:provider) { 'email' }
  let(:uid) { '123456789' }
  let(:tokens) do
    {
      access_token: 'access_token_123',
      refresh_token: 'refresh_token_456',
      expires_at: 1.hour.from_now
    }
  end
  let(:profile) do
    Spree::Authentication::Profile.new(
      provider: provider,
      uid: uid,
      email: 'user@example.com',
      email_verified: true,
      info: { first_name: 'John', last_name: 'Doe' },
      tokens: tokens
    )
  end

  describe 'validations' do
    subject { build(:user_identity) }

    it 'validates provider is a registered authentication strategy' do
      identity = build(:user_identity, provider: 'unsupported')
      expect(identity).not_to be_valid
      expect(identity.errors[:provider]).to include('is not included in the list')
    end

    describe 'uniqueness validation' do
      let(:user) { create(:user) }
      let!(:existing_identity) do
        create(:user_identity, user: user, provider: 'email', uid: '12345')
      end

      it 'validates uniqueness of uid scoped to provider and user_type' do
        duplicate = build(:user_identity, user: user, provider: 'email', uid: '12345')
        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:uid]).to include('has already been taken')
      end

      it 'allows same uid for different providers' do
        Spree.store_authentication_strategies.add(:other, Class.new)
        different_provider = build(:user_identity, user: user, provider: 'other', uid: '12345')
        expect(different_provider).to be_valid
      ensure
        Spree.store_authentication_strategies.remove(:other)
      end

      it 'allows same uid for different user types' do
        stub_const('Spree::AdminUser', Class.new(Spree.customer_class))

        different_user_type = build(:user_identity, user_type: 'Spree::AdminUser', user_id: user.id, provider: 'email', uid: '12345')
        expect(different_user_type).to be_valid
      end
    end
  end

  describe '.find_for' do
    let!(:user) { create(:user) }
    let!(:identity) { create(:user_identity, user: user, provider: provider, uid: uid) }

    it 'finds the identity for the user class' do
      expect(described_class.find_for(provider: provider, uid: uid)).to eq(identity)
    end

    it 'does not match an identity belonging to another user class' do
      stub_const('Spree::AdminUser', Class.new(Spree.customer_class))

      expect(described_class.find_for(provider: provider, uid: uid, user_class: Spree::AdminUser)).to be_nil
    end
  end

  describe '.attach_to' do
    let(:user) { create(:user) }

    it 'records the identity, profile and tokens on the account' do
      identity = described_class.attach_to(user, profile)

      expect(identity.user).to eq(user)
      expect(identity.provider).to eq(provider)
      expect(identity.uid).to eq(uid)
      expect(identity.access_token).to eq('access_token_123')
      expect(identity.refresh_token).to eq('refresh_token_456')
      expect(identity.expires_at).to be_within(1.second).of(tokens[:expires_at])
      expect(identity.info).to include('first_name' => 'John')
    end

    it 'updates the account identity instead of adding a second one' do
      existing = described_class.attach_to(user, profile)
      described_class.attach_to(
        user,
        Spree::Authentication::Profile.new(provider: provider, uid: uid, info: { first_name: 'Jane' },
                                           tokens: { access_token: 'new_token' })
      )

      expect(described_class.where(provider: provider, uid: uid).count).to eq(1)
      expect(existing.reload.access_token).to eq('new_token')
      expect(existing.info).to include('first_name' => 'Jane')
    end

    # Two first logins racing on one provider subject: the uniqueness rule
    # rejects the loser, which then re-reads the winner rather than raising.
    it 're-reads the winner when a concurrent login already claimed the subject' do
      winner_identity = described_class.attach_to(create(:user), profile)
      loser = create(:user)

      expect(described_class.attach_to(loser, profile)).to eq(winner_identity)
      expect(described_class.where(provider: provider, uid: uid).count).to eq(1)
    end
  end

  describe '.refresh_from' do
    let!(:identity) do
      create(:user_identity, provider: provider, uid: uid, access_token: 'old_token', refresh_token: 'old_refresh')
    end

    it 'updates the info and the tokens the provider returned' do
      described_class.refresh_from(identity, profile)

      identity.reload
      expect(identity.access_token).to eq('access_token_123')
      expect(identity.refresh_token).to eq('refresh_token_456')
      expect(identity.info).to include('first_name' => 'John')
    end

    # A provider that returns no new token (Weibo issues no refresh token, for
    # one) must not blank the stored one.
    it 'keeps stored tokens the provider did not return' do
      described_class.refresh_from(
        identity,
        Spree::Authentication::Profile.new(provider: provider, uid: uid, info: { first_name: 'Jane' }, tokens: {})
      )

      identity.reload
      expect(identity.access_token).to eq('old_token')
      expect(identity.refresh_token).to eq('old_refresh')
      expect(identity.info).to include('first_name' => 'Jane')
    end
  end

  describe '.find_or_create_from_oauth' do
    let(:info) { { email: 'shopper@example.com', first_name: 'John', last_name: 'Doe', email_verified: true } }

    context 'when the identity does not exist' do
      it 'creates the account through the registration workflow' do
        expect do
          @user = described_class.find_or_create_from_oauth(
            provider: provider, uid: uid, info: info, tokens: tokens, store: store
          )
        end.to change(Spree.customer_class, :count).by(1)
           .and change(described_class, :count).by(1)

        expect(@user.email).to eq('shopper@example.com')
        expect(@user.first_name).to eq('John')
        expect(@user.last_name).to eq('Doe')
      end

      # The shopper authenticated with the provider, so the account carries no
      # password — it is claimed later through password reset, exactly like an
      # account the checkout "create an account" box creates.
      it 'creates the account without a password' do
        user = described_class.find_or_create_from_oauth(
          provider: provider, uid: uid, info: info, tokens: tokens, store: store
        )

        expect(user.password_digest).to be_nil
      end

      it 'adopts an existing account whose address the provider verified' do
        existing = create(:user, email: 'shopper@example.com')

        user = described_class.find_or_create_from_oauth(
          provider: provider, uid: uid, info: info, tokens: tokens, store: store
        )

        expect(user).to eq(existing)
        expect(existing.identities.reload.count).to eq(1)
      end

      # Linking on an unverified address is how a shopper claims someone
      # else's account, so the claim is refused and registration fails on the
      # address already being taken.
      it 'refuses an address the provider did not verify' do
        create(:user, email: 'shopper@example.com')

        expect do
          described_class.find_or_create_from_oauth(
            provider: provider, uid: uid, info: info.merge(email_verified: false), tokens: tokens, store: store
          )
        end.to raise_error(ActiveRecord::RecordInvalid)
      end

      it 'asks for a registration instead of inventing an address' do
        before_count = Spree.customer_class.count

        expect do
          described_class.find_or_create_from_oauth(
            provider: provider, uid: uid, info: { first_name: 'John' }, tokens: tokens, store: store
          )
        end.to raise_error(Spree::Authentication::RegistrationRequired)

        expect(Spree.customer_class.count).to eq(before_count)
        expect(described_class.find_for(provider: provider, uid: uid)).to be_nil
      end

      # Staff accounts sit outside the storefront registration flow, so a
      # strategy the merchant wrote for them keeps creating its own account.
      it 'creates a staff account for a custom user class' do
        expect do
          @admin = described_class.find_or_create_from_oauth(
            provider: provider, uid: uid, info: info, tokens: tokens, store: store,
            user_class: Spree.admin_user_class
          )
        end.to change(Spree.admin_user_class, :count).by(1)

        expect(@admin).to be_a(Spree.admin_user_class)
        expect(
          described_class.find_for(provider: provider, uid: uid, user_class: Spree.admin_user_class)
        ).to be_present
      end
    end

    context 'when the identity already exists' do
      let!(:user) { create(:user, email: 'existing@example.com') }
      let!(:identity) do
        create(:user_identity, user: user, provider: provider, uid: uid,
                               access_token: 'old_token', refresh_token: 'old_refresh')
      end

      it 'does not create a new account' do
        expect do
          described_class.find_or_create_from_oauth(
            provider: provider, uid: uid, info: info, tokens: tokens, store: store
          )
        end.not_to change(Spree.customer_class, :count)
      end

      it 'returns the existing account' do
        expect(
          described_class.find_or_create_from_oauth(
            provider: provider, uid: uid, info: info, tokens: tokens, store: store
          )
        ).to eq(user)
      end

      it 'updates the identity tokens and info' do
        described_class.find_or_create_from_oauth(
          provider: provider, uid: uid, info: info, tokens: tokens, store: store
        )

        identity.reload
        expect(identity.access_token).to eq('access_token_123')
        expect(identity.refresh_token).to eq('refresh_token_456')
        expect(identity.expires_at).to be_within(1.second).of(tokens[:expires_at])
        expect(identity.info).to include('first_name' => 'John')
      end
    end
  end

  describe '#expired?' do
    context 'when expires_at is nil' do
      subject { build(:user_identity, expires_at: nil) }

      it { is_expected.not_to be_expired }
    end

    context 'when expires_at is in the future' do
      subject { build(:user_identity, expires_at: 1.hour.from_now) }

      it { is_expected.not_to be_expired }
    end

    context 'when expires_at is in the past' do
      subject { build(:user_identity, expires_at: 1.hour.ago) }

      it { is_expected.to be_expired }
    end
  end
end
