module Spree
  module Api
    module V3
      module Store
        # The administrative tree, read-only and public: the address pickers,
        # the seller-join form and the service-area binding all read it, and so
        # does a customer's own address form before they have signed in.
        #
        # One collection answers the client's three calls, because they differ
        # in filter rather than in shape: `parent_code` is its lazy cascade,
        # `keywords` is its search, and no `level` at all is the province list
        # its location page opens with.
        #
        # Cached by release and filter. The tree changes only when a new
        # `dataset_version` is imported, which is a different key rather than an
        # invalidation, so an entry never goes stale inside its release — and
        # nothing here has to be cleared when one arrives.
        class AdministrativeDivisionsController < Store::BaseController
          allow_guest_storefront_access!

          DEFAULT_LEVEL = 'province'.freeze

          # GET /api/v3/store/administrative_divisions
          def index
            render json: Rails.cache.fetch(cache_key) { renderable }
          end

          private

          def renderable
            { data: divisions.map { |division| serialize(division) } }
          end

          def serialize(division)
            serializer_class.new(division, params: serializer_params.merge(parents_with_children: parents_with_children)).to_h
          end

          def divisions
            @divisions ||= filtered.to_a
          end

          def filtered
            scope = Spree::AdministrativeDivision.order(:depth, :first_pinyin)

            if params[:parent_code].present?
              # Addressed by code, because that is what survives a re-import. A
              # code the release no longer carries answers an empty list rather
              # than an error: a picker whose step disappeared shows nothing,
              # which is the truth, and the client reloads the tree around it.
              #
              # Nil is not "no parent": a node with no parent is the root, so
              # matching on it would answer the top of the tree to a question
              # about a node that does not exist.
              parent_id = parent_id_from_code
              return Spree::AdministrativeDivision.none if parent_id.nil?

              scope.where(parent_id: parent_id)
            elsif params[:keywords].present?
              # The picker's search box: a customer or an operator types a name,
              # and the dataset carries the romanisation for the other half of
              # that question.
              keyword = "%#{params[:keywords].strip}%"
              scope.where('name LIKE :keyword OR pinyin LIKE :keyword', keyword: keyword)
            else
              scope.at_level(params[:level].presence || DEFAULT_LEVEL)
            end
          end

          def parent_id_from_code
            @parent_id_from_code ||= Spree::AdministrativeDivision.where(code: params[:parent_code]).limit(1).pick(:id)
          end

          # One query for the page, rather than one per node.
          def parents_with_children
            @parents_with_children ||= Spree::AdministrativeDivision
                                       .where(parent_id: divisions.map(&:id))
                                       .distinct
                                       .pluck(:parent_id)
                                       .to_set
          end

          # The release is the version half of the key, so a new import is a new
          # key; the rest is the filter, so the province list and one page of one
          # province's children do not share an entry.
          def cache_key
            [
              'spree_administrative_divisions/tree',
              Spree::AdministrativeDivision.current_dataset_version,
              params[:parent_code].presence || params[:keywords].presence || (params[:level].presence || DEFAULT_LEVEL)
            ].compact.join('/')
          end

          def serializer_class
            Spree::Api::V3::Store::AdministrativeDivisionSerializer
          end
        end
      end
    end
  end
end
