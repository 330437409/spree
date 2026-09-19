namespace :spree do
  namespace :administrative_divisions do
    desc <<~DESC
      Imports the Chinese administrative tree from a release shipped with the gem.

      Releases live in the gem under data/administrative/<dataset_version>/, and
      the task defaults to the newest one:

        bin/rails spree:administrative_divisions:import                # newest release, every level
        bin/rails spree:administrative_divisions:import[nbs-2023-06-30] # a named release
        LEVELS=country,province,city,district bin/rails ...            # skip the 41k townships

      A release replaces the one before it — every row records the release it came
      from, and rows from older releases are removed in the same transaction — so
      this is safe to run again, and a correction is a new release rather than an
      edit. Reference data is never edited in the admin UI.
    DESC
    task :import, [:dataset_version] => :environment do |_task, args|
      releases = Dir[SpreeAdministrativeDivisions::Engine.root.join('data/administrative/*')]
                 .select { |dir| File.directory?(dir) }
                 .map { |dir| File.basename(dir) }
                 .sort

      version = args[:dataset_version] || releases.last

      if version.nil?
        abort 'No release is shipped with this gem — expected a directory under data/administrative/.'
      end

      unless releases.include?(version)
        abort "Unknown release #{version.inspect}. Shipped releases: #{releases.join(', ')}."
      end

      levels = ENV['LEVELS'].presence&.split(',')&.map(&:strip)
      result = SpreeAdministrativeDivisions::Import.call(
        dataset_version: version,
        **levels ? { levels: levels } : {}
      )

      if result.failure?
        abort "Import failed: #{result.value}"
      end

      summary = result.value
      puts "Imported #{version} (#{summary[:source]})"
      summary[:counts].each { |level, count| puts "  #{level}: #{count}" }
      puts "  removed from older releases: #{summary[:removed]}" if summary[:removed].positive?
    end
  end
end
