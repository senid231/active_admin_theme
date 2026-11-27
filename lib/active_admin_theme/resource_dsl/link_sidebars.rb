module ActiveAdminTheme
  module LinkSidebars
    # related_records_sidebar do |customer|
    #   link "Orders", admin_orders_path(q: {customer_id_eq: customer.id}), count: -> { customer.orders.count }
    # end
    # external_links_sidebar { |customer| link "Billing", "https://billing.example/#{customer.id}" }
    #
    # Sidebar sections of links. The README lists the options.
    module ResourceDSL
      def related_records_sidebar(title: nil, **options, &block)
        ActiveAdminTheme::LinkSidebars.add(config, :related_records, title, options, block)
      end

      def external_links_sidebar(title: nil, **options, &block)
        ActiveAdminTheme::LinkSidebars.add(config, :external_links, title, options, block)
      end
    end

    TITLES = {related_records: "Related records", external_links: "External links"}.freeze
    Link = Struct.new(:label, :href, :count, :condition, keyword_init: true)

    # What the sidebar block runs in: `link` collects, anything else goes to
    # the view, so path helpers and `authorized?` work.
    class Collector < BasicObject
      attr_reader :links

      def initialize(view)
        @view = view
        @links = []
      end

      def link(label, href, count: nil, **options)
        unknown = options.keys - [:if]
        ::Kernel.raise ::ArgumentError, "link: unknown option #{unknown.map(&:inspect).join(", ")}, known options are :count, :if" if unknown.any?

        @links << Link.new(label: label, href: href, count: count, condition: options[:if])
      end

      def method_missing(name, *, **, &)
        @view.public_send(name, *, **, &)
      end
    end

    class Section < ActiveAdmin::SidebarSection
      def initialize(kind, title, options, links_block)
        @kind = kind
        @title = title
        @links_block = links_block
        section = self
        super(title || TITLES.fetch(kind), options) do
          links = section.visible_links(helpers)
          ul(class: "aat-link-list") do
            links.each do |link|
              li do
                attributes = {href: link.href}
                attributes.merge!(target: "_blank", rel: "noopener noreferrer") if section.external?
                a(**attributes) do
                  span link.label, class: "aat-link-label"
                  count = section.count_of(helpers, link)
                  span count.to_s, class: "aat-link-count" unless count.nil?
                end
              end
            end
          end
        end
      end

      def external?
        @kind == :external_links
      end

      def display_title
        @title || I18n.t("active_admin_theme.sidebars.#{@kind}", default: TITLES.fetch(@kind))
      end

      # An empty sidebar is not rendered. Without a render context there are
      # no links to count.
      def display_on?(action, render_context = self)
        super && (render_context.nil? || visible_links(render_context).any?)
      end

      def visible_links(view)
        collector = Collector.new(view)
        collector.instance_exec(view.params[:id].present? ? view.resource : nil, &@links_block)
        collector.links.select { |link| shown?(view, link.condition) }
      end

      def count_of(view, link)
        link.count.respond_to?(:call) ? view.instance_exec(&link.count) : link.count
      end

      private

      def shown?(view, condition)
        case condition
        when nil then true
        when Symbol, String then view.public_send(condition)
        else view.instance_exec(&condition)
        end
      end
    end

    class << self
      def add(config, kind, title, options, block)
        raise ArgumentError, "#{kind}_sidebar needs a block that calls link" unless block

        options = options.dup
        options[:only] = :show unless options.key?(:only) || options.key?(:except)
        config.sidebar_sections << Section.new(kind, title, options, block)
      end
    end
  end
end

unless ActiveAdmin::ResourceDSL.method_defined?(:related_records_sidebar)
  ActiveAdmin::ResourceDSL.include ActiveAdminTheme::LinkSidebars::ResourceDSL
end
