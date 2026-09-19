module Spree
  module Api
    module V3
      # The administrative tree as a picker reads it, shared by every surface
      # that binds a node: the storefront's address form, the dashboard's
      # warehouse form and the seller's own.
      #
      # One collection answers all of their calls, because they differ in filter
      # rather than in shape: `parent_code` is the lazy cascade, `keywords` is
      # the search box, and no filter at all is the province list a picker opens
      # with.
      #
      # The data is global reference data — no store scoping, nothing a caller
      # can see more or less of — so the three surfaces differ only in who may
      # ask, which each controller's base decides.
      module AdministrativeTree
        extend ActiveSupport::Concern

        DEFAULT_LEVEL = 'province'.freeze

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
            # and the dataset carries the romanisation for the other half of that
            # question.
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
