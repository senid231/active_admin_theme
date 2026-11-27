module ActiveAdminTheme
  module LinkSidebars
    # related_records_sidebar do |customer|
    #   link "Orders", admin_orders_path(q: {customer_id_eq: customer.id}), count: -> { customer.orders.count }
    # end
    # external_links_sidebar { |customer| link "Billing", "https://billing.example/#{customer.id}" }
    # related_records_sidebar do |customer|
    #   group("Shipping") { link "Parcels", admin_parcels_path, count: customer.parcels }
    # end
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
    Link = Struct.new(:label, :href, :count, :condition, :group, keyword_init: true)
    GROUP_HEADINGS = [:auto, true, false].freeze
    # With :auto, headings show above this many links.
    HEADINGS_FROM = 6

    # What the sidebar block runs in: `link` collects, anything else goes to
    # the view, so path helpers and `authorized?` work.
    class Collector < BasicObject
      attr_reader :links

      def initialize(view)
        @view = view
        @links = []
        @group = nil
      end

      # Links declared in the block belong to the group +name+.
      def group(name, &block)
        ::Kernel.raise ::ArgumentError, "group: groups do not nest" if @group
        ::Kernel.raise ::ArgumentError, "group needs a block that calls link" unless block

        @group = name.to_s
        begin
          block.call
        ensure
          @group = nil
        end
      end

      def link(label, href, count: nil, **options)
        unknown = options.keys - [:if]
        ::Kernel.raise ::ArgumentError, "link: unknown option #{unknown.map(&:inspect).join(", ")}, known options are :count, :if" if unknown.any?

        @links << Link.new(label: label, href: href, count: count, condition: options[:if], group: @group)
      end

      def method_missing(name, *, **, &)
        @view.public_send(name, *, **, &)
      end
    end

    class Section < ActiveAdmin::SidebarSection
      def initialize(kind, title, options, links_block, group_headings = :auto)
        unless GROUP_HEADINGS.include?(group_headings)
          raise ArgumentError, "group_headings: #{group_headings.inspect} is not one of #{GROUP_HEADINGS.map(&:inspect).join(", ")}"
        end

        @kind = kind
        @title = title
        @links_block = links_block
        @group_headings = group_headings
        section = self
        super(title || TITLES.fetch(kind), options) do
          div(class: "aat-link-lists") do
            section.lists(helpers).each_with_index do |(heading, links), index|
              heading_id = "#{section.id}-group-#{index}" if heading
              h4 heading, class: "aat-link-group", id: heading_id if heading
              list_attributes = {class: "aat-link-list"}
              list_attributes[:"aria-labelledby"] = heading_id if heading
              ul(**list_attributes) do
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

      # [heading or nil, links] pairs in render order: ungrouped links first,
      # then each group. Without headings there is one list, in declaration
      # order.
      def lists(view)
        links = visible_links(view)
        groups = links.filter_map(&:group).uniq
        return [[nil, links]] unless headings?(links, groups)

        ungrouped = links.reject(&:group)
        lists = ungrouped.any? ? [[nil, ungrouped]] : []
        lists + groups.map { |group| [group, links.select { |link| link.group == group }] }
      end

      # A value, a lambda, or anything that answers `count`, such as a
      # relation, which a lambda may return as well. nil shows no count.
      def count_of(view, link)
        value = link.count.respond_to?(:call) ? view.instance_exec(&link.count) : link.count
        case value
        when nil, Numeric, String then value
        else value.respond_to?(:count) ? value.count : value
        end
      end

      private

      def headings?(links, groups)
        case @group_headings
        when true then groups.any?
        when false then false
        else groups.size > 1 && links.size >= HEADINGS_FROM
        end
      end

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
        group_headings = options.delete(:group_headings) { :auto }
        options[:only] = :show unless options.key?(:only) || options.key?(:except)
        config.sidebar_sections << Section.new(kind, title, options, block, group_headings)
      end
    end
  end
end

unless ActiveAdmin::ResourceDSL.method_defined?(:related_records_sidebar)
  ActiveAdmin::ResourceDSL.include ActiveAdminTheme::LinkSidebars::ResourceDSL
end
