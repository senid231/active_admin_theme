module ActiveAdminTheme
  module SearchableSelect
    # searchable_select_options label: :name, search: :name_cont, per_page: 25
    #
    # Adds the collection action `<name>_options`, which serves the
    # `searchable_select` inputs. The README lists the options and the reply.
    module ResourceDSL
      # `filter:` is lambda(term, scope), the argument order of
      # activeadmin-searchable_select; `search:` and `apply_search:` take (scope, term).
      def searchable_select_options(name = nil, **options)
        source = ActiveAdminTheme::SearchableSelect.source(options.delete(:name) || name || :all, options)
        config.searchable_select_sources[source[:name]] = source

        collection_action source[:action], method: :get do
          authorize! ActiveAdmin::Authorization::READ, active_admin_config.resource_class
          render json: ActiveAdminTheme::SearchableSelect.page(self, source)
        end
      end
    end

    module ResourceExtension
      def searchable_select_sources
        @searchable_select_sources ||= {}
      end

      def searchable_select_path(name = :all)
        source = searchable_select_sources[name.to_sym]
        raise ArgumentError, "#{resource_name} has no searchable_select_options :#{name}" unless source

        "#{route_collection_path}/#{source[:action]}"
      end
    end

    DEFAULT_PER_PAGE = 50
    MAX_PER_PAGE = 500
    DEFAULT_ID_PREFIX = "id:".freeze
    OPTIONS = %i[scope label search allow_empty_search value order per_page additional_payload id_search].freeze
    ALIASES = %i[display_text text_attribute filter apply_search].freeze

    class << self
      def source(name, options)
        unknown = options.keys - OPTIONS - ALIASES
        if unknown.any?
          raise ArgumentError, "searchable_select_options: unknown option #{unknown.map(&:inspect).join(", ")}, known options are #{(OPTIONS + ALIASES).map(&:inspect).join(", ")}"
        end

        attribute = options[:text_attribute]
        filter = options[:filter]
        {
          name: name.to_sym,
          action: :"#{name}_options",
          scope: options[:scope],
          label: options[:label] || options[:display_text] || attribute,
          search: options[:search] || options[:apply_search] || (filter && ->(scope, term) { filter.call(term, scope) }) || (attribute && :"#{attribute}_cont"),
          allow_empty_search: options.fetch(:allow_empty_search, true),
          value: options[:value] || :id,
          order: options[:order],
          per_page: options[:per_page],
          id_prefix: id_prefix(options[:id_search]),
          additional_payload: options[:additional_payload]
        }
      end

      # A dependent select passes on its parent's value, and that may be the
      # None marker of active_admin_filter_extensions: it searches `_null` here
      # as it does on the index.
      def none_option_filters(filters)
        return filters unless defined?(ActiveAdminFilterExtensions::NoneOption)

        filters = filters.respond_to?(:to_unsafe_h) ? filters.to_unsafe_h : filters.to_h
        marker = ActiveAdminFilterExtensions.none_value
        keys = filters.filter_map do |key, value|
          key.to_s if key.to_s.match?(ActiveAdminFilterExtensions::NoneOption::KEY) && Array.wrap(value).include?(marker)
        end
        keys.empty? ? filters : ActiveAdminFilterExtensions::NoneOption.search_params(filters, keys, marker)
      end

      # Runs inside the resource controller's collection action.
      def page(controller, source)
        params = controller.params
        term = params[:term].to_s.strip
        return reply([], false) if term.empty? && !source[:allow_empty_search]

        authorization = controller.send(:active_admin_authorization)
        scope = base_scope(controller, source, params)
        scope = authorization.scope_collection(scope, ActiveAdmin::Authorization::READ)
        scope = scope.all
        klass = scope.klass
        filters = params[:q].respond_to?(:to_unsafe_h) ? params[:q] : {}
        scope = scope.ransack(none_option_filters(filters), auth_object: authorization).result

        if term.present?
          id = id_term(klass, source, term)
          scope = id ? scope.where(id_column(klass, source) => id) : apply_search(controller, scope, klass, source, term, authorization)
        end
        scope = apply_order(controller, scope, klass, source)

        per_page = per_page(source, params)
        page = [params[:page].to_i, 1].max
        records = scope.offset((page - 1) * per_page).limit(per_page + 1).to_a
        reply(records.first(per_page).map { |record| result(controller, source, record) }, records.size > per_page)
      end

      # The records an input on another resource's page may show as selected:
      # the read scope of the resource that has the endpoint, narrowed by a
      # `scope:` that takes no params. The page has no endpoint params for one
      # that takes them.
      def selected_scope(controller, resource, source, klass)
        authorization = resource ? authorization_for(controller, resource) : controller.send(:active_admin_authorization)
        return klass.none unless authorization.authorized?(ActiveAdmin::Authorization::READ, klass)

        scope = source&.dig(:scope)
        scope = scope&.arity&.zero? ? controller.instance_exec(&scope) : klass
        authorization.scope_collection(scope.all, ActiveAdmin::Authorization::READ).all
      end

      private

      def authorization_for(controller, resource)
        adapter = resource.namespace.authorization_adapter
        adapter = adapter.constantize if adapter.is_a?(String)
        adapter.new(resource, controller.send(:current_active_admin_user))
      end

      def reply(results, more)
        {results: results, pagination: {more: more}}
      end

      def result(controller, source, record)
        item = {id: call(controller, source[:value], record), text: label(controller, source, record).to_s}
        payload = source[:additional_payload]
        payload ? item.merge(controller.instance_exec(record, &payload).to_h) : item
      end

      def base_scope(controller, source, params)
        scope = source[:scope]
        return controller.send(:scoped_collection) unless scope

        scope.arity.zero? ? controller.instance_exec(&scope) : controller.instance_exec(params, &scope)
      end

      def id_prefix(id_search)
        case id_search
        when nil, false then nil
        when true then DEFAULT_ID_PREFIX
        when String
          raise ArgumentError, "searchable_select_options: id_search: must not be an empty String" if id_search.strip.empty?

          id_search.strip
        else
          raise ArgumentError, "searchable_select_options: id_search: must be true, false or a String prefix, not #{id_search.inspect}"
        end
      end

      # The exact id the term asks for (`id:123`), or nil for a text search. An
      # integer column takes digits only, so `#abc` stays a text search.
      def id_term(klass, source, term)
        prefix = source[:id_prefix]
        return unless prefix && term.downcase.start_with?(prefix.downcase)

        id = term[prefix.length..].strip
        return if id.empty?
        column = id_column(klass, source)
        # One term cannot name a composite key; search it as text.
        return if column.is_a?(Array)
        return if klass.type_for_attribute(column).type == :integer && !id.match?(/\A\d+\z/)

        id
      end

      # The `value:` attribute when it is a column, else the primary key.
      def id_column(klass, source)
        value = source[:value].to_s
        klass.column_names.include?(value) ? value : klass.primary_key
      end

      def per_page(source, params)
        default = source[:per_page] || ActiveAdminTheme.searchable_select_per_page || DEFAULT_PER_PAGE
        requested = params[:per_page].to_i
        requested.positive? ? [requested, [default, MAX_PER_PAGE].max].min : default
      end

      def label_methods
        Formtastic::FormBuilder.collection_label_methods
      end

      def label_column(klass, source)
        names = [source[:label], *label_methods].select { |name| name.is_a?(Symbol) || name.is_a?(String) }
        names.find { |name| klass.column_names.include?(name.to_s) }
      end

      def label(controller, source, record)
        return call(controller, source[:label], record) if source[:label]

        call(controller, label_methods.find { |name| record.respond_to?(name) }, record)
      end

      def call(controller, method_or_proc, record)
        method_or_proc.respond_to?(:call) ? controller.instance_exec(record, &method_or_proc) : record.public_send(method_or_proc)
      end

      def apply_search(controller, scope, klass, source, term, authorization)
        search = source[:search]
        return controller.instance_exec(scope, term, &search) if search.respond_to?(:call)
        return scope.search(term) if search.nil? && klass.respond_to?(:search)

        unless search
          column = label_column(klass, source)
          raise ArgumentError, "searchable_select_options for #{klass.name} needs search:, none of #{label_methods.join(", ")} is a column" unless column

          search = "#{column}_cont"
        end
        scope.ransack({search => term}, auth_object: authorization).result
      end

      def apply_order(controller, scope, klass, source)
        order = source[:order]
        return controller.instance_exec(scope, &order) if order.respond_to?(:call)

        # A composite primary key is an Array of columns.
        scope.reorder(order || Array(klass.primary_key).to_h { |column| [column, :desc] })
      end
    end
  end
end

ActiveAdmin::Resource.include ActiveAdminTheme::SearchableSelect::ResourceExtension
unless ActiveAdmin::ResourceDSL.method_defined?(:searchable_select_options)
  ActiveAdmin::ResourceDSL.include ActiveAdminTheme::SearchableSelect::ResourceDSL
end
