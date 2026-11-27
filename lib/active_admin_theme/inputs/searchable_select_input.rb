module ActiveAdminTheme
  module Inputs
    # f.input :customer, as: :searchable_select
    # filter :customer, as: :searchable_select
    #
    # A <select> holding only the selected record(s); the script loads the rest
    # from a `searchable_select_options` endpoint. The README lists the options.
    module SearchableSelectBehavior
      OPTION_KEYS = %i[url resource options_name placeholder depends_on depends_param depends_placeholder depends_optional auto_select_single load_all min_chars per_page].freeze

      def formtastic_options
        super + OPTION_KEYS
      end

      def input_html_options
        html = super
        html.merge(data: (html[:data] || {}).merge(searchable_select_data))
      end

      # Only the selected records: the rest come from the endpoint, so the
      # association's whole table is never rendered into the page.
      def collection_from_association
        klass = searchable_select_class
        source = searchable_select_source if klass
        value = source ? source[:value] : klass&.primary_key
        if value.respond_to?(:call)
          raise ArgumentError, "searchable_select input :#{method} cannot find the selected record of searchable_select_options :#{source[:name]}: value: must be an attribute, not a lambda"
        end

        values = searchable_select_selected_values if object && klass
        return [] if values.blank?

        label = options[:member_label] || source&.dig(:label)
        scope = ActiveAdminTheme::SearchableSelect.selected_scope(template.controller, searchable_select_resource, source, klass)
        found = scope.where(value => values).map do |record|
          # Formtastic's own label_method reads the collection being built here.
          method = label || builder.collection_label_methods.find { |name| record.respond_to?(name) }
          # The endpoint runs a label lambda in its controller; so does the page.
          text = method.respond_to?(:call) ? template.controller.instance_exec(record, &method) : record.public_send(method)
          [text, record.public_send(value)]
        end
        # A value the user may not read keeps its option, labelled with the
        # value itself, so saving the form does not clear it.
        found + (values.map(&:to_s) - found.map { |_, id| id.to_s }).map { |id| [id, id] }
      end

      private

      # A filter whose values a plugin moved into a Ransack grouping (an OR with
      # `_null`, for one) reads them back from the request instead.
      def searchable_select_selected_values
        values = Array(object.public_send(input_name)).flatten.compact_blank
        if values.empty? && object.is_a?(::Ransack::Search)
          values = Array(template.params.dig(:q, input_name)).flatten.compact_blank
        end
        none = ActiveAdminFilterExtensions.none_value if defined?(ActiveAdminFilterExtensions) && ActiveAdminFilterExtensions.respond_to?(:none_value)
        none ? values - [none] : values
      end

      def searchable_select_data
        data = {searchable_select: true, searchable_select_url: searchable_select_url}
        data[:placeholder] = options[:placeholder] if options[:placeholder]
        data[:searchable_select_load_all] = true if options[:load_all]
        data[:searchable_select_min_chars] = options[:min_chars] if options[:min_chars]
        data[:searchable_select_per_page] = options[:per_page] if options[:per_page]
        data[:searchable_select_auto_select] = true if options[:auto_select_single]
        if (parents = options[:depends_on])
          if parents.is_a?(Array)
            data[:searchable_select_parents] = parents.map { |parent| {name: "#{object_name}[#{parent}]", param: searchable_select_parent_param(parent)} }.to_json
          else
            data[:searchable_select_parent_name] = "#{object_name}[#{parents}]"
            data[:searchable_select_parent_param] = searchable_select_parent_param(parents)
          end
          data[:searchable_select_parent_optional] = true if options[:depends_optional]
          data[:searchable_select_parent_placeholder] = options[:depends_placeholder] if options[:depends_placeholder]
        end
        data
      end

      # `depends_param:` is a Hash of parent => param, or a String for one parent.
      def searchable_select_parent_param(parent)
        given = options[:depends_param]
        if given.is_a?(Hash)
          given = given.stringify_keys[parent.to_s]
        elsif given && Array(options[:depends_on]).size > 1
          raise ArgumentError, "searchable_select input :#{method} has several depends_on: parents, so depends_param: must be a Hash of parent => param"
        end
        given || (Ransack::Predicate.detect_from_string(parent.to_s) ? "q[#{parent}]" : "q[#{parent}_eq]")
      end

      def searchable_select_url
        url = options[:url]
        return template.instance_exec(&url).to_s if url.respond_to?(:call)
        return url.to_s if url

        resource = searchable_select_resource
        raise ArgumentError, "searchable_select input :#{method} needs url: or an association to a registered resource" unless resource

        resource.searchable_select_path(options[:options_name] || :all)
      end

      # The declaration the endpoint comes from; nil with `url:` or without a resource.
      def searchable_select_source
        return if options[:url]

        searchable_select_resource&.searchable_select_sources&.[]((options[:options_name] || :all).to_sym)
      end

      def searchable_select_resource
        target = options[:resource] || searchable_select_class
        return target if target.is_a?(ActiveAdmin::Resource)

        namespace = template.respond_to?(:active_admin_namespace) ? template.active_admin_namespace : ActiveAdmin.application.namespace(:admin)
        namespace.resource_for(target) if target
      end

      def searchable_select_class
        target = options[:resource]
        return target.resource_class if target.is_a?(ActiveAdmin::Resource)
        return target if target

        reflection.klass if reflection && !reflection.polymorphic?
      end
    end
  end
end

module ActiveAdminTheme
  module Inputs
    # f.input :status, as: :select, tom_select: {create: true, persist: false}
    #
    # `tom_select:` on any select input: a hash of Tom Select settings for this
    # select, true to upgrade it, false to leave it native.
    module TomSelectOption
      def input_html_options
        html = super
        return html unless options.key?(:tom_select)

        html.merge(data: (html[:data] || {}).merge(tom_select: options[:tom_select]))
      end
    end
  end
end

Formtastic::Inputs::SelectInput.prepend ActiveAdminTheme::Inputs::TomSelectOption unless Formtastic::Inputs::SelectInput < ActiveAdminTheme::Inputs::TomSelectOption

module ActiveAdmin
  module Inputs
    class SearchableSelectInput < ::Formtastic::Inputs::SelectInput
      include ActiveAdminTheme::Inputs::SearchableSelectBehavior
    end

    module Filters
      class SearchableSelectInput < ::ActiveAdmin::Inputs::Filters::SelectInput
        include ActiveAdminTheme::Inputs::SearchableSelectBehavior

        # The filter's `collection` plucks a column's distinct values when there is one.
        def pluck_column
          collection_from_association
        end
      end
    end
  end
end
