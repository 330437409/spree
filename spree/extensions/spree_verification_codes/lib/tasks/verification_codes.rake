namespace :spree do
  namespace :verification_codes do
    # Issues a code and prints it.
    #
    # The API never returns or logs a code — that is the point of the digest —
    # so this is how a person walks the flows by hand without an SMS account,
    # and how an operator proves the rest of the path works before the vendor
    # is configured. It refuses in production: a task that mints a credential
    # and prints it is a development tool, not an operator's route.
    #
    #   bin/rails spree:verification_codes:issue[13800138000,account]
    desc 'Issue a verification code for a phone and print it (never in production)'
    task :issue, %i[phone purpose] => :environment do |_task, args|
      if Rails.env.production?
        abort 'Refused: this task prints a credential and does not run in production.'
      end

      purpose = args[:purpose].presence || 'account'
      store = Spree::Store.default || Spree::Store.first
      abort 'No store to issue a code for.' if store.nil?

      unless Spree::VerificationCode::PURPOSES.include?(purpose)
        abort "Unknown purpose #{purpose.inspect}, expected one of #{Spree::VerificationCode::PURPOSES.join(', ')}."
      end

      phone = Spree::VerificationCode.normalize_phone(args[:phone])
      abort 'A phone number is required.' if phone.blank?

      plaintext = format('%06d', SecureRandom.random_number(1_000_000))
      expires_at = store.preferred_verification_code_ttl_minutes.minutes.from_now

      record = Spree::VerificationCode.create!(
        store: store, phone: phone, purpose: purpose, channel: 'sms',
        code: plaintext, expires_at: expires_at
      )

      puts "#{record.phone} (#{record.purpose}): #{plaintext} — valid until #{expires_at} (UTC)"
    end
  end
end
