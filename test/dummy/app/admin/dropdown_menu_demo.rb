# Demo of the dropdown_menu component. The links go to the echo action below,
# which prints the verb and the parameters instead of changing data.
ActiveAdmin.register_page "Dropdown menu" do
  menu false

  action_item :plain do
    link_to "Plain", "#", class: "action-item-button"
  end
  action_item :export_list do
    dropdown_menu_tag "Export", [
      ["CSV", "/admin/dropdown_menu/echo?to=csv"],
      ["Fish & Chips", "/admin/dropdown_menu/echo?to=fish", {class: "fish-link"}],
      ["Purge", "/admin/dropdown_menu/echo", {method: :delete, data: {confirm: "Purge everything?"}}]
    ]
  end
  action_item :export_block do
    dropdown_menu_tag "Export" do
      item "XML", "/admin/dropdown_menu/echo?to=xml"
    end
  end
  action_item :more do
    dropdown_menu_tag "More" do
      item "Archive", "/admin/dropdown_menu/echo?to=archive"
      item "Delete", "/admin/dropdown_menu/echo", method: :delete, data: {confirm: "Delete it?"}
    end
  end
  action_item :empty do
    dropdown_menu_tag "Empty", []
  end

  page_action :echo, method: [:get, :delete] do
    submitted = params.to_unsafe_h.except("authenticity_token", "_method", "controller", "action")
    render plain: "#{request.request_method} #{submitted.to_json}"
  end

  content do
    panel "Dropdown in the page" do
      dropdown_menu "Panel menu", id: "panel-menu" do
        item "Open", "/admin/dropdown_menu/echo?to=open"
        item "Close", "/admin/dropdown_menu/echo?to=close"
      end
    end
  end
end
