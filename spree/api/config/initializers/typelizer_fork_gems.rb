# The fork's own gems ship store serializers too — the membership wallet, the tier
# ladder, the scenario purchase, the points account — and every one of them is
# reachable through the same /api/v3/store the client calls. They belong in the
# generated types exactly as core's do (docs/plans/6.1-type-generation-for-fork-gems.md).
#
# Registered by scanning the engines that are *loaded*, rather than by each gem
# announcing itself: an application without a gem reports nothing for it, which is
# what keeps spree/api's own test app generating the core types alone, and a new
# fork gem is picked up without touching this file. A gem that must stay out of the
# generated types is excluded where core's own are, in `typelizer.rb`'s writer
# filters.
#
# This file must load *after* `typelizer.rb`, which assigns `config.dirs` outright:
# the file name orders it, and renaming it to sort earlier would silently drop these
# directories — and the next generation prunes what it does not write.
#
# Nothing here is enough on its own: the generation needs an application with every
# gem installed, because Typelizer prunes the directories it writes. That is the
# starter — `scripts/types/generate` runs it there.
Rails.application.config.after_initialize do
  Typelizer.configure do |config|
    config.dirs |= Rails::Engine.descendants.filter_map do |engine|
      path = engine.root.join('app/serializers/spree/api/v3')
      path if path.directory?
    end
  end
end
