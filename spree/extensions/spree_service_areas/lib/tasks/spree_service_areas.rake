namespace :spree do
  namespace :service_areas do
    desc 'Add "the seller has a service area" to every store\'s onboarding checklist'
    task install_requirement: :environment do
      Spree::Store.find_each do |store|
        if store.seller_requirements.exists?(type: SpreeServiceAreas::ServiceAreaRequirement.name)
          puts "#{store.name}: already on the checklist"
          next
        end

        # Last, and required: it is the one item a seller can only finish after
        # the warehouse exists, so putting it anywhere else makes the panel's
        # progress read as if something were missing that cannot be added yet.
        SpreeServiceAreas::ServiceAreaRequirement.create!(
          store: store,
          position: (store.seller_requirements.maximum(:position) || 0) + 1,
          active: true,
          required: true
        )

        puts "#{store.name}: added the service-area requirement"
      end
    end
  end
end
