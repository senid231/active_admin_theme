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
    OPTIONS = %i[scope label search allow_empty_search value order per_page additional_payload].freeze
    ALIASES = %i[display_text text_attribute filter apply_search].freeze

    class << self
      def source(name, options)
        unknown = options.keys - OPTIONS - ALIASES
        raise ArgumentError, "searchable_select_options: unknown option #{unknown.map(&:inspect).join(", ")}" if unknown.any?

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
          per_page: options[:per_page] || DEFAULT_PER_PAGE,
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

        scope = apply_search(controller, scope, klass, source, term, authorization) if term.present?
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

      def per_page(source, params)
        requested = params[:per_page].to_i
        requested.positive? ? [requested, [source[:per_page], MAX_PER_PAGE].max].min : source[:per_page]
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

        scope.reorder(order || {klass.primary_key => :desc})
      end
    end
  end
end

ActiveAdmin::Resource.include ActiveAdminTheme::SearchableSelect::ResourceExtension
unless ActiveAdmin::ResourceDSL.method_defined?(:searchable_select_options)
  ActiveAdmin::ResourceDSL.include ActiveAdminTheme::SearchableSelect::ResourceDSL
end
