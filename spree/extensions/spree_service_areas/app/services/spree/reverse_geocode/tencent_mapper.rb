module Spree
  module ReverseGeocode
    # Tencent's answer turned into bureau codes.
    #
    # The vendor speaks the bureau's language at the level it resolved: its
    # `adcode` is a GB/T 2260 code, so nothing has to be translated to find the
    # district — the levels above it are read off the imported tree, and the
    # township is matched by name inside that district. A name a vendor spells
    # differently from the bureau is what a shipped exceptions file is for
    # (`spree_administrative_divisions`' data directory holds those per vendor),
    # and no exception is needed today: a township that does not match costs the
    # precision of the match, never its answer.
    class TencentMapper
      # @param result [Spree::ReverseGeocode::Result] the provider's own terms
      # @return [Hash<Symbol, String>] the bureau codes that resolved
      def call(result)
        division = division_for(result)
        return {} if division.nil?

        {
          province: ancestor_code(division, 'province'),
          city: ancestor_code(division, 'city'),
          district: ancestor_code(division, 'district'),
          township: township_code(division, result)
        }.compact
      end

      private

      # The code names the deepest division the vendor resolved, which is
      # usually the district and occasionally a level above it — a whole city in
      # a municipality, a county-administered point. The names are the fallback
      # for an answer that carries no code at all.
      def division_for(result)
        find_by_code(result.district_code) || find_by_names(result)
      end

      def find_by_code(code)
        return nil if code.blank?

        Spree::AdministrativeDivision.find_by(code: code)
      end

      def find_by_names(result)
        province = division_named(result.province_name, 'province')
        city = division_named(result.city_name, 'city', parent: province)
        district = division_named(result.district_name, 'district', parent: city || province)

        district || city || province
      end

      def division_named(name, level, parent: nil)
        return nil if name.blank?

        scope = Spree::AdministrativeDivision.at_level(level).where(name: name)
        scope = scope.where(parent_id: parent.id) if parent.present?

        scope.order(:depth).first
      end

      def ancestor_code(division, level)
        return division.code if division.level == level
        return nil if division.parent.nil?

        ancestor_code(division.parent, level)
      end

      def township_code(division, result)
        return nil if result.town_name.blank?

        district = division.level == 'district' ? division : ancestor_division(division, 'district')
        return nil if district.nil?

        district.children.at_level('township').find_by(name: result.town_name)&.code
      end

      def ancestor_division(division, level)
        return division if division.level == level
        return nil if division.parent.nil?

        ancestor_division(division.parent, level)
      end
    end
  end
end
