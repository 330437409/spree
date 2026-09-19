module SpreeAdministrativeDivisions
  # Loads a shipped dataset release into +spree_administrative_divisions+.
  #
  # A release replaces the one before it rather than editing it: every row
  # records the +dataset_version+ it came from, the import writes the new
  # release level by level — so a child always finds its parent's id — and then
  # removes whatever the previous release left behind. Running it twice
  # changes nothing the second time, and a correction is a new release rather
  # than an update inside one.
  class Import
    prepend Spree::ServiceModule::Base

    LEVELS = %w[country province city district township].freeze

    # @param dataset_version [String] the release directory under data/administrative
    # @param levels [Array<String>] the levels to import; a host that has no use
    #   for townships imports the three above them and keeps a small table
    # @param data_root [Pathname] where the releases live
    # @return [Spree::ServiceModule::Result] with the release, the row counts and what was removed
    def call(dataset_version:, levels: LEVELS, data_root: default_data_root)
      @dataset_version = dataset_version
      @levels = levels.map(&:to_s) & LEVELS
      @release_dir = Pathname.new(data_root).join(dataset_version)

      return failure(:release_not_found) unless @release_dir.directory?

      rows = read_release
      return failure(:empty_release) if rows.empty?

      verify_codes!(rows)

      removed = nil
      Spree::AdministrativeDivision.transaction do
        write_levels(rows)
        removed = remove_previous_releases
      end

      success(summary(rows, removed))
    end

    private

    def default_data_root
      SpreeAdministrativeDivisions::Engine.root.join('data/administrative')
    end

    # The release is two files: everything above the township level, and the
    # townships. Either may be absent, and a file whose levels are not being
    # imported is not even read — the townships are 41k rows, and a host whose
    # pickers stop at the district level never pays for them.
    FILE_LEVELS = {
      'divisions.json' => %w[country province city district],
      'townships.json' => %w[township]
    }.freeze

    def read_release
      FILE_LEVELS.flat_map do |filename, levels|
        next [] if (levels & @levels).empty?

        file = @release_dir.join(filename)
        next [] unless file.exist?

        payload = JSON.parse(file.read)
        verify_release!(payload)

        payload.fetch('divisions').select { |row| @levels.include?(row['level']) }
      end
    end

    def verify_release!(payload)
      unless payload['dataset_version'] == @dataset_version
        raise ArgumentError,
              "the release in #{@release_dir} says #{payload['dataset_version'].inspect}, " \
              "not #{@dataset_version.inspect} — the directory names the release, so the two must agree"
      end

      # Provenance travels with the rows: a division answers where it came from
      # without anyone having to go back to the file.
      @source = payload['source']
      @source_updated_at = payload['source_updated_at']
    end

    # Level by level, because a row's parent id comes from the level above it
    # and does not exist until that level has been written.
    # A code names one node, so a release that carries one twice would have the
    # unique index decide which of the two survives — silently, and differently
    # on a second run. The publisher's own tree does repeat three cities under
    # their own code, which is why the shipped release resolves them at
    # preparation time and records what it dropped; a release that arrives with
    # duplicates anyway is refused here rather than half-imported.
    def verify_codes!(rows)
      duplicates = rows.map { |row| row['code'] }.tally.select { |_code, count| count > 1 }
      return if duplicates.empty?

      raise ArgumentError,
            "#{@dataset_version} carries duplicate codes: " \
            "#{duplicates.map { |code, count| "#{code} (#{count}×)" }.join(', ')}"
    end

    def write_levels(rows)
      LEVELS.each do |level|
        batch = rows.select { |row| row['level'] == level }
        next if batch.empty?

        parents = parent_ids_for(batch)
        Spree::AdministrativeDivision.upsert_all(
          batch.map { |row| attributes_for(row, parents) },
          **upsert_options
        )
      end
    end

    # MySQL infers the conflict target from the table's own unique index and
    # rejects an explicit `unique_by`, which PostgreSQL and SQLite require.
    def upsert_options
      return {} if Spree.mysql?

      { unique_by: :code }
    end

    def attributes_for(row, parents)
      timestamp = Time.current

      {
        code: row['code'],
        name: row['name'],
        level: row['level'],
        depth: row['depth'],
        parent_id: row['parent_code'] && parents[row['parent_code']],
        first_pinyin: row['first_pinyin'],
        pinyin: row['pinyin'],
        dataset_version: @dataset_version,
        source: @source,
        source_updated_at: @source_updated_at,
        created_at: timestamp,
        updated_at: timestamp
      }
    end

    def parent_ids_for(batch)
      codes = batch.map { |row| row['parent_code'] }.compact.uniq
      return {} if codes.empty?

      Spree::AdministrativeDivision.where(code: codes).pluck(:code, :id).to_h
    end

    # The table keeps exactly what this import wrote: rows from another release,
    # and rows of a level this import was not asked for. One statement, because
    # a removed node's children are themselves either older or out of scope, so
    # they leave with it rather than being orphaned.
    def remove_previous_releases
      Spree::AdministrativeDivision
        .where.not(dataset_version: @dataset_version)
        .or(Spree::AdministrativeDivision.where.not(level: @levels))
        .delete_all
    end

    def summary(rows, removed)
      {
        dataset_version: @dataset_version,
        source: @source,
        counts: rows.group_by { |row| row['level'] }.transform_values(&:size),
        removed: removed
      }
    end
  end
end
