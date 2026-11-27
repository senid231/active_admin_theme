module ActiveAdminTheme
  module Views
    # tabs do
    #   tab("Details") { ... }
    #   tab("History", id: "history") { ... }
    # end
    #
    # Built on Flowbite's tabs (data-tabs-toggle / data-tabs-target), which
    # ActiveAdmin already loads, so no extra script is needed.
    class Tabs < ActiveAdmin::Component
      builder_method :tabs

      def build(options = {})
        super(options)
        add_class "aat-tabs"
        @tab_ids = []
        base = Tabs.unique_id(helpers, "aat-tabs")
        @nav = ul(class: "aat-tabs-nav", role: "tablist", id: "#{base}-nav", "data-tabs-toggle": "##{base}-panels")
        @panels = div(id: "#{base}-panels")
      end

      # An id no other tab on the page has: two components may share titles.
      # It starts with a letter, since Flowbite passes it to querySelector.
      def self.unique_id(view, base)
        base = "tab-#{base}" unless base.match?(/\A[a-z]/i)
        id = base
        number = 1
        id = "#{base}-#{number += 1}" while taken_ids(view).include?(id)
        claim_id(view, id)
      end

      # An explicit id is kept as given.
      def self.claim_id(view, id)
        taken_ids(view) << id
        id
      end

      # Kept on the view, which renders the whole page.
      def self.taken_ids(view)
        view.instance_variable_get(:@aat_tab_ids) || view.instance_variable_set(:@aat_tab_ids, Set.new)
      end

      # An instance method, not a global builder_method, so `tab` stays free
      # for other components.
      def tab(title, options = {}, &block)
        insert_tag Tab, title, options, &block
      end

      def add_child(child)
        if @panels && child.is_a?(Tab)
          @panels << child
        else
          super
        end
      end

      def add_tab_button(title, id)
        first = @tab_ids.empty?
        @tab_ids << id
        with_current_arbre_element(@nav) do
          li(class: "aat-tab-item", role: "presentation") do
            button(title, type: "button", class: "aat-tab", role: "tab", id: "#{id}-tab",
                          "data-tabs-target": "##{id}", "aria-controls": id,
                          "aria-selected": first.to_s)
          end
        end
        first
      end
    end

    class Tab < ActiveAdmin::Component
      def build(title, options = {})
        # As in ActiveAdmin 3: a Symbol title shows titleized, and its id follows.
        title = title.to_s.titleize if title.is_a?(Symbol)
        id = options.delete(:id)
        id = id ? Tabs.claim_id(helpers, id.to_s) : Tabs.unique_id(helpers, title.to_s.parameterize.presence || "tab")
        tabs = [parent, parent&.parent].find { |element| element.is_a?(Tabs) }
        first = tabs ? tabs.add_tab_button(title, id) : true
        super(options.merge(id: id, role: "tabpanel", "aria-labelledby": "#{id}-tab"))
        add_class "aat-tab-panel"
        add_class "hidden" unless first
      end
    end
  end
end
